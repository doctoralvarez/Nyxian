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
 Fork doctoralvarez/Nyxian — version 1.1.0
 Changelog:
  - 1.1.0 (2026-11-10): the refusal report goes to Python's home as ForkPython
    saved it (fork.python.home): inside LiveContainer NSHomeDirectory() differs.
  - 1.0.0 (2026-11-10): posix_spawn replies -(100 + PEProcessSpawnFailure) when
    the spawn failed, -90 when the caller's process is unknown and -91 when it
    lacks process.spawn, so the caller can tell why; on a refusal it writes
    what it saw (caller's entitlements now / max / from its signature) to
    opt/python/.nyxian-spawn.txt.
*/

#import <mach/mach.h>
#import <LindChain/ProcEnvironment/Server/ServerSession.h>
#import <LindChain/ProcEnvironment/PEProcess.h>
#import <Frameworks/LiveProcessLegacy/LindChain/Services/bootstrapd/LDEApplicationWorkspace.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/ProcEnvironment/LiveContainer/LCUtils.h>
#import <LindChain/ProcEnvironment/Surface/trust/entitlement.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>

/* fork: what the host saw when it refused a spawn, for Nyxian Shell (python3 may read opt/python) */
static void PEForkWriteSpawnRefusal(ksurface_proc_t *proc, pid_t pid, NSString *path, BOOL hasArguments, BOOL hasEnvironment, BOOL hasDirectory)
{
    ksurface_trust_identity_t *identity = proc->nyx.identity;
    PEEntitlementFlags identityFlags = (identity != NULL && identity->entitlements != NULL) ? trust_identity_entitlement_flags_from_entitlements(identity->entitlements) : 0;
    NSString *text = [NSString stringWithFormat:
        @"host refused a spawn at %@\n"
        @"  caller pid %d, executable %s, trust level %d\n"
        @"  caller entitlements now 0x%llx, max 0x%llx, from its signature 0x%llx (process.spawn is 0x%llx)\n"
        @"  program %@, arguments %d, environment %d, directory %d\n",
        [NSDate date], pid, identity != NULL ? identity->path : "?", identity != NULL ? (int)identity->trustLevel : -1,
        (unsigned long long)proc_getentitlements(proc), (unsigned long long)proc_getmaxentitlements(proc), (unsigned long long)identityFlags,
        (unsigned long long)kPEEntitlementFlagProcessSpawn,
        [path isKindOfClass:NSString.class] ? path : @"?", hasArguments, hasEnvironment, hasDirectory];
    /* Nyxian Shell's Python home (written by ForkPython): NSHomeDirectory() differs inside LiveContainer */
    NSString *home = [[NSUserDefaults standardUserDefaults] stringForKey:@"fork.python.home"] ?: [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/rootfs/opt/python"];
    NSString *file = [home stringByAppendingPathComponent:@".nyxian-spawn.txt"];
    [text writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/permit.h>
#import <ksurface_config.h>

@interface ServerSession ()

@property (nonatomic,getter=proc) ksurface_proc_t *proc;

@end

@implementation ServerSession {
    pid_t _processIdentifier;
}

- (instancetype)initWithProcessidentifier:(pid_t)pid
{
    self = [super init];
    _processIdentifier = pid;
    return self;
}

- (ksurface_proc_t*)proc
{
    if(_proc == NULL)
    {
        /* attempting to get proc from ksurface */
        kern_return_t ret = proc_for_pid(_processIdentifier, &(_proc));
        if(ret != KERN_SUCCESS)
        {
            return NULL;
        }
    }
    
    return _proc;
}

/*
 posix_spawn
 */
- (void)spawnProcessWithPath:(NSString*)path
               withArguments:(NSArray<NSObject<NSSecureCoding,NSCopying>*>*)arguments
    withEnvironmentVariables:(NSDictionary *)environment
               withFileTable:(PEFileTable*)fileTable
        withWorkingDirectory:(NSString *)workingDirectory
              withSpawnFlags:(short)spawnFlags
             withSpawnPgroup:(pid_t)spawnPgroup
                   withReply:(void (^)(int64_t))reply
{
    static dispatch_queue_t spawnQueue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        spawnQueue = dispatch_queue_create("org.emexlabs.nyxian.oldserver.spawnqueue", DISPATCH_QUEUE_SERIAL);
    });
    __weak typeof(self) weakSelf = self;
    dispatch_async(spawnQueue, ^{
        __strong typeof(self) strongSelf = weakSelf;
        if(strongSelf == nil)
        {
            /* sead server session */
            return;
        }
        
        /* sanity checking proc */
        if(strongSelf.proc == NULL)
        {
            /* fork: -90, the caller's own process is not known to ksurface */
            klog_log("ServerSession:spawn", "no ksurface process for pid %d", strongSelf->_processIdentifier);
            reply(-90);
            return;
        }
        
        if(path &&
           arguments &&
           environment &&
           workingDirectory &&
           (entitlement_got_entitlement(proc_getentitlements(strongSelf->_proc), kPEEntitlementFlagProcessSpawn) ||
            entitlement_got_entitlement(proc_getentitlements(strongSelf->_proc), kPEEntitlementFlagProcessSpawnSignedOnly)))
        {
            NSMutableDictionary *mutableItems = [[NSMutableDictionary alloc] initWithDictionary:@{
                @"PEExecutablePath": path,
                @"PEArguments": arguments,
                @"PEEnvironment": environment,
                @"PEWorkingDirectory": workingDirectory,
                @"PEPOSIXSpawnFlags": @(spawnFlags),
                @"PEPOSIXSpawnPgroup": @(spawnPgroup),
            }];
            
            if(fileTable != nil)
            {
                [mutableItems setObject:fileTable forKey:@"PEFileTable"];
            }
            
            /* invoking spawn */
            pid_t pid = [[PEProcessManager shared] spawnProcessWithItems:mutableItems withKernelSurfaceProcess:strongSelf->_proc];
            
            /* fork: on failure -(100 + reason), so posix_spawn can say why (-1 stays "not entitled") */
            if(pid < 0 && PEProcessSpawnFailure > PEProcessSpawnFailureNone)
            {
                reply(-(100 + (int64_t)PEProcessSpawnFailure));
                return;
            }
            
            /* replying with pid of spawn */
            reply(pid);
            
            return;
        }
        
        /* fork: -91, the caller lacks process.spawn (or sent no path / arguments) */
        klog_log("ServerSession:spawn", "pid %d may not spawn %s", strongSelf->_processIdentifier, [path isKindOfClass:NSString.class] ? path.UTF8String : "?");
        PEForkWriteSpawnRefusal(strongSelf->_proc, strongSelf->_processIdentifier, path, arguments != nil, environment != nil, workingDirectory != nil);
        reply(-91);
    });
}

/*
 App switcher services
 */
- (void)setSnapshot:(UIImage*)image
{
    /* null pointer check */
    if(image == nil)
    {
        return;
    }
    
    /* finding process */
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:_processIdentifier];
    if(process != nil)
    {
        /* setting snapshot */
        process.snapshot = image;
    }
}

- (void)dealloc
{
    /* null pointer check */
    if(_proc != NULL)
    {
        kvo_release(_proc);
    }
}

@end
