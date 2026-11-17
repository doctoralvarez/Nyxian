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
 Fork doctoralvarez/Nyxian — version 1.6.0
 Changelog:
  - 1.6.0 (2026-11-17): the Swift checks (live issues, completion, help,
    symbols) run on a thread with a 64 MB stack instead of a 512 KB one.
    The Swift type checker goes deep on long SwiftUI files and could run off
    the small stack, which closed Nyxian while a project opened.
  - 1.5.0 (2026-11-14): -releaseMemory never waits. Closing a file while its
    code was still being checked (a Swift check can take several seconds)
    froze Nyxian: the editor released the server on the main thread and had
    to wait for the check to finish. Now, when a check is running, the
    release is only noted and done by the check itself when it ends.
  - 1.4.0 (2026-11-07): -swiftSymbolAtLine:utf8Column:content:inFile: for
    Find References (Swift).
  - 1.3.0 (2026-11-07): -getFixIts.
  - 1.2.0 (2026-11-07): -signatureHelpAtLine:utf8Column:content:.
  - 1.1.0 (2026-11-07): completions for Swift files too (phase 2).
  - 1.0.0 (2026-11-07): -completionsAtLine:utf8Column:content: for the
    editor's code completion (Clang files).
*/

#import <LindChain/IDELanguageServer/NXLanguageServer.h>
#import <MobileDevelopmentKit/MDKASTUnit.h>
#import <MobileDevelopmentKit/MDKFile.h>
#import <string.h>
#import <strings.h>
#include <os/lock.h>
#include <stdatomic.h>

#include <pthread.h>

/* fork: the Swift type checker recurses deeply on big SwiftUI files; GCD
   threads have 512 KB of stack, so Swift work runs on a thread with 64 MB
   (only reserved, used as needed) and the caller waits for it */
static __thread bool g_forkOnLargeStack = false;

static void *NXForkLargeStackEntry(void *context)
{
    @autoreleasepool {
        void (^block)(void) = (__bridge_transfer void (^)(void))context;
        g_forkOnLargeStack = true;
        block();
    }
    return NULL;
}

static void NXForkRunOnLargeStack(void (^block)(void))
{
    if(g_forkOnLargeStack)
    {
        block();
        return;
    }
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, 64 * 1024 * 1024);
    void *context = (__bridge_retained void *)[block copy];
    pthread_t thread;
    if(pthread_create(&thread, &attr, NXForkLargeStackEntry, context) != 0)
    {
        pthread_attr_destroy(&attr);
        void (^again)(void) = (__bridge_transfer void (^)(void))context;
        again();
        return;
    }
    pthread_attr_destroy(&attr);
    pthread_join(thread, NULL);
}

#pragma mark - SynpushServer

@implementation NXLanguageServer {
    os_unfair_lock _lock;
    MDKMutableASTUnit *_unit;
    MDKMutableFile *_file;
    /* fork: a release asked for while a check held the lock */
    atomic_bool _releasePending;
}

/* fork: called with the lock held, right before it is let go */
- (void)forkReleaseIfPending
{
    if(atomic_exchange(&_releasePending, false))
    {
        _unit = nil;
    }
}

- (instancetype)init:(NSString*)filepath
{
    self = [super init];
    if(!self) return nil;
    
    /* initializing step numero uno */
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    _file = [MDKMutableFile fileWithURL:fileURL];
    _lock = OS_UNFAIR_LOCK_INIT;
    return self;
}

#pragma mark - Reparse (incremental)

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args
{
    /* fork: on a big stack */
    if(_file.isSwift && !g_forkOnLargeStack)
    {
        NXForkRunOnLargeStack(^{ [self reparseFile:content withArgs:args]; });
        return;
    }

    /* getting data from content (dont allow lossy conversion, because otherwise chineese, japanese, etc users are pissed off)*/
    NSData *newData = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!newData)
    {
        return;
    }
    
    os_unfair_lock_lock(&_lock);
    
    /* checking for unit */
    if(_unit == nil)
    {
        /* needs reactivation */
        os_unfair_lock_unlock(&_lock);
        [self reactivateWithData:newData withArgs:args];
        return;
    }
    
    [_file setUnsavedData:newData];
    [_unit reparse];

    [self forkReleaseIfPending];
    os_unfair_lock_unlock(&_lock);
}

- (NSArray<MDKDiagnostic *> *)getDiagnostics
{
    os_unfair_lock_lock(&_lock);

    /* checking if unit is already active */
    if(_unit == nil)
    {
        /* its not so fall back to being an asshole */
        os_unfair_lock_unlock(&_lock);
        return @[];
    }
    
    NSArray<MDKDiagnostic *> *items = [_unit diagnostics];
    os_unfair_lock_unlock(&_lock);
    
    NSMutableArray<MDKDiagnostic *> *filteredItems = [NSMutableArray array];
    for(MDKDiagnostic *diagnostic in items)
    {
        if([diagnostic.fileSourceLocation.fileURL isEqual:_file.fileURL])
        {
            NSLog(@"%@", diagnostic.message);
            [filteredItems addObject:diagnostic];
        }
    }
    
    return filteredItems;
}

#pragma mark - Memory management

- (void)releaseMemory
{
    /* fork: never wait for a running check (the editor calls this on the
       main thread when it closes) */
    if(os_unfair_lock_trylock(&_lock))
    {
        atomic_store(&_releasePending, false);
        _unit = nil;
        os_unfair_lock_unlock(&_lock);
    }
    else
    {
        atomic_store(&_releasePending, true);
    }
}

- (BOOL)isActive
{
    os_unfair_lock_lock(&_lock);
    BOOL active = (_unit != nil);
    os_unfair_lock_unlock(&_lock);
    return active;
}

- (BOOL)reactivateWithData:(NSData*)data withArgs:(NSArray*)args
{
    /* checking if server is still active */
    if([self isActive])
    {
        return YES;
    }
    
    /* its not so we need to reactivate it */
    os_unfair_lock_lock(&_lock);
    
    /* creating new synpush core and update all */
    _unit = [MDKMutableASTUnit unitWithType:_file.isSwift ? MDKASTUnitTypeSwift : MDKASTUnitTypeClang];
    if(_unit == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return false;
    }
    
    [_file setUnsavedData:data];
    [_unit setFile:_file];
    [_unit setArguments:args];
    bool succeed = [_unit reparse];
    
    [self forkReleaseIfPending];
    os_unfair_lock_unlock(&_lock);
    
    return succeed;
}

- (NSArray<NSDictionary<NSString*,id>*>*)completionsAtLine:(NSInteger)line utf8Column:(NSInteger)column content:(NSString*)content
{
    /* fork: on a big stack */
    if(_file.isSwift && !g_forkOnLargeStack)
    {
        __block NSArray<NSDictionary<NSString*,id>*> * result = nil;
        NXForkRunOnLargeStack(^{ result = [self completionsAtLine:line utf8Column:column content:content]; });
        return result;
    }

    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(data == nil)
    {
        return nil;
    }
    
    os_unfair_lock_lock(&_lock);
    if(_unit == nil)
    {
        /* not parsed yet: the editor falls back to word completion */
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    
    [_file setUnsavedData:data];
    NSArray<NSDictionary<NSString*,id>*> *items = [_unit completionsAtLocation:MDKSourceLocationMake(line, column)];
    os_unfair_lock_unlock(&_lock);
    
    return items;
}

- (NSDictionary<NSString*,id>*)signatureHelpAtLine:(NSInteger)line utf8Column:(NSInteger)column content:(NSString*)content
{
    /* fork: on a big stack */
    if(_file.isSwift && !g_forkOnLargeStack)
    {
        __block NSDictionary<NSString*,id> * result = nil;
        NXForkRunOnLargeStack(^{ result = [self signatureHelpAtLine:line utf8Column:column content:content]; });
        return result;
    }

    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(data == nil)
    {
        return nil;
    }
    
    os_unfair_lock_lock(&_lock);
    if(_unit == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    
    [_file setUnsavedData:data];
    NSDictionary<NSString*,id> *help = [_unit signatureHelpAtLocation:MDKSourceLocationMake(line, column)];
    os_unfair_lock_unlock(&_lock);
    
    return help;
}

- (NSArray<NSDictionary<NSString*,id>*>*)getFixIts
{
    /* fork: on a big stack */
    if(_file.isSwift && !g_forkOnLargeStack)
    {
        __block NSArray<NSDictionary<NSString*,id>*> * result = nil;
        NXForkRunOnLargeStack(^{ result = [self getFixIts]; });
        return result;
    }

    os_unfair_lock_lock(&_lock);
    NSArray<NSDictionary<NSString*,id>*> *fixIts = (_unit != nil) ? [_unit fixIts] : @[];
    os_unfair_lock_unlock(&_lock);
    return fixIts;
}

- (NSDictionary<NSString*,id>*)swiftSymbolAtLine:(NSInteger)line utf8Column:(NSInteger)column content:(NSString*)content inFile:(NSString*)path
{
    /* fork: on a big stack */
    if(_file.isSwift && !g_forkOnLargeStack)
    {
        __block NSDictionary<NSString*,id> * result = nil;
        NXForkRunOnLargeStack(^{ result = [self swiftSymbolAtLine:line utf8Column:column content:content inFile:path]; });
        return result;
    }

    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(data == nil)
    {
        return nil;
    }
    
    os_unfair_lock_lock(&_lock);
    if(_unit == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    NSDictionary<NSString*,id> *symbol = nil;
    if(path == nil)
    {
        [_file setUnsavedData:data];
        symbol = [_unit swiftSymbolAtLocation:MDKSourceLocationMake(line, column) inFile:nil content:nil];
    }
    else
    {
        symbol = [_unit swiftSymbolAtLocation:MDKSourceLocationMake(line, column) inFile:[NSURL fileURLWithPath:path] content:data];
    }
    os_unfair_lock_unlock(&_lock);
    return symbol;
}

- (MDKFileSourceLocation*)getDefinitionAtLocation:(MDKSourceLocation)location
{
    /* fork: on a big stack */
    if(_file.isSwift && !g_forkOnLargeStack)
    {
        __block MDKFileSourceLocation * result = nil;
        NXForkRunOnLargeStack(^{ result = [self getDefinitionAtLocation:location]; });
        return result;
    }

    os_unfair_lock_lock(&_lock);
    MDKFileSourceLocation *fileSourceLocation = [_unit fileSourceLocationForDefinitionAtLocation:location];
    os_unfair_lock_unlock(&_lock);
    return fileSourceLocation;
}

@end
