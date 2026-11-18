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
 Fork doctoralvarez/Nyxian — version 1.11.0
 Changelog:
  - 1.11.0 (2026-11-17): a build started in Low Power Mode, or while iOS is
    slowing the device down because it is hot, leaves a warning under
    "Device" in the Issue Navigator saying why it may be slower (replaced
    on every build; nothing when all is normal).
  - 1.10.0 (2026-11-16): a build that fails without any error is done once
    more from a clean state (the project's compiled files and Nyxian's build
    notes removed, file by file); if it still fails, what the compiler
    printed (driver errors went only to the system log) is shown under
    Internal. Fixes projects that built on one device and not on another
    because of files left by an earlier build.
  - 1.9.0 (2026-11-16): Run with nothing changed opens the installed app at
    once: no compiling, linking, signing or installing again (ForkRunStamp:
    every file of the project, the build flags, the bundle id and this
    Nyxian; the app must still be installed). A build that compiled only
    the Swift files that changed and then fails without an error in the code
    is done again whole.
  - 1.8.0 (2026-11-15): a one-pass Swift build that fails with no error in
    the code is done again file by file at once (and Automatic stops using
    One Pass here), so the project still builds and runs.
  - 1.7.0 (2026-11-15): the build's flag signature includes the speed
    options (one pass), so changing them compiles everything again.
  - 1.6.0 (2026-11-12): Export .ipa signs Config/AppEntitlements.plist into
    the app (ad-hoc, ZSigner), so a signer (SideStore, …) sees the app's own
    entitlements (iCloud, memory) and asks for them.
  - 1.5.0 (2026-11-12): Export .ipa leaves out Nyxian's entitlements
    (org.emexlabs.nyxian.*, appended to the app only for running inside
    Nyxian) and removes one left from an earlier run; with
    Config/AppEntitlements.plist the share also carries <app>.entitlements
    for the signer.
  - 1.4.1 (2026-11-12): every build first makes sure the SDK's @State fix is
    in place (ForkSDKPatches.ensure).
  - 1.4.0 (2026-11-11): Library projects build (headsup lets them through);
    Run signs the .dylib and says it was built (a library is not run).
  - 1.3.0 (2026-11-09): forkQuietFailure: a failed build that will be tried
    again another way (the preview's quick build) shows no issue list.
  - 1.2.0 (2026-11-08): Cancel button (top left) while a project builds: the
    screen is usable at once, the build stops before its next stage, nothing
    is installed or run, and what was compiled is kept.
  - 1.1.0 (2026-11-07): Metal shaders — every .metal file of the project is
    copied into the app, and all of them together as NyxianShaders.metal, so
    the app can compile them on the device with makeLibrary(source:)
    (there is no Metal compiler on iOS). See "Add Metal Helper" in ⋯.
  - 1.0.0 (2026-11-06): New BuildType.build (compile and link only, no
    signing/install) used by the ⌘B "Build" shortcut.
*/

import Foundation
import Combine
import MobileDevelopmentKit
import CryptoKit

final class NXBuilder: NSObject {
    private(set) var project: NXProject
    private(set) var projectDirty: Bool
    private(set) var database: DebugDatabase
    
    private(set) var dependencyScanner: MDKDependencyScanner
    private(set) var phaseRunner: NXPhaseRunner
    private(set) var remoteCompiler: NXRemoteCompiler? = nil
    
    private(set) var incrementalBuild: Bool = UserDefaults.standard.object(forKey: "LDEIncrementalBuild") as? Bool ?? true
    private(set) var useRemoteServiceIfAvailable: Bool = UserDefaults.standard.object(forKey: "LDERemoteCompileService") as? Bool ?? true
    private let argsString: String
    
    static var builds: Bool = false
    /* fork: Cancel during a build — the build stops before its next stage and nothing is installed or run */
    static var forkCancelRequested: Bool = false
    /* fork: the next failed build shows no issue list (it is retried at once) */
    static var forkQuietFailure: Bool = false
    /* fork: whether the last build ended by Cancel */
    static var forkLastBuildCancelled: Bool = false
    
    init?(project: NXProject) {
        self.project = project
        self.project.reload()
        
        if !self.project.syncFolderStructureToCache() {
            return nil
        }
        
        self.database = DebugDatabase.getDatabase(ofPath: "\(self.project.cacheURL.path)/debug.json")
        self.database.reuseDatabase()
        
        if useRemoteServiceIfAvailable {
            remoteCompiler = NXRemoteCompiler.new()
        }
        
        if remoteCompiler?.setupDependencyScanner(withArguments: self.project.projectConfig.compilerFlags) ?? false,
           let remoteDependencyScanner = remoteCompiler?.dependencyScanner() {
            self.dependencyScanner = remoteDependencyScanner
        } else {
            self.dependencyScanner = MDKDependencyScanner(arguments: self.project.projectConfig.compilerFlags)
        }
        
        let phaseEngine: NXPhaseEngine
        do {
            phaseEngine = try NXPhaseEngine(project: self.project)
        } catch {
            self.database.addMessage(message: error.localizedDescription, severity: .error)
            self.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
            return nil
        }
        
        self.argsString = self.project.projectConfig.swiftFlags.joined(separator: " ") + self.project.projectConfig.compilerFlags.joined(separator: " ") + " \(self.project.projectConfig.linkFrameworksAutomatically)" + ForkBuildSpeed.signature(projectURL: self.project.url)
        
        // Check if the args string matches up
        if self.incrementalBuild,
           let args: String = (try? String(contentsOf: self.project.cacheURL.appendingPathComponent("args.txt"), encoding: .utf8)) {
            self.projectDirty = args != self.argsString
        } else {
            self.projectDirty = true
            self.database.clearDatabase() /* nothing valid anymore */
        }
        
        guard let phaseRunner = NXPhaseRunner(engine: phaseEngine) else {
            return nil
        }
        self.phaseRunner = phaseRunner
        
        super.init()
        
        phaseEngine.delegate = self
        self.phaseRunner.delegate = self
    }
    
    func headsup(buildType: NXBuilder.BuildType) throws {
        let type = project.projectConfig.schemeKind
        /* fork: libraries build too */
        if(type != .app && type != .utility && type != .kSurfaceKext && type != .library) {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Project type \(type) is unknown."])
        }
        
        guard let osVersionNeeded: MDKOSVersion = MDKOSVersion(versionString: project.projectConfig.deploymentTarget) else {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Target \"\(self.project.projectConfig.displayName ?? "Unknown") (\(self.project.projectConfig.bundleid ?? "Unknown"))\" cannot be build, host version cannot be compared. Version \(project.projectConfig.deploymentTarget!) is not valid."])
        }
        
        // Nyxian requirement check
        let minimumOSVersion: MDKOSVersion = MDKOSVersion(versionString: NXOSVersion.NXOSVersionSupportedBuildVersions.first)!
        let maximumOSVersion: MDKOSVersion = MDKOSVersion(versionString: NXOSVersion.NXOSVersionSupportedBuildVersions.last)!
        if osVersionNeeded < minimumOSVersion || osVersionNeeded > maximumOSVersion {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Target \"\(self.project.projectConfig.displayName ?? "Unknown") (\(self.project.projectConfig.bundleid ?? "Unknown"))\" declares deployment target \(osVersionNeeded) which is not supported by this version of Nyxian. This version of Nyxian supports \(minimumOSVersion) up to \(maximumOSVersion)."])
        }
        
        // Project requirement check
        if osVersionNeeded > MDKOSVersion.host,
           buildType == .run {
            throw NSError(domain: "com.cr4zy.nyxian.builder.headsup", code: 1, userInfo: [NSLocalizedDescriptionKey:"Target \"\(self.project.projectConfig.displayName ?? "Unknown") (\(self.project.projectConfig.bundleid ?? "Unknown"))\" declares deployment target \(osVersionNeeded) which doesn't support the host version \(MDKOSVersion.host). Please update your idevice."])
        }
    }
    
    /// fork: any error at all in the Issue Navigator
    private func forkHasAnyError() -> Bool {
        for (key, object) in self.database.debugObjects where key != "Internal" {
            if object.debugItems.contains(where: { $0.severity == .error || $0.severity == .fatal }) { return true }
        }
        return false
    }
    
    /// fork: object files and Nyxian's build notes of this project, for a clean build
    private func forkRemoveBuildProducts() {
        let fm = FileManager.default
        guard let cache: URL = self.project.cacheURL else { return }
        for name in ["NoPreviews", "WholeModule", "fork-swift-sources.txt", "fork-swift-interfaces.json", "fork-run-stamp.txt", "args.txt"] {
            try? fm.removeItem(at: cache.appendingPathComponent(name))
        }
        if let walker = fm.enumerator(at: cache, includingPropertiesForKeys: nil) {
            for case let file as URL in walker where file.pathExtension == "o" {
                try? fm.removeItem(at: file)
            }
        }
    }
    
    /// fork: an error in one of the project's Swift files
    private func forkHasSwiftErrors() -> Bool {
        for (key, object) in self.database.debugObjects where key.hasSuffix(".swift") {
            if object.debugItems.contains(where: { $0.severity == .error || $0.severity == .fatal }) { return true }
        }
        return false
    }
    
    func clean() throws {
        // now remove what was find
        for file in LDEFilesFinder(
            self.project.url.path,
            ["o","tmp"],
            ["Resources","Config"]
        ) {
            try? FileManager.default.removeItem(atPath: file)
        }
        
        // if payload exists remove it
        if self.project.projectConfig.schemeKind == .app {
            try? FileManager.default.removeItem(atPath: self.project.payloadURL.path)
            try? FileManager.default.removeItem(atPath: self.project.packageURL.path)
        }
    }
    
    func prepare() throws {
        if project.projectConfig.schemeKind == .app {
            try FileManager.default.createDirectory(at: self.project.payloadURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: self.project.resourcesURL, to: self.project.bundleURL)
            /* fork: Metal shader sources travel inside the app, to be compiled at run time */
            NXBuilder.forkBundleMetalSources(projectURL: self.project.url, bundleURL: self.project.bundleURL)
            
            let infoPlistDataSerialized = try PropertyListSerialization.data(fromPropertyList: self.project.projectConfig.infoDictionary ?? [:], format: .xml, options: 0)
            FileManager.default.createFile(atPath: self.project.bundleURL.appendingPathComponent("Info.plist").path, contents: infoPlistDataSerialized)
        } else if project.projectConfig.schemeKind == .kSurfaceKext {
            try FileManager.default.createDirectory(at: self.project.bundleURL, withIntermediateDirectories: true)
            let infoPlistDataSerialized = try PropertyListSerialization.data(fromPropertyList: self.project.projectConfig.infoDictionary ?? [:], format: .xml, options: 0)
            FileManager.default.createFile(atPath: self.project.bundleURL.appendingPathComponent("Info.plist").path, contents: infoPlistDataSerialized)
        }
    }
    
    func build() throws {
        let usedOnePass = ForkBuildSpeed.usesOnePass(swiftFileCount: ForkBuildSpeed.swiftFileCount(in: self.project.url))
        var ok = self.phaseRunner.runPhases()
        /* fork: compiled only the changed files and failed without an error in the
           code (e.g. the link): compile everything */
        if !ok, !usedOnePass, ForkBuildSpeed.lastPlanPartial, !NXBuilder.forkCancelRequested, !self.forkHasSwiftErrors() {
            let engine = try NXPhaseEngine(project: self.project)
            engine.delegate = self
            if let runner = NXPhaseRunner(engine: engine) {
                runner.delegate = self
                self.phaseRunner = runner
                self.projectDirty = true
                ok = runner.runPhases()
            }
        }
        /* fork: One Pass failed without an error in the code: build file by file */
        if !ok, usedOnePass, !NXBuilder.forkCancelRequested, !self.forkHasSwiftErrors() {
            if ForkBuildSpeed.onePassMode == 0 {
                UserDefaults.standard.set(true, forKey: ForkBuildSpeed.onePassFailedKey)
            }
            ForkBuildSpeed.forcePerFile = true
            defer { ForkBuildSpeed.forcePerFile = false }
            let engine = try NXPhaseEngine(project: self.project)
            engine.delegate = self
            if let runner = NXPhaseRunner(engine: engine) {
                runner.delegate = self
                self.phaseRunner = runner
                self.projectDirty = true
                ok = runner.runPhases()
                if ok {
                    self.database.addMessage(message: "Swift in One Pass did not work here, so the project was compiled file by file (Settings › Toolchain › Speed).", severity: .warning)
                }
            }
        }
        /* fork: still failing with no error at all: once more from a clean state */
        if !ok, !NXBuilder.forkCancelRequested, !self.forkHasAnyError() {
            self.forkRemoveBuildProducts()
            ForkBuildSpeed.forcePerFile = true
            defer { ForkBuildSpeed.forcePerFile = false }
            let engine = try NXPhaseEngine(project: self.project)
            engine.delegate = self
            if let runner = NXPhaseRunner(engine: engine) {
                runner.delegate = self
                self.phaseRunner = runner
                self.projectDirty = true
                var printed = ""
                let earlier = self.database.debugObjects["Internal"]
                self.database.debugObjects["Internal"] = nil
                ok = ForkStderrCapture.run(into: &printed) { runner.runPhases() }
                if ok {
                    self.database.addMessage(message: "The first build failed without an error in the code; it worked after a clean build.", severity: .warning)
                } else if self.database.debugObjects["Internal"] == nil, let earlier {
                    self.database.debugObjects["Internal"] = earlier
                }
                if !ok && !self.forkHasAnyError() {
                    let lines = printed.split(separator: "\n").map(String.init)
                        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    let wanted = lines.filter { $0.localizedCaseInsensitiveContains("error") }
                    for line in (wanted.isEmpty ? Array(lines.suffix(12)) : Array(wanted.suffix(12))) {
                        self.database.addMessage(message: line, severity: .error)
                    }
                }
            }
        }
        if !ok {
            throw NSError(domain: "com.cr4zy.nyxian.builder.runner", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to run project."])
        }
        
        do {
            try self.argsString.write(to: self.project.cacheURL.appendingPathComponent("args.txt"), atomically: false, encoding: .utf8)
        } catch {
            throw NSError(domain: "com.cr4zy.nyxian.builder.runner", code: 1, userInfo: [NSLocalizedDescriptionKey:error.localizedDescription])
        }
    }
    
    func install(buildType: NXBuilder.BuildType, executablePathCallback: @escaping (String?) -> Void) throws {
        let spinnerStart = DispatchWorkItem { XCButton.startSpinning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: spinnerStart)
        defer {
            spinnerStart.cancel()
            XCButton.stopSpinning()
        }
        
        if buildType == .run {
            var success: Bool = false;
            let semaphore = DispatchSemaphore(value: 0)
            checkSigningSetup() { codeSigningSetup in
                success = codeSigningSetup
                semaphore.signal()
            }
            semaphore.wait()
            
            if !success {
                throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Code signing is not properly set up. Cannot sign targets."])
            }
            
            if self.project.projectConfig.schemeKind == .app {
                let semaphore = DispatchSemaphore(value: 0)
                var nsError: NSError? = nil
                
                LCUtils.signAppBundle(withZSign: self.project.bundleURL) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if self.project.projectConfig.signMachOWithNyxianEntitlements {
                        trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, true, nil)
                    }
                    
                    guard result else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:error?.localizedDescription ?? "Unknown error happened signing application"])
                        semaphore.signal()
                        return
                    }
                    
                    guard LDEApplicationWorkspace.shared().installApplication(atBundlePath: project.bundleURL.path) else {
                        nsError = NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Unknown error happened installing application"]) // TODO: implement NSError pipeline
                        semaphore.signal()
                        return
                    }
                    
                    semaphore.signal()
                }
                semaphore.wait()
                
                if let nsError = nsError {
                    throw nsError
                }
            } else if self.project.projectConfig.schemeKind == .utility {
                LCUtils.signMachO(at: self.project.machoURL)
                if self.project.projectConfig.signMachOWithNyxianEntitlements {
                    trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, true, nil)
                }
                
                let path: String? = LDEApplicationWorkspace.shared().fastpathUtility(self.project.machoURL.path)
                if path == nil {
                    throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to fastpath install utility"])
                }
                executablePathCallback(path)
            } else if self.project.projectConfig.schemeKind == .library {
                /* fork: a library is not run — signed, and its place shown */
                LCUtils.signMachOWithoutPatch(at: self.project.machoURL)
                let name = self.project.machoURL.lastPathComponent
                DispatchQueue.main.async {
                    NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Built \(name) (a library is not run: use Export to share it)", withDelay: 0.0)
                }
                executablePathCallback(nil)
            } else if self.project.projectConfig.schemeKind == .kSurfaceKext {
                if let ptr = LCMapMachO(self.project.machoURL.path, false) {
                    ptr.pointee.header.pointee.filetype = UInt32(MH_KEXT_BUNDLE)
                    LCUnmapMachO(ptr)
                    
                    LCUtils.signMachOWithoutPatch(at: self.project.machoURL)
                    trust_nxt2_sign(self.project.machoURL.path, [
                        "org.emexlabs.nyxian.ksurface.kernelextension.loading" : true
                    ] as CFDictionary, true, nil)
                    vnode_refresh_with_path(self.project.machoURL.path)
                    let ret: kern_return_t = ksurface_fs_install_kext_at_path(self.project.bundleURL.path);
                    if ret != 0 {
                        throw NSError(domain: "com.cr4zy.nyxian.builder.install", code: 1, userInfo: [NSLocalizedDescriptionKey:"Failed to install kext: \(String(cString: mach_error_string(ret)))"])
                    }
                    
                    PERestartSelf()
                }
            }
        } else {
            if self.project.projectConfig.schemeKind == .kSurfaceKext {
                if let ptr = LCMapMachO(self.project.machoURL.path, false) {
                    ptr.pointee.header.pointee.filetype = UInt32(MH_KEXT_BUNDLE)
                    LCUnmapMachO(ptr)
                    
                    trust_nxt2_sign(self.project.machoURL.path, [
                        "org.emexlabs.nyxian.ksurface.kernelextension.loading" : true
                    ] as CFDictionary, true, nil)
                    
                    zipDirectoryAtPath(project.payloadURL.path, project.packageURL.path, true)
                }
            } else {
                if self.project.projectConfig.schemeKind == .app {
                    /* fork: an exported .ipa carries nothing of Nyxian — no
                       org.emexlabs.nyxian.* entitlements appended to the app
                       (they only matter when Nyxian runs it, and some signers
                       reject the extra bytes); a blob from an earlier run is
                       removed. Nyxian signs it again if it installs the .ipa. */
                    _ = trust_remove_blob(self.project.machoURL.path)
                    /* fork: the app's own Apple entitlements, written into its signature */
                    let appEntitlements = self.project.url.appendingPathComponent("Config/AppEntitlements.plist")
                    if let data = try? Data(contentsOf: appEntitlements),
                       let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
                       !plist.isEmpty,
                       let xml = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                        let bundleID: String = self.project.projectConfig.bundleid ?? ""
                        if !ZSigner.adhocSignMachO(atPath: self.project.machoURL.path, bundleId: bundleID, entitlementData: xml) {
                            throw NSError(domain: "com.cr4zy.nyxian.builder.export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not write the app's entitlements (Config/AppEntitlements.plist) into the app"])
                        }
                    }
                    try self.package()
                } else if self.project.projectConfig.signMachOWithNyxianEntitlements {
                    trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, false, nil)
                }
            }
        }
    }
    
    func package() throws {
        zipDirectoryAtPath(project.payloadURL.path, project.packageURL.path, true)
    }
    
    ///
    /// Static function to build the project
    ///
    enum BuildType {
        case run
        case export
        case build /* fork: compile and link only, skip signing/install */
    }
    
    static func buildProject(withProject project: NXProject,
                             buildType: NXBuilder.BuildType,
                             completion: @escaping (Bool,String?) -> Void) {
        project.projectConfig.reloadData()
        NXBuilder.forkCancelRequested = false
        
        XCButton.resetProgress()
        
        var execPath: String?
        
        MDKPthreadDispatch {
            autoreleasepool {
                NXBootstrap.shared().waitTillDone()
                /* fork: @State as SwiftUI's property wrapper, also after the SDK was unpacked again */
                ForkSDKPatches.ensure()
                
                var result: Bool = true
                guard let builder: NXBuilder = NXBuilder(
                    project: project
                ) else {
                    completion(false,nil)
                    return
                }
                
                /* fork: nothing changed since the installed run: open it again at once */
                let runStamp: String? = (buildType == .run && project.projectConfig.schemeKind == .app && builder.incrementalBuild && !builder.projectDirty)
                    ? ForkRunStamp.compute(project: project, args: builder.argsString) : nil
                if let runStamp, ForkRunStamp.saved(project) == runStamp,
                   let bundleID = project.projectConfig.bundleid,
                   LDEApplicationWorkspace.shared().applicationInstalled(withBundleID: bundleID) {
                    completion(true, nil)
                    return
                }
                ForkRunStamp.clear(project)
                
                /* fork: why this build may be slower (Low Power Mode, heat) */
                ForkDeviceSpeedNotice.report(into: builder.database)
                
                var resetNeeded: Bool = false
                func progressStage(systemName: String? = nil, increment: Double? = nil, handler: () throws -> Void) throws {
                    if NXBuilder.forkCancelRequested { throw CancellationError() }
                    let doReset: Bool = (increment == nil)
                    if doReset, resetNeeded {
                        XCButton.resetProgress()
                        resetNeeded = false
                    }
                    if let systemName = systemName { XCButton.switchImage(withSystemName: systemName, animated: true) }
                    try handler()
                    if !doReset, let increment = increment {
                        XCButton.incrementProgress(withValue: increment)
                        resetNeeded = true
                    }
                }
                
                func progressFlowBuilder(flow: [(String?,Double?,() throws -> Void)]) throws {
                    for item in flow { try progressStage(systemName: item.0, increment: item.1, handler: item.2) }
                }
                
                do {
                    // prepare
                    var flow: [(String?,Double?,() throws -> Void)] = [
                        (nil,nil,{ try builder.headsup(buildType: buildType) }),
                        (nil,nil,{ try builder.clean() }),
                        (nil,nil,{ try builder.prepare() }),
                        (nil,nil,{ try builder.build() })
                    ];
                    
                    /* fork: a plain build stops after compiling and linking */
                    if buildType != .build {
                        flow.append(("arrow.down.app.fill",nil,{try builder.install(buildType: buildType, executablePathCallback: { path in
                            execPath = path
                        }) }))
                    }
                    
                    // doit, just do it!
                    try progressFlowBuilder(flow: flow)
                } catch is CancellationError {
                    /* fork: cancelled — what was compiled stays for the next build */
                    result = false
                } catch {
                    try? builder.clean()
                    result = false
                    builder.database.addMessage(message: error.localizedDescription, severity: .error)
                }
                if NXBuilder.forkCancelRequested { result = false }
                /* fork: what is installed now, for the next Run */
                if result, buildType == .run, let runStamp { ForkRunStamp.save(project, runStamp) }
                builder.database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
                
                completion(result, execPath)
            }
        }
    }
}

func buildProjectWithArgumentUI(targetViewController: UIViewController,
                                project: NXProject,
                                buildType: NXBuilder.BuildType,
                                completion: @escaping (Bool,String?) -> Void = { _,_ in }) {
    autoreleasepool {
        targetViewController.navigationItem.titleView?.isUserInteractionEnabled = false
        XCButton.switchImageSync(withSystemName: "hammer.fill", animated: false)
        guard let oldBarButtons: [UIBarButtonItem] = targetViewController.navigationItem.rightBarButtonItems else { return }
        
        let barButton: UIBarButtonItem = UIBarButtonItem(customView: XCButton.shared())
        
        NXBuilder.builds = true
        targetViewController.navigationItem.setRightBarButtonItems([barButton], animated: true)
        targetViewController.navigationItem.setHidesBackButton(true, animated: true)
        
        /* fork: Cancel (top left) while it builds: the screen is yours again at once,
           the build stops before its next stage and nothing is installed or run */
        let oldLeftButtons = targetViewController.navigationItem.leftBarButtonItems
        var uiRestored = false
        let restoreUI = { [weak targetViewController] in
            guard !uiRestored, let targetViewController else { return }
            uiRestored = true
            targetViewController.navigationItem.setLeftBarButtonItems(oldLeftButtons, animated: true)
            targetViewController.navigationItem.setRightBarButtonItems(oldBarButtons, animated: true)
            targetViewController.navigationItem.setHidesBackButton(false, animated: true)
            targetViewController.navigationController?.navigationBar.isUserInteractionEnabled = true
            targetViewController.navigationItem.titleView?.isUserInteractionEnabled = true
        }
        let cancelButton = UIBarButtonItem(title: "Cancel", primaryAction: UIAction { _ in
            NXBuilder.forkCancelRequested = true
            XCButton.switchImage(withSystemName: "xmark", animated: true)
            restoreUI()
        })
        cancelButton.tintColor = .systemRed
        targetViewController.navigationItem.setLeftBarButtonItems([cancelButton], animated: true)
        
        NXDocumentManager.shared().saveAll {
            NXDocumentManager.shared().changeAllLockState(toBoolean: true)
            NXBuilder.buildProject(withProject: project, buildType: buildType) { result, fastPath in
                NXDocumentManager.shared().changeAllLockState(toBoolean: false)
                DispatchQueue.main.async {
                    let cancelled = NXBuilder.forkCancelRequested
                    NXBuilder.forkCancelRequested = false
                    NXBuilder.forkLastBuildCancelled = cancelled
                    restoreUI()
                    
                    NXBuilder.builds = false
                    
                    if cancelled {
                        NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Build cancelled", withDelay: 0.0)
                    } else if !result && NXBuilder.forkQuietFailure {
                        /* fork: retried by the caller */
                    } else if !result {
                        let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: project))
                        loggerView.modalPresentationStyle = .formSheet
                        targetViewController.present(loggerView, animated: true)
                    } else if buildType == .export {
                        /* fork: with Config/AppEntitlements.plist, its <app>.entitlements goes along */
                        ForkCleanExport.shareIPA(project)
                    }
                    
                    NXBuilder.forkQuietFailure = false
                    completion(result, fastPath)
                }
            }
        }
    }
}

extension NXBuilder {
    /// Copies the project's .metal files into the app and joins them as NyxianShaders.metal.
    static func forkBundleMetalSources(projectURL: URL, bundleURL: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: projectURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return }
        var combined = ""
        for case let url as URL in enumerator {
            let relative = url.path.replacingOccurrences(of: projectURL.path + "/", with: "")
            if relative.hasPrefix("Config/") || relative == "Config" { enumerator.skipDescendants(); continue }
            guard url.pathExtension.lowercased() == "metal",
                  let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if !relative.hasPrefix("Resources/") {
                let destination = bundleURL.appendingPathComponent(url.lastPathComponent)
                try? fm.removeItem(at: destination)
                try? fm.copyItem(at: url, to: destination)
            }
            combined += "// ---- \(relative)\n" + source + "\n"
        }
        guard !combined.isEmpty else { return }
        try? combined.write(to: bundleURL.appendingPathComponent("NyxianShaders.metal"), atomically: true, encoding: .utf8)
    }
}

// MARK: - fork: Run when nothing changed

/// A fingerprint of everything a Run installs: every file of the project (path,
/// size, date), the build flags, the bundle id and this Nyxian build. Saved after
/// a Run that installed the app; the same fingerprint later means the installed
/// app is still current.
enum ForkRunStamp {
    static func url(_ project: NXProject) -> URL {
        project.cacheURL.appendingPathComponent("fork-run-stamp.txt")
    }

    static func saved(_ project: NXProject) -> String? {
        try? String(contentsOf: url(project), encoding: .utf8)
    }

    static func save(_ project: NXProject, _ stamp: String) {
        try? stamp.write(to: url(project), atomically: true, encoding: .utf8)
    }

    static func clear(_ project: NXProject) {
        try? FileManager.default.removeItem(at: url(project))
    }

    static func compute(project: NXProject, args: String) -> String? {
        let root = project.url.standardizedFileURL
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: []) else { return nil }
        var lines: [String] = []
        let rootPath = root.path
        for case let file as URL in walker {
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let ext = file.pathExtension.lowercased()
            if ext == "o" || ext == "tmp" { continue }
            var path = file.standardizedFileURL.path
            if path.hasPrefix(rootPath) { path = String(path.dropFirst(rootPath.count)) }
            let date = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            lines.append("\(path)|\(values.fileSize ?? -1)|\(Int64(date * 1000))")
        }
        lines.sort()
        var nyxian = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
        if let exe = Bundle.main.executableURL,
           let date = (try? exe.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            nyxian += "|\(Int64(date.timeIntervalSince1970))"
        }
        lines.append("args:" + args)
        lines.append("bundle:" + (project.projectConfig.bundleid ?? ""))
        lines.append("nyxian:" + nyxian)
        let digest = SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - fork: what the compiler printed

/// Runs `body` with this process's standard error going to a file, and gives
/// back what was written: the Swift and clang drivers print their own errors
/// there (not to the Issue Navigator).
enum ForkStderrCapture {
    private static let lock = NSLock()

    static func run(into text: inout String, _ body: () -> Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let path = NSTemporaryDirectory() + "fork-stderr-\(getpid()).txt"
        let fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o600)
        guard fd >= 0 else { return body() }
        fflush(stderr)
        let saved = dup(STDERR_FILENO)
        dup2(fd, STDERR_FILENO)
        let result = body()
        fflush(stderr)
        if saved >= 0 {
            dup2(saved, STDERR_FILENO)
            close(saved)
        }
        close(fd)
        if let data = FileManager.default.contents(atPath: path) {
            text = String(decoding: data.suffix(64 * 1024), as: UTF8.self)
        }
        unlink(path)
        return result
    }
}

// MARK: - fork: Low Power Mode and heat

/// A build in Low Power Mode, or while iOS slows the device down because it is
/// hot, takes longer; a warning under "Device" says so (only then).
enum ForkDeviceSpeedNotice {
    static let title = "Device"

    static func report(into database: DebugDatabase) {
        database.debugObjects[title] = nil
        let info = ProcessInfo.processInfo
        if info.isLowPowerModeEnabled {
            database.addMessage(message: "Low Power Mode is on: iOS runs the processor slower, so building (and the app) can take noticeably longer. The result is the same.", title: title, severity: .warning)
        }
        switch info.thermalState {
        case .serious:
            database.addMessage(message: "The device is hot and iOS is slowing it down: building can take longer until it cools.", title: title, severity: .warning)
        case .critical:
            database.addMessage(message: "The device is very hot and iOS is slowing it down a lot: building will be much slower until it cools.", title: title, severity: .warning)
        default:
            break
        }
    }
}

