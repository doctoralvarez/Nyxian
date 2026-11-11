/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 emexlab

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-11): file pickers in apps Nyxian runs (SwiftUI .fileImporter,
    UIDocumentPickerViewController) open files as a copy. Opening "in place"
    hands the app a security-scoped URL issued for Nyxian, not for the app
    running inside it, so picking failed or hung (it works in Swift
    Playgrounds). Folders are still opened in place (they cannot be copied
    by the picker). Same idea as LiveContainer's "Fix File Picker".
*/

#import <UIKit/UIKit.h>
#import "../LCUtils.h"
#import "UIKitPrivate.h"
#import "utils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <LindChain/Utils/Swizzle.h>
#import <objc/message.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// Handler for AppDelegate
@implementation UIApplication(LiveContainerHook)

- (void)hook__connectUISceneFromFBSScene:(id)scene transitionContext:(UIApplicationSceneTransitionContext*)context
{
#if !TARGET_OS_MACCATALYST
    context.payload = nil;
    context.actions = nil;
#endif
    [self hook__connectUISceneFromFBSScene:scene transitionContext:context];
}

+ (BOOL)_wantsApplicationBehaviorAsExtension
{
    // Fix LiveProcess: Make _UIApplicationWantsExtensionBehavior return NO so delegate code runs in the run loop
    return YES;
}

- (CGRect)hook_statusBarFrame
{
    UIStatusBarManager* manager = [(UIWindowScene*)(UIApplication.sharedApplication.connectedScenes.anyObject) statusBarManager];
    if(manager)
    {
        return manager.statusBarFrame;
    }
    else
    {
        return [self hook_statusBarFrame];
    }
}

- (void)hook_setDelegate:(id<UIApplicationDelegate>)delegate
{
    if(![delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        // Fix old apps black screen when UIApplicationSupportsMultipleScenes is YES
        SwizzleObjCMethod(@selector(makeKeyAndVisible), [UIWindow class], @selector(hook_makeKeyAndVisible), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(makeKeyWindow), [UIWindow class], @selector(hook_makeKeyWindow), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(setHidden:), [UIWindow class], @selector(hook_setHidden:), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(statusBarFrame), [UIApplication class], @selector(hook_statusBarFrame), nil, kSwizzleMethodTypeInstance);
#pragma clang diagnostic pop
    }
    [self hook_setDelegate:delegate];
}

@end

@interface UIViewController ()

- (UIInterfaceOrientationMask)__supportedInterfaceOrientations;

@end

@implementation UIViewController (LiveContainerHook)

- (UIInterfaceOrientationMask)hook___supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)hook_shouldAutorotateToInterfaceOrientation:(NSInteger)orientation
{
    return YES;
}

@end

@implementation UIWindow (LiveContainerHook)

- (void)hook_setAutorotates:(BOOL)autorotates forceUpdateInterfaceOrientation:(BOOL)force
{
    [self hook_setAutorotates:YES forceUpdateInterfaceOrientation:YES];
}

- (void)hook_makeKeyAndVisible
{
    [self updateWindowScene];
    [self hook_makeKeyAndVisible];
}

- (void)hook_makeKeyWindow
{
    [self updateWindowScene];
    [self hook_makeKeyWindow];
}

- (void)hook_resignKeyWindow
{
    [self updateWindowScene];
    [self hook_resignKeyWindow];
}

- (void)hook_setHidden:(BOOL)hidden
{
    [self updateWindowScene];
    [self hook_setHidden:hidden];
}

- (void)updateWindowScene
{
    for(UIWindowScene *windowScene in [PrivClass(UIApplication) sharedApplication].connectedScenes)
    {
        if(!self.windowScene && self.screen == windowScene.screen)
        {
            self.windowScene = windowScene;
            break;
        }
    }
}

@end

/* fork: pickers hand over copies (see the changelog above) */
@implementation UIDocumentPickerViewController (NyxianForkHook)

static BOOL NXForkOnlyFolders(NSArray<UTType *> *types)
{
    if(types.count == 0) return NO;
    for(UTType *type in types)
    {
        if(![type conformsToType:UTTypeFolder] && ![type conformsToType:UTTypeDirectory]) return NO;
    }
    return YES;
}

- (instancetype)hook_initForOpeningContentTypes:(NSArray<UTType *> *)contentTypes asCopy:(BOOL)asCopy
{
    BOOL copy = asCopy || !NXForkOnlyFolders(contentTypes);
    return [self hook_initForOpeningContentTypes:contentTypes asCopy:copy];
}

- (instancetype)hook_initForOpeningContentTypes:(NSArray<UTType *> *)contentTypes
{
    return [self initForOpeningContentTypes:contentTypes asCopy:NO];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (instancetype)hook_initWithDocumentTypes:(NSArray<NSString *> *)allowedUTIs inMode:(UIDocumentPickerMode)mode
{
    BOOL folders = allowedUTIs.count > 0;
    for(NSString *uti in allowedUTIs)
    {
        if(![uti isEqualToString:@"public.folder"] && ![uti isEqualToString:@"public.directory"]) { folders = NO; break; }
    }
    if(mode == UIDocumentPickerModeOpen && !folders) mode = UIDocumentPickerModeImport;
    return [self hook_initWithDocumentTypes:allowedUTIs inMode:mode];
}
#pragma clang diagnostic pop

@end

void UIKitGuestHooksInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        SwizzleObjCMethod(@selector(_connectUISceneFromFBSScene:transitionContext:), [UIApplication class], @selector(hook__connectUISceneFromFBSScene:transitionContext:), nil, kSwizzleMethodTypeInstance);
#pragma clang diagnostic pop
        SwizzleObjCMethod(@selector(__supportedInterfaceOrientations), [UIViewController class], @selector(hook___supportedInterfaceOrientations), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(shouldAutorotateToInterfaceOrientation:), [UIViewController class], @selector(hook_shouldAutorotateToInterfaceOrientation:), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(setAutorotates:forceUpdateInterfaceOrientation:), [UIWindow class], @selector(hook_setAutorotates:forceUpdateInterfaceOrientation:), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(setDelegate:), [UIApplication class], @selector(hook_setDelegate:), nil, kSwizzleMethodTypeInstance);
        /* fork: file pickers hand over copies */
        SwizzleObjCMethod(@selector(initForOpeningContentTypes:asCopy:), [UIDocumentPickerViewController class], @selector(hook_initForOpeningContentTypes:asCopy:), nil, kSwizzleMethodTypeInstance);
        SwizzleObjCMethod(@selector(initForOpeningContentTypes:), [UIDocumentPickerViewController class], @selector(hook_initForOpeningContentTypes:), nil, kSwizzleMethodTypeInstance);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        SwizzleObjCMethod(@selector(initWithDocumentTypes:inMode:), [UIDocumentPickerViewController class], @selector(hook_initWithDocumentTypes:inMode:), nil, kSwizzleMethodTypeInstance);
#pragma clang diagnostic pop
    });
}
