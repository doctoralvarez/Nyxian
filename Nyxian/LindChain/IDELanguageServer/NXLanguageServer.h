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
  - 1.1.0 (2026-11-07): completions for Swift files too (phase 2).
  - 1.0.0 (2026-11-07): -completionsAtLine:utf8Column:content: for the
    editor's code completion (Clang files).
*/

#ifndef NXLANGUAGESERVER_H
#define NXLANGUAGESERVER_H

#import <Foundation/Foundation.h>
#import <MobileDevelopmentKit/MDKDiagnostic.h>
#import <MobileDevelopmentKit/MDKFileSourceLocation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

@interface NXLanguageServer : NSObject

- (instancetype)init:(NSString*)filepath;

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args;

- (NSArray<MDKDiagnostic *> *)getDiagnostics;
- (MDKFileSourceLocation*)getDefinitionAtLocation:(MDKSourceLocation)location;

/* fork: code completion at a 1-based line and UTF-8 byte column of `content` (Clang and Swift files); nil when the file has not been parsed yet */
- (NSArray<NSDictionary<NSString*,id>*>*)completionsAtLine:(NSInteger)line utf8Column:(NSInteger)column content:(NSString*)content NS_SWIFT_NAME(completions(line:utf8Column:content:));

- (void)releaseMemory;

@end

#endif /* NXLANGUAGESERVER_H */
