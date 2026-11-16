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
  - 1.0.0 (2026-11-15): ForkManualOrder — the order you give a list by holding
    a row and dragging it (projects, files and folders). getEntries keeps it:
    folders first and by name as before, then the order you set; items added
    later go to the end.
*/

import Foundation

struct FileListEntry: Identifiable {
    enum FileListEntryType {
        case file
        case dir
    }
    
    let id: UUID = UUID()
    let name: String
    let path: String
    let isLink: Bool
    let type: FileListEntryType
    
    static func getEntry(ofPath path: String) -> FileListEntry {
        var entry = FileListEntry(name: "N/A", path: path, isLink: false, type: .file)
        do {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
               let fileType = try FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType {
                let isLink: Bool = (fileType == .typeSymbolicLink)
                entry = FileListEntry(name: URL(fileURLWithPath: path).lastPathComponent,
                                      path: path,
                                      isLink: isLink,
                                      type: isDirectory.boolValue ? .dir : .file)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        return entry
    }
    
    static func getEntries(ofPath path: String) -> [FileListEntry] {
        var entries: [FileListEntry]? = nil
        do {
            let rawEntries: [String] = try FileManager.default.contentsOfDirectory(atPath: path)
            entries = rawEntries.map { FileListEntry.getEntry(ofPath: "\(path)/\($0)") }
            entries!.sort {
                $0.type == $1.type
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.type == .dir
            }
        } catch {
            print(error)
        }
        /* fork: the order set by hand (hold a row and drag it) */
        return ForkManualOrder.ordered(entries ?? [], id: ForkManualOrder.listID(forPath: path)) { $0.name }
    }
    
    static func getEntries(ofPath path: String, perEntryHandler: (FileListEntry) -> Void) {
        for item in FileListEntry.getEntries(ofPath: path) {
            perEntryHandler(item)
        }
    }
}


/// fork: the order you gave a list by holding a row and dragging it. Saved per
/// list (a folder, relative to Nyxian's root, or a section of the projects list).
enum ForkManualOrder {
    private static let key = "fork.manualOrder"

    /// A folder's id, relative to Nyxian's root so it survives a reinstall
    static func listID(forPath path: String) -> String {
        let root = NXBootstrap.shared().rootURL.path
        if path.hasPrefix(root) {
            return "files:" + String(path.dropFirst(root.count))
        }
        return "files:" + path
    }

    static func names(for id: String) -> [String] {
        let all = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        return all[id] ?? []
    }

    static func save(_ names: [String], for id: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        all[id] = names
        UserDefaults.standard.set(all, forKey: key)
    }

    static func forget(_ id: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        all.removeValue(forKey: id)
        UserDefaults.standard.set(all, forKey: key)
    }

    /// The items in the saved order; ones not saved yet keep their order, at the end
    static func ordered<T>(_ items: [T], id: String, name: (T) -> String) -> [T] {
        let saved = names(for: id)
        guard !saved.isEmpty else { return items }
        var rank: [String: Int] = [:]
        for (index, value) in saved.enumerated() where rank[value] == nil {
            rank[value] = index
        }
        let known = items.enumerated()
            .filter { rank[name($0.element)] != nil }
            .sorted { rank[name($0.element)]! < rank[name($1.element)]! }
            .map { $0.element }
        let others = items.filter { rank[name($0)] == nil }
        return known + others
    }
}
