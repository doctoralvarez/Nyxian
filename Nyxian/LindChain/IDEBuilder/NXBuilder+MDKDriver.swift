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
 Fork doctoralvarez/Nyxian — version 2.3.0
 Changelog:
  - 2.3.0 (2026-11-16): only the Swift files that changed are compiled again
    (ForkIncrementalSwift). A file whose change is only inside function,
    initializer or computed-property bodies (var body { ... } of a view, ...)
    is compiled alone; a change to anything other files can see (a type, a
    stored property, a signature, ...) or a file added or removed compiles
    every file, as before. If such a partial build fails without an error in
    the code (a link error, ...), the project is compiled whole at once.
    Swift in One Pass, Automatic: only with Incremental Build off (each build
    compiles everything then); with it on, compiling only what changed is
    faster for the edit-and-run loop.
  - 2.2.0 (2026-11-16): #Preview blocks no longer stop a build ("plugin for
    module 'PreviewsMacros' not found": that macro plugin only ships with
    Xcode). A Swift file with #Preview is compiled from a copy in the project
    cache where those blocks are blanked out (same lines and columns), and
    its errors are shown on the real file (ForkPreviewStripping).
  - 2.1.0 (2026-11-15): One Pass broke every project with two or more Swift
    files ("Failed to run project."): with -num-threads the compiler's extra
    object files did not end up where the link looked. One Pass is now a
    plain -wmo (one object file, the same path handling as file by file), and
    if a one-pass build still fails without any error in the code, the build
    is done again file by file at once and Automatic stops using One Pass on
    this device (choosing the option again tries it again).
  - 2.0.0 (2026-11-15): faster Swift builds, using the extra memory.
    * The "nothing changed" skip now really works for Swift: it looked for
      clang-type jobs, so Swift was always compiled again. It now reads the
      Swift jobs' own sources and object files (-o), and also checks that the
      set of Swift files is the one of the last good compile.
    * One pass (whole module, -wmo): all Swift files are compiled by a single
      compiler run, so SwiftUI and the other frameworks are loaded and every
      file is type-checked once instead of once per file; with -num-threads
      the machine code of each file is made in parallel. Automatic: on with
      two or more Swift files and Increased Memory Limit (or 4 GB or more).
    * Threads: with more memory every core is used (also the efficiency
      cores), for C / Objective-C files and the one-pass Swift code generation.
    (ForkBuildSpeed; Settings › Toolchain › Speed)
  - 1.0.0 (2026-11-07): Swift builds skip the compiler when no Swift file
    changed since the last build (every object file is newer than every Swift
    source and the build flags are the same); only the link runs. A change in
    any Swift file still recompiles all of them, because Swift files depend on
    each other (forkSkipSwiftCompileIfUnchanged).
*/

import Foundation
import MobileDevelopmentKit
import CryptoKit

extension NXBuilder: MDKDriverDelegate {
    func driver(_ driver: MDKDriver,
                outputPathForInputFile file: MDKFile) -> String? {
        return "\(self.project.cacheURL.path)/\(NXExpectedObjectFileURLForFileURL(NXRelativeURLFromBaseURLToFullURL(self.project.url, file.fileURL)).path)"
    }
    
    func driver(_ driver: MDKDriver, editJobListForJobList jobs: [MDKJob]) -> [MDKJob]? {
        if driver.type != .clang {
            /* fork: nothing to compile when no Swift file changed */
            /* fork: files with #Preview are compiled from a copy without those blocks */
            let withoutPreviews = ForkPreviewStripping.sanitize(jobs, cacheURL: self.project.cacheURL, sourceRoot: self.project.url.path)
            /* fork: one pass (-wmo -num-threads): its extra object files get fixed paths */
            let stable = ForkBuildSpeed.stableWholeModuleOutputs(withoutPreviews, cacheURL: self.project.cacheURL)
            let manifest = self.project.cacheURL.appendingPathComponent("fork-swift-sources.txt")
            let interfaces = self.project.cacheURL.appendingPathComponent("fork-swift-interfaces.json")
            if !(self.projectDirty || !self.incrementalBuild) {
                if let skipped = NXBuilder.forkSkipSwiftCompileIfUnchanged(stable, manifestURL: manifest) {
                    ForkBuildSpeed.beginSwiftCompile(jobs: [], allJobs: stable, manifestURL: manifest, interfacesURL: interfaces, partial: false)
                    return skipped
                }
                /* fork: only the files that changed, when only their bodies did */
                if let changedOnly = ForkIncrementalSwift.changedOnly(stable, manifestURL: manifest, interfacesURL: interfaces) {
                    ForkBuildSpeed.beginSwiftCompile(jobs: changedOnly, allJobs: stable, manifestURL: manifest, interfacesURL: interfaces, partial: true)
                    return changedOnly
                }
            }
            /* compiling everything: the lists are written again once every Swift job succeeded */
            try? FileManager.default.removeItem(at: manifest)
            try? FileManager.default.removeItem(at: interfaces)
            ForkBuildSpeed.beginSwiftCompile(jobs: stable, allJobs: stable, manifestURL: manifest, interfacesURL: interfaces, partial: false)
            return stable
        }
        
        // This can now in theory run in parallel ?:3
        // Lets make incremental build fast again >=3
        var newJobs: [MDKJob] = []
        var depsSet: Set<MDKDependency> = Set()
        
        /* fork: every core when there is more memory */
        let threads = CFIndex(ForkBuildSpeed.threads)
        
        let mdkThreadPoolGroup: MDKThreadPoolGroup = MDKThreadPoolGroup(threads: threads)
        for job in jobs {
            // Only need the compiler jobs lol
            if job.type == .compiler,
               let inputFileURLs = job.inputFileURLs,
               inputFileURLs.count == 1,    // If it is over 1, tf did it emit
               let _ = job.outputFileURL {
                mdkThreadPoolGroup.enter()
            }
        }
        
        // So we don't get a race condition, the thread safety expert Duy Tran would skip this step ^^
        //
        // Duy Tran quote: "MDKThreadPoolGroup only has 8 threads on a 8 core SoC."
        //
        var osUnfairLock: os_unfair_lock = .init()
        
        for job in jobs {
            // Only need the compiler jobs lol
            if job.type == .compiler,
               let inputFileURLs = job.inputFileURLs,
               inputFileURLs.count == 1,    // If it is over 1, tf did it emit
               let outputFileURL = job.outputFileURL {
                
                let inputFileURL = inputFileURLs[0]
                
                mdkThreadPoolGroup.dispatchExecution({
                    // Checking if the source file is newer than the compiled object file
                    guard let sourceDate = try? FileManager.default.attributesOfItem(atPath: inputFileURL.path)[.modificationDate] as? Date,
                          let objectDate = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.modificationDate] as? Date,
                          objectDate > sourceDate else {
                        self.database.removeFileDebug(ofPath: inputFileURL.path)
                        os_unfair_lock_lock(&osUnfairLock)
                        newJobs.append(job)
                        os_unfair_lock_unlock(&osUnfairLock)
                        return
                    }
                    
                    let inputFile: MDKFile = MDKFile(url: inputFileURL)
                    
                    // Checking if the header files included by the source code are newer than the object file
                    var outHeaders: NSArray? = nil
                    var outDependencies: NSArray? = nil
                    if !self.dependencyScanner.dependencies(for: inputFile, withHeaderFilePaths: &outHeaders, withDependencies: &outDependencies) {
                        self.database.removeFileDebug(ofPath: inputFile.fileURL.path)
                        os_unfair_lock_lock(&osUnfairLock)
                        newJobs.append(job)
                        os_unfair_lock_unlock(&osUnfairLock)
                        return
                    }
                    
                    guard let headers = outHeaders as? [MDKFile],
                          let dependencies = outDependencies as? [MDKDependency] else {
                        self.database.removeFileDebug(ofPath: inputFile.fileURL.path)
                        os_unfair_lock_lock(&osUnfairLock)
                        newJobs.append(job)
                        os_unfair_lock_unlock(&osUnfairLock)
                        return
                    }
                    
                    os_unfair_lock_lock(&osUnfairLock)
                    depsSet.formUnion(dependencies)
                    os_unfair_lock_unlock(&osUnfairLock)
                    
                    var needsRebuild = false
                    for header in headers {
                        guard let fileURL = header.fileURL,
                              let headerDate = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date,
                              objectDate > headerDate else {
                            self.database.removeFileDebug(ofPath: inputFileURL.path)
                            needsRebuild = true
                            break
                        }
                    }
                    
                    if needsRebuild {
                        self.database.removeFileDebug(ofPath: inputFileURL.path)
                        os_unfair_lock_lock(&osUnfairLock)
                        newJobs.append(job)
                        os_unfair_lock_unlock(&osUnfairLock)
                    }
                }, withCompletion: nil)
            }
        }
        
        mdkThreadPoolGroup.wait()
        
        for job in jobs {
            // Only need the compiler jobs lol
            if job.type == .compiler,
               let inputFileURLs = job.inputFileURLs,
               inputFileURLs.count == 1,    // If it is over 1, tf did it emit
               let _ = job.outputFileURL {
            } else {
                // Not a hack, usually this can only be a linker job
                newJobs.append(job)
            }
        }
        
        if self.projectDirty {
            newJobs = jobs
        }
        
        if self.project.projectConfig.linkFrameworksAutomatically {
            if var linkerJob: MDKJob = newJobs.last,
               linkerJob.type == .linker {
                var linkerFlgs: [String] = linkerJob.baseArguments
                
                for dependency in depsSet {
                    if dependency.name != "UIUtilities" {   // Call it the black sheep framework >:3
                        if dependency.isFramework {
                            linkerFlgs.append("-framework")
                            linkerFlgs.append(dependency.name)
                        } else if let libName = dependency.name {
                            linkerFlgs.append("-l\(libName)")
                        }
                    }
                }
                
                newJobs.removeLast()
                linkerJob = MDKJob(type: .linker, withArguments: linkerFlgs, withInputFileURLs: linkerJob.inputFileURLs, withOutputFileURL: linkerJob.outputFileURL)
                print("\(linkerJob.arguments ?? [])")
                newJobs.append(linkerJob)
            }
        }
        
        return newJobs
    }
}

extension NXBuilder {
    /// Drops the Swift compile jobs when every object file they write is newer
    /// than every Swift source, and the Swift files are the same set as in the
    /// last good compile. nil = compile.
    static func forkSkipSwiftCompileIfUnchanged(_ jobs: [MDKJob], manifestURL: URL) -> [MDKJob]? {
        let swiftJobs = jobs.filter { $0.type == .swiftCompiler }
        guard !swiftJobs.isEmpty else { return nil }
        let fm = FileManager.default
        func modified(_ path: String) -> Date? {
            (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        }
        
        var oldestObject: Date?
        var sources: Set<String> = []
        for job in swiftJobs {
            let parts = ForkBuildSpeed.swiftJobFiles(job)
            /* a job without its own object file (module merging, ...): do not guess */
            guard !parts.outputs.isEmpty else { return nil }
            for output in parts.outputs {
                guard let date = modified(output) else { return nil }
                oldestObject = min(oldestObject ?? date, date)
            }
            sources.formUnion(parts.sources)
        }
        guard let oldestObject, !sources.isEmpty else { return nil }
        
        /* a Swift file added or removed since the last good compile */
        guard let saved = try? String(contentsOf: manifestURL, encoding: .utf8),
              saved == ForkBuildSpeed.manifestText(sources) else { return nil }
        
        for path in sources {
            guard let date = modified(path), date < oldestObject else { return nil }
        }
        return jobs.filter { $0.type != .swiftCompiler }
    }
}

// MARK: - fork: build speed (uses the extra memory)

/// Settings › Toolchain › Speed. With Increased Memory Limit the compiler has
/// room for more at once: all Swift files in one pass, and every core.
@objc final class ForkBuildSpeed: NSObject {
    /// 0 = Automatic, 1 = On, 2 = Off
    static let onePassKey = "fork.build.swiftOnePass"
    static let onePassOptions: [String] = ["Automatic", "On", "Off"]
    /// more memory: use every core (default on)
    static let allCoresKey = "fork.build.allCores"
    /// a limit at least this big counts as "more memory"
    static let moreMemoryBytes: UInt64 = 4 * 1024 * 1024 * 1024

    /// About how much memory iOS lets Nyxian use (what is left + what it uses)
    static var memoryLimit: UInt64 { ForkMemoryInfo.available + ForkMemoryInfo.footprint }

    private static let increasedLimitEntitlement: Bool = ForkMemoryInfo.entitlement(ForkMemoryInfo.increasedLimit) == true

    /// Increased Memory Limit is in the signature, or the limit is big anyway
    @objc static var hasMoreMemory: Bool {
        increasedLimitEntitlement || memoryLimit >= moreMemoryBytes
    }

    static var performanceCores: Int { max(Int(CCGetMaximumPerformanceCores()), 1) }
    static var allCores: Int { max(ProcessInfo.processInfo.activeProcessorCount, 1) }

    /// The Threads setting, or every core when there is more memory
    @objc static var threads: Int {
        let chosen = (UserDefaults.standard.object(forKey: "cputhreads") as? NSNumber)?.intValue ?? performanceCores
        let user = max(chosen, 1)
        let useAll = UserDefaults.standard.object(forKey: allCoresKey) as? Bool ?? true
        if useAll && hasMoreMemory { return max(user, allCores) }
        return user
    }

    static var onePassMode: Int { UserDefaults.standard.integer(forKey: onePassKey) }

    /// Settings › Toolchain › Incremental Build (on by default)
    static var incrementalBuildOn: Bool { UserDefaults.standard.object(forKey: "LDEIncrementalBuild") as? Bool ?? true }

    /// Whether this build compiles all Swift files in one run
    /// set while a failed one-pass build is done again file by file
    static var forcePerFile = false
    /// One Pass failed here without an error in the code: Automatic leaves it off
    static let onePassFailedKey = "fork.build.swiftOnePassFailed"

    @objc static func usesOnePass(swiftFileCount: Int) -> Bool {
        if forcePerFile { return false }
        if onePassMode == 0 && UserDefaults.standard.bool(forKey: onePassFailedKey) { return false }
        switch onePassMode {
        case 1: return swiftFileCount >= 1
        case 2: return false
        /* with Incremental Build on, compiling only what changed is faster */
        default: return swiftFileCount >= 2 && hasMoreMemory && !incrementalBuildOn
        }
    }

    /// The flags NXPhaseEngine adds to the Swift driver
    @objc static func extraSwiftFlags(swiftFileCount: Int) -> [String] {
        guard usesOnePass(swiftFileCount: swiftFileCount) else { return [] }
        /* plain whole module: one object file (-num-threads broke the link) */
        return ["-wmo"]
    }

    /// Part of the build's flag signature: a change rebuilds everything
    static func signature(projectURL: URL) -> String {
        let flags = extraSwiftFlags(swiftFileCount: swiftFileCount(in: projectURL))
        return flags.isEmpty ? "" : " fork-speed:" + flags.joined(separator: " ")
    }

    /// Swift files of a project, as NXPhaseEngine finds them
    static func swiftFileCount(in projectURL: URL) -> Int {
        let files = LDEFilesFinder(projectURL.path, Set(["swift"]), Set(["Resources", "Config"]))
        return files?.count ?? 0
    }

    // MARK: Swift jobs

    /// Sources (.swift arguments) and object files (-o) of a Swift job
    static func swiftJobFiles(_ job: MDKJob) -> (sources: [String], outputs: [String]) {
        let args = job.baseArguments ?? []
        var sources: [String] = []
        var outputs: [String] = []
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "-o", index + 1 < args.count {
                outputs.append(args[index + 1])
                index += 2
                continue
            }
            if arg.hasSuffix(".swift") && arg.hasPrefix("/") {
                sources.append(arg)
            }
            index += 1
        }
        return (sources, outputs)
    }

    /// In one pass with -num-threads the compiler writes one object file per
    /// Swift file, all but the first to temporary names that change on every
    /// build. They get fixed paths in the project's cache (also in the link).
    static func stableWholeModuleOutputs(_ jobs: [MDKJob], cacheURL: URL) -> [MDKJob] {
        var remap: [(String, String)] = []
        let folder = cacheURL.appendingPathComponent("WholeModule")
        for job in jobs where job.type == .swiftCompiler {
            let args = job.baseArguments ?? []
            guard args.contains("-num-threads") else { continue }
            let parts = swiftJobFiles(job)
            guard parts.outputs.count > 1 else { continue }
            /* outputs follow the order of the sources (the module's files) */
            let sourceFiles = parts.sources
            for (index, output) in parts.outputs.enumerated() where index > 0 && !output.hasPrefix(cacheURL.path) {
                let base: String
                if index < sourceFiles.count {
                    base = (sourceFiles[index] as NSString).lastPathComponent
                } else {
                    base = "part\(index)"
                }
                let stable = folder.appendingPathComponent("\(index)-\(base).o").path
                remap.append((output, stable))
            }
        }
        guard !remap.isEmpty else { return jobs }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return jobs.map { job in
            let args = job.baseArguments ?? []
            var changed = false
            let newArgs: [String] = args.map { arg in
                var value = arg
                for (old, new) in remap where value.contains(old) {
                    value = value.replacingOccurrences(of: old, with: new)
                    changed = true
                }
                return value
            }
            guard changed else { return job }
            return MDKJob(type: job.type, withArguments: newArgs, withInputFileURLs: job.inputFileURLs, withOutputFileURL: job.outputFileURL)
        }
    }

    static func manifestText(_ sources: Set<String>) -> String {
        sources.sorted().joined(separator: "\n")
    }

    // MARK: the sources (and interfaces) of the last good compile

    private static var lock = os_unfair_lock()
    private static var pendingJobs = 0
    private static var pendingFailed = false
    private static var pendingSources: Set<String> = []
    private static var pendingInterfaces: [String: String] = [:]
    private static var pendingManifest: URL?
    private static var pendingInterfacesURL: URL?
    /// the last plan compiled only the files that changed
    private(set) static var lastPlanPartial = false

    static func beginSwiftCompile(jobs: [MDKJob], allJobs: [MDKJob], manifestURL: URL, interfacesURL: URL, partial: Bool) {
        let swiftJobs = jobs.filter { $0.type == .swiftCompiler }
        var sources: Set<String> = []
        for job in allJobs where job.type == .swiftCompiler { sources.formUnion(swiftJobFiles(job).sources) }
        /* the interfaces as they are now: what the next build compares with */
        let interfaces = swiftJobs.isEmpty ? [:] : ForkIncrementalSwift.interfaceHashes(of: sources)
        os_unfair_lock_lock(&lock)
        lastPlanPartial = partial
        pendingJobs = swiftJobs.count
        pendingFailed = false
        pendingSources = sources
        pendingInterfaces = interfaces
        pendingManifest = swiftJobs.isEmpty ? nil : manifestURL
        pendingInterfacesURL = swiftJobs.isEmpty ? nil : interfacesURL
        os_unfair_lock_unlock(&lock)
    }

    /// Called for every finished Swift job; the last good one writes the lists
    static func finishedSwiftJob(success: Bool) {
        os_unfair_lock_lock(&lock)
        guard let manifest = pendingManifest else {
            os_unfair_lock_unlock(&lock)
            return
        }
        if !success { pendingFailed = true }
        pendingJobs -= 1
        let done = pendingJobs <= 0
        let write = done && !pendingFailed
        let text = manifestText(pendingSources)
        let interfaces = pendingInterfaces
        let interfacesURL = pendingInterfacesURL
        if done {
            pendingManifest = nil
            pendingInterfacesURL = nil
        }
        os_unfair_lock_unlock(&lock)
        if write {
            try? text.write(to: manifest, atomically: true, encoding: .utf8)
            if let interfacesURL, !interfaces.isEmpty,
               let data = try? JSONSerialization.data(withJSONObject: interfaces, options: [.sortedKeys]) {
                try? data.write(to: interfacesURL, options: .atomic)
            }
        }
    }
}

// MARK: - fork: compile only the Swift files that changed

/// Which file-by-file Swift jobs must run. A Swift file is "changed" when it is
/// newer than its object file. If every changed file changed only inside bodies
/// (functions, initializers, computed properties and subscripts), the other
/// files cannot see the change and only the changed ones are compiled. Anything
/// else (types, stored properties, signatures, a file added or removed, a file
/// that could not be read) means everything, as before.
enum ForkIncrementalSwift {
    /// The jobs to run when only some files need compiling; nil = compile all
    static func changedOnly(_ jobs: [MDKJob], manifestURL: URL, interfacesURL: URL) -> [MDKJob]? {
        let swiftJobs = jobs.filter { $0.type == .swiftCompiler }
        guard !swiftJobs.isEmpty else { return nil }

        var sources: Set<String> = []
        for job in swiftJobs { sources.formUnion(ForkBuildSpeed.swiftJobFiles(job).sources) }
        /* the same Swift files as in the last good compile */
        guard let saved = try? String(contentsOf: manifestURL, encoding: .utf8),
              saved == ForkBuildSpeed.manifestText(sources) else { return nil }
        guard let data = try? Data(contentsOf: interfacesURL),
              let stored = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] else { return nil }

        let fm = FileManager.default
        func modified(_ path: String) -> Date? {
            (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        }

        var selected: Set<Int> = []
        for (index, job) in jobs.enumerated() where job.type == .swiftCompiler {
            /* only file-by-file jobs (one primary file, one object file) */
            guard let primary = primaryFile(of: job) else { return nil }
            let outputs = ForkBuildSpeed.swiftJobFiles(job).outputs
            guard outputs.count == 1 else { return nil }
            var changed = true
            if let objectDate = modified(outputs[0]), let sourceDate = modified(primary) {
                changed = sourceDate >= objectDate
            }
            guard changed else { continue }
            /* changed: only bodies may differ */
            guard let text = try? String(contentsOfFile: primary, encoding: .utf8),
                  let hash = interfaceHash(text),
                  let before = stored[primary], before == hash else { return nil }
            selected.insert(index)
        }
        guard !selected.isEmpty else { return nil }
        return jobs.enumerated().compactMap { index, job in
            (job.type != .swiftCompiler || selected.contains(index)) ? job : nil
        }
    }

    static func primaryFile(of job: MDKJob) -> String? {
        let args = job.baseArguments ?? []
        guard let at = args.firstIndex(of: "-primary-file"), at + 1 < args.count else { return nil }
        return args[at + 1]
    }

    static func interfaceHashes(of sources: Set<String>) -> [String: String] {
        var hashes: [String: String] = [:]
        for path in sources {
            if let text = try? String(contentsOfFile: path, encoding: .utf8), let hash = interfaceHash(text) {
                hashes[path] = hash
            }
        }
        return hashes
    }

    // MARK: the part of a file other files can see

    private static let bodyKeywords: Set<String> = ["func", "init", "deinit"]
    private static let accessorKeywords: Set<String> = ["var", "subscript"]
    private static let declarationKeywords: Set<String> = [
        "let", "case", "struct", "class", "enum", "protocol", "extension", "typealias",
        "import", "actor", "associatedtype", "operator", "precedencegroup", "macro"
    ]
    private static let accessorWords: Set<String> = [
        "get", "set", "async", "throws", "mutating", "nonmutating", "_read", "_modify", "rethrows"
    ]

    /// A hash of the file without comments, spacing and the contents of
    /// function / initializer / computed-property bodies; nil if it cannot be read
    static func interfaceHash(_ text: String) -> String? {
        let s = Array(text.utf16)
        var out: [UInt16] = []
        out.reserveCapacity(s.count / 2)
        var i = 0
        var parenDepth = 0
        var pending = 0          /* 0 none, 1 body follows (func/init), 2 accessor block may follow (var/subscript) */
        var pendingBase = 0
        var last: UInt16 = 0     /* last character written that is not a space */

        func emit(_ c: UInt16) {
            if c == 32 {
                if out.last != 32 { out.append(32) }
            } else {
                out.append(c)
                last = c
            }
        }
        func emit(_ string: String) { for c in string.utf16 { emit(c) } }

        while i < s.count {
            let c = s[i]
            let next: UInt16 = i + 1 < s.count ? s[i + 1] : 0
            /* comments */
            if c == 47 && next == 47 {
                while i < s.count && s[i] != 10 { i += 1 }
                emit(32)
                continue
            }
            if c == 47 && next == 42 {
                guard let end = skipBlockComment(s, i) else { return nil }
                i = end
                emit(32)
                continue
            }
            /* spacing */
            if c == 32 || c == 9 || c == 10 || c == 13 {
                emit(32)
                i += 1
                continue
            }
            /* string literals, kept as they are */
            if c == 34 || (c == 35 && startsRawString(s, i)) {
                guard let end = skipString(s, i) else { return nil }
                for k in i..<end { out.append(s[k]) }
                last = 34
                i = end
                continue
            }
            /* words */
            if isIdentifierStart(c) {
                var end = i
                while end < s.count && isIdentifierPart(s[end]) { end += 1 }
                let word = String(utf16CodeUnits: Array(s[i..<end]), count: end - i)
                let afterDot = last == 46
                emit(word)
                if !afterDot {
                    if bodyKeywords.contains(word) {
                        pending = 1
                        pendingBase = parenDepth
                    } else if accessorKeywords.contains(word) {
                        pending = 2
                        pendingBase = parenDepth
                    } else if declarationKeywords.contains(word) {
                        pending = 0
                    }
                }
                i = end
                continue
            }
            if c == 40 || c == 91 { parenDepth += 1 }
            if c == 41 || c == 93 { parenDepth -= 1 }
            if pending == 2 && c == 61 && parenDepth == pendingBase {
                /* var x = value: a stored property (its { didSet } stays as it is) */
                pending = 0
            }
            if c == 64 && parenDepth == pendingBase {
                /* an attribute: the next declaration starts */
                pending = 0
            }
            if c == 123 && pending != 0 && parenDepth == pendingBase {
                guard let close = matchingBrace(s, i) else { return nil }
                if pending == 1 {
                    emit("{}")
                } else {
                    emit(accessorSummary(s, from: i + 1, to: close))
                }
                pending = 0
                i = close + 1
                continue
            }
            if c == 125 && parenDepth == pendingBase {
                pending = 0
            }
            emit(c)
            i += 1
        }
        let digest = SHA256.hash(data: Data(String(utf16CodeUnits: out, count: out.count).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// What callers can see of a var / subscript block: a protocol requirement
    /// ({ get set }) as it is; a computed body only as "get" or "get set"
    private static func accessorSummary(_ s: [UInt16], from start: Int, to end: Int) -> String {
        var words: [String] = []
        var hasBraces = false
        var depth = 0
        var i = start
        while i < end {
            let c = s[i]
            if c == 123 { depth += 1; hasBraces = true; i += 1; continue }
            if c == 125 { depth -= 1; i += 1; continue }
            if c == 34 || (c == 35 && startsRawString(s, i)) {
                i = skipString(s, i) ?? end
                continue
            }
            if isIdentifierStart(c) {
                var e = i
                while e < end && isIdentifierPart(s[e]) { e += 1 }
                if depth == 0 { words.append(String(utf16CodeUnits: Array(s[i..<e]), count: e - i)) }
                i = e
                continue
            }
            i += 1
        }
        if !hasBraces && !words.isEmpty && words.allSatisfy({ accessorWords.contains($0) }) {
            return "{" + words.joined(separator: " ") + "}"
        }
        let settable = words.contains("set") || words.contains("_modify")
        return settable ? "{get set}" : "{get}"
    }

    private static func isIdentifierStart(_ c: UInt16) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c >= 128
    }
    private static func isIdentifierPart(_ c: UInt16) -> Bool {
        isIdentifierStart(c) || (c >= 48 && c <= 57)
    }

    /// #"..."# or ##"..."## starts here
    private static func startsRawString(_ s: [UInt16], _ at: Int) -> Bool {
        var i = at
        while i < s.count && s[i] == 35 { i += 1 }
        return i < s.count && s[i] == 34 && i > at
    }

    /// Index after the block comment starting at `at` (comments may nest)
    private static func skipBlockComment(_ s: [UInt16], _ at: Int) -> Int? {
        var depth = 0
        var i = at
        while i < s.count {
            let next: UInt16 = i + 1 < s.count ? s[i + 1] : 0
            if s[i] == 47 && next == 42 { depth += 1; i += 2; continue }
            if s[i] == 42 && next == 47 {
                depth -= 1
                i += 2
                if depth == 0 { return i }
                continue
            }
            i += 1
        }
        return nil
    }

    /// Index after the string literal starting at `at` ("...", """...""", #"..."#, with \( ) inside)
    private static func skipString(_ s: [UInt16], _ at: Int) -> Int? {
        var i = at
        var hashes = 0
        while i < s.count && s[i] == 35 { hashes += 1; i += 1 }
        guard i < s.count && s[i] == 34 else { return nil }
        let multiline = i + 2 < s.count && s[i + 1] == 34 && s[i + 2] == 34
        i += multiline ? 3 : 1
        while i < s.count {
            let c = s[i]
            if c == 92 {
                /* an escape needs as many # as the literal has */
                var k = i + 1
                var count = 0
                while count < hashes && k < s.count && s[k] == 35 { count += 1; k += 1 }
                if count == hashes {
                    if k < s.count && s[k] == 40 {
                        /* interpolation: up to the matching ) */
                        guard let close = matchingParen(s, k) else { return nil }
                        i = close + 1
                    } else {
                        i = k + 1
                    }
                    continue
                }
            }
            if !multiline && c == 10 && hashes == 0 { return nil }
            if c == 34 {
                let quoteEnd = multiline ? i + 3 : i + 1
                if multiline && !(i + 2 < s.count && s[i + 1] == 34 && s[i + 2] == 34) {
                    i += 1
                    continue
                }
                var k = quoteEnd
                var count = 0
                while count < hashes && k < s.count && s[k] == 35 { count += 1; k += 1 }
                if count == hashes { return k }
                i += 1
                continue
            }
            i += 1
        }
        return nil
    }

    /// The ) matching the ( at `open`, with strings and comments skipped
    private static func matchingParen(_ s: [UInt16], _ open: Int) -> Int? {
        matching(s, open, opening: 40, closing: 41)
    }

    /// The } matching the { at `open`, with strings and comments skipped
    private static func matchingBrace(_ s: [UInt16], _ open: Int) -> Int? {
        matching(s, open, opening: 123, closing: 125)
    }

    private static func matching(_ s: [UInt16], _ open: Int, opening: UInt16, closing: UInt16) -> Int? {
        var depth = 0
        var i = open
        while i < s.count {
            let c = s[i]
            let next: UInt16 = i + 1 < s.count ? s[i + 1] : 0
            if c == 47 && next == 47 {
                while i < s.count && s[i] != 10 { i += 1 }
                continue
            }
            if c == 47 && next == 42 {
                guard let end = skipBlockComment(s, i) else { return nil }
                i = end
                continue
            }
            if c == 34 || (c == 35 && startsRawString(s, i)) {
                guard let end = skipString(s, i) else { return nil }
                i = end
                continue
            }
            if c == opening { depth += 1 }
            if c == closing {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }
}

// MARK: - fork: #Preview without Xcode's macro plugin

/// The previews macro (#Preview) needs PreviewsMacros, a plugin that only
/// ships with Xcode. Building does not need previews, so a Swift file that has
/// #Preview is compiled from a copy in the project cache where those blocks are
/// blanked out with spaces (lines and columns stay the same), and diagnostics
/// on the copy are put back on the real file.
enum ForkPreviewStripping {
    private static var lock = os_unfair_lock()
    private static var originals: [String: String] = [:]

    /// The real file for a path of a copy (any other path unchanged)
    static func originalPath(_ path: String) -> String {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return originals[path] ?? path
    }

    private static let previewRegex = try? NSRegularExpression(pattern: #"#Preview\s*(\([^)]*\))?\s*\{"#)

    /// The text with every #Preview block turned into spaces (newlines kept); nil if it has none
    static func blankingPreviews(_ text: String) -> String? {
        guard text.contains("#Preview"), let regex = previewRegex else { return nil }
        let ns = NSMutableString(string: text)
        var searchFrom = 0
        var changed = false
        while searchFrom < ns.length,
              let match = regex.firstMatch(in: ns as String, range: NSRange(location: searchFrom, length: ns.length - searchFrom)) {
            let open = NSMaxRange(match.range) - 1
            guard let close = ForkSwiftUIPreview.matchingBrace(in: ns, open: open) else { break }
            for index in match.range.location...close {
                let c = ns.character(at: index)
                if c != 10 && c != 13 {
                    ns.replaceCharacters(in: NSRange(location: index, length: 1), with: " ")
                }
            }
            changed = true
            searchFrom = close + 1
        }
        return changed ? (ns as String) : nil
    }

    /// Swift jobs with each file that has #Preview replaced by its blanked copy
    static func sanitize(_ jobs: [MDKJob], cacheURL: URL, sourceRoot: String) -> [MDKJob] {
        var sources: Set<String> = []
        for job in jobs where job.type == .swiftCompiler {
            sources.formUnion(ForkBuildSpeed.swiftJobFiles(job).sources)
        }
        let folder = cacheURL.appendingPathComponent("NoPreviews")
        var remap: [String: String] = [:]
        for source in sources {
            guard let text = try? String(contentsOfFile: source, encoding: .utf8),
                  let blanked = blankingPreviews(text) else { continue }
            var relative = source
            if relative.hasPrefix(sourceRoot) { relative = String(relative.dropFirst(sourceRoot.count)) }
            let copy = folder.appendingPathComponent(relative).path
            let data = Data(blanked.utf8)
            /* written only when it changed, so its date tells the incremental build */
            if (try? Data(contentsOf: URL(fileURLWithPath: copy))) != data {
                try? FileManager.default.createDirectory(atPath: (copy as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                guard (try? data.write(to: URL(fileURLWithPath: copy), options: .atomic)) != nil else { continue }
            }
            remap[source] = copy
        }
        guard !remap.isEmpty else { return jobs }
        os_unfair_lock_lock(&lock)
        for (source, copy) in remap {
            originals[copy] = source
            originals[(copy as NSString).standardizingPath] = source
        }
        os_unfair_lock_unlock(&lock)
        return jobs.map { job in
            guard job.type == .swiftCompiler else { return job }
            let args = job.baseArguments ?? []
            let newArgs = args.map { remap[$0] ?? $0 }
            guard newArgs != args else { return job }
            return MDKJob(type: job.type, withArguments: newArgs, withInputFileURLs: job.inputFileURLs, withOutputFileURL: job.outputFileURL)
        }
    }
}
