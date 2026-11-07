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
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-07): Swift builds skip the compiler when no Swift file
    changed since the last build (every object file is newer than every Swift
    source and the build flags are the same); only the link runs. A change in
    any Swift file still recompiles all of them, because Swift files depend on
    each other (forkSkipSwiftCompileIfUnchanged).
*/

import MobileDevelopmentKit

extension NXBuilder: MDKDriverDelegate {
    func driver(_ driver: MDKDriver,
                outputPathForInputFile file: MDKFile) -> String? {
        return "\(self.project.cacheURL.path)/\(NXExpectedObjectFileURLForFileURL(NXRelativeURLFromBaseURLToFullURL(self.project.url, file.fileURL)).path)"
    }
    
    func driver(_ driver: MDKDriver, editJobListForJobList jobs: [MDKJob]) -> [MDKJob]? {
        if driver.type != .clang {
            /* fork: nothing to compile when no Swift file changed */
            return (self.projectDirty || !self.incrementalBuild) ? jobs : NXBuilder.forkSkipSwiftCompileIfUnchanged(jobs)
        }
        
        // This can now in theory run in parallel ?:3
        // Lets make incremental build fast again >=3
        var newJobs: [MDKJob] = []
        var depsSet: Set<MDKDependency> = Set()
        
        let userSelectedValue: NSNumber? = UserDefaults.standard.object(forKey: "cputhreads") as? NSNumber
        let userSelected = userSelectedValue?.intValue ?? CCGetMaximumPerformanceCores()
        let threads = CFIndex(userSelected == 0 ? 1 : userSelected)
        
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
    /// Drops the Swift compile jobs when all their objects are newer than all their sources.
    static func forkSkipSwiftCompileIfUnchanged(_ jobs: [MDKJob]) -> [MDKJob] {
        let fm = FileManager.default
        func modified(_ path: String) -> Date? {
            (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        }
        
        let compileJobs = jobs.filter { $0.type == .compiler }
        guard !compileJobs.isEmpty else { return jobs }
        
        var oldestObject: Date?
        var sources: Set<String> = []
        for job in compileJobs {
            /* a job without its own object file (module merging, …): do not guess */
            guard let output = job.outputFileURL, let date = modified(output.path) else { return jobs }
            oldestObject = min(oldestObject ?? date, date)
            for url in job.inputFileURLs ?? [] { sources.insert(url.path) }
        }
        guard let oldestObject, !sources.isEmpty else { return jobs }
        
        for path in sources {
            guard let date = modified(path), date < oldestObject else { return jobs }
        }
        return jobs.filter { $0.type != .compiler }
    }
}
