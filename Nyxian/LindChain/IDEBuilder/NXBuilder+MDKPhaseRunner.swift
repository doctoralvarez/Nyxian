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
  - 1.0.0 (2026-11-15): threads from ForkBuildSpeed (every core with more
    memory); a finished Swift job is reported for the "nothing changed"
    skip, and in one pass the diagnostics left by single-file builds go.
*/

import MobileDevelopmentKit

extension NXBuilder: MDKPhaseRunnerDelegate {
    func runner(_ runner: MDKPhaseRunner,
                phase: MDKPhase, execute job: MDKJob,
                withOutDiagnostics diagnostics: AutoreleasingUnsafeMutablePointer<NSArray>?,
                withOutMainSource mainSource: AutoreleasingUnsafeMutablePointer<NSString>?) -> Bool {
        var localDiags: NSArray?
        var localSource: NSString?
        
        let ok: Bool
        if self.useRemoteServiceIfAvailable,
            let remoteCompiler = self.remoteCompiler {
            ok = remoteCompiler.execute(job, with: &localDiags, withMainSource: &localSource)
        } else {
            ok = job.execute(withOutDiagnostics: &localDiags, withOutMainSource: &localSource)
        }

        if let diags = localDiags {
            diagnostics?.pointee = diags
        }
        if let source = localSource {
            mainSource?.pointee = source
        }

        return ok
    }
    
    func runner(_ runner: MDKPhaseRunner,
                multithreadingThreadCountFor phase: MDKPhase) -> CFIndex {
        /* fork: every core when there is more memory */
        return CFIndex(ForkBuildSpeed.threads)
    }
    
    func runner(_ runner: MDKPhaseRunner,
                phase: MDKPhase,
                finishedRunning job: MDKJob,
                withResultingDiagnostics diagnostics: [MDKDiagnostic]?,
                withMainSource mainSource: String?,
                wasSuccessful success: Bool) {
        /* fork: the last good Swift job records the sources for the next skip */
        if job.type == .swiftCompiler {
            ForkBuildSpeed.finishedSwiftJob(success: success)
            /* one pass: diagnostics come as "wmo"; clear what single files left before */
            if let mainSource = mainSource, !mainSource.hasSuffix(".swift") {
                for source in ForkBuildSpeed.swiftJobFiles(job).sources {
                    self.database.removeFileDebug(ofPath: source)
                }
            }
        }
        if let diagnostics = diagnostics,
           let mainSource = mainSource {
            self.database.removeFileDebug(ofPath: mainSource)
            if job.type == .linker {
                self.database.addDiagnosticMessages(title: "Linker", items: diagnostics, clearPrevious: true)
            } else {
                self.database.appendDebug(originatorPath: mainSource, synItems: diagnostics)
            }
        }
    }
}

