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
  - 1.0.0 (2026-11-09): -forkProcessSnapshot, -forkSendSignal:toProcessIdentifier:.
*/

#ifndef PEPROCESSMANAGER_H
#define PEPROCESSMANAGER_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/PEProcess.h>

@interface PEProcessManager : NSObject <PEProcessObserver>

- (instancetype)init;
+ (instancetype)shared;

- (pid_t)spawnProcessWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc;
- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier withItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc doRestartIfRunning:(BOOL)doRestartIfRunning;

- (void)closeIfRunningUsingBundleIdentifier:(NSString*)bundleIdentifier;
- (PEProcess*)processForProcessIdentifier:(pid_t)pid;
- (PEProcess*)processForBundleIdentifier:(NSString*)bundleIdentifier;

- (void)killAllRunningProcesses;

/* fork: every process of Nyxian's kernel, by pid: @{ @"pid", @"ppid", @"pgid"?, @"sid"?, @"uid", @"name",
   @"state" (running, stopped, zombie, starting), @"uptime"? (s), and for processes Nyxian runs
   @"displayName"?, @"bundleIdentifier"?, @"executablePath"?, @"cpu"?, @"memory"?, @"threads"? } */
- (NSArray<NSDictionary<NSString*,id>*>*)forkProcessSnapshot;
/* fork: a signal to any process (SIGSTOP, SIGCONT, SIGTERM, SIGKILL…) */
- (BOOL)forkSendSignal:(int)signal toProcessIdentifier:(pid_t)pid;

@end

#endif /* PEPROCESSMANAGER_H */
