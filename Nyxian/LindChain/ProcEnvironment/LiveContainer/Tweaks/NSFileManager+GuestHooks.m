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
  - 1.0.0 (2026-11-21): App Groups shared between apps. A group the app
    declares (Info.plist NXApplicationGroups, from the project's
    Config/AppEntitlements.plist) is the same folder for every app that
    declares it: <Nyxian root>/Data/AppGroup/<group> (next to the apps'
    containers). Before, each app got a folder of its own (and LC_HOME_PATH,
    which Nyxian never sets, made it "(null)/Documents/AppGroup/<group>"
    inside the app): an app and its widget never saw each other's data.
    Groups an app does not declare keep that old private folder, so data
    already there stays where it was.
*/

#import <Foundation/Foundation.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/ProcEnvironment/LiveContainer/Tweaks/Tweaks.h>
#import <LindChain/Utils/Swizzle.h>

/* fork: <root>/Data/AppGroup/<group> for a group in the app's NXApplicationGroups, else nil */
NSURL *NXForkSharedAppGroupURL(NSString *groupIdentifier)
{
    if(groupIdentifier.length == 0 || [groupIdentifier containsString:@"/"] || [groupIdentifier hasPrefix:@"."])
    {
        return nil;
    }
    NSArray *declared = [NSBundle.mainBundle objectForInfoDictionaryKey:@"NXApplicationGroups"];
    if(![declared isKindOfClass:[NSArray class]] || ![declared containsObject:groupIdentifier])
    {
        return nil;
    }
    const char *home = getenv("HOME");
    if(home == NULL)
    {
        return nil;
    }
    /* HOME is <root>/Data/Application/<container> */
    NSString *data = [[[NSString stringWithUTF8String:home] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    if(![data.lastPathComponent isEqualToString:@"Data"])
    {
        return nil;
    }
    NSURL *result = [NSURL fileURLWithPath:[data stringByAppendingPathComponent:[@"AppGroup" stringByAppendingPathComponent:groupIdentifier]] isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:result withIntermediateDirectories:YES attributes:nil error:nil];
    return result;
}

// NSFileManager simulate app group
@implementation NSFileManager (LiveContainer)

- (NSURL*)hook_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    /* fork: shared when the app declares the group */
    NSURL *shared = NXForkSharedAppGroupURL(groupIdentifier);
    if(shared != nil)
    {
        return shared;
    }
    NSURL *result;
    result = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s/Documents/AppGroup/%@", getenv("LC_HOME_PATH"), groupIdentifier]];
    [NSFileManager.defaultManager createDirectoryAtURL:result withIntermediateDirectories:YES attributes:nil error:nil];
    return result;
}

@end

void NSFMGuestHooksInit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SwizzleObjCMethod(@selector(containerURLForSecurityApplicationGroupIdentifier:), [NSFileManager class], @selector(hook_containerURLForSecurityApplicationGroupIdentifier:), nil, kSwizzleMethodTypeInstance);
    });
}
