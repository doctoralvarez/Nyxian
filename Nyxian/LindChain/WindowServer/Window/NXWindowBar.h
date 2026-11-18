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
  - 1.0.0 (2026-11-17): iPhone: minimizeButton and minimizeCallback (the bar
    shows close and minimize, like the iPad shows close and maximize).
*/

#ifndef NXWINDOWBAR_H
#define NXWINDOWBAR_H

#import <UIKit/UIKit.h>
#import <LindChain/WindowServer/Window/NXHitSurfaceButton.h>

@interface NXWindowBar : UIView

@property (nonatomic, strong, readonly) UIVisualEffectView *buttonIsland;

@property (nonatomic,strong) NXHitSurfaceButton *closeButton;
@property (nonatomic,strong) NXHitSurfaceButton *maximizeButton;
/* fork: iPhone only */
@property (nonatomic,strong) NXHitSurfaceButton *minimizeButton;
@property (nonatomic,copy) void (^minimizeCallback)(void);
@property (nonatomic,strong,getter=getTitle,setter=setTitle:) NSString *title;

- (instancetype)initWithTitle:(NSString*)title withCloseCallback:(void (^)(void))closeCallback withMaximizeCallback:(void (^)(void))maximizeCallback;
- (void)changeFocus:(BOOL)focusState;

- (void)setFullscreen:(BOOL)fullscreen animated:(BOOL)animated;

- (void)expandIsland;
- (void)collapseIsland;

@end

#endif /* NXWINDOWBAR_H */
