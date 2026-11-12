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
 Fork doctoralvarez/Nyxian — version 1.4.1
 Changelog:
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
        
        self.argsString = self.project.projectConfig.swiftFlags.joined(separator: " ") + self.project.projectConfig.compilerFlags.joined(separator: " ") + " \(self.project.projectConfig.linkFrameworksAutomatically)"
        
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
        if !self.phaseRunner.runPhases() {
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
                if self.project.projectConfig.signMachOWithNyxianEntitlements {
                    trust_nxt2_sign(self.project.machoURL.path, project.entitlementsConfig.dictionary as CFDictionary, false, nil)
                }
                if self.project.projectConfig.schemeKind == .app {
                    try self.package()
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
                        share(url: project.packageURL, remove: true)
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
