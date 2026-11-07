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
 * Fork doctoralvarez/Nyxian — version 1.0.0
 * Changelog:
 *  - 1.0.0 (2026-11-07): CCASTUnitCopyCompletionsAtLocation, code completion
 *    for Clang units through ASTUnit::CodeComplete.
 */

#ifndef CORECOMPILER_CCASTUNIT_T
#define CORECOMPILER_CCASTUNIT_T

#include <CoreCompiler/CCBase.h>
#include <CoreCompiler/CCDiagnostic.h>
#include <CoreCompiler/CCFile.h>
#include <CoreCompiler/CCFileSourceLocation.h>

typedef CF_ENUM(UInt8, CCASTUnitType) {
    kCCASTUnitTypeClang = 0,
    kCCASTUnitTypeSwift,
};

typedef struct __CCASTUnit *CCASTUnitRef;
typedef struct __CCASTUnit *CCMutableASTUnitRef;

CC_EXPORT CFTypeID CCASTUnitGetTypeID(void);

CC_EXPORT CCMutableASTUnitRef CCASTUnitCreateMutable(CFAllocatorRef allocator, CCASTUnitType type);

CC_EXPORT Boolean CCASTUnitReparse(CCMutableASTUnitRef mutableUnit);

CC_EXPORT void CCASTUnitSetArguments(CCMutableASTUnitRef mutableUnit, CFArrayRef arguments);

CC_EXPORT void CCASTUnitSetFile(CCMutableASTUnitRef mutableUnit, CCFileRef file);
CC_EXPORT CCFileRef CCASTUnitGetFile(CCASTUnitRef unit);
CC_EXPORT CCFileRef CCASTUnitCopyFile(CCASTUnitRef unit);

CC_EXPORT Boolean CCASTUnitErrorOccured(CCASTUnitRef unit);

CC_EXPORT CCFileSourceLocationRef CCASTUnitCopyDefinitionAtLocation(CCASTUnitRef unit, CCSourceLocation location);

CC_EXPORT CFArrayRef CCASTUnitCopyDiagnostics(CCASTUnitRef unit);

/*
 * fork doctoralvarez/Nyxian: code completion (Clang units only).
 *
 * Returns an array of CFDictionaries, or NULL when the unit is not a parsed
 * Clang unit. Keys: "text" (CFString, what is typed/inserted), "display"
 * (CFString, the full signature), "type" (CFString, result type, may be
 * absent), "kind" (CFNumber: 0 declaration, 1 keyword, 2 macro, 3 pattern),
 * "priority" (CFNumber, lower is better). `location` is 1-based; the column
 * counts UTF-8 bytes, like every Clang column.
 */
CC_EXPORT CFArrayRef CCASTUnitCopyCompletionsAtLocation(CCASTUnitRef unit, CCSourceLocation location);

#endif /* CORECOMPILER_CCASTUNIT_T */
