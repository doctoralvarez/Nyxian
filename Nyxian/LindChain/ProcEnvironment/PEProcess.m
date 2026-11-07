/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-07): -forkResourceUsage (CPU %, memory footprint and
    thread count of the process, read through its task port) for the
    profiler in the console.
*/

#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <LindChain/ProcEnvironment/PEProcess.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/ProcEnvironment/PEExtension.h>
#import <LindChain/ProcEnvironment/PEUserspaceManager.h>
#import <LindChain/ProcEnvironment/PEMachPort.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Surface/proc/proctil.h>
#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <LindChain/ProcEnvironment/PEFileTable.h>
#import <LindChain/ProcEnvironment/PEFileHandle.h>
#import <LindChain/ProcEnvironment/Shims/posix_spawn.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/tty/tty.h>
#import <LindChain/Private/mach/fileport.h>
#include <mach/mach.h>
#include <unistd.h>

static void PEAttachControllingTTYForSpawn(NSDictionary *items,
                                           ksurface_proc_t *child)
{
    PEFileTable *fileTable = items[@"PEFileTable"];
    if(fileTable == nil)
    {
        return;
    }
    
    /* TODO: go through the entire file table */
    PEFileHandle *stdinHandle = fileTable.fd_map[@(STDIN_FILENO)];
    if(stdinHandle == nil)
    {
        return;
    }
    
    int fd = [stdinHandle extractFileDescriptor];
    if(fd < 0)
    {
        return;
    }
    
    fileport_t port = MACH_PORT_NULL;
    if(fileport_makeport(fd, &port) != 0)
    {
        close(fd);
        return;
    }
    close(fd);
    
    ksurface_tty_t *tty = NULL;
    kern_return_t kr = tty_for_port(port, &tty);
    mach_port_deallocate(mach_task_self(), port);
    if(kr != KERN_SUCCESS || tty == NULL)
    {
        return;
    }
    
    if(tty_attach_proc(child, tty) != KERN_SUCCESS)
    {
        kvo_release(tty);
    }
}

@implementation PEProcess {
    NSHashTable<id<PEProcessObserver>> *_observers;
    os_unfair_lock _lock;
    _Atomic(int) _termState;
    _Atomic(int) _counted;
}

- (instancetype)initWithItems:(NSDictionary*)items
     withKernelSurfaceProcess:(ksurface_proc_t*)proc
{
    if(proc == NULL ||
       proctil(kProctilActionCount) != KERN_SUCCESS)
    {
        return nil;
    }
    
    self = [super init];
    if(self == nil)
    {
        proctil(kProctilActionUncount);
        return nil;
    }
    atomic_store(&_counted, true);
    
    _observers = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality capacity:0];
    _lock = OS_UNFAIR_LOCK_INIT;
    
    if(proctil(kProctilActionLock) != KERN_SUCCESS)
    {
        proctil(kProctilActionUncount);
        return nil;
    }
    
    self.executablePath = items[@"PEExecutablePath"];
    if(self.executablePath == nil)
    {
        proctil(kProctilActionUnlock);
        return nil;
    }
    
    short spawnFlags = [items[@"PEPOSIXSpawnFlags"] shortValue];
    pid_t spawnPgroup = (pid_t)[items[@"PEPOSIXSpawnPgroup"] intValue];
    
    if((spawnFlags & POSIX_SPAWN_SETSID) &&
       (spawnFlags & POSIX_SPAWN_SETPGROUP))
    {
        proctil(kProctilActionUnlock);
        return nil;
    }
    
    if((spawnFlags & POSIX_SPAWN_SETPGROUP) && spawnPgroup < 0)
    {
        proctil(kProctilActionUnlock);
        return nil;
    }
    
    if((spawnFlags & POSIX_SPAWN_SETPGROUP) && spawnPgroup > 0)
    {
        kvo_rdlock(proc);
        pid_t parentSid = proc_getsid(proc);
        kvo_unlock(proc);
        
        if(!proc_pgrp_exists_in_session(spawnPgroup, parentSid))
        {
            proctil(kProctilActionUnlock);
            return nil;
        }
    }
    
    kvo_rdlock(proc);
    ksurface_trust_identity_t *identity = trust_identity_create_from_path_with_parent_identity([self.executablePath UTF8String], proc->nyx.identity);
    if(identity == NULL)
    {
        kvo_unlock(proc);
        proctil(kProctilActionUnlock);
        return nil;
    }
    
    /* TODO: later on we need to drop allow it to become tighter by using the still not existing trust_identity_create_from_path_with_parent_identity */
    ksurface_trust_identity_t *sb_identity = (proc == kernel_proc_) ? identity : proc->nyx.identity;    /* dont allow sandbox escape by spawning children */
    if(sb_identity->filePermissions != NULL)
    {
        NSMutableDictionary *mutableItems = [items mutableCopy];
        [mutableItems setObject:(__bridge NSArray*)sb_identity->filePermissions forKey:@"PEFilePermissions"];
        items = mutableItems;
    }
    kvo_unlock(proc);
    
    /* assigning potential bundle information */
    self.applicationObject = nil;
    if(PEUserspaceManager.shared.isLaunchServiceManagerStable)
    {
        self.applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForExecutablePath:self.executablePath];
    }
    self.bundleIdentifier = self.applicationObject ? self.applicationObject.bundleIdentifier : nil;
    self.displayName = self.applicationObject ? self.applicationObject.localizedName : [self.executablePath lastPathComponent];
    
    /* spawning process */
    self.process = PESpawnFBProcess(items, &(self->_pid), &(self->_pidv));
    if(self.process == nil)
    {
        proctil(kProctilActionUnlock);
        return nil;
    }
    
    [self.process addObserver:self];
    if(!self.process.running)
    {
        /*
         * prevents a race condition, when we add a observer
         * and it already died then we shall handle the exit.
         */
        proctil(kProctilActionUnlock);
        return nil;
    }
    
    ksurface_proc_t *child = NULL;
    kern_return_t kr = proc_spawn(proc ?: kernel_proc_, &child, self.pid, self.pidv, identity);
    if(kr != KERN_SUCCESS)
    {
        [self terminate];
        proctil(kProctilActionUnlock);
        return nil;
    }
    else
    {
        if(spawnFlags & POSIX_SPAWN_SETSID)
        {
            kvo_wrlock(child);
            proc_setsid(child, self.pid);
            proc_setpgid(child, self.pid);
            child->bsd.kp_proc.p_flag &= ~P_CONTROLT;
            child->bsd.kp_eproc.e_tdev = -1;
            child->bsd.kp_eproc.e_tpgid = -1;
            kvo_unlock(child);
            PEAttachControllingTTYForSpawn(items, child);
        }
        else if(spawnFlags & POSIX_SPAWN_SETPGROUP)
        {
            pid_t desiredPgroup = spawnPgroup == 0 ? self.pid : spawnPgroup;
            kvo_wrlock(child);
            proc_setpgid(child, desiredPgroup);
            kvo_unlock(child);
        }
        
        self.proc = child;
    }
    
    proctil(kProctilActionUnlock);
    return self;
}

- (void)sendSignal:(int)signal
{
    /*
     * those signals are not supported at all
     * (for now atleast).
     */
    if(signal == SIGTTIN ||
       signal == SIGTTOU)
    {
        return;
    }
    
    /*
     * for some reason apple doesnt support SIGTSTP on iOS
     * (maybe we just use it wrong lol)
     */
    if(signal == SIGTSTP)
    {
        signal = SIGSTOP;
    }
    
    /*
     * TODO: this is okay, but we need to use a boolean flag
     *
     * if(signal == SIGSTOP)
     * {
     *     _isSuspended = YES;
     * }
     * else if(signal == SIGCONT)
     * {
     *     _isSuspended = NO;
     * }
     */
    
    [self.process.nsExtension _kill:signal];
    
    if(signal == SIGSTOP)
    {
        kvo_wrlock(_proc);
        _proc->bsd.kp_proc.p_stat = SSTOP;
        
        goto report_signal;
    }
    else if(signal == SIGCONT)
    {
        kvo_wrlock(_proc);
        _proc->bsd.kp_proc.p_stat = SRUN;
        
    report_signal:
        kvo_unlock(_proc);
        proc_state_change(_proc, W_STOPCODE(signal));
    }
}

- (void)forceTerminate
{
    if(atomic_exchange(&_termState, 2) == 2)
    {
        return;
    }
    [self sendSignal:SIGKILL];
}

- (void)terminate
{
    int expected = 0;
    if(atomic_compare_exchange_strong(&_termState, &expected, 1))
    {
        [self sendSignal:SIGTERM];
        
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf forceTerminate];
        });
        return;
    }
    [self forceTerminate];
}

- (void)suspend
{
    [self sendSignal:SIGSTOP];
}

- (void)resume
{
    [self sendSignal:SIGCONT];
}
        
- (void)processDidExit:(FBProcess *)arg1
{
    ksurface_proc_t *proc = self->_proc;
    self->_proc = nil;
    if(proc != NULL)
    {
        /* yep writing official wait4 code~~ */
        proc_state_change(proc, arg1.exitContext.underlyingContext.legacyCode);
        kern_return_t error = proc_zombify(proc);
        if(error != KERN_SUCCESS)
        {
            klog_log("PEProcess:processDidExit", "failed to remove pid %d", _pid);
        }
        kvo_release(proc);
    }
    
    /* notify observers */
    [self enumerateObservers:^(id<PEProcessObserver> observer) {
        [observer process:self didExitWithWait4Code:arg1.exitContext.underlyingContext.legacyCode];
    }];
}

- (void)processWillExit:(FBProcess *)arg1
{
    /* stub for when ever */
}

- (void)process:(FBProcess *)arg1 stateDidChangeFromState:(FBProcessState *)arg2 toState:(FBProcessState *)arg3
{
    /* stub for when ever */
}

- (void)enumerateObservers:(void (^)(id<PEProcessObserver> observer))block
{
    os_unfair_lock_lock(&_lock);
    NSArray<id<PEProcessObserver>> *snapshot = _observers.allObjects;
    os_unfair_lock_unlock(&_lock);
    for(id<PEProcessObserver> observer in snapshot)
    {
        block(observer);
    }
}

- (void)addObserver:(id<PEProcessObserver>)observer
{
    NSParameterAssert(observer);
    os_unfair_lock_lock(&_lock);
    [_observers addObject:observer];
    os_unfair_lock_unlock(&_lock);
}

- (void)removeObserver:(id<PEProcessObserver>)observer
{
    os_unfair_lock_lock(&_lock);
    [_observers removeObject:observer];
    os_unfair_lock_unlock(&_lock);
}

- (void)dealloc
{
    if(atomic_exchange(&_counted, false))
    {
        proctil(kProctilActionUncount);
    }
    
#if DEBUG
    NSLog(@"deallocated %@", self);
#endif /* DEBUG */
}

/* fork: profiler numbers, read through the task port the host keeps for the process */
- (NSDictionary<NSString*,NSNumber*>*)forkResourceUsage
{
    ksurface_proc_t *proc = self.proc;
    if(proc == NULL)
    {
        return nil;
    }
    
    task_special_port_t flavour = TASK_READ_PORT;
    task_t task = MACH_PORT_NULL;
    if(proc_task_for_proc(proc, &flavour, &task) != KERN_SUCCESS || task == MACH_PORT_NULL)
    {
        return nil;
    }
    
    uint64_t footprint = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t vmCount = TASK_VM_INFO_COUNT;
    if(task_info(task, TASK_VM_INFO, (task_info_t)&vmInfo, &vmCount) == KERN_SUCCESS)
    {
        footprint = vmInfo.phys_footprint;
    }
    
    double cpu = 0;
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t threadCount = 0;
    if(task_threads(task, &threads, &threadCount) == KERN_SUCCESS)
    {
        for(mach_msg_type_number_t i = 0; i < threadCount; i++)
        {
            thread_basic_info_data_t info;
            mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
            if(thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)&info, &count) == KERN_SUCCESS && !(info.flags & TH_FLAGS_IDLE))
            {
                cpu += (double)info.cpu_usage / (double)TH_USAGE_SCALE * 100.0;
            }
            mach_port_deallocate(mach_task_self(), threads[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threads, threadCount * sizeof(thread_act_t));
    }
    mach_port_deallocate(mach_task_self(), task);
    
    return @{
        @"cpu": @(cpu),
        @"memory": @(footprint),
        @"threads": @(threadCount)
    };
}

@end
