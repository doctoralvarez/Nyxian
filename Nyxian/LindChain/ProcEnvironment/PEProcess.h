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
 Fork doctoralvarez/Nyxian — version 1.2.0
 Changelog:
  - 1.2.0 (2026-11-10): PEProcessSpawnFailure, why the last spawn failed;
    PEForkSigningReport, how Nyxian sees the signature of some programs.
  - 1.1.1 (2026-11-07): nullability of +shared and the stop dictionary.
  - 1.1.0 (2026-11-07): NXForkDebugger — attaches to a running app through
    its task port: pause / continue, stop on Swift traps, line breakpoints
    with the CPU's hardware breakpoint registers, backtraces of every thread
    with file:line from the line tables.
  - 1.0.0 (2026-11-07): -forkResourceUsage (CPU %, memory footprint and
    thread count of the process, read through its task port) for the
    profiler in the console.
*/

#ifndef PRPROCESS_H
#define PRPROCESS_H

#import <Foundation/Foundation.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/ProcEnvironment/PEFileTable.h>
#import <LindChain/ProcEnvironment/PEProcessObserver.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <Frameworks/LiveProcessLegacy/LindChain/Services/bootstrapd/LDEApplicationWorkspace.h>

/// fork: why the last -initWithItems: failed (spawns are serial), for posix_spawn's error.
typedef NS_ENUM(int, PEProcessSpawnFailureReason) {
    PEProcessSpawnFailureNone = 0,
    PEProcessSpawnFailureBusy = 1,          /* process count or lock */
    PEProcessSpawnFailureArguments = 2,     /* no path, or bad session / process group */
    PEProcessSpawnFailureIdentity = 3,      /* the executable's signature or entitlements were refused */
    PEProcessSpawnFailureLaunch = 4,        /* the LiveProcess extension did not start */
    PEProcessSpawnFailureExited = 5,        /* it ended right away */
    PEProcessSpawnFailureRegister = 6,      /* kernel surface could not register it */
};
extern int PEProcessSpawnFailure;

/// fork: for each path, its NXT2 blob (present, valid, signed, cdhash) and the identity and
/// entitlement flags Nyxian would give it when started (process.spawn among them), as text.
NSString *PEForkSigningReport(NSArray<NSString *> *paths);

@interface PEProcess : NSObject <FBProcessObserver>

@property (nonatomic) ksurface_proc_t *proc;

@property (nonatomic,strong) FBProcess *process;
@property (nonatomic,strong) UIImage *snapshot;

@property (nonatomic,strong) LDEApplicationObject *applicationObject;
@property (nonatomic,strong) NSString *bundleIdentifier;
@property (nonatomic,strong) NSString *displayName;
@property (nonatomic,strong) NSString *executablePath;

@property (nonatomic,readonly) pid_t pid;
@property (nonatomic,readonly) int pidv;

- (instancetype)initWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc;

- (void)sendSignal:(int)signal;

- (void)forceTerminate;
- (void)terminate;
- (void)suspend;
- (void)resume;

- (void)addObserver:(id<PEProcessObserver>)observer;

/* fork: @{ @"cpu": percent (all threads, 100 = one core), @"memory": bytes (phys footprint), @"threads": count }, nil when the task is gone */
- (NSDictionary<NSString*,NSNumber*>*)forkResourceUsage;
- (void)removeObserver:(id<PEProcessObserver>)observer;

@end

/*
 * fork doctoralvarez/Nyxian: a small debugger for apps run from Nyxian.
 * Stop dictionaries (main queue): @"reason" (@"breakpoint", @"pause", @"trap"),
 * @"message", @"thread" (index of the stopped thread), @"threads": @[ @{ @"name",
 * @"frames": @[ @{ @"address", @"symbol", @"file"?, @"line"?, @"image"? } ] } ].
 */
@interface NXForkDebugger : NSObject

+ (nonnull instancetype)shared;

@property (nonatomic, copy) void (^stopHandler)(NSDictionary<NSString*,id> * _Nonnull stop);
@property (nonatomic, copy) void (^stateHandler)(void);

@property (atomic, readonly) BOOL attached;
@property (atomic, readonly) BOOL stopped;
/* @[ @{ @"path", @"line", @"resolvedLine"?, @"ok" } ] after the last -setBreakpoints: */
@property (atomic, readonly, copy) NSArray<NSDictionary<NSString*,id>*> *resolvedBreakpoints;
@property (atomic, readonly, copy) NSString *status;

/* executablePath: the linked app binary; objectRoot: folder with the build's .o files */
- (BOOL)attachToProcess:(PEProcess*)process executablePath:(NSString*)executablePath objectRoot:(NSString*)objectRoot;
/* @[ @{ @"path": absolute source path, @"line": 1-based } ], at most 6 are armed */
- (void)setBreakpoints:(NSArray<NSDictionary<NSString*,id>*>*)breakpoints;
- (BOOL)pause;
- (void)resume;
- (void)detach;

@end

#endif /* PRPROCESS_H */
