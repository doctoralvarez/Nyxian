/*
 * MIT License
 *
 * Copyright (c) 2026 emexlab
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * Fork doctoralvarez/Nyxian — version 1.4.0
 * Changelog:
 *  - 1.4.0 (2026-11-07): -swiftSymbolAtLocation:inFile:content:.
 *  - 1.3.0 (2026-11-07): fixIts.
 *  - 1.2.0 (2026-11-07): -signatureHelpAtLocation: (parameter help).
 *  - 1.1.0 (2026-11-07): +formattedSource:fileName: (clang-format).
 *  - 1.0.0 (2026-11-07): -completionsAtLocation: (Clang code completion).
 */

#ifndef MOBILEDEVELOPMENTKIT_MDKASTUNIT_H
#define MOBILEDEVELOPMENTKIT_MDKASTUNIT_H

#import <MobileDevelopmentKit/MDKCFType.h>
#import <MobileDevelopmentKit/MDKDiagnostic.h>
#import <MobileDevelopmentKit/MDKFile.h>
#import <MobileDevelopmentKit/MDKFileSourceLocation.h>

typedef NS_ENUM(UInt8, MDKASTUnitType) {
    MDKASTUnitTypeClang = 0,
    MDKASTUnitTypeSwift,
};

@interface MDKASTUnit : MDKCFType

@property (nonatomic, readonly) MDKFile *file;
@property (nonatomic, readonly) NSArray<MDKDiagnostic*> *diagnostics;
@property (nonatomic, readonly) BOOL hasErrorOccured;

- (MDKFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(MDKSourceLocation)location;

/* fork: code completion for Clang units; dictionaries with text, display, type, kind, priority. Column counts UTF-8 bytes. */
- (NSArray<NSDictionary<NSString*,id>*>*)completionsAtLocation:(MDKSourceLocation)location;

/* fork: parameter help for the call around `location` (text, doc, activeStart, activeLength, count); nil outside a call */
- (NSDictionary<NSString*,id>*)signatureHelpAtLocation:(MDKSourceLocation)location;

/* fork: the compiler's suggested fixes for this file from the last parse (see CCASTUnitCopyFixIts) */
@property (nonatomic, readonly) NSArray<NSDictionary<NSString*,id>*> *fixIts;

/* fork: what the Swift symbol at `location` refers to ("name", "usr", "module", "path", "line", "column"); url/data nil = this unit's file */
- (NSDictionary<NSString*,id>*)swiftSymbolAtLocation:(MDKSourceLocation)location inFile:(NSURL*)url content:(NSData*)data;

/* fork: clang-format for C, Objective-C and C++ text; nil when it cannot be formatted */
+ (NSString*)formattedSource:(NSString*)source fileName:(NSString*)fileName NS_SWIFT_NAME(formattedSource(_:fileName:));

@end

@interface MDKMutableASTUnit : MDKASTUnit

@property (nonatomic, readwrite) MDKFile *file;

+ (instancetype)unitWithType:(MDKASTUnitType)type;

- (BOOL)reparse;
- (void)setArguments:(NSArray<NSString*>*)arguments;

@end

#endif /* MOBILEDEVELOPMENTKIT_MDKASTUNIT_H */
