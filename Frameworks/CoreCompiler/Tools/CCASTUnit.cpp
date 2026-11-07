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
 *  - 1.3.0 (2026-11-07): brief documentation in completion results (Clang
 *    and Swift); CCASTUnitCopySignatureHelpAtLocation (Clang overloads,
 *    Swift IDEInspectionInstance::signatureHelp); shared request helpers.
 *  - 1.2.0 (2026-11-07): CCCopyFormattedSource, clang-format for C,
 *    Objective-C and C++ (LLVM style, tab indentation, no line reflow).
 *  - 1.1.0 (2026-11-07): Swift code completion (phase 2) through
 *    swift::ide::IDEInspectionInstance, the engine SourceKit uses;
 *    CCASTUnitCopyCompletionsAtLocation now serves Swift units too.
 *  - 1.0.1 (2026-11-07): include FrontendActions.h (complete SyntaxOnlyAction
 *    type for ASTUnit::CodeComplete's unique_ptr argument).
 *  - 1.0.0 (2026-11-07): CCASTUnitCopyCompletionsAtLocation, code completion
 *    for Clang units through ASTUnit::CodeComplete.
 */

#include <CoreCompiler/CCASTUnit.h>
#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Tooling/Tooling.h>
#include <clang/Basic/DiagnosticOptions.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/ADT/StringRef.h>
#include <clang/Basic/LLVM.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <swift/Frontend/Frontend.h>
#include <swift/AST/DiagnosticConsumer.h>
#include <swift/AST/DiagnosticEngine.h>
#include <swift/Basic/SourceManager.h>
#include <llvm/Support/MemoryBuffer.h>
#include <CoreCompiler/CCUtils.h>
#include <clang/Sema/CodeCompleteConsumer.h>
#include <clang/Frontend/FrontendActions.h>
#include <clang/Format/Format.h>
#include <clang/Tooling/Core/Replacement.h>
#include <swift/IDETool/IDEInspectionInstance.h>
#include <swift/IDE/CancellableResult.h>
#include <swift/IDE/CodeCompletionCache.h>
#include <swift/IDE/CodeCompletionContext.h>
#include <swift/IDE/CodeCompletionResult.h>
#include <swift/IDE/CodeCompletionResultSink.h>
#include <swift/IDE/CodeCompletionResultPrinter.h>
#include <swift/IDE/SignatureHelp.h>
#include <swift/IDE/SignatureHelpFormatter.h>
#include <swift/AST/PluginRegistry.h>
#include <llvm/Support/VirtualFileSystem.h>
#include <mutex>
#include <clang/Basic/SourceManager.h>
#include <clang/Basic/FileManager.h>

using namespace clang;
using namespace clang::driver;

struct CapturedDiag {
    swift::DiagID id;
    swift::DiagnosticKind kind;
    std::string message;
    std::string file;
    unsigned line = 0, column = 0;
};

class CapturingConsumer : public swift::DiagnosticConsumer {
public:
    std::vector<CapturedDiag> diags;

    void handleDiagnostic(swift::SourceManager &SM,
                          const swift::DiagnosticInfo &Info) override
    {
        CapturedDiag d;
        d.id = Info.ID;
        d.kind = Info.Kind;
        
        llvm::SmallString<256> buf;
        {
            llvm::raw_svector_ostream os(buf);
            swift::DiagnosticEngine::formatDiagnosticText(os, Info.FormatString, Info.FormatArgs);
        }
        d.message = std::string(buf);

        if(Info.Loc.isValid())
        {
            auto lc = SM.getPresumedLineAndColumnForLoc(Info.Loc);
            d.line = lc.first;
            d.column = lc.second;
            d.file = SM.getDisplayNameForLoc(Info.Loc).str();
        }
        diags.push_back(std::move(d));
    }
};

static CFTypeID gCCASTUnitTypeID = _kCFRuntimeNotATypeID;

struct __CCASTUnit {
    CFRuntimeBase _base;
    CCASTUnitType type;
    Boolean isMutable;
    
    /* clang ast unit property */
    std::unique_ptr<ASTUnit> unit;
    std::unique_ptr<clang::FrontendAction> action;
    
    /* swift driver properties */
    std::unique_ptr<swift::CompilerInstance> CI;
    std::unique_ptr<llvm::MemoryBuffer> primaryBuffer;
    CapturingConsumer consumer;
    
    /* shared ast unit properties */
    std::vector<std::string> BaseArgs;
    CCFileRef file;
    CFArrayRef diagnostics;
};

static void CCASTUnitFinalize(CFTypeRef cf)
{
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)cf;
    
    if(unit->CI != nullptr)
    {
        unit->CI->freeASTContext();
    }
    unit->CI.~unique_ptr();
    unit->primaryBuffer.~unique_ptr();
    unit->consumer.~CapturingConsumer();
    unit->unit.~unique_ptr();
    unit->action.~unique_ptr();
    unit->BaseArgs.~vector();
    
    if(unit->file != nullptr)
    {
        CFRelease(unit->file);
    }
    if(unit->diagnostics != nullptr)
    {
        CFRelease(unit->diagnostics);
    }
}

static void CCASTUnitInit(CFTypeRef cf)
{
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)cf;
    new (&unit->BaseArgs) std::vector<std::string>();
    new (&unit->unit) std::unique_ptr<ASTUnit>();
    new (&unit->action) std::unique_ptr<clang::FrontendAction>();
    new (&unit->CI) std::unique_ptr<swift::CompilerInstance>();
    new (&unit->primaryBuffer) std::unique_ptr<llvm::MemoryBuffer>();
    new (&unit->consumer) CapturingConsumer();
    unit->isMutable = true;
    unit->file = nullptr;
    unit->diagnostics = nullptr;
}

static const CFRuntimeClass gCCASTUnitClass = {
    0,                              /* version */
    "CCASTUnit",                    /* class name */
    CCASTUnitInit,                  /* init */
    NULL,                           /* copy */
    CCASTUnitFinalize,              /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCASTUnitGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCASTUnitTypeID = _CFRuntimeRegisterClass(&gCCASTUnitClass);
    });
    return gCCASTUnitTypeID;
}

Boolean _CCASTUnitRefillDiagnosticArrayClang(CCMutableASTUnitRef mutableUnit)
{
    if(mutableUnit->diagnostics != nullptr)
    {
        return false;
    }
    
    CFAllocatorRef allocator = CFGetAllocator(mutableUnit);
    
    /* now parse the diagnostics */
    CFIndex count = mutableUnit->unit->stored_diag_size();
    CFMutableArrayRef diagnostics = CFArrayCreateMutable(allocator, count, &kCFTypeArrayCallBacks);
    if(diagnostics == nullptr)
    {
        return false;
    }
    
    CFURLRef fileURL = CCFileGetFileURL(mutableUnit->file);
    CFStringRef filePath = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);
    
    /* now indice for indice */
    for(CFIndex i = 0; i < count; i++)
    {
        CCDiagnosticType type = kCCDiagnosticTypeFile;
        CCDiagnosticLevel level;
        CFURLRef fileURL = nullptr;
        CCSourceLocation location;
        CFStringRef message;
        
        const StoredDiagnostic &diag = mutableUnit->unit->stored_diag_begin()[i];
        clang::PresumedLoc loc = mutableUnit->unit->getSourceManager().getPresumedLoc(diag.getLocation());
        
        std::string fileNameStr;
        const char *fileName = nullptr;
        
        if(loc.isValid())
        {
            if(mutableUnit->file != nullptr)
            {
                char filePath[PATH_MAX];
                if(CFURLGetFileSystemRepresentation(CCFileGetFileURL(mutableUnit->file), true, (UInt8*)filePath, sizeof(filePath)))
                {
                    type = (strncmp(filePath, loc.getFilename(), PATH_MAX) == 0) ? kCCDiagnosticTypeTargetFile : kCCDiagnosticTypeFile;
                }
            }
            
            fileName = loc.getFilename();
            location = CCSourceLocationMake(loc.getLine(), loc.getColumn());
        }
        else
        {
            type = kCCDiagnosticTypeInternal;
            location = CCSourceLocationZero;
            
            fileNameStr = mutableUnit->unit->getOriginalSourceFileName().str();
            if(!fileNameStr.empty())
            {
                fileName = fileNameStr.c_str();
            }
        }
        
        if(fileName == nullptr)
        {
            continue;
        }
        
        CFStringRef fileStr = CFStringCreateWithCString(allocator, fileName, kCFStringEncodingUTF8);
        if(fileStr == nullptr)
        {
            continue;
        }
        
        fileURL = CFURLCreateWithFileSystemPath(allocator, fileStr, kCFURLPOSIXPathStyle, false);
        CFRelease(fileStr);
        if(fileURL == nullptr)
        {
            /* in-case fileURL is nullptr then it would crash when creating CCFileSourceLocation */
            continue;
        }
        
        message = CFStringCreateWithCString(allocator, diag.getMessage().str().c_str(), kCFStringEncodingUTF8);
        
        /* resolves message severity  mapping */
        switch(diag.getLevel())
        {
            case clang::DiagnosticsEngine::Note:
                level = kCCDiagnosticLevelNote;
                break;
            case clang::DiagnosticsEngine::Remark:
                level = kCCDiagnosticLevelRemark;
                break;
            case clang::DiagnosticsEngine::Warning:
                level = kCCDiagnosticLevelWarning;
                break;
            case clang::DiagnosticsEngine::Error:
                level = kCCDiagnosticLevelError;
                break;
            case clang::DiagnosticsEngine::Fatal:
                level = kCCDiagnosticLevelFatal;
                break;
            default:
                level = kCCDiagnosticLevelUnknown;
                break;
        }
        
        CCFileSourceLocationRef fileSourceLocation = CCFileSourceLocationCreate(allocator, fileURL, location);
        CCDiagnosticRef result = CCDiagnosticCreate(allocator, type, level, filePath, fileSourceLocation, message);
        if(fileSourceLocation != NULL)
        {
            CFRelease(fileSourceLocation);
        }
        if(fileURL)
        {
            CFRelease(fileURL);
        }
        CFRelease(message);
        
        CFArrayAppendValue(diagnostics, result);
        CFRelease(result); /* array owns now a reference */
    }
    
    CFRelease(filePath);
    
    mutableUnit->diagnostics = diagnostics;
    
    return true;
}

static Boolean _CCASTUnitRefillDiagnosticArraySwift(CCMutableASTUnitRef u)
{
    CFAllocatorRef allocator = CFGetAllocator(u);
    CFMutableArrayRef diagnostics = CFArrayCreateMutable(allocator, u->consumer.diags.size(), &kCFTypeArrayCallBacks);
    if(diagnostics == nullptr)
    {
        return false;
    }
    
    char unitPath[PATH_MAX];
    CFURLGetFileSystemRepresentation(CCFileGetFileURL(u->file), true, (UInt8 *)unitPath, sizeof(unitPath));
    CFStringRef filePath = CFURLCopyFileSystemPath(CCFileGetFileURL(u->file), kCFURLPOSIXPathStyle);
    
    for(const CapturedDiag &d : u->consumer.diags)
    {
        CCDiagnosticLevel level;
        switch(d.kind)
        {
            case swift::DiagnosticKind::Note:
                level = kCCDiagnosticLevelNote;
                break;
            case swift::DiagnosticKind::Remark:
                level = kCCDiagnosticLevelRemark;
                break;
            case swift::DiagnosticKind::Warning:
                level = kCCDiagnosticLevelWarning;
                break;
            case swift::DiagnosticKind::Error:
                level = kCCDiagnosticLevelError;
                break;
            default:
                level = kCCDiagnosticLevelUnknown;
                break;
        }
        if(level == kCCDiagnosticLevelUnknown)
        {
            continue;
        }
        
        CCDiagnosticType type;
        CCSourceLocation location;
        CCFileSourceLocationRef fileSourceLocation = nullptr;
        
        if(d.file.empty())
        {
            type = kCCDiagnosticTypeInternal;
            location = CCSourceLocationZero;
        }
        else
        {
            type = (d.file == unitPath) ? kCCDiagnosticTypeTargetFile : kCCDiagnosticTypeFile;
            location = CCSourceLocationMake(d.line, d.column);
            
            CFStringRef fileStr = CFStringCreateWithCString(allocator, d.file.c_str(), kCFStringEncodingUTF8);
            if(fileStr != nullptr)
            {
                CFURLRef fileURL = CFURLCreateWithFileSystemPath(allocator, fileStr, kCFURLPOSIXPathStyle, false);
                CFRelease(fileStr);
                if(fileURL != nullptr)
                {
                    fileSourceLocation = CCFileSourceLocationCreate(allocator, fileURL, location);
                    CFRelease(fileURL);
                }
            }
        }
        
        CFStringRef message = CFStringCreateWithCString(allocator, d.message.c_str(), kCFStringEncodingUTF8);
        if(message == nullptr)
        {
            if(fileSourceLocation) { CFRelease(fileSourceLocation); }
            continue;
        }
        
        CCDiagnosticRef result = CCDiagnosticCreate(allocator, type, level, filePath, fileSourceLocation, message);
        CFRelease(message);
        if(fileSourceLocation)
        {
            CFRelease(fileSourceLocation);
        }
        if(result == nullptr)
        {
            continue;
        }
        
        CFArrayAppendValue(diagnostics, result);
        CFRelease(result);
    }
    
    CFRelease(filePath);
    u->diagnostics = diagnostics;
    return true;
}

Boolean _CCASTUnitRefillDiagnosticArray(CCMutableASTUnitRef mutableUnit)
{
    if(mutableUnit->diagnostics != nullptr)
    {
        return true;
    }
    switch(mutableUnit->type)
    {
        case kCCASTUnitTypeClang:
            return _CCASTUnitRefillDiagnosticArrayClang(mutableUnit);
        case kCCASTUnitTypeSwift:
            return _CCASTUnitRefillDiagnosticArraySwift(mutableUnit);
        default:
            return false;
    }
}

CCMutableASTUnitRef CCASTUnitCreateMutable(CFAllocatorRef allocator,
                                           CCASTUnitType type)
{
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)_CFRuntimeCreateInstance(allocator, CCASTUnitGetTypeID(), sizeof(__CCASTUnit) - sizeof(CFRuntimeBase), nullptr);
    if(unit == nullptr)
    {
        return nullptr;
    }
    unit->type = type;
    return unit;
}

CCASTUnitRef CCASTUnitCreateWithASTUnit(CFAllocatorRef allocator,
                                        std::unique_ptr<clang::ASTUnit> astUnit,
                                        std::unique_ptr<clang::FrontendAction> action)
{
    assert(astUnit != nullptr);

    CCFileRef file = nullptr;
    std::string originalInputFileName = astUnit->getOriginalSourceFileName().str();
    if(originalInputFileName.empty())
    {
        return nullptr;
    }
    
    const char *originalInputFileNameCStr = originalInputFileName.c_str();
    file = CCFileCreateWithCString(allocator, originalInputFileNameCStr, kCFStringEncodingUTF8);
    if(file == nullptr)
    {
        return nullptr;
    }
    
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)_CFRuntimeCreateInstance(allocator, CCASTUnitGetTypeID(), sizeof(__CCASTUnit) - sizeof(CFRuntimeBase), nullptr);
    if(unit == nullptr)
    {
        CFRelease(file);
        return nullptr;
    }
    
    unit->file = file;
    unit->unit = std::move(astUnit);
    unit->action = std::move(action);
    
    _CCASTUnitRefillDiagnosticArray(unit);

    /* marking immutable, since not a live AST object */
    unit->isMutable = false;

    return (CCASTUnitRef)unit;
}

static const char *_CCASTUnitLangFlagForFile(CCFileRef file)
{
    switch(CCFileGetType(file))
    {
        case kCCFileTypeC:
            return "c";
        /*
         * MARK: special mapping, due to missing indexing in CoreCompiler for now
         *
         * case CCFileTypeCHeader:
         *    return "c-header";
        */
        case kCCFileTypeObjC:
            return "objective-c";
        case kCCFileTypeCHeader:
        case kCCFileTypeObjCHeader:
            return "objective-c-header";
        case kCCFileTypeCXX:
            return "c++";
        case kCCFileTypeCXXHeader:
            return "c++-header";
        case kCCFileTypeObjCXX:
            return "objective-c++";
        case kCCFileTypeObjCXXHeader:
            return "objective-c++-header";
        default:
            return nullptr;
    }
}

Boolean _CCASTUnitReparseClang(CCMutableASTUnitRef mutableUnit)
{
    assert(mutableUnit->isMutable);
    
    /*
     * releasing diagnostics array, because
     * the data it contains is now invalid
     * anyways.
     */
    if(mutableUnit->diagnostics != nullptr)
    {
        CFRelease(mutableUnit->diagnostics);
        
        /* so the data is officially not valid anymore */
        mutableUnit->diagnostics = nullptr;
    }
    
    if(mutableUnit->BaseArgs.size() == 0)
    {
        /* arguments havent been set */
        return false;
    }
    
    /* setting up argument */
    SmallVector<const char *, 64> args;
    for(const std::string &arg : mutableUnit->BaseArgs)
    {
        args.push_back(arg.c_str());
    }
    
    char filePath[PATH_MAX];
    CFURLGetFileSystemRepresentation(CCFileGetFileURL(mutableUnit->file), true, (UInt8*)filePath, sizeof(filePath));
    
    args.push_back(filePath);
    
    IntrusiveRefCntPtr<DiagnosticIDs> diagID(new DiagnosticIDs());
    auto diagOpts = std::make_shared<DiagnosticOptions>();
    IntrusiveRefCntPtr<DiagnosticsEngine> diags(new DiagnosticsEngine(diagID, *diagOpts, new clang::IgnoringDiagConsumer(), /*ShouldOwnClient=*/true));
    
    SmallVector<ASTUnit::RemappedFile, 4> remaps;
    CFDataRef data = CCFileGetUnsavedData(mutableUnit->file);
    if(data != nullptr)
    {
        llvm::StringRef contentRef((const char*)CFDataGetBytePtr(data), CFDataGetLength(data));
        std::unique_ptr<llvm::MemoryBuffer> buf = llvm::MemoryBuffer::getMemBufferCopy(contentRef, filePath);
        auto remap = clang::ASTUnit::RemappedFile(filePath, buf.release());
        remaps.push_back(remap);
    }
    ArrayRef<ASTUnit::RemappedFile> remapRef = remaps;
    
    if(mutableUnit->unit == nullptr)
        reparse_from_nothing:
    {
        mutableUnit->unit = ASTUnit::LoadFromCommandLine(args.data(),
                                                         args.data() + args.size(),
                                                         std::make_shared<PCHContainerOperations>(),
                                                         diagOpts,
                                                         diags,
                                                         "",    /* resources comes from arguments */
                                                         /*StorePreamblesInMemory=*/true,
                                                         /*PreambleStoragePath=*/"",
                                                         /*OnlyLocalDecls=*/false,
                                                         clang::CaptureDiagsKind::All,
                                                         remapRef,
                                                         /*RemappedFilesKeepOriginalName=*/true,
                                                         /*PrecompilePreambleAfterNParses=*/0,  // 0 = no preamble precompilation
                                                         clang::TU_Complete,
                                                         /*CacheCodeCompletionResults=*/false,
                                                         /*IncludeBriefComments=*/false,
                                                         /*AllowPCHWithCompilerErrors=*/false,
                                                         clang::SkipFunctionBodiesScope::None,
                                                         /*SingleFileParse=*/false,
                                                         /*UserFilesAreVolatile=*/false,
                                                         /*ForSerialization=*/false,
                                                         /*RetainExcludedConditionalBlocks=*/false,
                                                         /*ModuleFormat=*/std::nullopt,
                                                         nullptr);
    }
    else if(mutableUnit->unit->Reparse(std::make_shared<PCHContainerOperations>(), remapRef))
    {
        /*
         * failed reparse, gonna have to
         * parse from 0.
         */
        mutableUnit->unit.reset();
        remaps.clear();
        if(data != nullptr)
        {
            llvm::StringRef contentRef((const char*)CFDataGetBytePtr(data), CFDataGetLength(data));
            remaps.push_back(ASTUnit::RemappedFile(filePath, llvm::MemoryBuffer::getMemBufferCopy(contentRef, filePath).release()));
        }
        remapRef = remaps;
        goto reparse_from_nothing;
    }
    
    if((mutableUnit->unit != nullptr) && !_CCASTUnitRefillDiagnosticArray(mutableUnit))
    {
        return false;
    }
    
    return true;
}

static Boolean _CCASTUnitReparseSwift(CCMutableASTUnitRef mutableUnit)
{
    if(mutableUnit->CI != nullptr)
    {
        mutableUnit->CI->freeASTContext();
        mutableUnit->CI.reset();
    }
    mutableUnit->primaryBuffer.reset();
    mutableUnit->consumer.diags.clear();
    
    char primaryPath[PATH_MAX];
    if(!CFURLGetFileSystemRepresentation(CCFileGetFileURL(mutableUnit->file), true, (UInt8 *)primaryPath, sizeof(primaryPath)))
    {
        return false;
    }
    
    auto CI = std::make_unique<swift::CompilerInstance>();
    CI->addDiagnosticConsumer(&mutableUnit->consumer);
    
    llvm::SmallVector<const char *, 64> args;
    for(size_t i = 0; i < mutableUnit->BaseArgs.size(); i++)
    {
        const std::string &arg = mutableUnit->BaseArgs[i];
        if(arg == "-Xfrontend")
        {
            if(i + 1 < mutableUnit->BaseArgs.size())
            {
                args.push_back(mutableUnit->BaseArgs[++i].c_str());
            }
            continue;
        }
        args.push_back(arg.c_str());
    }
    
    swift::CompilerInvocation invocation;
    if(invocation.parseArgs(args, CI->getDiags(), nullptr, "", ""))
    {
        return false;
    }
    
    invocation.getFrontendOptions().RequestedAction = swift::FrontendOptions::ActionType::Typecheck;
    
    /* load unsaved buffer */
    CFDataRef data = CCFileGetUnsavedData(mutableUnit->file);
    if(data != nullptr)
    {
        llvm::StringRef content((const char *)CFDataGetBytePtr(data), CFDataGetLength(data));
        mutableUnit->primaryBuffer = llvm::MemoryBuffer::getMemBufferCopy(content, primaryPath);
    }
    
    {
        auto &io = invocation.getFrontendOptions().InputsAndOutputs;
        swift::FrontendInputsAndOutputs rebuilt;
        for(const auto &in : io.getAllInputs())
        {
            bool isPrimary = (in.getFileName() == primaryPath);
            rebuilt.addInput(swift::InputFile(in.getFileName(), isPrimary, isPrimary ? mutableUnit->primaryBuffer.get() : nullptr));
        }
        io = std::move(rebuilt);
    }
    
    /* so it can build properly */
    CCInitializeSwiftModulesOnce();

    std::string error;
    if(CI->setup(invocation, error))
    {
        return false;
    }
    
    CI->performSema();
    
    mutableUnit->CI = std::move(CI);
    
    return _CCASTUnitRefillDiagnosticArray(mutableUnit);
}

Boolean CCASTUnitReparse(CCMutableASTUnitRef mutableUnit)
{
    assert(mutableUnit->isMutable);
    
    if(mutableUnit->diagnostics != nullptr)
    {
        CFRelease(mutableUnit->diagnostics);
        mutableUnit->diagnostics = nullptr;
    }
    if(mutableUnit->BaseArgs.empty())
    {
        return false;
    }

    switch(mutableUnit->type)
    {
        case kCCASTUnitTypeClang:
            return _CCASTUnitReparseClang(mutableUnit);
        case kCCASTUnitTypeSwift:
            return _CCASTUnitReparseSwift(mutableUnit);
        default:
            return false;
    }
}

void CCASTUnitSetArguments(CCMutableASTUnitRef mutableUnit,
                           CFArrayRef arguments)
{
    assert(mutableUnit->isMutable);
    
    mutableUnit->unit.reset();
    if(mutableUnit->CI != nullptr)
    {
        mutableUnit->CI->freeASTContext();
    }
    mutableUnit->CI.reset();
    mutableUnit->primaryBuffer.reset();
    mutableUnit->BaseArgs.clear();
    
    if(mutableUnit->type == kCCASTUnitTypeClang)
    {
        mutableUnit->BaseArgs.push_back("clang");
        
        const char *lang = _CCASTUnitLangFlagForFile(mutableUnit->file);
        if(lang)
        {
            mutableUnit->BaseArgs.push_back("-x");
            mutableUnit->BaseArgs.push_back(lang);
        }
        
        /*
         * silencing those weird linker warnings
         * on live typechecking, which libclang
         * doesn't do automatically, but it should
         * be done automatically to not piss of
         * developers and engineers like me.
         */
        mutableUnit->BaseArgs.push_back("--start-no-unused-arguments");
        const char *homeEnv = std::getenv("HOME");
        if(homeEnv)
        {
            std::string cachePath = std::string(homeEnv) + "/Documents/Cache/Clang";
            if(!llvm::sys::fs::create_directories(cachePath))
            {
                mutableUnit->BaseArgs.push_back("-fmodules-cache-path=" + cachePath);
            }
        }
        
        CFIndex count = CFArrayGetCount(arguments);
        for(CFIndex i = 0; i < count; i++)
        {
            CFStringRef arg = (CFStringRef)CFArrayGetValueAtIndex(arguments, i);
            const char *ptr = CFStringGetCStringPtr(arg, kCFStringEncodingUTF8);
            if(ptr)
            {
                mutableUnit->BaseArgs.push_back(ptr);
            }
            else
            {
                char buf[1024];
                CFStringGetCString(arg, buf, sizeof(buf), kCFStringEncodingUTF8);
                mutableUnit->BaseArgs.push_back(buf);
            }
        }
        mutableUnit->BaseArgs.push_back("--end-no-unused-arguments");
    }
    else
    {
        mutableUnit->BaseArgs.push_back("-typecheck");
        CFIndex count = CFArrayGetCount(arguments);
        for(CFIndex i = 0; i < count; i++)
        {
            CFStringRef arg = (CFStringRef)CFArrayGetValueAtIndex(arguments, i);
            const char *ptr = CFStringGetCStringPtr(arg, kCFStringEncodingUTF8);
            if(ptr)
            {
                mutableUnit->BaseArgs.push_back(ptr);
            }
            else
            {
                char buf[1024];
                CFStringGetCString(arg, buf, sizeof(buf), kCFStringEncodingUTF8);
                mutableUnit->BaseArgs.push_back(buf);
            }
        }
    }
}

void CCASTUnitSetFile(CCMutableASTUnitRef mutableUnit,
                      CCFileRef file)
{
    assert(mutableUnit->isMutable);

    if(mutableUnit->file != nullptr)
    {
        if(!CFEqual(CCFileGetFileURL(mutableUnit->file), CCFileGetFileURL(file)))
        {
            mutableUnit->unit.reset();
        }
        CFRelease(mutableUnit->file);
    }
    mutableUnit->file = (CCFileRef)CFRetain(file);
}

CCFileRef CCASTUnitGetFile(CCASTUnitRef unit)
{
    return unit->file;
}

CCFileRef CCASTUnitCopyFile(CCASTUnitRef unit)
{
    if(unit->file == nullptr)
    {
        return nullptr;
    }
    return CCFileCreateCopy(CFGetAllocator(unit), unit->file);
}

Boolean CCASTUnitErrorOccured(CCASTUnitRef unit)
{
    switch(unit->type)
    {
        case kCCASTUnitTypeClang:
            return unit->unit ? unit->unit->getDiagnostics().hasErrorOccurred() : true;
        case kCCASTUnitTypeSwift:
            return unit->CI ? unit->CI->getDiags().hadAnyError() : true;
        default:
            return true;
    }
}

class DeclAtLocationVisitor : public RecursiveASTVisitor<DeclAtLocationVisitor> {
public:
    SourceLocation targetLoc;
    SourceManager *SM;
    Decl *found = nullptr;
    
    bool shouldVisitTemplateInstantiations() const { return true; }
    
    bool VisitDeclRefExpr(DeclRefExpr *E)
    {
        if(SM->getSpellingLoc(E->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            found = E->getDecl();
            return false;
        }
        return true;
    }
    
    bool VisitMemberExpr(MemberExpr *E)
    {
        if(SM->getSpellingLoc(E->getMemberLoc()) == SM->getSpellingLoc(targetLoc))
        {
            found = E->getMemberDecl();
            return false;
        }
        return true;
    }
    
    bool VisitObjCMessageExpr(ObjCMessageExpr *E)
    {
        if(SM->getSpellingLoc(E->getSelectorStartLoc()) == SM->getSpellingLoc(targetLoc))
        {
            found = E->getMethodDecl();
            return false;
        }
        return true;
    }
    
    bool VisitObjCPropertyRefExpr(ObjCPropertyRefExpr *E)
    {
        if(SM->getSpellingLoc(E->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            if(E->isExplicitProperty())
            {
                found = E->getExplicitProperty();
            }
            return false;
        }
        return true;
    }
    
    bool VisitObjCInterfaceDecl(ObjCInterfaceDecl *D)
    {
        if(D->getSuperClass() &&
           SM->getSpellingLoc(D->getSuperClassLoc()) == SM->getSpellingLoc(targetLoc))
        {
            found = D->getSuperClass()->getDefinition();
            if(!found)
            {
                found = D->getSuperClass();
            }
            return false;
        }
        
        auto locIt = D->protocol_loc_begin();
        for(auto *proto : D->protocols())
        {
            if(SM->getSpellingLoc(*locIt) == SM->getSpellingLoc(targetLoc))
            {
                found = proto->getDefinition();
                if(!found)
                {
                    found = proto;
                }
                return false;
            }
            ++locIt;
        }
        
        return true;
    }
    
    bool VisitObjCCategoryDecl(ObjCCategoryDecl *D)
    {
        if(D->getClassInterface() &&
           SM->getSpellingLoc(D->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            found = D->getClassInterface()->getDefinition();
            return false;
        }
        return true;
    }
    
    bool VisitObjCImplementationDecl(ObjCImplementationDecl *D)
    {
        if(SM->getSpellingLoc(D->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            ObjCInterfaceDecl *iface = D->getClassInterface();
            if(iface)
            {
                found = iface->getDefinition();
                return false;
            }
        }
        return true;
    }
    
    bool VisitObjCInterfaceTypeLoc(ObjCInterfaceTypeLoc TL)
    {
        if(SM->getSpellingLoc(TL.getNameLoc()) == SM->getSpellingLoc(targetLoc))
        {
            ObjCInterfaceDecl *iface = TL.getIFaceDecl();
            if(iface)
            {
                found = iface->getDefinition();
                if(!found)
                {
                    found = iface;
                }
                return false;
            }
        }
        return true;
    }
    
    bool VisitNamedDecl(NamedDecl *D)
    {
        if(SM->getSpellingLoc(D->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            found = D;
            return false;
        }
        return true;
    }
};

CCFileSourceLocationRef CCASTUnitCopyDefinitionAtLocation(CCASTUnitRef unit,
                                                          CCSourceLocation location)
{
    if(unit->unit == nullptr || unit->file == nullptr || unit->type == kCCASTUnitTypeSwift)
    {
        return nullptr;
    }
    
    char filePath[PATH_MAX];
    if(!CFURLGetFileSystemRepresentation(CCFileGetFileURL(unit->file), true, (UInt8*)filePath, sizeof(filePath)))
    {
        return nullptr;
    }
    
    SourceManager &SM = unit->unit->getSourceManager();
    FileManager &FM = unit->unit->getFileManager();
    
    auto fileEntry = FM.getFileRef(filePath);
    if(!fileEntry)
    {
        return nullptr;
    }
    
    FileID fileID = SM.translateFile(*fileEntry);
    if(fileID.isInvalid())
    {
        return nullptr;
    }
    
    SourceLocation loc = SM.translateLineCol(fileID, (unsigned int)location.line, (unsigned int)location.column);
    if(loc.isInvalid())
    {
        return nullptr;
    }
    
    DeclAtLocationVisitor visitor;
    visitor.targetLoc = loc;
    visitor.SM = &SM;
    visitor.TraverseAST(unit->unit->getASTContext());
    
    Decl *cursor = visitor.found;
    if(!cursor)
    {
        return nullptr;
    }
    
    Decl *defDecl = nullptr;
    
    /* getting definition (hopefully) */
    if(auto *ID = dyn_cast<ObjCInterfaceDecl>(cursor))
    {
        defDecl = ID->getDefinition();
    }
    else if(auto *PD = dyn_cast<ObjCProtocolDecl>(cursor))
    {
        defDecl = PD->getDefinition();
    }
    else if(auto *TD = dyn_cast<TagDecl>(cursor))
    {
        defDecl = TD->getDefinition();
    }
    else if(auto *FD = dyn_cast<FunctionDecl>(cursor))
    {
        defDecl = FD->getDefinition();
    }
    
    /* last resort */
    if(defDecl == nullptr)
    {
        defDecl = cursor->getCanonicalDecl();
    }
    
    if(!defDecl)
    {
        return nullptr;
    }
    
    SourceLocation defLoc = defDecl->getLocation();
    PresumedLoc presumed = SM.getPresumedLoc(defLoc);
    
    if(presumed.isInvalid())
    {
        return nullptr;
    }
    
    CFAllocatorRef allocator = CFGetAllocator(unit);
    CFStringRef fileStr = CFStringCreateWithCString(allocator, presumed.getFilename(), kCFStringEncodingUTF8);
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(allocator, fileStr, kCFURLPOSIXPathStyle, false);
    CFRelease(fileStr);
    
    CCSourceLocation resultLoc = CCSourceLocationMake(presumed.getLine(), presumed.getColumn());
    CCFileSourceLocationRef result = CCFileSourceLocationCreate(allocator, fileURL, resultLoc);
    CFRelease(fileURL);
    return result;
}

CFArrayRef CCASTUnitCopyDiagnostics(CCASTUnitRef unit)
{
    if(unit->diagnostics == nullptr)
    {
        return nullptr;
    }
    return (CFArrayRef)CFRetain(unit->diagnostics);
}

#pragma mark - fork: code completion

namespace {

struct CCCompletionItem {
    std::string text;
    std::string display;
    std::string resultType;
    std::string doc;
    int kind;
    unsigned priority;
};

struct CCSignatureItem {
    std::string text;
    std::string doc;
    long activeStart;   /* byte offset of the current argument in text, -1 when unknown */
    long activeLength;
};

/* Turns Clang's completion results (and call overloads) into plain strings while Sema is still alive. */
class CCCollectingCompletionConsumer : public clang::CodeCompleteConsumer {
public:
    explicit CCCollectingCompletionConsumer(const clang::CodeCompleteOptions &options)
        : clang::CodeCompleteConsumer(options),
          CCTUInfo(std::make_shared<clang::GlobalCodeCompletionAllocator>()) {}
    
    void ProcessCodeCompleteResults(clang::Sema &S,
                                    clang::CodeCompletionContext Context,
                                    clang::CodeCompletionResult *Results,
                                    unsigned NumResults) override
    {
        for(unsigned i = 0; i < NumResults && items.size() < 5000; i++)
        {
            clang::CodeCompletionResult &result = Results[i];
            if(result.Availability == CXAvailability_NotAvailable ||
               result.Availability == CXAvailability_NotAccessible)
            {
                continue;
            }
            
            clang::CodeCompletionString *completion = result.CreateCodeCompletionString(S, Context, getAllocator(), CCTUInfo, /*IncludeBriefComments=*/true);
            if(completion == nullptr)
            {
                continue;
            }
            
            const char *typed = completion->getTypedText();
            if(typed == nullptr || typed[0] == '\0')
            {
                continue;
            }
            
            CCCompletionItem item;
            item.text = typed;
            item.kind = (int)result.Kind;
            item.priority = completion->getPriority();
            if(const char *brief = completion->getBriefComment())
            {
                item.doc = brief;
            }
            
            for(const clang::CodeCompletionString::Chunk &chunk : *completion)
            {
                switch(chunk.Kind)
                {
                    case clang::CodeCompletionString::CK_Optional:
                        /* nested optional parameters are left out of the summary */
                        break;
                    case clang::CodeCompletionString::CK_ResultType:
                        if(chunk.Text != nullptr) item.resultType = chunk.Text;
                        break;
                    case clang::CodeCompletionString::CK_Informative:
                        break;
                    default:
                        if(chunk.Text != nullptr) item.display += chunk.Text;
                        break;
                }
            }
            
            items.push_back(std::move(item));
        }
    }
    
    void ProcessOverloadCandidates(clang::Sema &S,
                                   unsigned CurrentArg,
                                   OverloadCandidate *Candidates,
                                   unsigned NumCandidates,
                                   clang::SourceLocation OpenParLoc,
                                   bool Braced) override
    {
        for(unsigned i = 0; i < NumCandidates && signatures.size() < 32; i++)
        {
            clang::CodeCompletionString *signature = Candidates[i].CreateSignatureString(CurrentArg, S, getAllocator(), CCTUInfo, /*IncludeBriefComments=*/true, Braced);
            if(signature == nullptr)
            {
                continue;
            }
            
            CCSignatureItem item;
            item.activeStart = -1;
            item.activeLength = 0;
            std::string resultType;
            for(const clang::CodeCompletionString::Chunk &chunk : *signature)
            {
                if(chunk.Kind == clang::CodeCompletionString::CK_Optional || chunk.Text == nullptr)
                {
                    continue;
                }
                if(chunk.Kind == clang::CodeCompletionString::CK_ResultType)
                {
                    resultType = chunk.Text;
                    continue;
                }
                if(chunk.Kind == clang::CodeCompletionString::CK_CurrentParameter)
                {
                    item.activeStart = (long)item.text.size();
                    item.activeLength = (long)strlen(chunk.Text);
                }
                item.text += chunk.Text;
            }
            if(!resultType.empty())
            {
                /* "int printf(const char *, ...)" */
                std::string prefix = resultType + " ";
                item.text = prefix + item.text;
                if(item.activeStart >= 0)
                {
                    item.activeStart += (long)prefix.size();
                }
            }
            if(const char *brief = signature->getBriefComment())
            {
                item.doc = brief;
            }
            if(!item.text.empty())
            {
                signatures.push_back(std::move(item));
            }
        }
    }
    
    clang::CodeCompletionAllocator &getAllocator() override
    {
        return CCTUInfo.getAllocator();
    }
    
    clang::CodeCompletionTUInfo &getCodeCompletionTUInfo() override
    {
        return CCTUInfo;
    }
    
    std::vector<CCCompletionItem> items;
    std::vector<CCSignatureItem> signatures;
    
private:
    clang::CodeCompletionTUInfo CCTUInfo;
};

static CFStringRef CCCreateCFString(const std::string &value)
{
    return CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)value.data(), (CFIndex)value.size(), kCFStringEncodingUTF8, false);
}

/* UTF-16 length of the first `bytes` UTF-8 bytes of `text` (the editor counts in UTF-16) */
static CFIndex CCUTF16Length(const std::string &text, size_t bytes)
{
    if(bytes > text.size())
    {
        bytes = text.size();
    }
    CFStringRef head = CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)text.data(), (CFIndex)bytes, kCFStringEncodingUTF8, false);
    if(head == nullptr)
    {
        return (CFIndex)bytes;
    }
    CFIndex length = CFStringGetLength(head);
    CFRelease(head);
    return length;
}

static void CCDictionarySetString(CFMutableDictionaryRef dict, CFStringRef key, const std::string &value)
{
    if(value.empty())
    {
        return;
    }
    CFStringRef string = CCCreateCFString(value);
    if(string != nullptr)
    {
        CFDictionarySetValue(dict, key, string);
        CFRelease(string);
    }
}

static void CCDictionarySetNumber(CFMutableDictionaryRef dict, CFStringRef key, long value)
{
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &value);
    if(number != nullptr)
    {
        CFDictionarySetValue(dict, key, number);
        CFRelease(number);
    }
}

/* the signature dictionary handed to the editor: text, doc, activeStart/activeLength (UTF-16), count */
static CFDictionaryRef CCCreateSignatureDictionary(const std::string &text, const std::string &doc, long activeStart, long activeLength, long count)
{
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if(dict == nullptr)
    {
        return nullptr;
    }
    CCDictionarySetString(dict, CFSTR("text"), text);
    CCDictionarySetString(dict, CFSTR("doc"), doc);
    if(activeStart >= 0 && activeLength > 0)
    {
        CFIndex start = CCUTF16Length(text, (size_t)activeStart);
        CFIndex end = CCUTF16Length(text, (size_t)(activeStart + activeLength));
        CCDictionarySetNumber(dict, CFSTR("activeStart"), (long)start);
        CCDictionarySetNumber(dict, CFSTR("activeLength"), (long)(end - start));
    }
    CCDictionarySetNumber(dict, CFSTR("count"), count);
    return dict;
}

} /* namespace */

/* Runs ASTUnit::CodeComplete for a Clang unit at `location` against the unsaved text. */
static Boolean _CCASTUnitRunClangCodeComplete(CCASTUnitRef unit, CCSourceLocation location, CCCollectingCompletionConsumer &consumer)
{
    if(unit == nullptr || unit->type != kCCASTUnitTypeClang || unit->unit == nullptr || unit->file == nullptr)
    {
        return false;
    }
    if(!location.isValid || location.line <= 0 || location.column <= 0)
    {
        return false;
    }
    
    char filePath[PATH_MAX];
    if(!CFURLGetFileSystemRepresentation(CCFileGetFileURL(unit->file), true, (UInt8 *)filePath, sizeof(filePath)))
    {
        return false;
    }
    
    /* complete against the editor's current text, not the file on disk */
    SmallVector<ASTUnit::RemappedFile, 1> remaps;
    CFDataRef data = CCFileGetUnsavedData(unit->file);
    if(data != nullptr)
    {
        llvm::StringRef contentRef((const char *)CFDataGetBytePtr(data), CFDataGetLength(data));
        remaps.push_back(ASTUnit::RemappedFile(filePath, llvm::MemoryBuffer::getMemBufferCopy(contentRef, filePath).release()));
    }
    
    /* the same fresh managers libclang hands to ASTUnit::CodeComplete */
    DiagnosticOptions diagOpts;
    {
        IntrusiveRefCntPtr<DiagnosticsEngine> diag(new DiagnosticsEngine(new DiagnosticIDs(), diagOpts, new clang::IgnoringDiagConsumer(), /*ShouldOwnClient=*/true));
        IntrusiveRefCntPtr<FileManager> fileMgr = unit->unit->getFileManagerPtr();
        IntrusiveRefCntPtr<SourceManager> sourceMgr(new SourceManager(*diag, *fileMgr));
        LangOptions langOpts = unit->unit->getLangOpts();
        SmallVector<StoredDiagnostic, 8> storedDiagnostics;
        SmallVector<const llvm::MemoryBuffer *, 1> ownedBuffers;
        
        unit->unit->CodeComplete(llvm::StringRef(filePath),
                                 (unsigned)location.line,
                                 (unsigned)location.column,
                                 remaps,
                                 /*IncludeMacros=*/true,
                                 /*IncludeCodePatterns=*/false,
                                 /*IncludeBriefComments=*/true,
                                 consumer,
                                 std::make_shared<PCHContainerOperations>(),
                                 diag,
                                 langOpts,
                                 sourceMgr,
                                 fileMgr,
                                 storedDiagnostics,
                                 ownedBuffers,
                                 nullptr);
        
        /* CodeComplete moved the remapped buffers into ownedBuffers */
        for(const llvm::MemoryBuffer *buffer : ownedBuffers)
        {
            delete buffer;
        }
    }
    return true;
}

static clang::CodeCompleteOptions CCCompletionOptions(void)
{
    clang::CodeCompleteOptions options;
    options.IncludeMacros = 1;
    options.IncludeCodePatterns = 0;
    options.IncludeGlobals = 1;
    options.IncludeBriefComments = 1;
    return options;
}

static CFArrayRef _CCASTUnitCopySwiftCompletions(CCASTUnitRef unit, CCSourceLocation location);
static CFDictionaryRef _CCASTUnitCopySwiftSignatureHelp(CCASTUnitRef unit, CCSourceLocation location);

CFArrayRef CCASTUnitCopyCompletionsAtLocation(CCASTUnitRef unit,
                                              CCSourceLocation location)
{
    if(unit != nullptr && unit->type == kCCASTUnitTypeSwift)
    {
        return _CCASTUnitCopySwiftCompletions(unit, location);
    }
    
    CCCollectingCompletionConsumer consumer(CCCompletionOptions());
    if(!_CCASTUnitRunClangCodeComplete(unit, location, consumer))
    {
        return nullptr;
    }
    
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)consumer.items.size(), &kCFTypeArrayCallBacks);
    if(array == nullptr)
    {
        return nullptr;
    }
    
    for(const CCCompletionItem &item : consumer.items)
    {
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 6, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if(dict == nullptr)
        {
            continue;
        }
        CCDictionarySetString(dict, CFSTR("text"), item.text);
        CCDictionarySetString(dict, CFSTR("display"), item.display.empty() ? item.text : item.display);
        CCDictionarySetString(dict, CFSTR("type"), item.resultType);
        CCDictionarySetString(dict, CFSTR("doc"), item.doc);
        CCDictionarySetNumber(dict, CFSTR("kind"), (long)item.kind);
        CCDictionarySetNumber(dict, CFSTR("priority"), (long)item.priority);
        if(CFDictionaryContainsKey(dict, CFSTR("text")))
        {
            CFArrayAppendValue(array, dict);
        }
        CFRelease(dict);
    }
    
    return array;
}

CFDictionaryRef CCASTUnitCopySignatureHelpAtLocation(CCASTUnitRef unit,
                                                     CCSourceLocation location)
{
    if(unit != nullptr && unit->type == kCCASTUnitTypeSwift)
    {
        return _CCASTUnitCopySwiftSignatureHelp(unit, location);
    }
    
    CCCollectingCompletionConsumer consumer(CCCompletionOptions());
    if(!_CCASTUnitRunClangCodeComplete(unit, location, consumer) || consumer.signatures.empty())
    {
        return nullptr;
    }
    
    /* prefer an overload that knows which argument is being typed */
    const CCSignatureItem *best = &consumer.signatures.front();
    for(const CCSignatureItem &signature : consumer.signatures)
    {
        if(signature.activeStart >= 0)
        {
            best = &signature;
            break;
        }
    }
    return CCCreateSignatureDictionary(best->text, best->doc, best->activeStart, best->activeLength, (long)consumer.signatures.size());
}

#pragma mark - fork: Swift code completion (phase 2)

namespace {

struct CCSwiftCompletionItem {
    std::string name;
    std::string display;
    std::string resultType;
    std::string insert;
    std::string doc;
    long cursor;
    int kind;
    int priority;
};

/* "font(<#T##font: Font?##Font?#>)" -> "font()" with the caret where the first placeholder was */
static void CCStripSwiftPlaceholders(const std::string &source, std::string &out, long &cursor)
{
    out.clear();
    cursor = -1;
    size_t i = 0;
    while(i < source.size())
    {
        if(source.compare(i, 2, "<#") == 0)
        {
            size_t end = source.find("#>", i + 2);
            if(end == std::string::npos)
            {
                out.append(source, i, std::string::npos);
                break;
            }
            if(cursor < 0)
            {
                cursor = (long)out.size();
            }
            i = end + 2;
            continue;
        }
        out.push_back(source[i]);
        i++;
    }
    if(cursor < 0)
    {
        cursor = (long)out.size();
    }
}

/* the identifier a result is filtered by: "font(_ font: Font?)" -> "font" */
static std::string CCSwiftCompletionName(const std::string &display)
{
    size_t i = 0;
    while(i < display.size() && (display[i] == '.' || display[i] == '@' || display[i] == '#'))
    {
        i++;
    }
    size_t start = i;
    while(i < display.size())
    {
        unsigned char c = (unsigned char)display[i];
        if(isalnum(c) || c == '_' || c >= 0x80)
        {
            i++;
            continue;
        }
        break;
    }
    return display.substr(start, i - start);
}

static int CCSwiftCompletionKind(const swift::ide::CodeCompletionResult *result)
{
    using swift::ide::CodeCompletionResultKind;
    using swift::ide::CodeCompletionDeclKind;
    switch(result->getKind())
    {
        case CodeCompletionResultKind::Keyword:
            return 1;
        case CodeCompletionResultKind::Pattern:
        case CodeCompletionResultKind::Literal:
        case CodeCompletionResultKind::BuiltinOperator:
            return 3;
        case CodeCompletionResultKind::Declaration:
            break;
    }
    switch(result->getAssociatedDeclKind())
    {
        case CodeCompletionDeclKind::Class:
        case CodeCompletionDeclKind::Actor:
        case CodeCompletionDeclKind::Struct:
        case CodeCompletionDeclKind::Enum:
        case CodeCompletionDeclKind::Protocol:
        case CodeCompletionDeclKind::TypeAlias:
        case CodeCompletionDeclKind::AssociatedType:
        case CodeCompletionDeclKind::GenericTypeParam:
            return 10; /* type */
        case CodeCompletionDeclKind::Constructor:
        case CodeCompletionDeclKind::StaticMethod:
        case CodeCompletionDeclKind::InstanceMethod:
        case CodeCompletionDeclKind::FreeFunction:
        case CodeCompletionDeclKind::Subscript:
            return 11; /* function */
        case CodeCompletionDeclKind::StaticVar:
        case CodeCompletionDeclKind::InstanceVar:
        case CodeCompletionDeclKind::LocalVar:
        case CodeCompletionDeclKind::GlobalVar:
        case CodeCompletionDeclKind::EnumElement:
            return 12; /* value */
        case CodeCompletionDeclKind::Macro:
            return 2;
        default:
            return 0;
    }
}

/* one engine for the whole process, like a SourceKit context: it keeps the last
 * type-checked AST and reuses it while the edits stay inside function bodies */
static swift::ide::IDEInspectionInstance &CCSharedIDEInspectionInstance(void)
{
    static swift::ide::IDEInspectionInstance *instance = new swift::ide::IDEInspectionInstance(std::make_shared<swift::PluginRegistry>());
    return *instance;
}

static swift::ide::CodeCompletionCache &CCSharedCompletionCache(void)
{
    static swift::ide::CodeCompletionCache *cache = new swift::ide::CodeCompletionCache();
    return *cache;
}

/* the cache above is not documented as thread safe */
static std::mutex gCCSwiftCompletionMutex;

static CFStringRef CCCreateSwiftCFString(const std::string &value)
{
    return CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)value.data(), (CFIndex)value.size(), kCFStringEncodingUTF8, false);
}

} /* namespace */

/* Everything the Swift IDE engine needs for a request at `location` of the unit's unsaved text. */
struct CCSwiftRequest {
    std::string primaryPath;
    llvm::SmallVector<const char *, 64> args;
    swift::CompilerInvocation invocation;
    std::unique_ptr<llvm::MemoryBuffer> buffer;
    unsigned offset;
};

static bool _CCSwiftPrepareRequest(CCASTUnitRef unit, CCSourceLocation location, CCSwiftRequest &request)
{
    if(unit->file == nullptr || unit->BaseArgs.empty() || !location.isValid || location.line <= 0 || location.column <= 0)
    {
        return false;
    }
    
    char primaryPath[PATH_MAX];
    if(!CFURLGetFileSystemRepresentation(CCFileGetFileURL(unit->file), true, (UInt8 *)primaryPath, sizeof(primaryPath)))
    {
        return false;
    }
    request.primaryPath = primaryPath;
    
    CFDataRef data = CCFileGetUnsavedData(unit->file);
    if(data == nullptr)
    {
        return false;
    }
    llvm::StringRef content((const char *)CFDataGetBytePtr(data), CFDataGetLength(data));
    
    /* 1-based line and UTF-8 column -> byte offset */
    size_t offset = 0;
    for(CFIndex line = 1; line < location.line; line++)
    {
        size_t newline = content.find('\n', offset);
        if(newline == llvm::StringRef::npos)
        {
            return false;
        }
        offset = newline + 1;
    }
    offset += (size_t)(location.column - 1);
    if(offset > content.size())
    {
        return false;
    }
    
    /* same frontend arguments as the live type checking in _CCASTUnitReparseSwift */
    for(size_t i = 0; i < unit->BaseArgs.size(); i++)
    {
        const std::string &arg = unit->BaseArgs[i];
        if(arg == "-Xfrontend")
        {
            if(i + 1 < unit->BaseArgs.size())
            {
                request.args.push_back(unit->BaseArgs[++i].c_str());
            }
            continue;
        }
        request.args.push_back(arg.c_str());
    }
    
    CCInitializeSwiftModulesOnce();
    
    swift::SourceManager parseSM;
    swift::DiagnosticEngine parseDiags(parseSM);
    if(request.invocation.parseArgs(request.args, parseDiags, nullptr, "", ""))
    {
        return false;
    }
    request.invocation.getFrontendOptions().RequestedAction = swift::FrontendOptions::ActionType::Typecheck;
    
    /* the edited file is the primary input; its text comes from the request buffer */
    {
        auto &io = request.invocation.getFrontendOptions().InputsAndOutputs;
        swift::FrontendInputsAndOutputs rebuilt;
        bool foundPrimary = false;
        for(const auto &in : io.getAllInputs())
        {
            bool isPrimary = (in.getFileName() == request.primaryPath);
            foundPrimary = foundPrimary || isPrimary;
            rebuilt.addInput(swift::InputFile(in.getFileName(), isPrimary));
        }
        if(!foundPrimary)
        {
            rebuilt.addInput(swift::InputFile(request.primaryPath, true));
        }
        io = std::move(rebuilt);
    }
    
    std::unique_ptr<llvm::MemoryBuffer> original = llvm::MemoryBuffer::getMemBufferCopy(content, request.primaryPath);
    request.offset = (unsigned)offset;
    request.buffer = swift::ide::makeCodeCompletionMemoryBuffer(original.get(), request.offset, request.primaryPath);
    return request.buffer != nullptr;
}

static CFArrayRef _CCASTUnitCopySwiftCompletions(CCASTUnitRef unit, CCSourceLocation location)
{
    CCSwiftRequest request;
    if(!_CCSwiftPrepareRequest(unit, location, request))
    {
        return nullptr;
    }
    swift::CompilerInvocation &invocation = request.invocation;
    llvm::SmallVector<const char *, 64> &args = request.args;
    std::unique_ptr<llvm::MemoryBuffer> &completionBuffer = request.buffer;
    unsigned completionOffset = request.offset;
    
    std::vector<CCSwiftCompletionItem> items;
    
    {
        std::lock_guard<std::mutex> guard(gCCSwiftCompletionMutex);
        
        swift::ide::CodeCompletionContext completionContext(CCSharedCompletionCache());
        completionContext.setAnnotateResult(false);
        
        CCSharedIDEInspectionInstance().codeComplete(
            invocation,
            args,
            llvm::vfs::getRealFileSystem(),
            completionBuffer.get(),
            completionOffset,
            /*DiagC=*/nullptr,
            completionContext,
            /*CancellationFlag=*/nullptr,
            [&](swift::ide::CancellableResult<swift::ide::CodeCompleteResult> result) {
                if(result.getKind() != swift::ide::CancellableResultKind::Success)
                {
                    return;
                }
                
                const swift::ide::CodeCompleteResult &success = result.getResult();
                for(swift::ide::CodeCompletionResult *completion : success.ResultSink.Results)
                {
                    if(completion == nullptr || items.size() >= 5000)
                    {
                        continue;
                    }
                    
                    CCSwiftCompletionItem item;
                    {
                        llvm::raw_string_ostream os(item.display);
                        swift::ide::printCodeCompletionResultDescription(*completion, os, /*leadingPunctuation=*/false);
                    }
                    {
                        llvm::raw_string_ostream os(item.resultType);
                        swift::ide::printCodeCompletionResultTypeName(*completion, os);
                    }
                    std::string source;
                    {
                        llvm::raw_string_ostream os(source);
                        swift::ide::printCodeCompletionResultSourceText(*completion, os);
                    }
                    
                    llvm::StringRef brief = completion->getBriefDocComment();
                    item.doc = brief.str();
                    
                    item.name = CCSwiftCompletionName(item.display);
                    if(item.name.empty())
                    {
                        continue;
                    }
                    CCStripSwiftPlaceholders(source, item.insert, item.cursor);
                    if(item.insert.empty())
                    {
                        item.insert = item.name;
                        item.cursor = (long)item.insert.size();
                    }
                    item.kind = CCSwiftCompletionKind(completion);
                    /* nearer contexts first (locals, members, module, then the SDK); not recommended last */
                    item.priority = (int)completion->getSemanticContext() * 10 + (completion->isNotRecommended() ? 1000 : 0);
                    items.push_back(std::move(item));
                }
            });
    }
    
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)items.size(), &kCFTypeArrayCallBacks);
    if(array == nullptr)
    {
        return nullptr;
    }
    
    for(const CCSwiftCompletionItem &item : items)
    {
        CFStringRef text = CCCreateSwiftCFString(item.name);
        CFStringRef display = CCCreateSwiftCFString(item.display.empty() ? item.name : item.display);
        CFStringRef insert = CCCreateSwiftCFString(item.insert);
        CFStringRef type = item.resultType.empty() ? nullptr : CCCreateSwiftCFString(item.resultType);
        if(text == nullptr || display == nullptr || insert == nullptr)
        {
            if(text) CFRelease(text);
            if(display) CFRelease(display);
            if(insert) CFRelease(insert);
            if(type) CFRelease(type);
            continue;
        }
        
        /* the caret offset inside "insert" is in UTF-16 units, as the editor counts */
        CFIndex cursorUTF16 = CFStringGetLength(insert);
        if(item.cursor >= 0 && (size_t)item.cursor <= item.insert.size())
        {
            CFStringRef head = CCCreateSwiftCFString(item.insert.substr(0, (size_t)item.cursor));
            if(head != nullptr)
            {
                cursorUTF16 = CFStringGetLength(head);
                CFRelease(head);
            }
        }
        
        int kind = item.kind;
        int priority = item.priority;
        long cursor = (long)cursorUTF16;
        CFNumberRef kindNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &kind);
        CFNumberRef priorityNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &priority);
        CFNumberRef cursorNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &cursor);
        
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 7, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(dict, CFSTR("text"), text);
        CFDictionarySetValue(dict, CFSTR("display"), display);
        CFDictionarySetValue(dict, CFSTR("insert"), insert);
        CCDictionarySetString(dict, CFSTR("doc"), item.doc);
        if(type != nullptr) CFDictionarySetValue(dict, CFSTR("type"), type);
        if(kindNumber != nullptr) CFDictionarySetValue(dict, CFSTR("kind"), kindNumber);
        if(priorityNumber != nullptr) CFDictionarySetValue(dict, CFSTR("priority"), priorityNumber);
        if(cursorNumber != nullptr) CFDictionarySetValue(dict, CFSTR("cursor"), cursorNumber);
        CFArrayAppendValue(array, dict);
        
        CFRelease(dict);
        CFRelease(text);
        CFRelease(display);
        CFRelease(insert);
        if(type != nullptr) CFRelease(type);
        if(kindNumber != nullptr) CFRelease(kindNumber);
        if(priorityNumber != nullptr) CFRelease(priorityNumber);
        if(cursorNumber != nullptr) CFRelease(cursorNumber);
    }
    
    return array;
}

#pragma mark - fork: Swift signature help

static CFDictionaryRef _CCASTUnitCopySwiftSignatureHelp(CCASTUnitRef unit, CCSourceLocation location)
{
    CCSwiftRequest request;
    if(!_CCSwiftPrepareRequest(unit, location, request))
    {
        return nullptr;
    }
    
    std::string text;
    std::string doc;
    long activeStart = -1;
    long activeLength = 0;
    long count = 0;
    
    {
        std::lock_guard<std::mutex> guard(gCCSwiftCompletionMutex);
        
        CCSharedIDEInspectionInstance().signatureHelp(
            request.invocation,
            request.args,
            llvm::vfs::getRealFileSystem(),
            request.buffer.get(),
            request.offset,
            /*DiagC=*/nullptr,
            /*CancellationFlag=*/nullptr,
            [&](swift::ide::CancellableResult<swift::ide::SignatureHelpResults> result) {
                if(result.getKind() != swift::ide::CancellableResultKind::Success)
                {
                    return;
                }
                const swift::ide::SignatureHelpResults &success = result.getResult();
                if(success.Result == nullptr)
                {
                    return;
                }
                
                llvm::BumpPtrAllocator allocator;
                swift::ide::SignatureHelpFormatter formatter(allocator);
                swift::ide::FormattedSignatureHelp formatted = formatter.format(*success.Result);
                if(formatted.Signatures.empty())
                {
                    return;
                }
                
                count = (long)formatted.Signatures.size();
                unsigned index = formatted.ActiveSignature < formatted.Signatures.size() ? formatted.ActiveSignature : 0;
                const swift::ide::FormattedSignatureHelp::Signature &signature = formatted.Signatures[index];
                text = signature.Text.str();
                doc = signature.DocComment.str();
                if(signature.ActiveParam.has_value() && *signature.ActiveParam < signature.Params.size())
                {
                    const swift::ide::FormattedSignatureHelp::Parameter &parameter = signature.Params[*signature.ActiveParam];
                    activeStart = (long)parameter.Offset;
                    activeLength = (long)parameter.Length;
                }
            });
    }
    
    if(text.empty())
    {
        return nullptr;
    }
    return CCCreateSignatureDictionary(text, doc, activeStart, activeLength, count);
}

#pragma mark - fork: clang-format

CFStringRef CCCopyFormattedSource(CFStringRef source, CFStringRef fileName)
{
    if(source == nullptr)
    {
        return nullptr;
    }
    
    auto toUTF8 = [](CFStringRef string) -> std::string {
        if(string == nullptr)
        {
            return std::string();
        }
        CFIndex length = CFStringGetLength(string);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        std::string buffer((size_t)maxSize, '\0');
        if(!CFStringGetCString(string, &buffer[0], maxSize, kCFStringEncodingUTF8))
        {
            return std::string();
        }
        buffer.resize(strlen(buffer.c_str()));
        return buffer;
    };
    
    std::string code = toUTF8(source);
    std::string name = toUTF8(fileName);
    if(name.empty())
    {
        name = "source.m";
    }
    
    clang::format::FormatStyle::LanguageKind language = clang::format::guessLanguage(name, code);
    clang::format::FormatStyle style = clang::format::getLLVMStyle(language);
    /* match the editor: tabs of width 4, and never re-wrap the user's lines */
    style.IndentWidth = 4;
    style.TabWidth = 4;
    style.UseTab = clang::format::FormatStyle::UT_ForIndentation;
    style.ColumnLimit = 0;
    
    std::vector<clang::tooling::Range> ranges;
    ranges.push_back(clang::tooling::Range(0, (unsigned)code.size()));
    clang::tooling::Replacements replacements = clang::format::reformat(style, code, ranges, name);
    llvm::Expected<std::string> formatted = clang::tooling::applyAllReplacements(code, replacements);
    if(!formatted)
    {
        llvm::consumeError(formatted.takeError());
        return nullptr;
    }
    
    return CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)formatted->data(), (CFIndex)formatted->size(), kCFStringEncodingUTF8, false);
}
