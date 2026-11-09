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
  - 1.0.0 (2026-11-09): -forkProcessSnapshot (every process of Nyxian's
    kernel: pid, parent, group, session, name, state, CPU, memory, threads)
    and -forkSendSignal:toProcessIdentifier: for the process monitor.
*/

#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#import <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <LindChain/ProcEnvironment/Surface/proc/spawn.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <Frameworks/LiveProcessLegacy/LindChain/Services/bootstrapd/LDEApplicationWorkspace.h>
#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <Nyxian-Swift.h>
#import <os/lock.h>
#include <mach/mach_time.h>

@implementation PEProcessManager {
    NSMutableDictionary<NSNumber*,PEProcess*> *_processes;
    os_unfair_lock _lock;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _processes = [[NSMutableDictionary alloc] init];
        if(_processes == nil)
        {
            return nil;
        }
        _lock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

+ (instancetype)shared
{
    static PEProcessManager *processManagerSingletone = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processManagerSingletone = [[PEProcessManager alloc] init];
    });
    return processManagerSingletone;
}

- (pid_t)spawnProcessWithItems:(NSDictionary*)items
      withKernelSurfaceProcess:(ksurface_proc_t*)proc
{    
    /* creating a process */
    PEProcess *process = [[PEProcess alloc] initWithItems:items withKernelSurfaceProcess:proc ?: kernel_proc_];
    if(process == nil)
    {
        return -1;
    }
    
    /* getting process identifier */
    pid_t pid = process.pid;
    if(pid < 0)
    {
        return -1;
    }
    
    /* inserting process */
    [process addObserver:self];
    os_unfair_lock_lock(&_lock);
    [_processes setObject:process forKey:@(pid)];
    os_unfair_lock_unlock(&_lock);
    
    /* returning pid */
    return pid;
}

- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier
                                withItems:(NSDictionary*)items
                 withKernelSurfaceProcess:(ksurface_proc_t*)proc
                       doRestartIfRunning:(BOOL)doRestartIfRunning
{
    PEProcess *existingProcess = [self processForBundleIdentifier:bundleIdentifier];
    if(existingProcess != nil)
    {
        NXWindowSession *windowSession = [[NXWindowServer shared] windowSessionForBundleIdentifier:existingProcess.bundleIdentifier];
        if(windowSession != nil && windowSession.window != nil && !doRestartIfRunning)
        {
            
            if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
            {
                [[NXWindowServer shared] activateWindowForIdentifier:windowSession.windowIdentifier animated:true withCompletion:nil];
            }
            else
            {
                [windowSession.window focusWindow];
            }
            return existingProcess.pid;
        }
        else
        {
            [existingProcess forceTerminate];
        }
    }
    
    LDEApplicationObject *applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForBundleID:bundleIdentifier];
    if(applicationObject == nil)
    {
        errno = EAGAIN;
        return -1;
    }
    
    /* creating process */
    NSMutableDictionary *mutableItems = [items mutableCopy];
    
    [mutableItems setValuesForKeysWithDictionary:@{
        @"PEExecutablePath": applicationObject.executablePath,
        @"PEArguments": @[
            applicationObject.executablePath
        ],
        @"PEEnvironment": @{
            @"HOME": applicationObject.containerPath,
            @"CFFIXED_USER_HOME": applicationObject.containerPath,
            @"TMPDIR": [applicationObject.containerPath stringByAppendingPathComponent:@"/Tmp"]
        },
        @"PEWorkingDirectory": [applicationObject.containerPath stringByAppendingPathComponent:@"/Documents"],
    }];
    
    PEProcess *process = [[PEProcess alloc] initWithItems:mutableItems withKernelSurfaceProcess:proc ?: kernel_proc_];
    if(process == nil)
    {
        return -1;
    }
    
    /* getting pid of process */
    pid_t pid = process.pid;
    if(pid < 0)
    {
        return -1;
    }
    
    /* setting process */
    [process addObserver:self];
    os_unfair_lock_lock(&_lock);
    [_processes setObject:process forKey:@(pid)];
    os_unfair_lock_unlock(&_lock);

    return pid;
}

- (PEProcess*)processForProcessIdentifier:(pid_t)pid
{
    PEProcess *process = nil;
    os_unfair_lock_lock(&_lock);
    process = [_processes objectForKey:@(pid)];
    os_unfair_lock_unlock(&_lock);
    return process;
}

- (PEProcess*)processForBundleIdentifier:(NSString*)bundleIdentifier
{
    os_unfair_lock_lock(&_lock);
    for(PEProcess *process in _processes.allValues)
    {
        if(process && [process.bundleIdentifier isEqualToString:bundleIdentifier])
        {
            os_unfair_lock_unlock(&_lock);
            return process;
        }
    }
    os_unfair_lock_unlock(&_lock);
    return nil;
}

- (void)process:(PEProcess *)process didExitWithWait4Code:(int)code
{
    [process removeObserver:self];
    os_unfair_lock_lock(&_lock);
    [_processes removeObjectForKey:@(process.pid)];
    os_unfair_lock_unlock(&_lock);
}

- (void)closeIfRunningUsingBundleIdentifier:(NSString*)bundleIdentifier
{
    PEProcess *process = [self processForBundleIdentifier:bundleIdentifier];
    if(process)
    {
        [process forceTerminate];
    }
}

- (void)killAllRunningProcesses;
{
    os_unfair_lock_lock(&_lock);
    for(PEProcess *process in _processes.allValues)
    {
        [process sendSignal:SIGKILL];
    }
    os_unfair_lock_unlock(&_lock);
}

/* MARK: fork — process monitor */

- (NSArray<NSDictionary<NSString*,id>*>*)forkProcessSnapshot
{
    kinfo_proc_t *kp = NULL;
    size_t len = 0;
    if(proc_list(kernel_proc_, &kp, &len, PROC_FLV_ALL, 0) != KERN_SUCCESS || kp == NULL)
    {
        return @[];
    }
    NSMutableArray *result = [NSMutableArray array];
    size_t count = len / sizeof(kinfo_proc_t);
    for(size_t i = 0; i < count; i++)
    {
        pid_t pid = kp[i].kp_proc.p_pid;
        NSString *comm = [NSString stringWithUTF8String:kp[i].kp_proc.p_comm] ?: @"";
        NSString *state;
        switch(kp[i].kp_proc.p_stat)
        {
            case SSTOP: state = @"stopped"; break;
            case SZOMB: state = @"zombie"; break;
            case SIDL:  state = @"starting"; break;
            default:    state = @"running"; break;
        }
        NSMutableDictionary *entry = [@{
            @"pid": @(pid),
            @"ppid": @(kp[i].kp_eproc.e_ppid),
            @"uid": @(kp[i].kp_eproc.e_ucred.cr_uid),
            @"name": comm,
            @"state": state,
        } mutableCopy];
        ksurface_proc_t *proc = NULL;
        if(proc_for_pid(pid, &proc) == KERN_SUCCESS && proc != NULL)
        {
            kvo_rdlock(proc);
            entry[@"pgid"] = @(proc->nyx.pgid);
            entry[@"sid"] = @(proc->nyx.sid);
            uint64_t start = proc->nyx.start_abstime;
            kvo_unlock(proc);
            kvo_release(proc);
            if(start > 0)
            {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t now = mach_absolute_time();
                if(now > start && tb.denom != 0)
                {
                    entry[@"uptime"] = @((double)(now - start) * tb.numer / tb.denom / 1e9);
                }
            }
        }
        PEProcess *process = [self processForProcessIdentifier:pid];
        if(process != nil)
        {
            if(process.displayName.length) entry[@"displayName"] = process.displayName;
            if(process.bundleIdentifier.length) entry[@"bundleIdentifier"] = process.bundleIdentifier;
            if(process.executablePath.length) entry[@"executablePath"] = process.executablePath;
            NSDictionary *usage = [process forkResourceUsage];
            if(usage != nil) [entry addEntriesFromDictionary:usage];
        }
        [result addObject:entry];
    }
    free(kp);
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"pid"] compare:b[@"pid"]];
    }];
    return result;
}

- (BOOL)forkSendSignal:(int)signal toProcessIdentifier:(pid_t)pid
{
    ksurface_proc_t *proc = NULL;
    if(proc_for_pid(pid, &proc) != KERN_SUCCESS || proc == NULL)
    {
        return NO;
    }
    kern_return_t kr = proc_kill(proc, signal);
    kvo_release(proc);
    return kr == KERN_SUCCESS;
}

@end
