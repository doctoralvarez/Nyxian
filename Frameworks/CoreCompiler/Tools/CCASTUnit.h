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
 *  - 1.4.0 (2026-11-07): CCASTUnitCopyFixIts.
 *  - 1.3.0 (2026-11-07): CCASTUnitCopySignatureHelpAtLocation; completion
 *    dictionaries carry "doc".
 *  - 1.2.0 (2026-11-07): CCCopyFormattedSource (clang-format).
 *  - 1.1.0 (2026-11-07): Swift units are completed too (phase 2).
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
 * fork doctoralvarez/Nyxian: code completion for Clang and Swift units.
 *
 * Returns an array of CFDictionaries, or NULL when the unit is not parsed yet.
 * Keys: "text" (CFString, the name results are filtered by), "display"
 * (CFString, the full signature), "type" (CFString, result type, may be
 * absent), "kind" (CFNumber: 0 declaration, 1 keyword, 2 macro, 3 pattern,
 * 10 type, 11 function, 12 value), "priority" (CFNumber, lower is better).
 * Swift results also carry "insert" (CFString, text to insert with the
 * argument placeholders removed) and "cursor" (CFNumber, UTF-16 offset inside
 * "insert" for the caret). `location` is 1-based; the column counts UTF-8
 * bytes.
 */
CC_EXPORT CFArrayRef CCASTUnitCopyCompletionsAtLocation(CCASTUnitRef unit, CCSourceLocation location);

/*
 * fork doctoralvarez/Nyxian: parameter help for the call around `location`
 * (Clang overloads or Swift signature help). Keys: "text" (CFString),
 * "doc" (CFString, may be absent), "activeStart"/"activeLength" (CFNumber,
 * UTF-16 range of the current argument in text, may be absent), "count"
 * (CFNumber, number of overloads). NULL when there is no call.
 */
CC_EXPORT CFDictionaryRef CCASTUnitCopySignatureHelpAtLocation(CCASTUnitRef unit, CCSourceLocation location);

/*
 * fork doctoralvarez/Nyxian: the compiler's suggested fixes for the edited file,
 * from the last parse. Array of dictionaries: "line", "column" (CFNumber, where
 * the issue is), "message" (CFString), "edits" (CFArray of "startLine",
 * "startColumn", "endLine", "endColumn" — 1-based, UTF-8 byte columns, end
 * exclusive — and "text", the replacement).
 */
CC_EXPORT CFArrayRef CCASTUnitCopyFixIts(CCASTUnitRef unit);

/* fork doctoralvarez/Nyxian: clang-format a C/Objective-C/C++ source (language guessed from fileName); NULL on failure */
CC_EXPORT CFStringRef CCCopyFormattedSource(CFStringRef source, CFStringRef fileName);

#endif /* CORECOMPILER_CCASTUNIT_T */
