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
  - 1.0.0 (2026-11-22): App Store preflight and "Xcode on Mac".
    Preflight looks at what would go to App Store Connect, before a build
    number is spent: for a project (the app and the extensions its Export
    embeds) and for an .ipa. Each finding says what Apple would answer (its
    ITMS code where it has one) and, when Nyxian can, fixes it in the project:
    privacy manifest (PrivacyInfo.xcprivacy with the required-reason APIs the
    code uses), iPad orientations and launch screen (Info-extra.plist),
    export compliance (ITSAppUsesNonExemptEncryption, after you confirm) and
    the build number (higher than App Store Connect's last one).
    Nyxian never writes DTXcode / DTXcodeBuild / DTSDKBuild: they say which
    Xcode built the app, and an .ipa from Nyxian was not built by Xcode
    (ITMS-90534). That last step goes to "Xcode on Mac": the projects go to
    the private repository, the App Store (Xcode) workflow makes an Xcode
    project of them on your Mac (GitHub's when yours is off), and Xcode
    archives, signs and uploads the app. Then the build's processing in App
    Store Connect is followed.
*/

import UIKit
import Foundation

// MARK: - Findings

struct ForkPreflightFinding {
    enum Level: Int { case error = 0, warning, info, ok }
    let level: Level
    let code: String?
    let title: String
    let detail: String
    var fix: ForkPreflightFix? = nil
}

enum ForkPreflightFix {
    /// keys merged into the project's Info-extra.plist
    case infoExtra(project: URL, keys: [String: Any], label: String)
    /// ITSAppUsesNonExemptEncryption = NO, asked first (it is your declaration to Apple)
    case encryptionExempt(project: URL)
    /// Resources/PrivacyInfo.xcprivacy with these categories and reasons
    case privacyManifest(project: URL, categories: [String: [String]])
    /// Config/Project.plist NXBundleVersion
    case build(project: URL, value: String)

    var label: String {
        switch self {
        case .infoExtra(_, _, let label): return label
        case .encryptionExempt: return "Declare standard encryption only"
        case .privacyManifest: return "Add to PrivacyInfo.xcprivacy"
        case .build(_, let value): return "Set the build to \(value)"
        }
    }
}

// MARK: - Preflight

enum ForkPreflight {

    // what Apple's scan looks for (required-reason APIs) and the reason most apps give
    struct ReasonAPI { let category: String; let tokens: [String]; let reasons: [String]; let what: String }
    static let reasonAPIs: [ReasonAPI] = [
        ReasonAPI(category: "NSPrivacyAccessedAPICategoryUserDefaults",
                  tokens: ["UserDefaults", "NSUserDefaults", "AppStorage"],
                  reasons: ["CA92.1"], what: "UserDefaults / @AppStorage"),
        ReasonAPI(category: "NSPrivacyAccessedAPICategoryFileTimestamp",
                  tokens: ["creationDate", "modificationDate", "contentModificationDateKey", "creationDateKey",
                           "NSFileCreationDate", "NSFileModificationDate", "getattrlist", "fstatat", "lstat(", "fstat(", " stat("],
                  reasons: ["C617.1"], what: "file dates (creationDate, modificationDate, stat)"),
        ReasonAPI(category: "NSPrivacyAccessedAPICategorySystemBootTime",
                  tokens: ["systemUptime", "mach_absolute_time"],
                  reasons: ["35F9.1"], what: "systemUptime / mach_absolute_time"),
        ReasonAPI(category: "NSPrivacyAccessedAPICategoryDiskSpace",
                  tokens: ["volumeAvailableCapacity", "volumeTotalCapacity", "NSFileSystemFreeSize", "NSFileSystemSize", "statfs", "statvfs"],
                  reasons: ["E174.1"], what: "free disk space"),
        ReasonAPI(category: "NSPrivacyAccessedAPICategoryActiveKeyboards",
                  tokens: ["activeInputModes"],
                  reasons: ["54BD.1"], what: "activeInputModes"),
    ]

    // APIs that need a purpose string in Info.plist (ITMS-90683)
    static let purposeStrings: [(tokens: [String], key: String, what: String)] = [
        (["AVCaptureDevice", "AVCaptureSession", "sourceType = .camera", ".camera)"], "NSCameraUsageDescription", "the camera"),
        (["PHPhotoLibrary", "PHAssetChangeRequest", "UIImageWriteToSavedPhotosAlbum"], "NSPhotoLibraryUsageDescription", "the photo library"),
        (["CLLocationManager"], "NSLocationWhenInUseUsageDescription", "location"),
        (["AVAudioRecorder", "requestRecordPermission", "AVAudioApplication.requestRecordPermission"], "NSMicrophoneUsageDescription", "the microphone"),
        (["SFSpeechRecognizer"], "NSSpeechRecognitionUsageDescription", "speech recognition"),
        (["CNContactStore"], "NSContactsUsageDescription", "contacts"),
        (["EKEventStore"], "NSCalendarsFullAccessUsageDescription", "calendars (or NSRemindersFullAccessUsageDescription for reminders)"),
        (["HKHealthStore"], "NSHealthShareUsageDescription", "Health"),
        (["CBCentralManager", "CBPeripheralManager"], "NSBluetoothAlwaysUsageDescription", "Bluetooth"),
        (["LAContext"], "NSFaceIDUsageDescription", "Face ID"),
        (["CMMotionManager", "CMPedometer"], "NSMotionUsageDescription", "motion"),
        (["NFCNDEFReaderSession", "NFCTagReaderSession"], "NFCReaderUsageDescription", "NFC"),
    ]

    static let allOrientations = [
        "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
        "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
    ]

    // MARK: project helpers

    static func infoExtraURL(_ project: URL) -> URL { project.appendingPathComponent("Info-extra.plist") }

    static func readPlist(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let p = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return [:] }
        return p
    }

    static func writePlist(_ value: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    /// The Info.plist the app gets: NXBundleInfo with Info-extra.plist (NXProject joins them)
    static func info(of project: NXProject) -> [String: Any] {
        NXProject(url: project.url)?.projectConfig.infoDictionary as? [String: Any] ?? project.projectConfig.infoDictionary as? [String: Any] ?? [:]
    }

    static func sources(of project: NXProject) -> String {
        var text = ""
        for url in ProjectFileIndex.files(in: project.url as URL) where ["swift", "m", "mm", "c", "cpp", "h"].contains(url.pathExtension) {
            if let s = try? String(contentsOf: url, encoding: .utf8) { text += s + "\n" }
        }
        return text
    }

    /// Every file of a project (images, xcprivacy, …), hidden ones left out
    static func allFiles(in root: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        var out: [URL] = []
        for case let url as URL in e where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { out.append(url) }
        return out
    }

    static func privacyManifests(in project: URL) -> [URL] {
        allFiles(in: project).filter { $0.lastPathComponent == "PrivacyInfo.xcprivacy" }
    }

    /// categories → reasons already declared in a bundle's PrivacyInfo.xcprivacy
    static func declared(_ plist: [String: Any]) -> [String: [String]] {
        var out: [String: [String]] = [:]
        for item in plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? [] {
            if let c = item["NSPrivacyAccessedAPIType"] as? String {
                out[c] = item["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
            }
        }
        return out
    }

    static func projectPlist(_ project: URL) -> [String: Any] { readPlist(project.appendingPathComponent("Config/Project.plist")) }

    static func versions(_ project: NXProject) -> (version: String, build: String) {
        let p = projectPlist(project.url as URL)
        let build = p["NXBundleVersion"] as? String ?? "1.0"
        let version = p["NXBundleShortVersion"] as? String ?? build
        return (version, build)
    }

    static func nextBuild(after builds: [String], current: String) -> String {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
        func less(_ a: [Int], _ b: [Int]) -> Bool {
            for i in 0..<max(a.count, b.count) {
                let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
                if x != y { return x < y }
            }
            return false
        }
        var top = parts(current)
        for b in builds where less(top, parts(b)) { top = parts(b) }
        if top.isEmpty { return "1" }
        top[top.count - 1] += 1
        return top.map(String.init).joined(separator: ".")
    }

    // MARK: project (Xcode on Mac, and what Export puts in an .ipa)

    static func check(project app: NXProject, forXcode: Bool) async -> [ForkPreflightFinding] {
        var out: [ForkPreflightFinding] = []
        let root = app.url as URL
        let name = app.projectConfig.displayName ?? root.lastPathComponent
        let bundleID = app.projectConfig.bundleid ?? ""
        let info = info(of: app)
        let (version, build) = versions(app)

        if bundleID.range(of: #"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$"#, options: .regularExpression) == nil {
            out.append(.init(level: .error, code: nil, title: "Bundle ID \"\(bundleID)\"",
                             detail: "App Store Connect takes letters, digits, \"-\" and dots (com.you.app)."))
        }
        if version.range(of: #"^\d+(\.\d+){0,2}$"#, options: .regularExpression) == nil {
            out.append(.init(level: .error, code: "ITMS-90060", title: "Version \"\(version)\"",
                             detail: "The version (CFBundleShortVersionString) is up to three numbers with dots, like 1.2 or 1.2.3."))
        }
        if build.range(of: #"^\d+(\.\d+){0,2}$"#, options: .regularExpression) == nil {
            out.append(.init(level: .error, code: nil, title: "Build \"\(build)\"",
                             detail: "The build (CFBundleVersion) is up to three numbers with dots."))
        }

        // App Store Connect: the app record and the builds it already has
        if ForkASCAccount.isConfigured {
            do {
                if let record = try await ForkASCAPI.app(bundleID: bundleID) {
                    let q = version.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? version
                    let json = try await ForkASCAPI.request("GET", "/v1/builds?filter[app]=\(record.id)&filter[preReleaseVersion.version]=\(q)&fields[builds]=version&limit=200")
                    let builds = (json["data"] as? [[String: Any]] ?? []).compactMap { ($0["attributes"] as? [String: Any])?["version"] as? String }
                    let next = nextBuild(after: builds, current: build)
                    if builds.contains(build) || next != nextBuild(after: [], current: build) {
                        out.append(.init(level: .error, code: "ITMS-90189",
                                         title: "Build \(build) of \(version) is already in App Store Connect",
                                         detail: "Each upload needs a higher build number than the ones Apple has (\(builds.prefix(5).joined(separator: ", "))).",
                                         fix: .build(project: root, value: next)))
                    } else {
                        out.append(.init(level: .ok, code: nil, title: "\(record.name) is in App Store Connect",
                                         detail: "Version \(version), build \(build): not uploaded before."))
                    }
                } else {
                    out.append(.init(level: .error, code: nil, title: "No app \(bundleID) in App Store Connect",
                                     detail: "Create it once: App Store Connect › Apps › + › New App, with this bundle ID (register it at developer.apple.com › Identifiers if it is not in the list)."))
                }
            } catch {
                out.append(.init(level: .warning, code: nil, title: "App Store Connect not checked", detail: error.localizedDescription))
            }
        } else {
            out.append(.init(level: .info, code: nil, title: "App Store Connect not checked",
                             detail: "Add the API key above to check the app record and the build numbers already used."))
        }

        // icon
        let iconURL = ForkAssetCatalog.iconURL(root)
        if let image = UIImage(contentsOfFile: iconURL.path), let cg = image.cgImage {
            if cg.width != 1024 || cg.height != 1024 {
                out.append(.init(level: .error, code: "ITMS-90022", title: "App icon is \(cg.width)×\(cg.height)",
                                 detail: "Config/AppIcon.png has to be 1024×1024."))
            }
            let alpha = cg.alphaInfo
            if alpha != .none && alpha != .noneSkipFirst && alpha != .noneSkipLast {
                out.append(.init(level: forXcode ? .info : .warning, code: "ITMS-90717", title: "App icon has transparency",
                                 detail: forXcode ? "Xcode on Mac flattens it (no alpha) before compiling the icon." : "The App Store icon can't have an alpha channel: save Config/AppIcon.png without transparency, then App Icon above again."))
            }
            if !forXcode && !ForkAssetCatalog.isCurrent(root) {
                out.append(.init(level: .error, code: "ITMS-90713", title: "Assets.car not compiled for this icon",
                                 detail: "App Icon (Assets.car) above, then Export again. Xcode on Mac does this by itself."))
            }
        } else {
            out.append(.init(level: .error, code: "ITMS-90022", title: "No app icon",
                             detail: "Put a 1024×1024 PNG at \(name)/Config/AppIcon.png (Export › Set App Icon)."))
        }

        // iPad
        let families = (info["UIDeviceFamily"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? [1, 2]
        if families.contains(2) && (info["UIRequiresFullScreen"] as? Bool) != true {
            let ipad = (info["UISupportedInterfaceOrientations~ipad"] as? [String]) ?? (info["UISupportedInterfaceOrientations"] as? [String]) ?? []
            if Set(ipad) != Set(allOrientations) {
                out.append(.init(level: .error, code: "ITMS-90474", title: "iPad needs all four orientations",
                                 detail: "An iPad app with multitasking supports portrait, upside down and both landscapes (or sets UIRequiresFullScreen).",
                                 fix: .infoExtra(project: root, keys: ["UISupportedInterfaceOrientations~ipad": allOrientations], label: "Add the four iPad orientations")))
            }
        }
        if info["UILaunchScreen"] == nil && info["UILaunchStoryboardName"] == nil {
            out.append(.init(level: forXcode ? .warning : .error, code: "ITMS-90475", title: "No launch screen",
                             detail: "iPad multitasking needs a launch screen. An empty UILaunchScreen is the plain one SwiftUI apps use.",
                             fix: .infoExtra(project: root, keys: ["UILaunchScreen": [String: Any]()], label: "Add an empty UILaunchScreen")))
        }

        // export compliance
        if info["ITSAppUsesNonExemptEncryption"] == nil {
            out.append(.init(level: .warning, code: nil, title: "Export compliance not declared",
                             detail: "Without ITSAppUsesNonExemptEncryption, App Store Connect asks about encryption for every build. An app that only uses HTTPS and Apple's own encryption declares NO.",
                             fix: .encryptionExempt(project: root)))
        }

        // privacy manifest and purpose strings, for the app and each extension
        let extensions = ForkEmbeddedExtensions.embedded(in: app)
        let appGroups = !(ForkAppEntitlements.read(app)["com.apple.security.application-groups"] as? [String] ?? []).isEmpty
        for project in [app] + extensions {
            let label = project === app ? name : (project.projectConfig.displayName ?? (project.url as URL).lastPathComponent)
            let text = sources(of: project)
            var have: [String: [String]] = [:]
            for url in privacyManifests(in: project.url as URL) {
                for (k, v) in declared(readPlist(url)) { have[k, default: []] += v }
            }
            var missing: [String: [String]] = [:]
            var what: [String] = []
            for api in reasonAPIs where api.tokens.contains(where: { text.contains($0) }) {
                if have[api.category] == nil {
                    var reasons = api.reasons
                    if api.category == "NSPrivacyAccessedAPICategoryUserDefaults" && appGroups && text.contains("suiteName") { reasons.append("1C8F.1") }
                    missing[api.category] = reasons
                    what.append(api.what)
                }
            }
            if !missing.isEmpty {
                out.append(.init(level: .error, code: "ITMS-91053", title: "\(label): required-reason APIs not declared",
                                 detail: "The code uses \(what.joined(separator: ", ")). Each bundle declares them in PrivacyInfo.xcprivacy with Apple's reason codes (\(missing.values.flatMap { $0 }.joined(separator: ", "))): check they say what your app does.",
                                 fix: .privacyManifest(project: project.url as URL, categories: missing)))
            } else if !have.isEmpty || reasonAPIs.contains(where: { $0.tokens.contains(where: { text.contains($0) }) }) {
                out.append(.init(level: .ok, code: nil, title: "\(label): privacy manifest", detail: "The required-reason APIs the code uses are declared."))
            }
            if project === app {
                for p in purposeStrings where p.tokens.contains(where: { text.contains($0) }) && info[p.key] == nil {
                    out.append(.init(level: .warning, code: "ITMS-90683", title: "No \(p.key)",
                                     detail: "The code seems to use \(p.what). iOS shows this text when it asks permission; write what your app does with it in Info-extra.plist (Apple rejects vague ones)."))
                }
            }
        }

        // extensions
        for ext in extensions {
            let extName = ext.projectConfig.displayName ?? (ext.url as URL).lastPathComponent
            if ForkEmbeddedExtensions.extensionPoint(of: ext) == ForkEmbeddedExtensions.widgetPoint && !ForkEmbeddedExtensions.usesWidgetKit(ext) {
                out.append(.init(level: .error, code: nil, title: "\(extName): no @main WidgetBundle or Widget",
                                 detail: "A widget extension starts from a @main type adopting WidgetBundle or Widget."))
            } else {
                out.append(.init(level: .ok, code: nil, title: "\(extName) goes in as \(bundleID).\(ForkEmbeddedExtensions.suffix(of: ext))",
                                 detail: "Same version and build as the app."))
            }
        }

        if forXcode {
            out.append(.init(level: .ok, code: "ITMS-90534", title: "Built by Xcode",
                             detail: "Xcode on Mac builds and signs it: DTXcode, DTSDKBuild, Assets.car, Metadata.appintents and the privacy report are Xcode's own."))
            if ForkXcodeOnMac.teamID.isEmpty {
                out.append(.init(level: .warning, code: nil, title: "No Team ID",
                                 detail: "Fill in Team ID (Xcode on Mac), or add the APPLE_TEAM_ID secret to the repository."))
            }
        } else {
            out.append(.init(level: .error, code: "ITMS-90534", title: "Not built by Xcode",
                             detail: "An .ipa exported by Nyxian has no DTXcode / DTSDKBuild: Nyxian does not write them, because they would claim an Xcode that did not build it. Apple asks for Xcode 26 or later: send the project with Xcode on Mac."))
        }
        return out.sorted { $0.level.rawValue < $1.level.rawValue }
    }

    // MARK: .ipa (the direct upload)

    static func check(ipa info: ForkASCIPAInfo) -> [ForkPreflightFinding] {
        var out: [ForkPreflightFinding] = []
        let fm = FileManager.default
        let app = info.appFolder
        let appInfo = readPlist(app.appendingPathComponent("Info.plist"))
        var bundles: [(URL, [String: Any])] = [(app, appInfo)]
        let plugIns = app.appendingPathComponent("PlugIns")
        for ext in ((try? fm.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)) ?? []) where ext.pathExtension == "appex" {
            bundles.append((ext, readPlist(ext.appendingPathComponent("Info.plist"))))
        }

        let dtKeys = ["DTXcode", "DTXcodeBuild", "DTSDKBuild", "DTPlatformBuild", "DTCompiler"]
        let missingDT = dtKeys.filter { appInfo[$0] == nil }
        if !missingDT.isEmpty {
            out.append(.init(level: .error, code: "ITMS-90534", title: "Not built by Xcode",
                             detail: "No \(missingDT.joined(separator: ", ")) in Info.plist. They say which Xcode built the app; Nyxian does not write them for a build Xcode did not make. Apple asks for Xcode 26 or later: use Xcode on Mac with the project."))
        }

        for (bundle, plist) in bundles {
            let label = bundle.lastPathComponent
            guard let exe = plist["CFBundleExecutable"] as? String, let mach = ForkMachO(url: bundle.appendingPathComponent(exe)) else {
                out.append(.init(level: .error, code: nil, title: "\(label): no executable", detail: "CFBundleExecutable is missing or not a Mach-O."))
                continue
            }
            if mach.architectures.contains(where: { $0 != "arm64" }) {
                out.append(.init(level: .error, code: "ITMS-90087", title: "\(label): \(mach.architectures.joined(separator: ", "))",
                                 detail: "The App Store takes arm64 only."))
            }
            if let sdk = mach.sdk, let major = Int(sdk.split(separator: ".").first ?? ""), major < 26 {
                out.append(.init(level: .error, code: "ITMS-90725", title: "\(label): iOS \(sdk) SDK",
                                 detail: "Apple asks for the iOS 26 SDK or later."))
            }
            let privateLibs = mach.dylibs.filter { $0.contains("/PrivateFrameworks/") }
            if !privateLibs.isEmpty {
                out.append(.init(level: .error, code: "ITMS-90338", title: "\(label): private frameworks",
                                 detail: privateLibs.joined(separator: "\n")))
            }
            // required-reason APIs seen in the binary, against its PrivacyInfo.xcprivacy
            let have = declared(readPlist(bundle.appendingPathComponent("PrivacyInfo.xcprivacy")))
            /* short names (stat, lstat) would match any text in the binary: only the longer ones count here */
            let used = reasonAPIs.filter { api in
                api.tokens.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " (")) }.filter { $0.count >= 6 }.contains { mach.contains($0) }
            }
            let missing = used.filter { have[$0.category] == nil }
            if !missing.isEmpty {
                out.append(.init(level: .error, code: "ITMS-91053", title: "\(label): required-reason APIs not declared",
                                 detail: "It uses \(missing.map { $0.what }.joined(separator: ", ")) and has no PrivacyInfo.xcprivacy entry for it (Preflight on the project adds it)."))
            }
            if bundle != app {
                if plist["CFBundleShortVersionString"] as? String != appInfo["CFBundleShortVersionString"] as? String ||
                    plist["CFBundleVersion"] as? String != appInfo["CFBundleVersion"] as? String {
                    out.append(.init(level: .warning, code: "ITMS-90473", title: "\(label): version differs from the app", detail: "An extension has the app's version and build."))
                }
                if let id = plist["CFBundleIdentifier"] as? String, !id.hasPrefix(info.bundleID + ".") {
                    out.append(.init(level: .error, code: nil, title: "\(label): \(id)", detail: "An extension's bundle ID starts with the app's (\(info.bundleID).…)."))
                }
            }
        }

        if appInfo["CFBundleIconName"] == nil || !fm.fileExists(atPath: app.appendingPathComponent("Assets.car").path) {
            out.append(.init(level: .error, code: "ITMS-90713", title: "No compiled app icon", detail: "Assets.car and CFBundleIconName: App Icon above, then Export again."))
        }
        let families = (appInfo["UIDeviceFamily"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
        if families.contains(2) && (appInfo["UIRequiresFullScreen"] as? Bool) != true {
            let ipad = (appInfo["UISupportedInterfaceOrientations~ipad"] as? [String]) ?? (appInfo["UISupportedInterfaceOrientations"] as? [String]) ?? []
            if Set(ipad) != Set(allOrientations) {
                out.append(.init(level: .error, code: "ITMS-90474", title: "iPad needs all four orientations", detail: "Preflight on the project adds them."))
            }
            if appInfo["UILaunchScreen"] == nil && appInfo["UILaunchStoryboardName"] == nil {
                out.append(.init(level: .error, code: "ITMS-90475", title: "No launch screen", detail: "Preflight on the project adds an empty UILaunchScreen."))
            }
        }
        if appInfo["ITSAppUsesNonExemptEncryption"] == nil {
            out.append(.init(level: .warning, code: nil, title: "Export compliance not declared", detail: "App Store Connect will ask about encryption for this build."))
        }
        if fm.fileExists(atPath: app.appendingPathComponent("Metadata.appintents").path) {
            out.append(.init(level: .info, code: nil, title: "Metadata.appintents written by Nyxian",
                             detail: "Not by Xcode's appintentsmetadataprocessor: Apple has not seen this format from anything but Xcode. Xcode on Mac writes its own."))
        }
        if !appInfo.keys.filter({ $0.hasPrefix("NX") }).isEmpty {
            out.append(.init(level: .info, code: nil, title: "Nyxian keys in Info.plist", detail: "\(appInfo.keys.filter { $0.hasPrefix("NX") }.sorted().joined(separator: ", ")): harmless, the App Store ignores them."))
        }
        if out.allSatisfy({ $0.level != .error }) {
            out.append(.init(level: .ok, code: nil, title: "Nothing blocking found", detail: "Apple runs more checks when it processes the build."))
        }
        return out.sorted { $0.level.rawValue < $1.level.rawValue }
    }

    // MARK: fixes

    static func apply(_ fix: ForkPreflightFix) throws {
        switch fix {
        case .infoExtra(let project, let keys, _):
            var plist = readPlist(infoExtraURL(project))
            for (k, v) in keys { plist[k] = v }
            try writePlist(plist, to: infoExtraURL(project))
        case .encryptionExempt(let project):
            var plist = readPlist(infoExtraURL(project))
            plist["ITSAppUsesNonExemptEncryption"] = false
            try writePlist(plist, to: infoExtraURL(project))
        case .privacyManifest(let project, let categories):
            let url = privacyManifests(in: project).first ?? project.appendingPathComponent("Resources/PrivacyInfo.xcprivacy")
            var plist = readPlist(url)
            var types = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
            for (category, reasons) in categories.sorted(by: { $0.key < $1.key }) {
                if let i = types.firstIndex(where: { $0["NSPrivacyAccessedAPIType"] as? String == category }) {
                    var existing = types[i]["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
                    for r in reasons where !existing.contains(r) { existing.append(r) }
                    types[i]["NSPrivacyAccessedAPITypeReasons"] = existing
                } else {
                    types.append(["NSPrivacyAccessedAPIType": category, "NSPrivacyAccessedAPITypeReasons": reasons])
                }
            }
            plist["NSPrivacyAccessedAPITypes"] = types
            if plist["NSPrivacyTracking"] == nil { plist["NSPrivacyTracking"] = false }
            if plist["NSPrivacyTrackingDomains"] == nil { plist["NSPrivacyTrackingDomains"] = [String]() }
            if plist["NSPrivacyCollectedDataTypes"] == nil { plist["NSPrivacyCollectedDataTypes"] = [[String: Any]]() }
            try writePlist(plist, to: url)
        case .build(let project, let value):
            let url = project.appendingPathComponent("Config/Project.plist")
            var plist = readPlist(url)
            /* the version falls back to the build: keep it as it is */
            if plist["NXBundleShortVersion"] == nil { plist["NXBundleShortVersion"] = plist["NXBundleVersion"] as? String ?? "1.0" }
            plist["NXBundleVersion"] = value
            try writePlist(plist, to: url)
        }
    }
}

// MARK: - Mach-O (architectures, SDK, libraries, strings)

struct ForkMachO {
    let architectures: [String]
    let sdk: String?
    let dylibs: [String]
    private let data: Data

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count > 32 else { return nil }
        self.data = data
        func u32(_ o: Int, big: Bool = false) -> UInt32 {
            guard o + 4 <= data.count else { return 0 }
            let v = data.subdata(in: o..<o + 4).withUnsafeBytes { $0.load(as: UInt32.self) }
            return big ? UInt32(bigEndian: v) : v
        }
        var slices: [(Int, UInt32)] = []
        let magic = u32(0, big: true)
        if magic == 0xCAFEBABE {
            let n = Int(u32(4, big: true))
            for i in 0..<min(n, 8) {
                let base = 8 + i * 20
                slices.append((Int(u32(base + 8, big: true)), u32(base, big: true)))
            }
        } else {
            slices.append((0, u32(4)))
        }
        func archName(_ cpu: UInt32) -> String {
            switch cpu { case 0x0100000C: return "arm64"; case 0x01000007: return "x86_64"; case 12: return "armv7"; default: return String(format: "cpu 0x%x", cpu) }
        }
        architectures = slices.map { archName($0.1) }
        guard let arm = slices.first(where: { $0.1 == 0x0100000C }) ?? slices.first, u32(arm.0) == 0xFEEDFACF else { return nil }
        let start = arm.0
        let ncmds = Int(u32(start + 16))
        var offset = start + 32
        var libs: [String] = []
        var sdkText: String?
        for _ in 0..<min(ncmds, 512) {
            let cmd = u32(offset), size = Int(u32(offset + 4))
            guard size > 0, offset + size <= data.count else { break }
            if [0xC, 0x80000018, 0x8000001F, 0x20].contains(cmd) {
                let nameOffset = Int(u32(offset + 8))
                if nameOffset < size {
                    let raw = data.subdata(in: offset + nameOffset..<offset + size)
                    libs.append(String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self))
                }
            } else if cmd == 0x32 {   // LC_BUILD_VERSION
                let v = u32(offset + 16)
                sdkText = "\(v >> 16).\((v >> 8) & 0xFF)"
            } else if cmd == 0x25 && sdkText == nil {   // LC_VERSION_MIN_IPHONEOS
                let v = u32(offset + 12)
                sdkText = "\(v >> 16).\((v >> 8) & 0xFF)"
            }
            offset += size
        }
        dylibs = libs
        sdk = sdkText
    }

    func contains(_ text: String) -> Bool { data.range(of: Data(text.utf8)) != nil }
}

// MARK: - Xcode on Mac

enum ForkXcodeOnMac {
    static let workflow = "appstore-xcode.yml"
    static let release = "appstore-requests"
    static let workflowRepository = "doctoralvarez/Nyxian"
    static let ref = "mejoras-editor-ipad"
    static var privateRepository: String { ForkAboutViewController.backupRepository }

    static let teamKey = "fork.asc.teamID"
    static var teamID: String {
        get {
            if let t = UserDefaults.standard.string(forKey: teamKey), !t.isEmpty { return t }
            return ForkASCProfile.all().map { $0.teamID }.first { !$0.isEmpty } ?? ""
        }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), forKey: teamKey) }
    }

    enum Mode: String { case upload, check }

    struct Result {
        let ok: Bool
        let stage: String
        let xcode: String
        let issues: [String]
        let log: URL?
    }

    /// The app projects that can go to the App Store (not the extensions)
    static func apps() -> [NXProject] {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: ForkEmbeddedExtensions.projectsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return items.compactMap { url -> NXProject? in
            guard fm.fileExists(atPath: url.appendingPathComponent("Config/Project.plist").path),
                  let p = NXProject(url: url), p.projectConfig.schemeKind == .app,
                  ForkEmbeddedExtensions.extensionPoint(of: p) == nil else { return nil }
            return p
        }.sorted { ($0.projectConfig.displayName ?? "") < ($1.projectConfig.displayName ?? "") }
    }

    // MARK: GitHub

    private static func github(_ urlText: String, method: String = "GET", body: Data? = nil, contentType: String = "application/json", accept: String = "application/vnd.github+json") async throws -> (Data, Int) {
        guard let token = ForkWheelBuilder.token else {
            throw ForkASCError.message("Add your GitHub token in Settings › Toolchain › iOS Builds. It needs \"Contents: Read and write\" on \(privateRepository) and \"Actions: Read and write\" on \(workflowRepository).")
        }
        guard let url = URL(string: urlText) else { throw ForkASCError.message("Bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 300
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(accept, forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body { req.httpBody = body; req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: req)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private static func json(_ data: Data) -> Any? { try? JSONSerialization.jsonObject(with: data) }

    private static func failure(_ status: Int, _ data: Data, _ what: String) -> ForkASCError {
        var text = "\(what) (GitHub \(status))"
        if status == 401 { text += ": the token is not valid or expired." }
        if status == 403 || status == 404 { text += ": the token needs \"Contents: Read and write\" on \(privateRepository) and \"Actions: Read and write\" on \(workflowRepository)." }
        if let m = (json(data) as? [String: Any])?["message"] as? String { text += "\n\(m)" }
        return ForkASCError.message(text)
    }

    private static func releaseID() async throws -> Int {
        let api = "https://api.github.com/repos/\(privateRepository)/releases"
        let (data, status) = try await github("\(api)/tags/\(release)")
        if status == 200, let id = (json(data) as? [String: Any])?["id"] as? Int { return id }
        let body = try JSONSerialization.data(withJSONObject: [
            "tag_name": release, "name": "App Store requests", "prerelease": true,
            "body": "Temporary files of Nyxian's Settings › App Store Connect › Xcode on Mac: <request>.zip (the projects) goes up, the App Store (Xcode) workflow answers <request>-result.json and <request>-log.txt. Private.",
        ])
        let (created, createdStatus) = try await github(api, method: "POST", body: body)
        guard createdStatus == 201, let id = (json(created) as? [String: Any])?["id"] as? Int else { throw failure(createdStatus, created, "Could not create the \(release) release") }
        return id
    }

    // MARK: request

    /// Only what JSON holds (an Info.plist can have dates or data, which JSONSerialization does not take)
    static func jsonSafe(_ value: Any) -> Any? {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n
        case let a as [Any]: return a.compactMap { jsonSafe($0) }
        case let d as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in d { if let safe = jsonSafe(v) { out[k] = safe } }
            return out
        case let d as Date: return ISO8601DateFormatter().string(from: d)
        default: return nil
        }
    }

    static func manifestEntry(_ p: NXProject, folder: String) -> [String: Any] {
        let (version, build) = ForkPreflight.versions(p)
        var entry: [String: Any] = [
            "folder": folder,
            "name": p.projectConfig.displayName ?? folder,
            "executable": p.projectConfig.executable ?? folder,
            "bundleID": p.projectConfig.bundleid ?? "",
            "version": version,
            "build": build,
            "deploymentTarget": p.projectConfig.deploymentTarget ?? "17.0",
            "info": jsonSafe(ForkPreflight.info(of: p)) ?? [:],
            "entitlements": jsonSafe(ForkAppEntitlements.read(p)) ?? [:],
            "swiftFlags": p.projectConfig.swiftFlags ?? [],
            "linkerFlags": p.projectConfig.linkerFlags ?? [],
        ]
        if let families = (ForkPreflight.info(of: p)["UIDeviceFamily"] as? [Any])?.compactMap({ ($0 as? NSNumber)?.intValue }) {
            entry["deviceFamily"] = families
        }
        return entry
    }

    private static func copyProject(_ from: URL, to: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: to, withIntermediateDirectories: true)
        for url in ForkPreflight.allFiles(in: from) {
            let rel = ProjectFileIndex.relativePath(url, root: from)
            if rel.hasPrefix("Config/AssetCatalog/") || rel.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { continue }
            let dest = to.appendingPathComponent(rel)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if url.pathExtension == "swift", let live = LiveEditorRegistry.editor(forPath: url.path)?.textView.text {
                try Data(live.utf8).write(to: dest)
            } else {
                try fm.copyItem(at: url, to: dest)
            }
        }
    }

    /// Sends the app (and the extensions its Export embeds) to Xcode on the Mac and waits for its answer
    static func send(_ app: NXProject, mode: Mode, progress: @escaping (String) -> Void) async throws -> Result {
        let fm = FileManager.default
        let request = UUID().uuidString
        let work = ForkASCPipeline.workRoot().appendingPathComponent("xcode-\(request)", isDirectory: true)
        let staging = work.appendingPathComponent("request", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        progress("Packing the projects…")
        let appFolder = (app.url as URL).lastPathComponent
        try copyProject(app.url as URL, to: staging.appendingPathComponent(appFolder))
        var extensions: [[String: Any]] = []
        let appEntry = manifestEntry(app, folder: appFolder)
        for ext in ForkEmbeddedExtensions.embedded(in: app) {
            let folder = (ext.url as URL).lastPathComponent
            try copyProject(ext.url as URL, to: staging.appendingPathComponent(folder))
            var entry = manifestEntry(ext, folder: folder)
            entry["bundleID"] = "\(app.projectConfig.bundleid ?? "").\(ForkEmbeddedExtensions.suffix(of: ext))"
            entry["point"] = ForkEmbeddedExtensions.extensionPoint(of: ext) ?? ForkEmbeddedExtensions.widgetPoint
            /* an extension shares the app's App Groups, as Export gives them */
            var ent = entry["entitlements"] as? [String: Any] ?? [:]
            if let groups = (appEntry["entitlements"] as? [String: Any])?["com.apple.security.application-groups"] {
                ent["com.apple.security.application-groups"] = groups
            }
            entry["entitlements"] = ent
            extensions.append(entry)
        }
        let manifest: [String: Any] = ["format": 1, "teamID": teamID, "app": appEntry, "extensions": extensions]
        guard JSONSerialization.isValidJSONObject(manifest) else { throw ForkASCError.message("The project's settings could not be written as JSON.") }
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: staging.appendingPathComponent("manifest.json"))
        let zip = work.appendingPathComponent("\(request).zip")
        guard zipDirectoryAtPath(staging.path, zip.path, false), let zipData = try? Data(contentsOf: zip) else {
            throw ForkASCError.message("Could not pack the projects.")
        }

        progress("Sending to the private repository…")
        let releaseID = try await releaseID()
        let (upData, upStatus) = try await github("https://uploads.github.com/repos/\(privateRepository)/releases/\(releaseID)/assets?name=\(request).zip",
                                                 method: "POST", body: zipData, contentType: "application/zip")
        guard upStatus == 201 else { throw failure(upStatus, upData, "Could not upload the projects") }
        try? fm.removeItem(at: zip)

        progress("Starting Xcode on the Mac…")
        let body = try JSONSerialization.data(withJSONObject: ["ref": ref, "inputs": ["request": request, "mode": mode.rawValue]])
        let (d, st) = try await github("https://api.github.com/repos/\(workflowRepository)/actions/workflows/\(workflow)/dispatches", method: "POST", body: body)
        guard st == 204 else { throw failure(st, d, "Could not start the App Store (Xcode) workflow") }

        /* the answer: <request>-result.json on the same private release */
        let deadline = Date().addingTimeInterval(75 * 60)
        let started = Date()
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000_000)
            let minutes = Int(Date().timeIntervalSince(started) / 60)
            progress("Xcode on the Mac is working (\(minutes) min)… your Mac if it is on, GitHub's otherwise.")
            let (ad, ast) = try await github("https://api.github.com/repos/\(privateRepository)/releases/\(releaseID)/assets?per_page=100")
            guard ast == 200, let assets = json(ad) as? [[String: Any]] else { continue }
            guard let resultAsset = assets.first(where: { ($0["name"] as? String) == "\(request)-result.json" }),
                  let resultID = resultAsset["id"] as? Int else { continue }
            let (rd, rst) = try await github("https://api.github.com/repos/\(privateRepository)/releases/assets/\(resultID)", accept: "application/octet-stream")
            guard rst == 200, let result = json(rd) as? [String: Any] else { throw ForkASCError.message("Could not read the answer from the Mac (GitHub \(rst)).") }
            var logURL: URL?
            if let logAsset = assets.first(where: { ($0["name"] as? String) == "\(request)-log.txt" }), let logID = logAsset["id"] as? Int {
                let (ld, lst) = try await github("https://api.github.com/repos/\(privateRepository)/releases/assets/\(logID)", accept: "application/octet-stream")
                if lst == 200 {
                    /* Documents is what Files shows (On My iPad › Nyxian) */
                    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("AppStoreConnect", isDirectory: true)
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let url = folder.appendingPathComponent("Xcode-\(appFolder)-log.txt")
                    try? ld.write(to: url)
                    logURL = url
                }
                _ = try? await github("https://api.github.com/repos/\(privateRepository)/releases/assets/\(logID)", method: "DELETE")
            }
            _ = try? await github("https://api.github.com/repos/\(privateRepository)/releases/assets/\(resultID)", method: "DELETE")
            return Result(ok: result["ok"] as? Bool ?? false,
                          stage: result["stage"] as? String ?? "",
                          xcode: result["xcode"] as? String ?? "",
                          issues: result["issues"] as? [String] ?? [],
                          log: logURL)
        }
        throw ForkASCError.message("No answer from the Mac in 75 minutes: see the App Store (Xcode) workflow on GitHub.")
    }

    /// The build in App Store Connect after an upload: PROCESSING, VALID, INVALID…
    static func processingState(bundleID: String, version: String, build: String) async throws -> String? {
        guard let app = try await ForkASCAPI.app(bundleID: bundleID) else { return nil }
        let v = version.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? version
        let b = build.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? build
        let json = try await ForkASCAPI.request("GET", "/v1/builds?filter[app]=\(app.id)&filter[preReleaseVersion.version]=\(v)&filter[version]=\(b)&fields[builds]=processingState,version")
        return ((json["data"] as? [[String: Any]])?.first?["attributes"] as? [String: Any])?["processingState"] as? String
    }
}

// MARK: - Report screen

final class ForkPreflightViewController: UITableViewController {
    private var findings: [ForkPreflightFinding]
    private let recheck: (() async -> [ForkPreflightFinding])?
    private let action: (title: String, run: () -> Void)?
    private let note: String

    init(title: String, note: String, findings: [ForkPreflightFinding],
         recheck: (() async -> [ForkPreflightFinding])? = nil, action: (title: String, run: () -> Void)? = nil) {
        self.findings = findings
        self.recheck = recheck
        self.action = action
        self.note = note
        super.init(style: .insetGrouped)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError() }

    private var errors: Int { findings.filter { $0.level == .error }.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: self, action: #selector(copyReport))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func copyReport() {
        UIPasteboard.general.string = ([title ?? "Preflight", note] + findings.map { f in
            "[\(["ERROR", "WARNING", "INFO", "OK"][f.level.rawValue])]\(f.code.map { " \($0)" } ?? "") \(f.title)\n  \(f.detail)"
        }).joined(separator: "\n")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { action == nil ? 1 : 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? findings.count : 1 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "\(errors) error\(errors == 1 ? "" : "s") · \(findings.filter { $0.level == .warning }.count) warning(s)" : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { section == 0 ? note : nil }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1, let action {
            let c = UITableViewCell(style: .default, reuseIdentifier: nil)
            c.textLabel?.text = errors > 0 ? "\(action.title) anyway" : action.title
            c.textLabel?.textColor = errors > 0 ? .systemOrange : .systemBlue
            c.imageView?.image = UIImage(systemName: "arrow.up.circle.fill")
            return c
        }
        let f = findings[indexPath.row]
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.textLabel?.text = (f.code.map { "\($0) · " } ?? "") + f.title
        c.textLabel?.numberOfLines = 0
        c.textLabel?.font = .preferredFont(forTextStyle: .subheadline)
        c.detailTextLabel?.text = f.detail + (f.fix.map { "\n→ \($0.label)" } ?? "")
        c.detailTextLabel?.numberOfLines = 0
        c.detailTextLabel?.textColor = .secondaryLabel
        let symbols = ["xmark.octagon.fill", "exclamationmark.triangle.fill", "info.circle.fill", "checkmark.circle.fill"]
        let colors: [UIColor] = [.systemRed, .systemOrange, .systemBlue, .systemGreen]
        c.imageView?.image = UIImage(systemName: symbols[f.level.rawValue])
        c.imageView?.tintColor = colors[f.level.rawValue]
        c.accessoryType = f.fix == nil ? .none : .detailButton
        c.selectionStyle = f.fix == nil ? .none : .default
        return c
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        self.tableView(tableView, didSelectRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1, let action {
            dismiss(animated: true) { action.run() }
            return
        }
        guard let fix = findings[indexPath.row].fix else { return }
        if case .encryptionExempt = fix {
            let ask = UIAlertController(title: "Standard encryption only?",
                                        message: "Choose this only if the app uses no encryption of its own: HTTPS, Apple's frameworks (CryptoKit, Keychain, Data Protection) count as exempt. Nyxian writes ITSAppUsesNonExemptEncryption = NO in Info-extra.plist; it is your declaration to Apple.",
                                        preferredStyle: .alert)
            ask.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            ask.addAction(UIAlertAction(title: "Only standard encryption", style: .default) { _ in self.apply(fix) })
            present(ask, animated: true)
            return
        }
        apply(fix)
    }

    private func apply(_ fix: ForkPreflightFix) {
        do { try ForkPreflight.apply(fix) } catch {
            let a = UIAlertController(title: "Could not fix it", message: error.localizedDescription, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        guard let recheck else { return }
        Task { @MainActor in
            self.findings = await recheck()
            self.tableView.reloadData()
        }
    }
}
