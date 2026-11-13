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
  - 1.0.0 (2026-11-13): two-way sync of app projects with a folder of Swift
    Playgrounds packages (iCloud Drive › Playgrounds). The folder is picked
    once in Files and kept as a bookmark (no iCloud entitlement needed).
    Each app project is paired with one .swiftpm; on each sync the side
    that changed is copied to the other with SwiftPlaygroundsExporter /
    SwiftPlaygroundsImporter. Both changed: the newer one wins and the
    other is first copied to "Playgrounds Sync Backups". Deleting never
    crosses over: a project deleted in Nyxian leaves its package alone (and
    is not imported again), a package deleted in Playgrounds stops the
    project's sync. Files still in the cloud are downloaded first; a
    package that does not finish downloading waits for the next sync.
    Settings: ForkPlaygroundsSyncViewController.
*/

import Foundation
import UIKit
import CryptoKit
import UniformTypeIdentifiers

// MARK: - Engine

final class ForkPlaygroundsSync {
    static let shared = ForkPlaygroundsSync()

    /// Posted on the main queue when a sync created or changed projects.
    static let didChangeProjects = Notification.Name("ForkPlaygroundsSyncDidChangeProjects")
    /// Posted on the main queue when a sync starts or ends (settings screen).
    static let didChangeStatus = Notification.Name("ForkPlaygroundsSyncDidChangeStatus")

    static let backupsFolderName = "Playgrounds Sync Backups"

    enum Mode {
        /// Both ways, new projects and packages included.
        case full
        /// Only Nyxian → Playgrounds (going to the background, a project may be open).
        case pushOnly
    }

    enum SyncError: LocalizedError {
        case noFolder
        case folderUnavailable(String)
        case folderLooksEmpty

        var errorDescription: String? {
            switch self {
            case .noFolder: return "Choose the Playgrounds folder first (iCloud Drive › Playgrounds)."
            case .folderUnavailable(let reason): return "The Playgrounds folder cannot be opened: \(reason). Choose it again."
            case .folderLooksEmpty: return "The Playgrounds folder looks empty, although projects were synced with it. iCloud may still be loading it, so nothing was changed."
            }
        }
    }

    struct Pair: Codable {
        var package: String
        var localSignature: String
        var remoteSignature: String
    }

    struct State: Codable {
        var bookmark: Data?
        var folderName: String?
        var automatic = true
        /// project folder name (its UUID) → package
        var pairs: [String: Pair] = [:]
        /// packages never imported (again): their project was deleted or left out
        var ignoredPackages: Set<String> = []
        /// project folder names left out of the sync
        var excludedProjects: Set<String> = []
        var lastSync: Date?
        var lastSummary: String?

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            bookmark = try c.decodeIfPresent(Data.self, forKey: .bookmark)
            folderName = try c.decodeIfPresent(String.self, forKey: .folderName)
            automatic = try c.decodeIfPresent(Bool.self, forKey: .automatic) ?? true
            pairs = try c.decodeIfPresent([String: Pair].self, forKey: .pairs) ?? [:]
            ignoredPackages = try c.decodeIfPresent(Set<String>.self, forKey: .ignoredPackages) ?? []
            excludedProjects = try c.decodeIfPresent(Set<String>.self, forKey: .excludedProjects) ?? []
            lastSync = try c.decodeIfPresent(Date.self, forKey: .lastSync)
            lastSummary = try c.decodeIfPresent(String.self, forKey: .lastSummary)
        }
    }

    struct Report {
        var exported: [String] = []
        var imported: [String] = []
        var newPackages: [String] = []
        var newProjects: [String] = []
        var conflicts: [String] = []
        var waiting: [String] = []
        var stopped: [String] = []
        var problems: [String] = []

        var changedProjects: Bool { !imported.isEmpty || !newProjects.isEmpty }
        var changedAnything: Bool { !exported.isEmpty || !newPackages.isEmpty || changedProjects }

        var summary: String {
            var lines: [String] = []
            func add(_ title: String, _ names: [String]) {
                guard !names.isEmpty else { return }
                lines.append("\(title): " + names.joined(separator: ", "))
            }
            add("Sent to Playgrounds", exported)
            add("New in Playgrounds", newPackages)
            add("Updated from Playgrounds", imported)
            add("New from Playgrounds", newProjects)
            add("Both changed (newer kept, other one backed up)", conflicts)
            add("Still downloading from iCloud (next sync)", waiting)
            add("No longer synced (deleted on one side)", stopped)
            lines.append(contentsOf: problems.map { "⚠︎ " + $0 })
            return lines.isEmpty ? "Everything was already in sync." : lines.joined(separator: "\n")
        }
    }

    private struct Signature {
        let hash: String
        let newest: Date
    }

    private static let stateKey = "fork.playgroundsSync.state"
    private let queue = DispatchQueue(label: "fork.playgroundsSync", qos: .utility)
    private(set) var isRunning = false
    private var lastAutomaticRun = Date.distantPast

    // MARK: state

    var state: State {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
                  let state = try? JSONDecoder().decode(State.self, from: data) else { return State() }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.stateKey)
            }
        }
    }

    var hasFolder: Bool { state.bookmark != nil }

    static var backupsURL: URL {
        NXBootstrap.shared().rootURL.appendingPathComponent(backupsFolderName)
    }

    /// Keeps a folder picked in Files. A different folder starts the pairing over.
    func setFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        var state = self.state
        if state.folderName != url.lastPathComponent || state.bookmark == nil {
            state.pairs = [:]
            state.ignoredPackages = []
        }
        state.bookmark = bookmark
        state.folderName = url.lastPathComponent
        self.state = state
    }

    func forgetFolder() {
        var state = self.state
        state.bookmark = nil
        state.folderName = nil
        state.pairs = [:]
        state.ignoredPackages = []
        state.lastSummary = nil
        self.state = state
    }

    func setExcluded(_ excluded: Bool, projectKey: String, packageName: String) {
        var state = self.state
        if excluded {
            state.excludedProjects.insert(projectKey)
            /* its package must not come back as a second project */
            if let pair = state.pairs.removeValue(forKey: projectKey) {
                state.ignoredPackages.insert(pair.package)
            }
        } else {
            state.excludedProjects.remove(projectKey)
            /* lets it pair again with the package of its name */
            state.ignoredPackages.remove(packageName)
        }
        self.state = state
    }

    func allowImportAgain(_ package: String) {
        var state = self.state
        state.ignoredPackages.remove(package)
        self.state = state
    }

    // MARK: triggers (main queue)

    /// Opening Nyxian, coming back to it or to the projects list.
    func syncAutomatically(from presenter: UIViewController?) {
        guard state.automatic, hasFolder, !isRunning,
              Date().timeIntervalSince(lastAutomaticRun) > 10 else { return }
        lastAutomaticRun = Date()
        sync(mode: .full) { report, error in
            if let error {
                NXAlertDiagnosticPresenter.notifyUser(with: .warning, withMessage: "Playgrounds sync: " + error.localizedDescription, withDelay: 0.0)
            } else if let report, !report.conflicts.isEmpty || !report.problems.isEmpty {
                NXAlertDiagnosticPresenter.notifyUser(with: .warning, withMessage: "Playgrounds sync:\n" + report.summary, withDelay: 0.0)
            } else if let report, report.changedAnything {
                NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Playgrounds sync:\n" + report.summary, withDelay: 0.0)
            }
        }
    }

    /// Leaving Nyxian: send what changed here before iOS suspends it.
    func pushInBackground() {
        guard state.automatic, hasFolder, !isRunning else { return }
        var task = UIBackgroundTaskIdentifier.invalid
        task = UIApplication.shared.beginBackgroundTask(withName: "Playgrounds sync") {
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
        sync(mode: .pushOnly) { _, _ in
            if task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
        }
    }

    /// Runs one sync; `completion` is called on the main queue.
    func sync(mode: Mode, completion: ((Report?, Error?) -> Void)? = nil) {
        guard !isRunning else {
            completion?(nil, nil)
            return
        }
        isRunning = true
        NotificationCenter.default.post(name: Self.didChangeStatus, object: nil)
        let snapshot = state
        queue.async {
            var working = snapshot
            var report = Report()
            var failure: Error?
            do {
                try self.run(mode: mode, state: &working, report: &report)
            } catch {
                failure = error
            }
            DispatchQueue.main.async {
                var fresh = self.state
                /* only what a sync owns; the folder and the switch may have been changed meanwhile */
                if fresh.bookmark == snapshot.bookmark {
                    fresh.pairs = working.pairs
                    fresh.ignoredPackages = working.ignoredPackages
                    fresh.excludedProjects = working.excludedProjects
                    if working.bookmark != snapshot.bookmark { fresh.bookmark = working.bookmark }
                }
                if failure == nil {
                    fresh.lastSync = Date()
                    fresh.lastSummary = report.summary
                } else {
                    fresh.lastSummary = failure?.localizedDescription
                }
                self.state = fresh
                self.isRunning = false
                if report.changedProjects {
                    NotificationCenter.default.post(name: Self.didChangeProjects, object: nil)
                }
                NotificationCenter.default.post(name: Self.didChangeStatus, object: nil)
                completion?(failure == nil ? report : nil, failure)
            }
        }
    }

    // MARK: the sync itself (background queue)

    private func run(mode: Mode, state: inout State, report: inout Report) throws {
        guard let bookmark = state.bookmark else { throw SyncError.noFolder }
        var stale = false
        let folder: URL
        do {
            folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        } catch {
            throw SyncError.folderUnavailable(error.localizedDescription)
        }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        if stale, let renewed = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            state.bookmark = renewed
        }

        let fm = FileManager.default

        /* the folder as iCloud knows it now */
        var listing: [URL] = []
        var listingError: Error?
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: folder, options: .immediatelyAvailableMetadataOnly, error: &coordinationError) { url in
            do {
                listing = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            } catch {
                listingError = error
            }
        }
        if let error = listingError ?? coordinationError {
            throw SyncError.folderUnavailable(error.localizedDescription)
        }
        let packages = Set(listing.filter { $0.pathExtension.lowercased() == "swiftpm" }.map { $0.lastPathComponent })
        if packages.isEmpty && !state.pairs.isEmpty {
            throw SyncError.folderLooksEmpty
        }

        let projectsURL = NXBootstrap.shared().rootURL.appendingPathComponent("Projects")
        let projects: [NXProject] = onMain {
            let raw = NXProject.listProjects(at: projectsURL) as! [String: [NXProject]]
            return raw.values.flatMap { $0 }
        }
        var byKey: [String: NXProject] = [:]
        for project in projects { byKey[Self.key(of: project)] = project }

        /* deletions never cross over */
        for (key, pair) in state.pairs {
            if byKey[key] == nil {
                state.pairs.removeValue(forKey: key)
                state.ignoredPackages.insert(pair.package)
                report.stopped.append(pair.package.replacingOccurrences(of: ".swiftpm", with: "") + " (deleted in Nyxian)")
            } else if !packages.contains(pair.package) {
                state.pairs.removeValue(forKey: key)
                state.excludedProjects.insert(key)
                report.stopped.append(Self.name(of: byKey[key]!) + " (deleted in Playgrounds)")
            }
        }

        let eligible = projects
            .filter { Self.isEligible($0) && !state.excludedProjects.contains(Self.key(of: $0)) }
            .sorted { Self.name(of: $0).localizedCaseInsensitiveCompare(Self.name(of: $1)) == .orderedAscending }

        /* first time: a project and a package with the same name belong together */
        var pairedPackages = Set(state.pairs.values.map { $0.package })
        for project in eligible where state.pairs[Self.key(of: project)] == nil {
            let expected = Self.packageName(of: project)
            if packages.contains(expected), !pairedPackages.contains(expected), !state.ignoredPackages.contains(expected) {
                /* empty signatures: both sides count as changed, so the newer one wins (with a backup) */
                state.pairs[Self.key(of: project)] = Pair(package: expected, localSignature: "", remoteSignature: "")
                pairedPackages.insert(expected)
            }
        }

        var usedNames = packages

        for project in eligible {
            let key = Self.key(of: project)
            let name = Self.name(of: project)

            guard let pair = state.pairs[key] else {
                /* a project Playgrounds does not have yet */
                var packageName = Self.packageName(of: project)
                var counter = 2
                let base = packageName.replacingOccurrences(of: ".swiftpm", with: "")
                while usedNames.contains(packageName) || state.ignoredPackages.contains(packageName) {
                    packageName = "\(base) \(counter).swiftpm"
                    counter += 1
                }
                do {
                    let local = signature(ofProject: project)
                    let remote = try exportProject(project, to: folder.appendingPathComponent(packageName), report: &report)
                    state.pairs[key] = Pair(package: packageName, localSignature: local.hash, remoteSignature: remote.hash)
                    usedNames.insert(packageName)
                    report.newPackages.append(name)
                } catch {
                    /* e.g. no Swift files yet: turned off, so it does not warn on every sync */
                    state.excludedProjects.insert(key)
                    report.problems.append("\(name): \(error.localizedDescription) Its sync was turned off; turn it back on in Playgrounds Sync when it is ready.")
                }
                continue
            }

            let packageURL = folder.appendingPathComponent(pair.package)
            let local = signature(ofProject: project)
            let remote = signature(ofPackage: packageURL)
            let localChanged = local.hash != pair.localSignature
            let remoteChanged = remote.hash != pair.remoteSignature

            do {
                switch (localChanged, remoteChanged) {
                case (false, false):
                    continue
                case (true, false):
                    let written = try exportProject(project, to: packageURL, report: &report)
                    state.pairs[key] = Pair(package: pair.package, localSignature: local.hash, remoteSignature: written.hash)
                    report.exported.append(name)
                case (false, true):
                    guard mode == .full else { continue }
                    if let updated = try importPackage(packageURL, into: project, backup: nil, report: &report) {
                        state.pairs[key] = Pair(package: pair.package, localSignature: updated.local, remoteSignature: updated.remote)
                        report.imported.append(name)
                    }
                case (true, true):
                    guard mode == .full else { continue }
                    if local.newest >= remote.newest {
                        /* Nyxian is newer: keep a copy of the Playgrounds version, then replace it */
                        guard let copy = try materialize(packageURL) else {
                            report.waiting.append(name)
                            continue
                        }
                        try backupPackage(copy, named: pair.package)
                        try? fm.removeItem(at: copy.deletingLastPathComponent())
                        let written = try exportProject(project, to: packageURL, report: &report)
                        state.pairs[key] = Pair(package: pair.package, localSignature: local.hash, remoteSignature: written.hash)
                        report.exported.append(name)
                    } else {
                        /* Playgrounds is newer: keep a copy of the Nyxian project, then update it */
                        guard let updated = try importPackage(packageURL, into: project, backup: name, report: &report) else { continue }
                        state.pairs[key] = Pair(package: pair.package, localSignature: updated.local, remoteSignature: updated.remote)
                        report.imported.append(name)
                    }
                    report.conflicts.append(name)
                }
            } catch {
                report.problems.append("\(name): \(error.localizedDescription)")
            }
        }

        /* packages Nyxian does not have yet */
        guard mode == .full else { return }
        pairedPackages = Set(state.pairs.values.map { $0.package })
        for package in packages.sorted() where !pairedPackages.contains(package) && !state.ignoredPackages.contains(package) {
            let packageURL = folder.appendingPathComponent(package)
            let display = package.replacingOccurrences(of: ".swiftpm", with: "")
            do {
                guard let copy = try materialize(packageURL) else {
                    report.waiting.append(display)
                    continue
                }
                defer { try? fm.removeItem(at: copy.deletingLastPathComponent()) }
                let remote = signature(ofPackage: packageURL)
                let result = try onMain {
                    try SwiftPlaygroundsImporter.importPackage(at: copy, intoProjectsAt: projectsURL)
                }
                let local = signature(ofProject: result.project)
                state.pairs[Self.key(of: result.project)] = Pair(package: package, localSignature: local.hash, remoteSignature: remote.hash)
                report.newProjects.append(Self.name(of: result.project))
            } catch {
                /* not an app package (or broken): leave it alone from now on */
                state.ignoredPackages.insert(package)
                report.problems.append("\(display): \(error.localizedDescription) It will not be tried again (Settings › Playgrounds Sync to retry).")
            }
        }
    }

    // MARK: one direction at a time

    /// Writes the project into `destination` (a .swiftpm in the Playgrounds folder) and returns the package's new signature.
    private func exportProject(_ project: NXProject, to destination: URL, report: inout Report) throws -> Signature {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("PlaygroundsSync-\(UUID().uuidString)")
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        let result = try onMain { try SwiftPlaygroundsExporter.export(project, into: temp) }
        let built = result.packageURL

        var writeError: Error?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        if fm.fileExists(atPath: destination.path) {
            /* in place: Playgrounds' own hidden .swiftpm folder (its workspace state) stays */
            coordinator.coordinate(writingItemAt: destination, options: .forMerging, error: &coordinationError) { url in
                do {
                    for item in try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        try fm.removeItem(at: item)
                    }
                    for item in try fm.contentsOfDirectory(at: built, includingPropertiesForKeys: nil, options: []) {
                        try fm.copyItem(at: item, to: url.appendingPathComponent(item.lastPathComponent))
                    }
                } catch {
                    writeError = error
                }
            }
        } else {
            coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { url in
                do {
                    try fm.copyItem(at: built, to: url)
                } catch {
                    writeError = error
                }
            }
        }
        if let error = writeError ?? coordinationError { throw error }
        return signature(ofPackage: destination)
    }

    /// Brings the package into the project. nil when iCloud has not finished downloading it.
    private func importPackage(_ packageURL: URL, into project: NXProject, backup: String?, report: inout Report) throws -> (local: String, remote: String)? {
        let fm = FileManager.default
        guard let copy = try materialize(packageURL) else {
            report.waiting.append(Self.name(of: project))
            return nil
        }
        defer { try? fm.removeItem(at: copy.deletingLastPathComponent()) }
        if let backup {
            try backupProject(project, named: backup)
        }
        let remote = signature(ofPackage: packageURL)
        let projectsURL = NXBootstrap.shared().rootURL.appendingPathComponent("Projects")
        let result = try onMain {
            try SwiftPlaygroundsImporter.importPackage(at: copy, intoProjectsAt: projectsURL, updating: project)
        }
        return (signature(ofProject: result.project).hash, remote.hash)
    }

    /// A local copy of the package with every file downloaded; nil if iCloud did not finish within a minute.
    private func materialize(_ packageURL: URL) throws -> URL? {
        let fm = FileManager.default
        let files = packageFiles(packageURL)

        /* ask iCloud for what is not on the device yet, then wait a little */
        var pending = files.filter { !isDownloaded($0.url) }
        for file in pending { try? fm.startDownloadingUbiquitousItem(at: file.url) }
        let deadline = Date().addingTimeInterval(60)
        while !pending.isEmpty && Date() < deadline {
            Thread.sleep(forTimeInterval: 1)
            pending = pending.filter { !isDownloaded($0.url) }
        }
        if !pending.isEmpty { return nil }

        let temp = fm.temporaryDirectory.appendingPathComponent("PlaygroundsSync-\(UUID().uuidString)")
        let copy = temp.appendingPathComponent(packageURL.lastPathComponent)
        try fm.createDirectory(at: copy, withIntermediateDirectories: true)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        for file in files {
            var copyError: Error?
            var coordinationError: NSError?
            let destination = copy.appendingPathComponent(file.relative)
            coordinator.coordinate(readingItemAt: file.url, options: [], error: &coordinationError) { url in
                do {
                    try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: url, to: destination)
                } catch {
                    copyError = error
                }
            }
            if let error = copyError ?? coordinationError {
                try? fm.removeItem(at: temp)
                throw error
            }
        }
        return copy
    }

    private func isDownloaded(_ url: URL) -> Bool {
        if !FileManager.default.fileExists(atPath: url.path) { return false }
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true,
              let status = values.ubiquitousItemDownloadingStatus else { return true }
        return status == .current
    }

    // MARK: backups

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }

    private func backupProject(_ project: NXProject, named name: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.backupsURL, withIntermediateDirectories: true)
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        try fm.copyItem(at: project.url, to: Self.backupsURL.appendingPathComponent("\(safe) (Nyxian) \(Self.stamp())"))
    }

    private func backupPackage(_ copy: URL, named package: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.backupsURL, withIntermediateDirectories: true)
        let base = package.replacingOccurrences(of: ".swiftpm", with: "")
        try fm.copyItem(at: copy, to: Self.backupsURL.appendingPathComponent("\(base) (Playgrounds) \(Self.stamp()).swiftpm"))
    }

    // MARK: what changed

    /// Files of the project the export reads (hidden files and Git left out): path, size and date.
    private func signature(ofProject project: NXProject) -> Signature {
        let root = project.url as URL
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        var lines: [String] = []
        var newest = Date.distantPast
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: keys), values.isDirectory != true else { continue }
                let date = values.contentModificationDate ?? .distantPast
                if date > newest { newest = date }
                lines.append("\(ProjectFileIndex.relativePath(url, root: root))|\(values.fileSize ?? 0)|\(Int(date.timeIntervalSince1970))")
            }
        }
        return Signature(hash: Self.hash(lines), newest: newest)
    }

    /// Files of the package (not Playgrounds' hidden .swiftpm folder): path and date. Files still in
    /// iCloud have no size yet, so only the date counts.
    private func signature(ofPackage packageURL: URL) -> Signature {
        var lines: [String] = []
        var newest = Date.distantPast
        for file in packageFiles(packageURL) {
            let date = file.date
            if date > newest { newest = date }
            lines.append("\(file.relative)|\(Int(date.timeIntervalSince1970))")
        }
        return Signature(hash: Self.hash(lines), newest: newest)
    }

    private struct PackageFile {
        let url: URL        /// the real file (where an old-style ".name.icloud" placeholder points)
        let relative: String
        let date: Date
    }

    private func packageFiles(_ packageURL: URL) -> [PackageFile] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        var result: [PackageFile] = []
        guard let enumerator = FileManager.default.enumerator(at: packageURL, includingPropertiesForKeys: Array(keys), options: []) else { return [] }
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: keys))?.isDirectory == true
            if isDirectory {
                if name.hasPrefix(".") || name == ".build" { enumerator.skipDescendants() }
                continue
            }
            var real = url
            if name.hasPrefix(".") {
                /* only iCloud's placeholders of files not downloaded yet */
                guard name.hasSuffix(".icloud") else { continue }
                let realName = String(name.dropFirst().dropLast(".icloud".count))
                guard !realName.isEmpty else { continue }
                real = url.deletingLastPathComponent().appendingPathComponent(realName)
            }
            let date = (try? url.resourceValues(forKeys: keys))?.contentModificationDate ?? .distantPast
            result.append(PackageFile(url: real, relative: ProjectFileIndex.relativePath(real, root: packageURL), date: date))
        }
        return result.sorted { $0.relative < $1.relative }
    }

    private static func hash(_ lines: [String]) -> String {
        let text = lines.sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: projects

    static func key(of project: NXProject) -> String {
        (project.url as URL).lastPathComponent
    }

    static func name(of project: NXProject) -> String {
        project.projectConfig.displayName ?? project.projectConfig.executable ?? "App"
    }

    /// Swift app projects (Python, Java and Node.js projects have no .swiftpm form).
    static func isEligible(_ project: NXProject) -> Bool {
        project.projectConfig.schemeKind == .app && ForkPython.scriptKind(of: project) == nil
    }

    /// The package name SwiftPlaygroundsExporter gives the project.
    static func packageName(of project: NXProject) -> String {
        var base = Self.name(of: project).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        if base.isEmpty { base = "App" }
        return "\(base).swiftpm"
    }

    private func onMain<T>(_ work: () throws -> T) rethrows -> T {
        if Thread.isMainThread { return try work() }
        return try DispatchQueue.main.sync(execute: work)
    }
}

// MARK: - Settings screen

final class ForkPlaygroundsSyncViewController: UITableViewController, UIDocumentPickerDelegate {
    private enum Section: Int, CaseIterable {
        case folder, sync, projects, ignored, more
    }

    private var projects: [NXProject] = []
    private var ignored: [String] = []
    private let sync = ForkPlaygroundsSync.shared

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Playgrounds Sync"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: ForkPlaygroundsSync.didChangeStatus, object: nil)
        reload()
    }

    @objc private func reload() {
        let raw = NXProject.listProjects(at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects")) as! [String: [NXProject]]
        projects = raw.values.flatMap { $0 }
            .filter { ForkPlaygroundsSync.isEligible($0) }
            .sorted { ForkPlaygroundsSync.name(of: $0).localizedCaseInsensitiveCompare(ForkPlaygroundsSync.name(of: $1)) == .orderedAscending }
        ignored = sync.state.ignoredPackages.sorted()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .folder: return 1
        case .sync: return 3
        case .projects: return sync.hasFolder ? projects.count : 0
        case .ignored: return sync.hasFolder ? ignored.count : 0
        case .more: return sync.hasFolder ? 2 : 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .folder: return "Swift Playgrounds folder"
        case .sync: return "Sync"
        case .projects: return sync.hasFolder && !projects.isEmpty ? "App projects" : nil
        case .ignored: return sync.hasFolder && !ignored.isEmpty ? "Packages not imported" : nil
        case .more: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .folder:
            return "Choose iCloud Drive › Playgrounds in Files. Every Swift app project here is kept in step with a .swiftpm there, so Swift Playgrounds on your other devices sees it, and its changes come back here."
        case .sync:
            let state = sync.state
            var text = "Automatic: when Nyxian opens, when you come back to it or to the projects list, and (Nyxian → Playgrounds only) when you leave it. When both sides changed, the newer one is kept and the other one is first copied to \(ForkPlaygroundsSync.backupsFolderName)."
            if let summary = state.lastSummary { text += "\n\nLast sync:\n" + summary }
            return text
        case .projects:
            return sync.hasFolder && !projects.isEmpty ? "Deleting never crosses over: a project deleted here leaves its package in Playgrounds, and a package deleted there turns its project's switch off." : nil
        case .ignored:
            return sync.hasFolder && !ignored.isEmpty ? "Their project was deleted or left out, or they could not be imported. Tap one to import it again on the next sync." : nil
        case .more:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let state = sync.state
        let busy = sync.isRunning
        switch Section(rawValue: indexPath.section)! {
        case .folder:
            cell.textLabel?.text = "Folder"
            cell.detailTextLabel?.text = state.folderName ?? "Choose…"
            cell.accessoryType = .disclosureIndicator
        case .sync:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Automatic"
                let toggle = UISwitch()
                toggle.isOn = state.automatic
                toggle.addTarget(self, action: #selector(toggleAutomatic(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                cell.selectionStyle = .none
            case 1:
                cell.textLabel?.text = busy ? "Syncing…" : "Sync Now"
                let enabled: Bool = !busy && sync.hasFolder
                cell.textLabel?.textColor = enabled ? (tableView.tintColor ?? UIColor.systemBlue) : UIColor.secondaryLabel
                if busy {
                    let spinner = UIActivityIndicatorView(style: .medium)
                    spinner.startAnimating()
                    cell.accessoryView = spinner
                }
            default:
                cell.textLabel?.text = "Last sync"
                if let date = state.lastSync {
                    let formatter = RelativeDateTimeFormatter()
                    cell.detailTextLabel?.text = formatter.localizedString(for: date, relativeTo: Date())
                } else {
                    cell.detailTextLabel?.text = "Never"
                }
                cell.selectionStyle = .none
            }
        case .projects:
            let project = projects[indexPath.row]
            let key = ForkPlaygroundsSync.key(of: project)
            cell.textLabel?.text = ForkPlaygroundsSync.name(of: project)
            cell.detailTextLabel?.text = state.pairs[key]?.package ?? (state.excludedProjects.contains(key) ? "Off" : "Next sync")
            let toggle = UISwitch()
            toggle.isOn = !state.excludedProjects.contains(key)
            toggle.isEnabled = !busy
            toggle.tag = indexPath.row
            toggle.addTarget(self, action: #selector(toggleProject(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        case .ignored:
            cell.textLabel?.text = ignored[indexPath.row].replacingOccurrences(of: ".swiftpm", with: "")
            cell.detailTextLabel?.text = "Import again"
            cell.textLabel?.textColor = busy ? .secondaryLabel : .label
        case .more:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Show Backups in Files"
                cell.textLabel?.textColor = tableView.tintColor
            } else {
                cell.textLabel?.text = "Stop Syncing"
                cell.textLabel?.textColor = .systemRed
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .folder:
            guard !sync.isRunning else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true)
        case .sync:
            guard indexPath.row == 1, sync.hasFolder, !sync.isRunning else { return }
            syncNow()
        case .projects:
            break
        case .ignored:
            guard !sync.isRunning else { return }
            sync.allowImportAgain(ignored[indexPath.row])
            reload()
        case .more:
            if indexPath.row == 0 {
                try? FileManager.default.createDirectory(at: ForkPlaygroundsSync.backupsURL, withIntermediateDirectories: true)
                ForkFilesApp.open(ForkPlaygroundsSync.backupsURL, from: self)
            } else {
                guard !sync.isRunning else { return }
                let alert = UIAlertController(title: "Stop Syncing?", message: "Nyxian forgets the folder and the pairing. Nothing is deleted on either side.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Stop Syncing", style: .destructive) { [weak self] _ in
                    self?.sync.forgetFolder()
                    self?.reload()
                })
                present(alert, animated: true)
            }
        }
    }

    private func syncNow() {
        sync.sync(mode: .full) { [weak self] report, error in
            guard let self else { return }
            self.reload()
            if let error {
                self.forkGitHubAlert("Playgrounds Sync", error.localizedDescription)
            } else if let report {
                self.forkGitHubAlert("Playgrounds Sync", report.summary)
            }
        }
        reload()
    }

    @objc private func toggleAutomatic(_ sender: UISwitch) {
        var state = sync.state
        state.automatic = sender.isOn
        sync.state = state
    }

    @objc private func toggleProject(_ sender: UISwitch) {
        guard projects.indices.contains(sender.tag), !sync.isRunning else { return }
        let project = projects[sender.tag]
        sync.setExcluded(!sender.isOn,
                         projectKey: ForkPlaygroundsSync.key(of: project),
                         packageName: ForkPlaygroundsSync.packageName(of: project))
        reload()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            try sync.setFolder(url)
            reload()
            syncNow()
        } catch {
            forkGitHubAlert("Playgrounds Sync", "That folder cannot be kept: \(error.localizedDescription)")
        }
    }
}
