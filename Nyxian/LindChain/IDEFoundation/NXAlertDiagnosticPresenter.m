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
  - 1.0.0 (2026-11-10): notices are shown one at a time: one that arrives while
    another is showing (or while a screen is appearing or going away) waits for
    it to close. Two notices at once ("Node.js is ready", "Java is ready")
    could freeze Nyxian.
*/

#import <LindChain/IDEFoundation/NXAlertDiagnosticPresenter.h>
#import <LindChain/WindowServer/NXWindowServer.h>

static UIViewController *NXTopViewController(UIViewController *viewController)
{
    if(viewController.presentedViewController)
    {
        return NXTopViewController(viewController.presentedViewController);
    }
    
    if([viewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *nav = (UINavigationController *)viewController;
        return NXTopViewController(nav.visibleViewController ?: nav);
    }
    
    if([viewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tab = (UITabBarController *)viewController;
        return NXTopViewController(tab.selectedViewController ?: tab);
    }
    
    return viewController;
}

static NSString *NXStringForNXAlertDiagnosticPresenterLevel(NXAlertDiagnosticPresenterLevel level)
{
    switch(level)
    {
        case NXAlertDiagnosticPresenterLevelNote:
            return @"Note";
        case NXAlertDiagnosticPresenterLevelWarning:
            return @"Warning";
        case NXAlertDiagnosticPresenterLevelError:
        default:
            return @"Error";
    }
}

@implementation NXAlertDiagnosticPresenter

+ (void)notifyUserWithLevel:(NXAlertDiagnosticPresenterLevel)level
                withMessage:(NSString*)message
                  withDelay:(double)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self forkEnqueueTitle:NXStringForNXAlertDiagnosticPresenterLevel(level) message:(message ?: @"")];
    });
}

/* fork: one notice at a time (main queue only) */
static NSMutableArray<NSArray<NSString *> *> *NXForkPendingNotices;
static BOOL NXForkNoticeShowing = NO;
static __weak UIAlertController *NXForkCurrentNotice;

+ (void)forkEnqueueTitle:(NSString *)title message:(NSString *)message
{
    if(NXForkPendingNotices == nil) NXForkPendingNotices = [NSMutableArray array];
    NSArray<NSString *> *notice = @[title, message];
    if(![NXForkPendingNotices containsObject:notice]) [NXForkPendingNotices addObject:notice];
    [self forkShowNextNotice];
}

+ (void)forkShowNextNotice
{
    /* the notice was closed some other way */
    if(NXForkNoticeShowing && (NXForkCurrentNotice == nil || NXForkCurrentNotice.presentingViewController == nil)) NXForkNoticeShowing = NO;
    if(NXForkNoticeShowing || NXForkPendingNotices.count == 0) return;
    UIViewController *viewController = NXTopViewController(NXWindowServer.shared.rootViewController);
    if(viewController == nil || viewController.isBeingPresented || viewController.isBeingDismissed ||
       viewController.view.window == nil || viewController.transitionCoordinator != nil)
    {
        /* a screen is appearing or going away: try again in a moment */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self forkShowNextNotice];
        });
        return;
    }
    NSArray<NSString *> *notice = NXForkPendingNotices.firstObject;
    [NXForkPendingNotices removeObjectAtIndex:0];
    NXForkNoticeShowing = YES;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:notice[0] message:notice[1] preferredStyle:UIAlertControllerStyleAlert];
    NXForkCurrentNotice = alertController;
    [alertController addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        NXForkNoticeShowing = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self forkShowNextNotice];
        });
    }]];
    [viewController presentViewController:alertController animated:YES completion:^{
        if(alertController.presentingViewController == nil)
        {
            /* UIKit did not show it: let the next one through */
            NXForkNoticeShowing = NO;
        }
    }];
}

@end
