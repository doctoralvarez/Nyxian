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
 Fork doctoralvarez/Nyxian — version 1.3.0
 Changelog:
  - 1.3.0 (2026-11-12): programs start with NYXIAN_STOREKIT=simulate (unless
    switched off in Permissions) so apps can test in-app purchases with a
    simulated store.
  - 1.2.0 (2026-11-10): -initWithItems: records why a spawn failed
    (PEProcessSpawnFailure, logged as PEProcess:spawn) so posix_spawn can
    return a telling error instead of always EPERM. PEForkSigningReport
    (only reads the NXT2 blobs: building an identity could sign the file again
    while Nyxian was signing a runtime).
  - 1.1.0 (2026-11-07): NXForkDebugger (end of file) — debugger for apps run
    from Nyxian: pause / continue, stop on traps, hardware line breakpoints,
    backtraces with file:line from DWARF line tables of the build's objects.
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
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>
#import <LindChain/ProcEnvironment/Surface/trust/signing.h>
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

int PEProcessSpawnFailure = PEProcessSpawnFailureNone;

/* fork: remembers and logs why a spawn failed, then gives nil */
static id PEForkSpawnFailed(int reason, NSString *path)
{
    static const char *names[] = { "none", "busy", "arguments", "identity (signature or entitlements)", "launch (LiveProcess)", "exited right away", "register" };
    int savedErrno = errno;
    PEProcessSpawnFailure = reason;
    klog_log("PEProcess:spawn", "cannot spawn %s: %s (errno %d)", [path isKindOfClass:[NSString class]] ? path.UTF8String : "?", (reason >= 0 && reason <= 6) ? names[reason] : "?", savedErrno);
    return nil;
}

NSString *PEForkSigningReport(NSArray<NSString *> *paths)
{
    NSMutableString *text = [NSMutableString string];
    for(NSString *path in paths)
    {
        [text appendFormat:@"%@\n", path];
        if(access(path.fileSystemRepresentation, R_OK) != 0)
        {
            [text appendFormat:@"  not readable (errno %d)\n", errno];
            continue;
        }
        ksurface_nxt2_t blob;
        bzero(&blob, sizeof(blob));
        kern_return_t kr = trust_nxt2_read(path.fileSystemRepresentation, &blob);
        if(kr != KERN_SUCCESS)
        {
            [text appendFormat:@"  NXT2: none or unreadable (kr %d)\n", kr];
        }
        else
        {
            NSDictionary *entitlements = (__bridge NSDictionary *)blob.entitlements;
            [text appendFormat:@"  NXT2: valid %d, signed %d, cdhash ok %d, needs resign %d, keys: %@\n",
                 blob.isValid, blob.isSigned, blob.isCdHashValid, blob.needsResign,
                 [[entitlements.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "] ?: @"-"];
            if(blob.entitlements != NULL) CFRelease(blob.entitlements);
        }
    }
    return text;
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
    PEProcessSpawnFailure = PEProcessSpawnFailureNone;
    if(proc == NULL ||
       proctil(kProctilActionCount) != KERN_SUCCESS)
    {
        return PEForkSpawnFailed(PEProcessSpawnFailureBusy, items[@"PEExecutablePath"]);
    }
    
    self = [super init];
    if(self == nil)
    {
        proctil(kProctilActionUncount);
        return PEForkSpawnFailed(PEProcessSpawnFailureBusy, items[@"PEExecutablePath"]);
    }
    atomic_store(&_counted, true);
    
    _observers = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality capacity:0];
    _lock = OS_UNFAIR_LOCK_INIT;
    
    if(proctil(kProctilActionLock) != KERN_SUCCESS)
    {
        proctil(kProctilActionUncount);
        return PEForkSpawnFailed(PEProcessSpawnFailureBusy, items[@"PEExecutablePath"]);
    }
    
    self.executablePath = items[@"PEExecutablePath"];
    if(self.executablePath == nil)
    {
        proctil(kProctilActionUnlock);
        return PEForkSpawnFailed(PEProcessSpawnFailureArguments, items[@"PEExecutablePath"]);
    }
    
    short spawnFlags = [items[@"PEPOSIXSpawnFlags"] shortValue];
    pid_t spawnPgroup = (pid_t)[items[@"PEPOSIXSpawnPgroup"] intValue];
    
    if((spawnFlags & POSIX_SPAWN_SETSID) &&
       (spawnFlags & POSIX_SPAWN_SETPGROUP))
    {
        proctil(kProctilActionUnlock);
        return PEForkSpawnFailed(PEProcessSpawnFailureArguments, items[@"PEExecutablePath"]);
    }
    
    if((spawnFlags & POSIX_SPAWN_SETPGROUP) && spawnPgroup < 0)
    {
        proctil(kProctilActionUnlock);
        return PEForkSpawnFailed(PEProcessSpawnFailureArguments, items[@"PEExecutablePath"]);
    }
    
    if((spawnFlags & POSIX_SPAWN_SETPGROUP) && spawnPgroup > 0)
    {
        kvo_rdlock(proc);
        pid_t parentSid = proc_getsid(proc);
        kvo_unlock(proc);
        
        if(!proc_pgrp_exists_in_session(spawnPgroup, parentSid))
        {
            proctil(kProctilActionUnlock);
            return PEForkSpawnFailed(PEProcessSpawnFailureArguments, items[@"PEExecutablePath"]);
        }
    }
    
    kvo_rdlock(proc);
    ksurface_trust_identity_t *identity = trust_identity_create_from_path_with_parent_identity([self.executablePath UTF8String], proc->nyx.identity);
    if(identity == NULL)
    {
        kvo_unlock(proc);
        proctil(kProctilActionUnlock);
        return PEForkSpawnFailed(PEProcessSpawnFailureIdentity, items[@"PEExecutablePath"]);
    }
    
    /* TODO: later on we need to drop allow it to become tighter by using the still not existing trust_identity_create_from_path_with_parent_identity */
    ksurface_trust_identity_t *sb_identity = (proc == kernel_proc_) ? identity : proc->nyx.identity;    /* dont allow sandbox escape by spawning children */
    if(sb_identity->filePermissions != NULL)
    {
        NSMutableDictionary *mutableItems = [items mutableCopy];
        [mutableItems setObject:(__bridge NSArray*)sb_identity->filePermissions forKey:@"PEFilePermissions"];
        items = mutableItems;
    }
    /* fork: whose network setting applies (the parent's too: a child cannot escape it) */
    char ownPath[MAXPATHLEN];
    char sandboxPath[MAXPATHLEN];
    strlcpy(ownPath, identity->path, sizeof(ownPath));
    strlcpy(sandboxPath, sb_identity->path, sizeof(sandboxPath));
    kvo_unlock(proc);
    
    if(NXForkPermissionNetworkBlocked(ownPath) || NXForkPermissionNetworkBlocked(sandboxPath))
    {
        NSMutableDictionary *mutableItems = [items mutableCopy];
        NSMutableDictionary *environment = [mutableItems[@"PEEnvironment"] mutableCopy] ?: [NSMutableDictionary dictionary];
        environment[@"NYXIAN_NETWORK"] = @"blocked";
        mutableItems[@"PEEnvironment"] = environment;
        items = mutableItems;
        klog_log("PEProcess:permissions", "network blocked for %s", ownPath);
    }
    
    /* fork: StoreKit cannot reach the App Store from inside Nyxian; tell the program to simulate it */
    if(NXForkPermissionStoreKitSimulated(ownPath))
    {
        NSMutableDictionary *mutableItems = [items mutableCopy];
        NSMutableDictionary *environment = [mutableItems[@"PEEnvironment"] mutableCopy] ?: [NSMutableDictionary dictionary];
        environment[@"NYXIAN_STOREKIT"] = @"simulate";
        mutableItems[@"PEEnvironment"] = environment;
        items = mutableItems;
    }
    
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
        return PEForkSpawnFailed(PEProcessSpawnFailureLaunch, items[@"PEExecutablePath"]);
    }
    
    [self.process addObserver:self];
    if(!self.process.running)
    {
        /*
         * prevents a race condition, when we add a observer
         * and it already died then we shall handle the exit.
         */
        proctil(kProctilActionUnlock);
        return PEForkSpawnFailed(PEProcessSpawnFailureExited, items[@"PEExecutablePath"]);
    }
    
    ksurface_proc_t *child = NULL;
    kern_return_t kr = proc_spawn(proc ?: kernel_proc_, &child, self.pid, self.pidv, identity);
    if(kr != KERN_SUCCESS)
    {
        [self terminate];
        proctil(kProctilActionUnlock);
        return PEForkSpawnFailed(PEProcessSpawnFailureRegister, items[@"PEExecutablePath"]);
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

/* MARK: - fork: NXForkDebugger */

#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach-o/stab.h>
#include <mach-o/dyld_images.h>
#include <mach/exc.h>
#include <dlfcn.h>
#include <pthread.h>

#define FORK_DBG_MAX_BREAKPOINTS 6
#define FORK_DBG_VA_MASK 0x0000007FFFFFFFFFULL

typedef struct {
    uint64_t address;   /* unslid address in the linked binary */
    uint32_t file;      /* index into the file table */
    uint32_t line;
    uint8_t isStmt;
    uint8_t endSequence;
} ForkLineRow;

typedef struct {
    uint64_t address;   /* unslid */
    uint32_t name;      /* index into the name table */
} ForkSymbol;

typedef struct {
    union {
        __Request__exception_raise_t v;
        uint8_t pad[1024];
    };
} ForkExceptionRequest;

static int ForkCompareRows(const void *a, const void *b)
{
    const ForkLineRow *x = a, *y = b;
    if(x->address != y->address) return x->address < y->address ? -1 : 1;
    /* an end of sequence sorts before a row starting at the same address */
    return (int)y->endSequence - (int)x->endSequence;
}

static int ForkCompareSymbols(const void *a, const void *b)
{
    const ForkSymbol *x = a, *y = b;
    return x->address < y->address ? -1 : (x->address > y->address ? 1 : 0);
}

static uint64_t ForkReadULEB(const uint8_t **p, const uint8_t *end)
{
    uint64_t result = 0;
    unsigned shift = 0;
    while(*p < end)
    {
        uint8_t byte = *(*p)++;
        if(shift < 64) result |= (uint64_t)(byte & 0x7f) << shift;
        shift += 7;
        if(!(byte & 0x80)) break;
    }
    return result;
}

static int64_t ForkReadSLEB(const uint8_t **p, const uint8_t *end)
{
    int64_t result = 0;
    unsigned shift = 0;
    uint8_t byte = 0;
    while(*p < end)
    {
        byte = *(*p)++;
        if(shift < 64) result |= (int64_t)(byte & 0x7f) << shift;
        shift += 7;
        if(!(byte & 0x80)) break;
    }
    if(shift < 64 && (byte & 0x40)) result |= -((int64_t)1 << shift);
    return result;
}

static const char *ForkReadCString(const uint8_t **p, const uint8_t *end)
{
    const char *start = (const char *)*p;
    while(*p < end && **p != 0) (*p)++;
    if(*p < end) (*p)++;
    return start;
}

@interface NXForkDebugger ()
{
    task_t _task;
    mach_port_t _exceptionPort;
    exception_mask_t _oldMasks[EXC_TYPES_COUNT];
    mach_port_t _oldPorts[EXC_TYPES_COUNT];
    exception_behavior_t _oldBehaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t _oldFlavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t _oldCount;
    
    ForkLineRow *_rows;
    size_t _rowCount;
    size_t _rowCapacity;
    ForkSymbol *_symbols;
    size_t _symbolCount;
    
    uint8_t _uuid[16];
    uint64_t _textVMAddr;
    uint64_t _textVMSize;
    uint64_t _slide;
    BOOL _slideKnown;
    
    uint64_t _armed[FORK_DBG_MAX_BREAKPOINTS];
    int _armedCount;
    
    dispatch_semaphore_t _resumeSemaphore;
    BOOL _stoppedByException;
    BOOL _running;
    pthread_t _serverThread;
}

@property (atomic, readwrite) BOOL attached;
@property (atomic, readwrite) BOOL stopped;
@property (atomic, readwrite, copy) NSArray<NSDictionary<NSString*,id>*> *resolvedBreakpoints;
@property (atomic, readwrite, copy) NSString *status;
@property (nonatomic, strong) NSMutableArray<NSString*> *files;
@property (nonatomic, strong) NSMutableDictionary<NSString*,NSNumber*> *fileIndex;
@property (nonatomic, strong) NSMutableArray<NSString*> *names;
@property (nonatomic, copy) NSArray<NSDictionary<NSString*,id>*> *wantedBreakpoints;
@property (nonatomic, strong) NSMutableSet<NSNumber*> *steppingThreads;
@property (nonatomic, strong) NSArray<NSDictionary*> *images;

- (void)serve;
- (void)applyBreakpoints;
- (BOOL)findSlide;

@end

@implementation NXForkDebugger

+ (instancetype)shared
{
    static NXForkDebugger *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[NXForkDebugger alloc] init]; });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _status = @"Not attached";
        _resolvedBreakpoints = @[];
        _wantedBreakpoints = @[];
        _steppingThreads = [NSMutableSet set];
    }
    return self;
}

- (void)notifyState
{
    void (^handler)(void) = self.stateHandler;
    if(handler) dispatch_async(dispatch_get_main_queue(), handler);
}

/* MARK: debug info */

- (uint32_t)internFile:(NSString*)path
{
    NSNumber *existing = self.fileIndex[path];
    if(existing) return existing.unsignedIntValue;
    uint32_t index = (uint32_t)self.files.count;
    [self.files addObject:path];
    self.fileIndex[path] = @(index);
    return index;
}

- (void)appendRow:(ForkLineRow)row
{
    if(_rowCount == _rowCapacity)
    {
        _rowCapacity = _rowCapacity ? _rowCapacity * 2 : 4096;
        _rows = realloc(_rows, _rowCapacity * sizeof(ForkLineRow));
    }
    _rows[_rowCount++] = row;
}

- (void)resetDebugInfo
{
    free(_rows); _rows = NULL; _rowCount = 0; _rowCapacity = 0;
    free(_symbols); _symbols = NULL; _symbolCount = 0;
    self.files = [NSMutableArray array];
    self.fileIndex = [NSMutableDictionary dictionary];
    self.names = [NSMutableArray array];
    memset(_uuid, 0, sizeof(_uuid));
    _textVMAddr = 0; _textVMSize = 0; _slide = 0; _slideKnown = NO;
}

/* Reads the linked binary: __TEXT, UUID, function symbols, and the debug map (object -> function -> address). */
- (NSDictionary<NSString*,NSDictionary<NSString*,NSNumber*>*>*)loadExecutable:(NSString*)path globals:(NSMutableDictionary<NSString*,NSNumber*>*)globals
{
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if(data.length < sizeof(struct mach_header_64)) return nil;
    const uint8_t *base = data.bytes;
    const struct mach_header_64 *header = (const struct mach_header_64 *)base;
    if(header->magic != MH_MAGIC_64) return nil;
    
    const struct symtab_command *symtab = NULL;
    uint8_t textSectionIndex = 0, sectionCounter = 0;
    const uint8_t *cursor = base + sizeof(struct mach_header_64);
    for(uint32_t i = 0; i < header->ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)cursor;
        if((const uint8_t *)lc + sizeof(*lc) > base + data.length) break;
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            if(strncmp(seg->segname, "__TEXT", 16) == 0)
            {
                _textVMAddr = seg->vmaddr;
                _textVMSize = seg->vmsize;
            }
            const struct section_64 *sections = (const struct section_64 *)(seg + 1);
            for(uint32_t s = 0; s < seg->nsects; s++)
            {
                sectionCounter++;
                if(strncmp(sections[s].segname, "__TEXT", 16) == 0 && strncmp(sections[s].sectname, "__text", 16) == 0)
                {
                    textSectionIndex = sectionCounter;
                }
            }
        }
        else if(lc->cmd == LC_UUID)
        {
            memcpy(_uuid, ((const struct uuid_command *)lc)->uuid, 16);
        }
        else if(lc->cmd == LC_SYMTAB)
        {
            symtab = (const struct symtab_command *)lc;
        }
        cursor += lc->cmdsize;
    }
    if(symtab == NULL || symtab->symoff + (uint64_t)symtab->nsyms * sizeof(struct nlist_64) > data.length) return @{};
    
    const struct nlist_64 *nl = (const struct nlist_64 *)(base + symtab->symoff);
    const char *strings = (const char *)(base + symtab->stroff);
    NSMutableDictionary<NSString*,NSMutableDictionary<NSString*,NSNumber*>*> *debugMap = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString*,NSNumber*> *currentObject = nil;
    _symbols = calloc(symtab->nsyms + 1, sizeof(ForkSymbol));
    
    for(uint32_t i = 0; i < symtab->nsyms; i++)
    {
        if(nl[i].n_un.n_strx >= symtab->strsize) continue;
        const char *name = strings + nl[i].n_un.n_strx;
        if(nl[i].n_type & N_STAB)
        {
            if(nl[i].n_type == N_OSO)
            {
                NSString *object = [NSString stringWithUTF8String:name];
                currentObject = object ? debugMap[object] : nil;
                if(object && currentObject == nil)
                {
                    currentObject = [NSMutableDictionary dictionary];
                    debugMap[object] = currentObject;
                }
            }
            else if(nl[i].n_type == N_FUN && nl[i].n_sect != NO_SECT && name[0] != 0 && currentObject)
            {
                NSString *function = [NSString stringWithUTF8String:name];
                if(function) currentObject[function] = @(nl[i].n_value);
            }
            else if(nl[i].n_type == N_SO && name[0] == 0)
            {
                currentObject = nil;
            }
            continue;
        }
        if((nl[i].n_type & N_TYPE) == N_SECT && nl[i].n_sect == textSectionIndex && name[0] != 0)
        {
            NSString *symbol = [NSString stringWithUTF8String:name];
            if(symbol == nil) continue;
            globals[symbol] = @(nl[i].n_value);
            _symbols[_symbolCount].address = nl[i].n_value;
            _symbols[_symbolCount].name = (uint32_t)self.names.count;
            [self.names addObject:symbol];
            _symbolCount++;
        }
    }
    qsort(_symbols, _symbolCount, sizeof(ForkSymbol), ForkCompareSymbols);
    return debugMap;
}

/* Line program of one object file, translated to addresses of the linked binary. */
- (void)loadObject:(NSString*)path functions:(NSDictionary<NSString*,NSNumber*>*)functions globals:(NSDictionary<NSString*,NSNumber*>*)globals
{
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if(data.length < sizeof(struct mach_header_64)) return;
    const uint8_t *base = data.bytes;
    const uint8_t *fileEnd = base + data.length;
    const struct mach_header_64 *header = (const struct mach_header_64 *)base;
    if(header->magic != MH_MAGIC_64 || header->filetype != MH_OBJECT) return;
    
    const struct section_64 *debugLine = NULL, *lineStr = NULL, *debugStr = NULL;
    uint8_t textIndex = 0, counter = 0;
    const struct symtab_command *symtab = NULL;
    const uint8_t *cursor = base + sizeof(struct mach_header_64);
    for(uint32_t i = 0; i < header->ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)cursor;
        if((const uint8_t *)lc + sizeof(*lc) > fileEnd) return;
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            const struct section_64 *sections = (const struct section_64 *)(seg + 1);
            for(uint32_t s = 0; s < seg->nsects; s++)
            {
                counter++;
                const struct section_64 *section = &sections[s];
                if(strncmp(section->sectname, "__text", 16) == 0 && strncmp(section->segname, "__TEXT", 16) == 0) textIndex = counter;
                else if(strncmp(section->sectname, "__debug_line", 16) == 0) debugLine = section;
                else if(strncmp(section->sectname, "__debug_line_str", 16) == 0) lineStr = section;
                else if(strncmp(section->sectname, "__debug_str", 16) == 0) debugStr = section;
            }
        }
        else if(lc->cmd == LC_SYMTAB)
        {
            symtab = (const struct symtab_command *)lc;
        }
        cursor += lc->cmdsize;
    }
    if(debugLine == NULL || symtab == NULL || debugLine->offset + debugLine->size > data.length) return;
    if(symtab->symoff + (uint64_t)symtab->nsyms * sizeof(struct nlist_64) > data.length) return;
    
    /* object-local function symbols, to map object addresses to the linked binary */
    const struct nlist_64 *nl = (const struct nlist_64 *)(base + symtab->symoff);
    const char *strings = (const char *)(base + symtab->stroff);
    ForkSymbol *local = calloc(symtab->nsyms + 1, sizeof(ForkSymbol));
    uint64_t *localFinal = calloc(symtab->nsyms + 1, sizeof(uint64_t));
    size_t localCount = 0;
    for(uint32_t i = 0; i < symtab->nsyms; i++)
    {
        if((nl[i].n_type & N_STAB) || (nl[i].n_type & N_TYPE) != N_SECT || nl[i].n_sect != textIndex) continue;
        if(nl[i].n_un.n_strx >= symtab->strsize) continue;
        NSString *name = [NSString stringWithUTF8String:strings + nl[i].n_un.n_strx];
        if(name == nil) continue;
        NSNumber *final = functions[name] ?: globals[name];
        if(final == nil) continue;
        local[localCount].address = nl[i].n_value;
        local[localCount].name = (uint32_t)localCount;
        localFinal[localCount] = final.unsignedLongLongValue;
        localCount++;
    }
    /* sort both arrays together */
    for(size_t i = 1; i < localCount; i++)
    {
        ForkSymbol key = local[i];
        uint64_t keyFinal = localFinal[i];
        size_t j = i;
        while(j > 0 && local[j - 1].address > key.address)
        {
            local[j] = local[j - 1];
            localFinal[j] = localFinal[j - 1];
            j--;
        }
        local[j] = key;
        localFinal[j] = keyFinal;
    }
    if(localCount == 0)
    {
        free(local); free(localFinal);
        return;
    }
    
    /* the section with its relocations applied (DW_LNE_set_address operands) */
    NSMutableData *lineData = [NSMutableData dataWithBytes:base + debugLine->offset length:debugLine->size];
    uint8_t *lines = lineData.mutableBytes;
    if(debugLine->nreloc > 0 && debugLine->reloff + (uint64_t)debugLine->nreloc * 8 <= data.length)
    {
        const uint32_t *relocs = (const uint32_t *)(base + debugLine->reloff);
        for(uint32_t r = 0; r < debugLine->nreloc; r++)
        {
            int32_t address = (int32_t)relocs[r * 2];
            uint32_t info = relocs[r * 2 + 1];
            uint32_t symbolnum = info & 0xFFFFFF;
            uint32_t length = (info >> 25) & 3;
            uint32_t isExtern = (info >> 27) & 1;
            uint32_t type = (info >> 28) & 0xF;
            if(address < 0) continue;
            if(type == 1 /* ARM64_RELOC_SUBTRACTOR: pair, a difference */) { r++; continue; }
            if(type != 0 /* ARM64_RELOC_UNSIGNED */ || length != 3 || (uint64_t)address + 8 > debugLine->size) continue;
            if(isExtern && symbolnum < symtab->nsyms)
            {
                uint64_t value;
                memcpy(&value, lines + address, 8);
                value += nl[symbolnum].n_value;
                memcpy(lines + address, &value, 8);
            }
        }
    }
    
    const uint8_t *p = lines;
    const uint8_t *end = lines + debugLine->size;
    while(p + 4 <= end)
    {
        uint32_t unitLength;
        memcpy(&unitLength, p, 4);
        p += 4;
        if(unitLength == 0xffffffff || unitLength == 0 || p + unitLength > end) break;  /* 64-bit DWARF: not produced for Apple targets */
        const uint8_t *unitEnd = p + unitLength;
        uint16_t version;
        memcpy(&version, p, 2); p += 2;
        if(version < 2 || version > 5) { p = unitEnd; continue; }
        if(version >= 5) p += 2;  /* address_size, segment_selector_size */
        uint32_t headerLength;
        memcpy(&headerLength, p, 4); p += 4;
        const uint8_t *programStart = p + headerLength;
        if(programStart > unitEnd) { p = unitEnd; continue; }
        uint8_t minInst = *p++;
        if(version >= 4) p++;  /* maximum_operations_per_instruction */
        uint8_t defaultIsStmt = *p++;
        int8_t lineBase = (int8_t)*p++;
        uint8_t lineRange = *p++;
        uint8_t opcodeBase = *p++;
        const uint8_t *standardLengths = p;
        p += opcodeBase > 0 ? opcodeBase - 1 : 0;
        if(lineRange == 0) { p = unitEnd; continue; }
        
        NSMutableArray<NSString*> *dirs = [NSMutableArray array];
        NSMutableArray<NSNumber*> *fileIndexes = [NSMutableArray array];
        
        if(version < 5)
        {
            [dirs addObject:@""];
            while(p < programStart && *p)
            {
                const char *dir = ForkReadCString(&p, programStart);
                [dirs addObject:[NSString stringWithUTF8String:dir] ?: @""];
            }
            if(p < programStart) p++;
            [fileIndexes addObject:@(UINT32_MAX)];  /* v4 file numbers start at 1 */
            while(p < programStart && *p)
            {
                const char *name = ForkReadCString(&p, programStart);
                uint64_t dirIndex = ForkReadULEB(&p, programStart);
                ForkReadULEB(&p, programStart);
                ForkReadULEB(&p, programStart);
                NSString *file = [NSString stringWithUTF8String:name] ?: @"";
                if(![file hasPrefix:@"/"] && dirIndex < dirs.count && dirs[dirIndex].length) file = [dirs[dirIndex] stringByAppendingPathComponent:file];
                [fileIndexes addObject:@([self internFile:file])];
            }
        }
        else
        {
            /* DWARF 5 entry formats */
            BOOL ok = YES;
            for(int pass = 0; pass < 2 && ok; pass++)
            {
                uint8_t formatCount = *p++;
                uint64_t formats[16][2];
                if(formatCount > 16) { ok = NO; break; }
                for(uint8_t f = 0; f < formatCount; f++)
                {
                    formats[f][0] = ForkReadULEB(&p, programStart);
                    formats[f][1] = ForkReadULEB(&p, programStart);
                }
                uint64_t count = ForkReadULEB(&p, programStart);
                for(uint64_t e = 0; e < count && ok; e++)
                {
                    NSString *pathValue = nil;
                    uint64_t dirIndex = 0;
                    for(uint8_t f = 0; f < formatCount && ok; f++)
                    {
                        uint64_t content = formats[f][0], form = formats[f][1];
                        NSString *string = nil;
                        uint64_t number = 0;
                        switch(form)
                        {
                            case 0x08: string = [NSString stringWithUTF8String:ForkReadCString(&p, programStart)]; break;  /* string */
                            case 0x1f: case 0x0e:  /* line_strp, strp */
                            {
                                uint32_t offset; memcpy(&offset, p, 4); p += 4;
                                const struct section_64 *pool = form == 0x1f ? lineStr : debugStr;
                                if(pool && offset < pool->size && pool->offset + pool->size <= data.length)
                                    string = [NSString stringWithUTF8String:(const char *)(base + pool->offset + offset)];
                                break;
                            }
                            case 0x0b: number = *p; p += 1; break;
                            case 0x05: { uint16_t v; memcpy(&v, p, 2); number = v; p += 2; break; }
                            case 0x06: { uint32_t v; memcpy(&v, p, 4); number = v; p += 4; break; }
                            case 0x07: p += 8; break;
                            case 0x1e: p += 16; break;  /* data16 (MD5) */
                            case 0x0f: number = ForkReadULEB(&p, programStart); break;
                            case 0x09: { uint64_t len = ForkReadULEB(&p, programStart); p += len; break; }
                            default: ok = NO; break;
                        }
                        if(content == 1 /* DW_LNCT_path */) pathValue = string;
                        else if(content == 2 /* DW_LNCT_directory_index */) dirIndex = number;
                    }
                    if(pass == 0)
                    {
                        [dirs addObject:pathValue ?: @""];
                    }
                    else
                    {
                        NSString *file = pathValue ?: @"";
                        if(![file hasPrefix:@"/"] && dirIndex < dirs.count && dirs[dirIndex].length) file = [dirs[dirIndex] stringByAppendingPathComponent:file];
                        [fileIndexes addObject:@([self internFile:file])];
                    }
                }
            }
            if(!ok) { p = unitEnd; continue; }
        }
        
        /* the line number program */
        p = programStart;
        uint64_t address = 0;
        uint64_t file = 1;
        int64_t line = 1;
        BOOL isStmt = defaultIsStmt != 0;
        size_t lastSymbol = 0;
        
        while(p < unitEnd)
        {
            uint8_t opcode = *p++;
            BOOL emit = NO, endSequence = NO;
            if(opcode >= opcodeBase)
            {
                uint8_t adjusted = opcode - opcodeBase;
                address += (uint64_t)(adjusted / lineRange) * minInst;
                line += lineBase + (adjusted % lineRange);
                emit = YES;
            }
            else if(opcode == 0)
            {
                uint64_t length = ForkReadULEB(&p, unitEnd);
                const uint8_t *next = p + length;
                if(next > unitEnd || length == 0) break;
                uint8_t sub = *p++;
                if(sub == 1) { emit = YES; endSequence = YES; }
                else if(sub == 2 && length >= 9) { memcpy(&address, p, 8); }
                p = next;
            }
            else
            {
                switch(opcode)
                {
                    case 1: emit = YES; break;
                    case 2: address += ForkReadULEB(&p, unitEnd) * minInst; break;
                    case 3: line += ForkReadSLEB(&p, unitEnd); break;
                    case 4: file = ForkReadULEB(&p, unitEnd); break;
                    case 5: ForkReadULEB(&p, unitEnd); break;
                    case 6: isStmt = !isStmt; break;
                    case 7: break;
                    case 8: address += (uint64_t)((255 - opcodeBase) / lineRange) * minInst; break;
                    case 9: { uint16_t v; memcpy(&v, p, 2); p += 2; address += v; break; }
                    case 10: case 11: break;
                    case 12: ForkReadULEB(&p, unitEnd); break;
                    default:
                        /* unknown standard opcode: skip its ULEB operands */
                        for(uint8_t k = 0; k < standardLengths[opcode - 1]; k++) ForkReadULEB(&p, unitEnd);
                        break;
                }
            }
            
            if(emit)
            {
                /* object address -> linked address through the enclosing function */
                uint64_t lookup = endSequence && address > 0 ? address - 1 : address;
                size_t lo = 0, hi = localCount;
                while(lo < hi) { size_t mid = (lo + hi) / 2; if(local[mid].address <= lookup) lo = mid + 1; else hi = mid; }
                if(lo > 0)
                {
                    lastSymbol = lo - 1;
                    ForkLineRow row;
                    row.address = localFinal[lastSymbol] + (address - local[lastSymbol].address);
                    row.file = (file < fileIndexes.count) ? fileIndexes[file].unsignedIntValue : UINT32_MAX;
                    row.line = (uint32_t)(line > 0 ? line : 0);
                    row.isStmt = isStmt;
                    row.endSequence = endSequence;
                    if(row.file != UINT32_MAX) [self appendRow:row];
                }
                if(endSequence)
                {
                    address = 0; file = 1; line = 1; isStmt = defaultIsStmt != 0;
                }
            }
        }
        p = unitEnd;
    }
    free(local);
    free(localFinal);
}

- (void)loadDebugInfoForExecutable:(NSString*)executablePath objectRoot:(NSString*)objectRoot
{
    [self resetDebugInfo];
    NSMutableDictionary<NSString*,NSNumber*> *globals = [NSMutableDictionary dictionary];
    NSDictionary<NSString*,NSDictionary<NSString*,NSNumber*>*> *debugMap = [self loadExecutable:executablePath globals:globals];
    
    NSMutableSet<NSString*> *done = [NSMutableSet set];
    for(NSString *object in debugMap)
    {
        if(![[NSFileManager defaultManager] fileExistsAtPath:object]) continue;
        [done addObject:object.stringByStandardizingPath];
        [self loadObject:object functions:debugMap[object] globals:globals];
    }
    /* linkers that write no debug map: every object of the build folder, matched by symbol name */
    if(objectRoot.length)
    {
        NSDirectoryEnumerator<NSString*> *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:objectRoot];
        for(NSString *relative in enumerator)
        {
            if(![relative.pathExtension isEqualToString:@"o"]) continue;
            NSString *object = [objectRoot stringByAppendingPathComponent:relative].stringByStandardizingPath;
            if([done containsObject:object]) continue;
            [self loadObject:object functions:@{} globals:globals];
        }
    }
    qsort(_rows, _rowCount, sizeof(ForkLineRow), ForkCompareRows);
}

/* MARK: addresses */

- (BOOL)readTask:(uint64_t)address size:(size_t)size into:(void*)buffer
{
    vm_size_t got = 0;
    return vm_read_overwrite(_task, (vm_address_t)address, size, (vm_address_t)buffer, &got) == KERN_SUCCESS && got == size;
}

/* Where the app binary is loaded: the executable region whose Mach-O UUID matches. */
- (BOOL)findSlide
{
    if(_slideKnown) return YES;
    vm_address_t address = 0;
    while(YES)
    {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        if(vm_region_64(_task, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object) != KERN_SUCCESS) break;
        if(object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
        if(info.protection & VM_PROT_EXECUTE)
        {
            uint8_t page[0x1000];
            if([self readTask:address size:sizeof(page) into:page])
            {
                const struct mach_header_64 *header = (const struct mach_header_64 *)page;
                if(header->magic == MH_MAGIC_64 && header->sizeofcmds < sizeof(page) - sizeof(*header))
                {
                    const uint8_t *cursor = page + sizeof(*header);
                    for(uint32_t i = 0; i < header->ncmds && cursor + sizeof(struct load_command) <= page + sizeof(page); i++)
                    {
                        const struct load_command *lc = (const struct load_command *)cursor;
                        if(lc->cmdsize == 0) break;
                        if(lc->cmd == LC_UUID && memcmp(((const struct uuid_command *)lc)->uuid, _uuid, 16) == 0)
                        {
                            _slide = (uint64_t)address - _textVMAddr;
                            _slideKnown = YES;
                            return YES;
                        }
                        cursor += lc->cmdsize;
                    }
                }
            }
        }
        address += size;
        if(size == 0) break;
    }
    return NO;
}

- (void)loadImages
{
    NSMutableArray *images = [NSMutableArray array];
    task_dyld_info_data_t dyldInfo;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    if(task_info(_task, TASK_DYLD_INFO, (task_info_t)&dyldInfo, &count) == KERN_SUCCESS && dyldInfo.all_image_info_addr)
    {
        struct { uint32_t version; uint32_t infoArrayCount; uint64_t infoArray; } head;
        if([self readTask:dyldInfo.all_image_info_addr size:sizeof(head) into:&head] && head.infoArray && head.infoArrayCount < 4096)
        {
            for(uint32_t i = 0; i < head.infoArrayCount; i++)
            {
                struct { uint64_t load; uint64_t path; uint64_t date; } entry;
                if(![self readTask:head.infoArray + i * sizeof(entry) size:sizeof(entry) into:&entry]) break;
                char path[256] = {0};
                if(entry.path) [self readTask:entry.path size:sizeof(path) - 1 into:path];
                path[sizeof(path) - 1] = 0;
                NSString *name = [[NSString stringWithUTF8String:path] lastPathComponent] ?: @"?";
                [images addObject:@{ @"load": @(entry.load), @"name": name }];
            }
        }
    }
    [images sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"load"] compare:b[@"load"]]; }];
    self.images = images;
}

- (NSString*)demangle:(NSString*)symbol
{
    static char *(*demangle)(const char *, size_t, char *, size_t *, uint32_t);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ demangle = dlsym(RTLD_DEFAULT, "swift_demangle"); });
    NSString *name = [symbol hasPrefix:@"_"] ? [symbol substringFromIndex:1] : symbol;
    if(demangle && ([name hasPrefix:@"$s"] || [name hasPrefix:@"$S"] || [name hasPrefix:@"_T"]))
    {
        const char *mangled = name.UTF8String;
        char *readable = demangle(mangled, strlen(mangled), NULL, NULL, 0);
        if(readable)
        {
            NSString *result = [NSString stringWithUTF8String:readable];
            free(readable);
            if(result) name = result;
        }
    }
    return name.length > 160 ? [[name substringToIndex:157] stringByAppendingString:@"…"] : name;
}

- (NSDictionary*)describeAddress:(uint64_t)address isReturn:(BOOL)isReturn
{
    NSMutableDictionary *frame = [NSMutableDictionary dictionaryWithObject:@(address) forKey:@"address"];
    if(_slideKnown && address >= _textVMAddr + _slide && address < _textVMAddr + _slide + _textVMSize)
    {
        uint64_t unslid = address - _slide;
        uint64_t lookup = isReturn ? unslid - 1 : unslid;
        size_t lo = 0, hi = _symbolCount;
        while(lo < hi) { size_t mid = (lo + hi) / 2; if(_symbols[mid].address <= lookup) lo = mid + 1; else hi = mid; }
        if(lo > 0) frame[@"symbol"] = [self demangle:self.names[_symbols[lo - 1].name]];
        lo = 0; hi = _rowCount;
        while(lo < hi) { size_t mid = (lo + hi) / 2; if(_rows[mid].address <= lookup) lo = mid + 1; else hi = mid; }
        if(lo > 0 && !_rows[lo - 1].endSequence && _rows[lo - 1].line > 0)
        {
            frame[@"file"] = self.files[_rows[lo - 1].file];
            frame[@"line"] = @(_rows[lo - 1].line);
        }
        frame[@"image"] = @"app";
    }
    else
    {
        for(NSDictionary *image in self.images.reverseObjectEnumerator)
        {
            if([image[@"load"] unsignedLongLongValue] <= address)
            {
                frame[@"image"] = image[@"name"];
                frame[@"symbol"] = [NSString stringWithFormat:@"%@ + 0x%llx", image[@"name"], address - [image[@"load"] unsignedLongLongValue]];
                break;
            }
        }
        if(frame[@"symbol"] == nil) frame[@"symbol"] = [NSString stringWithFormat:@"0x%llx", address];
    }
    return frame;
}

- (NSArray*)framesForThread:(thread_t)thread
{
    arm_thread_state64_t state;
    mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
    if(thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)&state, &count) != KERN_SUCCESS) return @[];
    NSMutableArray *frames = [NSMutableArray array];
    uint64_t pc = arm_thread_state64_get_pc(state) & FORK_DBG_VA_MASK;
    uint64_t lr = arm_thread_state64_get_lr(state) & FORK_DBG_VA_MASK;
    uint64_t fp = arm_thread_state64_get_fp(state);
    [frames addObject:[self describeAddress:pc isReturn:NO]];
    BOOL leaf = YES;
    for(int i = 0; i < 64 && fp; i++)
    {
        uint64_t pair[2];
        if(![self readTask:fp size:sizeof(pair) into:pair]) break;
        uint64_t ret = pair[1] & FORK_DBG_VA_MASK;
        /* a leaf function may not have pushed a frame yet: lr is its caller */
        if(leaf && lr && ret != lr && i == 0)
        {
            [frames addObject:[self describeAddress:lr isReturn:YES]];
        }
        leaf = NO;
        if(ret == 0) break;
        [frames addObject:[self describeAddress:ret isReturn:YES]];
        if(pair[0] <= fp) break;
        fp = pair[0];
    }
    return frames;
}

- (NSDictionary*)stopInfoWithReason:(NSString*)reason thread:(thread_t)stoppedThread message:(NSString*)message
{
    [self loadImages];
    [self findSlide];
    NSMutableArray *threads = [NSMutableArray array];
    NSInteger stoppedIndex = 0;
    thread_act_array_t list = NULL;
    mach_msg_type_number_t count = 0;
    if(task_threads(_task, &list, &count) == KERN_SUCCESS)
    {
        for(mach_msg_type_number_t i = 0; i < count; i++)
        {
            NSString *name = [NSString stringWithFormat:@"Thread %u", i + 1];
            thread_extended_info_data_t extended;
            mach_msg_type_number_t extendedCount = THREAD_EXTENDED_INFO_COUNT;
            if(thread_info(list[i], THREAD_EXTENDED_INFO, (thread_info_t)&extended, &extendedCount) == KERN_SUCCESS && extended.pth_name[0])
            {
                name = [NSString stringWithFormat:@"%@ — %s", name, extended.pth_name];
            }
            /* same thread, different port names: compare thread ids */
            BOOL isStopped = NO;
            if(stoppedThread != MACH_PORT_NULL)
            {
                thread_identifier_info_data_t a, b;
                mach_msg_type_number_t ac = THREAD_IDENTIFIER_INFO_COUNT, bc = THREAD_IDENTIFIER_INFO_COUNT;
                if(thread_info(list[i], THREAD_IDENTIFIER_INFO, (thread_info_t)&a, &ac) == KERN_SUCCESS &&
                   thread_info(stoppedThread, THREAD_IDENTIFIER_INFO, (thread_info_t)&b, &bc) == KERN_SUCCESS &&
                   a.thread_id == b.thread_id)
                {
                    isStopped = YES;
                    stoppedIndex = (NSInteger)threads.count;
                }
            }
            [threads addObject:@{ @"name": name, @"frames": [self framesForThread:list[i]], @"stopped": @(isStopped) }];
            mach_port_deallocate(mach_task_self(), list[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)list, count * sizeof(thread_act_t));
    }
    return @{ @"reason": reason, @"message": message ?: @"", @"thread": @(stoppedIndex), @"threads": threads };
}

/* MARK: breakpoints */

static NSInteger ForkPathMatchScore(NSString *requested, NSString *candidate)
{
    NSArray<NSString*> *a = requested.stringByStandardizingPath.pathComponents;
    NSArray<NSString*> *b = candidate.stringByStandardizingPath.pathComponents;
    NSInteger score = 0;
    while(score < (NSInteger)a.count && score < (NSInteger)b.count &&
          [a[a.count - 1 - score] isEqualToString:b[b.count - 1 - score]]) score++;
    return score;
}

- (uint64_t)addressForPath:(NSString*)path line:(NSInteger)line resolvedLine:(NSInteger*)resolved
{
    /* the debug info file(s) that are this source file */
    NSInteger best = 0;
    NSMutableIndexSet *matches = [NSMutableIndexSet indexSet];
    for(NSUInteger i = 0; i < self.files.count; i++)
    {
        NSInteger score = ForkPathMatchScore(path, self.files[i]);
        if(score > best) { best = score; [matches removeAllIndexes]; }
        if(score == best && score > 0) [matches addIndex:i];
    }
    if(best == 0) return 0;
    /* the line itself, or the next line that has code (up to 20 lines below) */
    for(NSInteger wanted = line; wanted < line + 20; wanted++)
    {
        uint64_t found = 0;
        for(size_t r = 0; r < _rowCount; r++)
        {
            const ForkLineRow *row = &_rows[r];
            if(row->endSequence || !row->isStmt || row->line != (uint32_t)wanted || ![matches containsIndex:row->file]) continue;
            if(found == 0 || row->address < found) found = row->address;
        }
        if(found)
        {
            *resolved = wanted;
            return found;
        }
    }
    return 0;
}

- (void)armThreads
{
    arm_debug_state64_t state;
    memset(&state, 0, sizeof(state));
    for(int i = 0; i < _armedCount; i++)
    {
        state.__bvr[i] = _armed[i];
        state.__bcr[i] = (0xFu << 5) | (0b10u << 1) | 1u;  /* all bytes, EL0, enabled */
    }
    task_set_state(_task, ARM_DEBUG_STATE64, (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT);  /* new threads */
    thread_act_array_t list = NULL;
    mach_msg_type_number_t count = 0;
    if(task_threads(_task, &list, &count) == KERN_SUCCESS)
    {
        for(mach_msg_type_number_t i = 0; i < count; i++)
        {
            thread_set_state(list[i], ARM_DEBUG_STATE64, (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT);
            mach_port_deallocate(mach_task_self(), list[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)list, count * sizeof(thread_act_t));
    }
}

- (void)applyBreakpoints
{
    @synchronized(self)
    {
        if(!self.attached) return;
        BOOL haveSlide = [self findSlide];
        NSMutableArray *resolved = [NSMutableArray array];
        _armedCount = 0;
        for(NSDictionary *bp in self.wantedBreakpoints)
        {
            NSString *path = bp[@"path"];
            NSInteger line = [bp[@"line"] integerValue];
            NSInteger resolvedLine = 0;
            uint64_t address = path ? [self addressForPath:path line:line resolvedLine:&resolvedLine] : 0;
            BOOL ok = address != 0 && haveSlide && _armedCount < FORK_DBG_MAX_BREAKPOINTS;
            if(ok) _armed[_armedCount++] = address + _slide;
            NSMutableDictionary *entry = [@{ @"path": path ?: @"", @"line": @(line), @"ok": @(ok) } mutableCopy];
            if(resolvedLine) entry[@"resolvedLine"] = @(resolvedLine);
            [resolved addObject:entry];
        }
        self.resolvedBreakpoints = resolved;
        [self armThreads];
        if(!haveSlide && self.wantedBreakpoints.count)
        {
            self.status = @"Waiting for the app to load…";
        }
        else
        {
            self.status = [NSString stringWithFormat:@"Attached · %d breakpoint%@ armed", _armedCount, _armedCount == 1 ? @"" : @"s"];
        }
    }
    [self notifyState];
}

- (void)setBreakpoints:(NSArray<NSDictionary<NSString*,id>*>*)breakpoints
{
    self.wantedBreakpoints = breakpoints ?: @[];
    if(self.attached)
    {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [self applyBreakpoints]; });
    }
}

/* MARK: exception server */

- (void)setSingleStep:(BOOL)step thread:(thread_t)thread skipping:(uint64_t)address
{
    arm_debug_state64_t state;
    memset(&state, 0, sizeof(state));
    for(int i = 0; i < _armedCount; i++)
    {
        state.__bvr[i] = _armed[i];
        state.__bcr[i] = (_armed[i] == address && step) ? 0 : ((0xFu << 5) | (0b10u << 1) | 1u);
    }
    if(step) state.__mdscr_el1 |= 1;  /* MDSCR_EL1.SS */
    thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT);
}

static uint64_t ForkThreadID(thread_t thread)
{
    thread_identifier_info_data_t info;
    mach_msg_type_number_t count = THREAD_IDENTIFIER_INFO_COUNT;
    return thread_info(thread, THREAD_IDENTIFIER_INFO, (thread_info_t)&info, &count) == KERN_SUCCESS ? info.thread_id : 0;
}

- (void)replyTo:(ForkExceptionRequest*)request code:(kern_return_t)code
{
    __Reply__exception_raise_t reply;
    memset(&reply, 0, sizeof(reply));
    reply.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(request->v.Head.msgh_bits), 0);
    reply.Head.msgh_id = request->v.Head.msgh_id + 100;
    reply.Head.msgh_remote_port = request->v.Head.msgh_remote_port;
    reply.Head.msgh_size = sizeof(reply);
    reply.NDR = NDR_record;
    reply.RetCode = code;
    if(mach_msg(&reply.Head, MACH_SEND_MSG, reply.Head.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL) == MACH_MSG_SUCCESS)
    {
        request->v.Head.msgh_remote_port = MACH_PORT_NULL;
    }
    mach_msg_destroy(&request->v.Head);
}

- (void)deliverStop:(NSDictionary*)stop
{
    self.stopped = YES;
    self.status = stop[@"message"];
    void (^handler)(NSDictionary*) = self.stopHandler;
    dispatch_async(dispatch_get_main_queue(), ^{ if(handler) handler(stop); });
    [self notifyState];
}

static void *ForkDebuggerServer(void *context)
{
    NXForkDebugger *debugger = (__bridge NXForkDebugger *)context;
    [debugger serve];
    return NULL;
}

- (void)serve
{
    pthread_setname_np("Nyxian debugger");
    int slideAttempts = 0;
    while(_running)
    {
        /* the app binary may load after the process starts: keep looking for it to arm breakpoints */
        if(!_slideKnown && slideAttempts < 100 && self.wantedBreakpoints.count)
        {
            slideAttempts++;
            if([self findSlide]) [self applyBreakpoints];
        }
        
        ForkExceptionRequest request;
        memset(&request, 0, sizeof(request));
        request.v.Head.msgh_local_port = _exceptionPort;
        request.v.Head.msgh_size = sizeof(request);
        mach_msg_return_t mr = mach_msg(&request.v.Head, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof(request), _exceptionPort, 200, MACH_PORT_NULL);
        if(mr == MACH_RCV_TIMED_OUT) continue;
        if(mr != MACH_MSG_SUCCESS) break;
        if(request.v.msgh_body.msgh_descriptor_count != 2)
        {
            mach_msg_destroy(&request.v.Head);
            continue;
        }
        
        thread_t thread = request.v.thread.name;
        uint64_t threadID = ForkThreadID(thread);
        arm_thread_state64_t state;
        mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
        uint64_t pc = 0;
        if(thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)&state, &count) == KERN_SUCCESS)
        {
            pc = arm_thread_state64_get_pc(state) & FORK_DBG_VA_MASK;
        }
        
        /* the single step after a breakpoint: arm it again and go on */
        BOOL wasStepping;
        @synchronized(self)
        {
            wasStepping = [self.steppingThreads containsObject:@(threadID)];
            if(wasStepping) [self.steppingThreads removeObject:@(threadID)];
        }
        if(wasStepping)
        {
            [self setSingleStep:NO thread:thread skipping:0];
            [self replyTo:&request code:KERN_SUCCESS];
            continue;
        }
        
        BOOL isBreakpoint = NO;
        for(int i = 0; i < _armedCount; i++) if(_armed[i] == pc) isBreakpoint = YES;
        
        task_suspend(_task);
        _stoppedByException = YES;
        NSDictionary *frame = [self describeAddress:pc isReturn:NO];
        NSString *where = frame[@"file"] ? [NSString stringWithFormat:@"%@:%@", [frame[@"file"] lastPathComponent], frame[@"line"]] : (frame[@"symbol"] ?: @"");
        NSString *message = isBreakpoint
            ? [NSString stringWithFormat:@"Breakpoint at %@", where]
            : [NSString stringWithFormat:@"Stopped by a trap (Swift runtime error or brk) at %@. Continue lets the app crash as usual.", where];
        [self deliverStop:[self stopInfoWithReason:isBreakpoint ? @"breakpoint" : @"trap" thread:thread message:message]];
        
        dispatch_semaphore_wait(_resumeSemaphore, DISPATCH_TIME_FOREVER);
        
        if(isBreakpoint && _running)
        {
            @synchronized(self) { [self.steppingThreads addObject:@(threadID)]; }
            [self setSingleStep:YES thread:thread skipping:pc];
        }
        _stoppedByException = NO;
        self.stopped = NO;
        task_resume(_task);
        [self replyTo:&request code:(isBreakpoint || !_running) ? KERN_SUCCESS : KERN_FAILURE];
        self.status = @"Running";
        [self notifyState];
    }
}

/* MARK: public */

- (BOOL)attachToProcess:(PEProcess*)process executablePath:(NSString*)executablePath objectRoot:(NSString*)objectRoot
{
    [self detach];
    if(process == nil || process.proc == NULL) return NO;
    
    task_special_port_t flavour = TASK_KERNEL_PORT;
    task_t task = MACH_PORT_NULL;
    if(proc_task_for_proc(process.proc, &flavour, &task) != KERN_SUCCESS || task == MACH_PORT_NULL)
    {
        self.status = @"No access to the app's task";
        [self notifyState];
        return NO;
    }
    _task = task;
    
    [self loadDebugInfoForExecutable:executablePath objectRoot:objectRoot];
    
    mach_port_t port = MACH_PORT_NULL;
    if(mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS ||
       mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND) != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), _task);
        _task = MACH_PORT_NULL;
        return NO;
    }
    _exceptionPort = port;
    _oldCount = EXC_TYPES_COUNT;
    task_get_exception_ports(_task, EXC_MASK_BREAKPOINT, _oldMasks, &_oldCount, _oldPorts, _oldBehaviors, _oldFlavors);
    if(task_set_exception_ports(_task, EXC_MASK_BREAKPOINT, _exceptionPort, EXCEPTION_DEFAULT, THREAD_STATE_NONE) != KERN_SUCCESS)
    {
        self.status = @"Could not take the app's breakpoint exceptions";
        [self detach];
        [self notifyState];
        return NO;
    }
    
    _resumeSemaphore = dispatch_semaphore_create(0);
    _running = YES;
    self.attached = YES;
    self.stopped = NO;
    self.status = [NSString stringWithFormat:@"Attached · %zu lines of debug info", _rowCount];
    pthread_create(&_serverThread, NULL, ForkDebuggerServer, (__bridge void *)self);
    [self applyBreakpoints];
    return YES;
}

- (BOOL)pause
{
    if(!self.attached || self.stopped) return NO;
    if(task_suspend(_task) != KERN_SUCCESS) return NO;
    [self deliverStop:[self stopInfoWithReason:@"pause" thread:MACH_PORT_NULL message:@"Paused"]];
    return YES;
}

- (void)resume
{
    if(!self.attached || !self.stopped) return;
    if(_stoppedByException)
    {
        dispatch_semaphore_signal(_resumeSemaphore);
    }
    else
    {
        self.stopped = NO;
        task_resume(_task);
        self.status = @"Running";
        [self notifyState];
    }
}

- (void)detach
{
    if(!self.attached && _task == MACH_PORT_NULL) return;
    BOOL wasRunning = _running;
    _running = NO;
    if(self.stopped) [self resume];
    if(wasRunning) pthread_join(_serverThread, NULL);
    if(_task != MACH_PORT_NULL)
    {
        _armedCount = 0;
        [self armThreads];
        for(mach_msg_type_number_t i = 0; i < _oldCount; i++)
        {
            task_set_exception_ports(_task, _oldMasks[i], _oldPorts[i], _oldBehaviors[i], _oldFlavors[i]);
        }
        mach_port_deallocate(mach_task_self(), _task);
        _task = MACH_PORT_NULL;
    }
    if(_exceptionPort != MACH_PORT_NULL)
    {
        mach_port_destruct(mach_task_self(), _exceptionPort, -1, 0);
        _exceptionPort = MACH_PORT_NULL;
    }
    _oldCount = 0;
    [self.steppingThreads removeAllObjects];
    self.attached = NO;
    self.stopped = NO;
    self.status = @"Not attached";
    [self notifyState];
}

@end
