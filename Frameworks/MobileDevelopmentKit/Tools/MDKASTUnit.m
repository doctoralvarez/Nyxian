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
 * Fork doctoralvarez/Nyxian — version 1.3.0
 * Changelog:
 *  - 1.3.0 (2026-11-07): fixIts.
 *  - 1.2.0 (2026-11-07): -signatureHelpAtLocation: (parameter help).
 *  - 1.1.0 (2026-11-07): +formattedSource:fileName: (clang-format).
 *  - 1.0.0 (2026-11-07): -completionsAtLocation: (Clang code completion).
 */

#import <MobileDevelopmentKit/MDKASTUnit.h>
#import <CoreCompiler/CCASTUnit.h>
#import <objc/runtime.h>

@implementation MDKASTUnit

+ (void)load
{
    _CFRuntimeBridgeClasses(CCASTUnitGetTypeID(), "MDKASTUnit");
}

- (MDKFile*)file
{
    return (__bridge MDKFile*)CCASTUnitGetFile((__bridge void *)self);
}

- (NSArray<MDKDiagnostic*>*)diagnostics
{
    return (__bridge_transfer NSArray<MDKDiagnostic*>*)CCASTUnitCopyDiagnostics((__bridge void *)self);
}

- (BOOL)hasErrorOccured
{
    return CCASTUnitErrorOccured((__bridge void *)self);
}

- (MDKFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(MDKSourceLocation)location
{
    return (__bridge_transfer MDKFileSourceLocation*)CCASTUnitCopyDefinitionAtLocation((__bridge void*)self, (CCSourceLocation){ location.isValid, location.line, location.column });
}

- (NSArray<NSDictionary<NSString*,id>*>*)fixIts
{
    CFArrayRef fixIts = CCASTUnitCopyFixIts((__bridge void*)self);
    return fixIts != NULL ? (__bridge_transfer NSArray*)fixIts : @[];
}

- (NSDictionary<NSString*,id>*)signatureHelpAtLocation:(MDKSourceLocation)location
{
    CFDictionaryRef help = CCASTUnitCopySignatureHelpAtLocation((__bridge void*)self, (CCSourceLocation){ location.isValid, location.line, location.column });
    return help != NULL ? (__bridge_transfer NSDictionary*)help : nil;
}

+ (NSString*)formattedSource:(NSString*)source fileName:(NSString*)fileName
{
    CFStringRef formatted = CCCopyFormattedSource((__bridge CFStringRef)source, (__bridge CFStringRef)fileName);
    return formatted != NULL ? (__bridge_transfer NSString*)formatted : nil;
}

- (NSArray<NSDictionary<NSString*,id>*>*)completionsAtLocation:(MDKSourceLocation)location
{
    CFArrayRef completions = CCASTUnitCopyCompletionsAtLocation((__bridge void*)self, (CCSourceLocation){ location.isValid, location.line, location.column });
    return completions != NULL ? (__bridge_transfer NSArray*)completions : @[];
}

@end

@implementation MDKMutableASTUnit

@dynamic file;

+ (instancetype)unitWithType:(MDKASTUnitType)type
{
    MDKASTUnit *obj = (__bridge_transfer MDKASTUnit*)CCASTUnitCreateMutable(kCFAllocatorSystemDefault, (type == MDKASTUnitTypeClang) ? kCCASTUnitTypeClang : kCCASTUnitTypeSwift);
    object_setClass(obj, [MDKMutableASTUnit class]);
    return (MDKMutableASTUnit *)obj;
}

- (void)setFile:(MDKFile*)file
{
    CCASTUnitSetFile((__bridge void *)self, (__bridge CCFileRef)file);
}

- (BOOL)reparse
{
    return CCASTUnitReparse((__bridge void *)self);
}

- (void)setArguments:(NSArray<NSString*>*)arguments
{
    CCASTUnitSetArguments((__bridge void *)self, (__bridge CFArrayRef)arguments);
}

@end
