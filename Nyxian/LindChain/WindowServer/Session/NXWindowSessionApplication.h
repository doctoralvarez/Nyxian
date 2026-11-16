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
  - 1.0.0 (2026-11-15): -forkApplyInterfaceStyle (light / dark mode for the app's scene).
*/

#ifndef NXWINDOWSESSIONAPPLICATION_H
#define NXWINDOWSESSIONAPPLICATION_H

#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/WindowServer/Window/NXWindowSession.h>
#import <LindChain/Private/UIKitPrivate.h>

@interface NXWindowSessionApplication : NXWindowSession <PEProcessObserver>

@property (nonatomic, strong) PEProcess *process;
@property (nonatomic, strong) NSTimer *backgroundEnforcementTimer;
@property (nonatomic, strong) FBScene *scene;

@property (nonatomic) _UISceneHostingController *sceneHostingController;
@property (nonatomic) _UIScenePresenter *scenePresenter;
@property (nonatomic, readwrite) UIView *contentView;

- (instancetype)initWithProcess:(PEProcess*)process;

+ (void)bringSessionToFrontWithBundleIdentifier:(NSString*)bundleIdentifier;

/* fork: gives the app's scene the current light / dark mode */
- (void)forkApplyInterfaceStyle;

@end

#endif /* NXWINDOWSESSIONAPPLICATION_H */
