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
 Fork doctoralvarez/Nyxian — version 1.12.0
 Changelog:
  - 1.12.0 (2026-11-11): pull to refresh is instant in every folder and
    subfolder (no wait or fade-in); a list also reads its folder again when
    it shows again (back from a subfolder or the editor) and when Nyxian
    comes back to the front.
  - 1.11.0 (2026-11-11): swipe a file or folder to the left › Delete (asks
    first); swipe to the right › Export (share sheet) and Edit (a file opens
    in the code editor, a folder is renamed).
  - 1.10.1 (2026-11-11): pull to refresh works in every folder, also short
    ones (the list always bounces); the refresh control is set in viewDidLoad.
  - 1.10.0 (2026-11-11): selection bar (also after a two-finger slide) has
    icons for Delete, Copy, Cut (move on Paste), Duplicate, Compress (.zip
    in this folder) and Share/Export, plus Select All.
  - 1.9.0 (2026-11-10): .jar files: tap or hold › Run (java -jar, miniJVM),
    Run in Browser (CheerpJ), Open Contents (NAME.jar.contents, to edit);
    hold that folder › Pack into NAME.jar (the old one stays as .bak).
  - 1.8.0 (2026-11-09): .ipynb notebooks open in the notebook viewer
    (2026-11-10). The profiler's graphs have "All Processes".
    Select several files and folders by sliding two
    fingers down the list (as in Files or Mail), which starts selection mode
    by itself; selection mode shows iOS's selection circles; on iPad, Shift-
    and ⌘-click work too.
  - 1.7.1 (2026-11-09): a template named like a system type (ObservableObject,
    View, Codable…) gets a suffix (ObservableObjectModel): the type inherited
    from itself and the compiler, which runs inside Nyxian, crashed.
  - 1.7.0 (2026-11-08): New › From Template (SwiftUI View, List and Detail,
    Observable Model, Codable Model, Python Script / Notebook / Module).
  - 1.6.1 (2026-11-08): the debugger is off by default (Settings ›
    Customization › Debugger); it attaches only when it is on.
  - 1.6.0 (2026-11-08): pictures, PDFs and media open in a Quick Look preview
    (ForkQuickLook) instead of the text editor.
  - 1.5.1 (2026-11-08): "Run" in a Python project runs its script (no build).
  - 1.5.0 (2026-11-07): debugger UI — breakpoints per project
    (ForkBreakpoints), the session that attaches NXForkDebugger to every run
    (ForkDebugSession), Pause / Continue next to the profiler and the stop
    sheet with every thread's backtrace (ForkDebugControlView,
    ForkStopViewController).
  - 1.4.0 (2026-11-07): ⋯ > Add Metal Helper writes MetalLibrary+App.swift
    (MTLDevice.makeAppLibrary(): Xcode's default library, or the .metal
    sources Nyxian bundles, compiled on the device). Profiler pill over the console (CPU, memory,
    threads of the running app, tap for the last minute as graphs;
    ForkProfilerView). Export opens an export assistant first (version and
    build number, icon / bundle identifier / missing usage-description checks
    with one-tap fixes), then builds the .ipa (ForkExportAssistant).
  - 1.4.0 (2026-11-07): GitHub branches (list, create, switch), history of
    the branch with each commit's changes, and Discard Changes (swipe a file
    in Review Changes). GitHubBranchesViewController, GitHubHistoryViewController.
  - 1.3.1 (2026-11-07): build fix — NXConsoleView() is failable.
  - 1.3.0 (2026-11-07): "Commit and Push…" first shows the changes since the
    last sync (added / modified / deleted, +/− lines) with a line diff per
    file (GitHubChangesViewController, LineDiff). iPhone: the program's
    print() output goes to a Console window (⋯ > Console), opened next to
    the app in the window switcher — no new edge gestures (ForkPhoneConsole).
  - 1.2.0 (2026-11-07): GitHub sync through the REST API (⋯ > GitHub):
    commit and push, pull, repository link and Keychain token
    (GitHubSync, GitHubLink, GitHubTokenStore at the end of this file).
  - 1.1.1 (2026-11-07): fix build — project.url is an implicitly unwrapped
    optional from Objective-C; store it as URL in search and quick open.
  - 1.1.0 (2026-11-07): "Search in Project" and "Open Quickly" (⋯ menu, and
    ⇧⌘F / ⇧⌘O on iPad); ProjectSearchViewController, QuickOpenViewController
    and ProjectFileIndex live at the end of this file.
  - 1.0.0 (2026-11-07): "Select All" / "Deselect All" button in the
    selection toolbar (next to Delete); checkmarks now survive cell reuse
    while scrolling in selection mode.
*/

import UIKit
import UniformTypeIdentifiers
import CryptoKit
import Security

class FileListViewController: NXUITableViewController, UIDocumentPickerDelegate {
    let project: NXProject?
    let path: String
    var entries: [FileListEntry]
    let isSublink: Bool
    let isReadOnly: Bool
    var isSelecting: Bool = false
    var selectedPaths: Set<String> = []
    /* fork: toolbar button that toggles between "Select All" and "Deselect All" */
    private var selectAllButton: UIBarButtonItem?
    
    var observation: NSKeyValueObservation?

    init(isSublink: Bool = false,
         project: NXProject?,
         path: String? = nil,
         isReadOnly: Bool = false) {
        self.isReadOnly = isReadOnly
        self.project = project
        
        if let project = project {
            NXUser.shared().projectName = project.projectConfig.displayName
            self.path = path ?? project.url.path
        } else {
            self.path = path ?? ""
        }
        
        self.entries = FileListEntry.getEntries(ofPath: self.path)
        self.isSublink = isSublink
        super.init(style: .insetGrouped)
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(performRefresh), for: .valueChanged)
    }
    
    init(isSublink: Bool = false,
         path: String,
         isReadOnly: Bool = false)
    {
        self.project = nil
        self.path = path
        self.entries = FileListEntry.getEntries(ofPath: self.path)
        self.isSublink = isSublink
        self.isReadOnly = isReadOnly
        super.init(style: .insetGrouped)
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(performRefresh), for: .valueChanged)
    }
    
    /// fork: the list again after a jar was opened or packed
    func forkReloadEntries() {
        self.entries = FileListEntry.getEntries(ofPath: self.path)
        self.tableView.reloadData()
    }

    @objc func performRefresh() {
        /* fork: instant — the folder is read again and shown right away (no
           half-second wait and no fade-in animation) */
        if !self.isSublink, let project = self.project {
            if project.reload() {
                self.title = project.projectConfig.displayName
            }
        }
        forkReloadEntries()
        self.refreshControl?.endRefreshing()
    }

    /// fork: coming back to this list (from a subfolder, the editor, another
    /// app…) shows what is in the folder now
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isSelecting { forkReloadEntries() }
        /* (the base class drops every observer when the list disappears) */
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(forkAppBecameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func forkAppBecameActive() {
        if !isSelecting, viewIfLoaded?.window != nil { forkReloadEntries() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
        /* fork: needed before a two-finger slide can start selecting */
        self.tableView.allowsMultipleSelectionDuringEditing = !self.isReadOnly
        /* fork: pull down to read the folder again, also when it has few files
           (a list shorter than the screen did not bounce, so it could not be pulled) */
        self.tableView.alwaysBounceVertical = true
        if self.refreshControl == nil, !self.isSelecting {
            self.refreshControl = UIRefreshControl()
            self.refreshControl?.addTarget(self, action: #selector(performRefresh), for: .valueChanged)
        }

        if let project = self.project {
            if !self.isSublink {
                observation = project.observe(\.projectConfig.dictionary, options: [.new, .old]) { [weak self] project, change in
                    DispatchQueue.main.async {
                        self?.title = project.projectConfig.displayName
                    }
                }
                self.title = project.projectConfig.displayName
            } else {
                self.title = URL(fileURLWithPath: self.path).lastPathComponent
            }
        } else {
            self.title = URL(fileURLWithPath: self.path).lastPathComponent
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad, !self.isSublink {
            self.navigationItem.setLeftBarButton(UIBarButtonItem(primaryAction: UIAction(title: "Close") { [weak self] _ in
                guard let self = self else { return }
                UserDefaults.standard.set(nil, forKey: "LDELastProjectSelected")
                self.dismiss(animated: true)
            }), animated: false)
        }
        
        if !self.isReadOnly {
            if #available(iOS 26.0, *) {
                self.navigationItem.setRightBarButton(UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle.fill"), primaryAction: nil, menu: generateMenu()), animated: false)
            } else {
                self.navigationItem.setRightBarButton(UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), primaryAction: nil, menu: generateMenu()), animated: false)
            }
        }
    }

    @objc func toggleSelectionMode() {
        isSelecting.toggle()
        selectedPaths.removeAll()

        tableView.allowsMultipleSelection = isSelecting
        /* fork: iOS's selection circles; also the mode the two-finger slide uses */
        tableView.allowsMultipleSelectionDuringEditing = true
        if tableView.isEditing != isSelecting {
            tableView.setEditing(isSelecting, animated: true)
        }

        navigationItem.rightBarButtonItem?.isEnabled = !isSelecting

        if isSelecting {
            /* fork: the usual actions for what is selected — delete, copy, cut (move),
               duplicate, compress (.zip here) and share */
            let deleteButton = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteSelected))
            deleteButton.tintColor = .systemRed
            deleteButton.accessibilityLabel = "Delete"
            let copyButton = UIBarButtonItem(image: UIImage(systemName: "doc.on.doc"), style: .plain, target: self, action: #selector(copySelected))
            copyButton.accessibilityLabel = "Copy"
            let cutButton = UIBarButtonItem(image: UIImage(systemName: "scissors"), style: .plain, target: self, action: #selector(forkCutSelected))
            cutButton.accessibilityLabel = "Move (paste it in another folder)"
            let duplicateButton = UIBarButtonItem(image: UIImage(systemName: "plus.square.on.square"), style: .plain, target: self, action: #selector(forkDuplicateSelected))
            duplicateButton.accessibilityLabel = "Duplicate"
            let zipButton = UIBarButtonItem(image: UIImage(systemName: "archivebox"), style: .plain, target: self, action: #selector(forkCompressSelected))
            zipButton.accessibilityLabel = "Compress"
            let shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareSelected))
            shareButton.accessibilityLabel = "Share / Export"
            let selectAllButton = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(toggleSelectAll))
            self.selectAllButton = selectAllButton
            self.updateSelectAllButton()
            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            setToolbarItems([deleteButton, spacer, copyButton, spacer, cutButton, spacer, duplicateButton, spacer, zipButton, spacer, shareButton, spacer, selectAllButton], animated: true)
            navigationController?.setToolbarHidden(false, animated: true)
            tabBarController?.tabBar.isHidden = true
            
            let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(toggleSelectionMode))
            navigationItem.setLeftBarButton(doneButton, animated: true)
            self.refreshControl = nil
        } else {
            self.selectAllButton = nil
            setToolbarItems(nil, animated: true)
            navigationController?.setToolbarHidden(true, animated: true)
            tabBarController?.tabBar.isHidden = false
            
            if UIDevice.current.userInterfaceIdiom == .pad,
               !self.isSublink {
                self.navigationItem.setLeftBarButton(UIBarButtonItem(primaryAction: UIAction(title: "Close") { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.set(nil, forKey: "LDELastProjectSelected")
                    self.dismiss(animated: true)
                }), animated: true)
            } else {
                navigationItem.setLeftBarButton(nil, animated: true)
            }
            
            self.refreshControl = UIRefreshControl()
            self.refreshControl?.addTarget(self, action: #selector(performRefresh), for: .valueChanged)
            tableView.reloadData()
        }
    }

    // MARK: - Fork: select all / deselect all
    
    private var allEntriesSelected: Bool {
        !entries.isEmpty && entries.allSatisfy { selectedPaths.contains($0.path) }
    }
    
    private func updateSelectAllButton() {
        selectAllButton?.title = allEntriesSelected ? "Deselect All" : "Select All"
        selectAllButton?.isEnabled = !entries.isEmpty
    }
    
    @objc func toggleSelectAll() {
        guard isSelecting else { return }
        
        let selectEverything = !allEntriesSelected
        for (row, entry) in entries.enumerated() {
            let indexPath = IndexPath(row: row, section: 0)
            if selectEverything {
                selectedPaths.insert(entry.path)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            } else {
                selectedPaths.remove(entry.path)
                tableView.deselectRow(at: indexPath, animated: false)
                tableView.cellForRow(at: indexPath)?.accessoryType = (entry.type == .dir) ? .disclosureIndicator : .none
            }
        }
        
        updateSelectAllButton()
    }
    
    @objc func deleteSelected() {
        guard !selectedPaths.isEmpty else { return }

        let alert = UIAlertController(
            title: "Delete \(selectedPaths.count) item\(selectedPaths.count == 1 ? "" : "s")?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            for path in self.selectedPaths {
                let fileUrl = URL(fileURLWithPath: path)
                if ((try? FileManager.default.removeItem(at: fileUrl)) != nil), let project = self.project {
                    let database: DebugDatabase = DebugDatabase.getDatabase(ofPath: project.cacheURL.appendingPathComponent("debug.json").path)
                    NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["close", fileUrl.path])
                    database.removeFileDebug(ofPath: fileUrl.path)
                    database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
                } else {
                    try? FileManager.default.removeItem(atPath: path)
                }
            }

            self.entries.removeAll { self.selectedPaths.contains($0.path) }
            self.selectedPaths.removeAll()
            self.tableView.reloadData()
            self.toggleSelectionMode()
        })

        present(alert, animated: true)
    }

    @objc func shareSelected() {
        guard !selectedPaths.isEmpty else { return }
        let urls = selectedPaths.map { URL(fileURLWithPath: $0) }
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        activityVC.modalPresentationStyle = .popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 0, height: 0)
            popover.permittedArrowDirections = .down
        }
        present(activityVC, animated: true)
    }

    @objc func copySelected() {
        PasteBoardServices.copy(mode: .copy, paths:selectedPaths)
        toggleSelectionMode()
        NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Copied: use Paste in another folder", withDelay: 0.0)
    }

    /* fork: cut — the items move when they are pasted in another folder */
    @objc func forkCutSelected() {
        guard !selectedPaths.isEmpty else { return }
        let moved = selectedPaths
        PasteBoardServices.onMove = { [weak self] in
            guard let self else { return }
            self.entries.removeAll { moved.contains($0.path) }
            self.tableView.reloadData()
        }
        PasteBoardServices.copy(mode: .move, paths: moved)
        toggleSelectionMode()
        NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Cut: use Paste in the folder to move them to", withDelay: 0.0)
    }

    /* fork: "name copy.ext", "name copy 2.ext"… next to each one */
    @objc func forkDuplicateSelected() {
        guard !selectedPaths.isEmpty else { return }
        let fm = FileManager.default
        for path in selectedPaths.sorted() {
            let source = URL(fileURLWithPath: path)
            let folder = source.deletingLastPathComponent()
            let ext = source.pathExtension
            let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
            var n = 1
            var destination: URL
            repeat {
                let name = n == 1 ? "\(stem) copy" : "\(stem) copy \(n)"
                destination = folder.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
                n += 1
            } while fm.fileExists(atPath: destination.path)
            if (try? fm.copyItem(at: source, to: destination)) != nil, folder.path == URL(fileURLWithPath: self.path).path {
                entries.append(FileListEntry.getEntry(ofPath: destination.path))
            }
        }
        toggleSelectionMode()
    }

    /* fork: one .zip with everything selected, in this folder */
    @objc func forkCompressSelected() {
        guard !selectedPaths.isEmpty else { return }
        let fm = FileManager.default
        let items = selectedPaths.sorted().map { URL(fileURLWithPath: $0) }
        let folder = URL(fileURLWithPath: self.path)
        let baseName = items.count == 1 ? items[0].deletingPathExtension().lastPathComponent : "Archive"
        var destination = folder.appendingPathComponent("\(baseName).zip")
        var n = 2
        while fm.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(baseName) \(n).zip")
            n += 1
        }
        toggleSelectionMode()
        DispatchQueue.global(qos: .userInitiated).async {
            /* a folder with copies of the items, zipped with them at its top */
            let staging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Compress-\(UUID().uuidString)")
            try? fm.createDirectory(at: staging, withIntermediateDirectories: true)
            for item in items {
                try? fm.copyItem(at: item, to: staging.appendingPathComponent(item.lastPathComponent))
            }
            zipDirectoryAtPath(staging.path, destination.path, false)
            try? fm.removeItem(at: staging)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if fm.fileExists(atPath: destination.path) {
                    self.entries.append(FileListEntry.getEntry(ofPath: destination.path))
                    self.tableView.reloadData()
                    NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Made \(destination.lastPathComponent)", withDelay: 0.0)
                } else {
                    NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Could not make the .zip", withDelay: 0.0)
                }
            }
        }
    }

    func createEntry(mode: FileListEntry.FileListEntryType) {
        let alert: UIAlertController = UIAlertController(
            title: "Create \((mode == .file) ? "File" : "Folder")",
            message: nil,
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let destination: URL = URL(fileURLWithPath: self.path).appendingPathComponent(alert.textFields![0].text ?? "")
            
            var isDirectory: ObjCBool = ObjCBool(false)
            if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
                self.presentConfirmationAlert(
                    title: mode == .dir ? "Error" : "Warning",
                    message: "\(isDirectory.boolValue ? "Folder" : "File") with the name \"\(destination.lastPathComponent)\" already exists. \(!isDirectory.boolValue ? "" : "Folders cannot be removed!")",
                    confirmTitle: "Overwrite",
                    confirmStyle: .destructive,
                    confirmHandler: {
                        try? String(NXUser.shared().generateFileCreationContent(forName: destination.lastPathComponent)).write(to: destination, atomically: true, encoding: .utf8)
                        self.replaceFile(destination: destination)
                    },
                    addHandler: mode == .file && !isDirectory.boolValue
                )
            } else {
                if mode == .file {
                    try? String(NXUser.shared().generateFileCreationContent(forName: destination.lastPathComponent)).write(to: destination, atomically: true, encoding: .utf8)
                } else {
                    try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
                }
                self.addFile(destination: destination)
            }
        })
        
        self.present(alert, animated: true)
    }
    
    /// Asks for a name and writes the template's file into this folder.
    func forkCreateFromTemplate(_ template: ForkFileTemplate) {
        let alert = UIAlertController(title: template.title, message: template.subtitle, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = template.placeholder
            field.autocapitalizationType = template.fileExtension == "py" ? .none : .words
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let typed = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespaces)
            var name = ForkFileTemplate.identifier(from: typed.isEmpty ? template.placeholder : typed, type: template.fileExtension != "py")
            /* a type named like one it uses (ObservableObject, View, Codable…) would inherit from itself */
            if template.fileExtension == "swift", ForkFileTemplate.reservedNames.contains(name) {
                name += template.suffix
                NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Named \(name): \(typed) is a type of the system", withDelay: 0.0)
            }
            let destination = URL(fileURLWithPath: self.path).appendingPathComponent("\(name).\(template.fileExtension)")
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "\(destination.lastPathComponent) already exists", withDelay: 0.0)
                return
            }
            let header = String(NXUser.shared().generateFileCreationContent(forName: destination.lastPathComponent))
            try? (header + template.body(name)).write(to: destination, atomically: true, encoding: .utf8)
            self.addFile(destination: destination)
        })
        present(alert, animated: true)
    }
    
    func generateMenu() -> UIMenu {
        var rootMenuChildren: [UIMenu] = []
        
        // Project Roots Menu in case its the root of the project obviously
        if !self.isSublink, UIDevice.current.userInterfaceIdiom != .pad, let project = self.project {
            var projectMenuElements: [UIMenuElement] = []
            if !NXApplicationState.extensionLessMode {
                projectMenuElements.append(UIAction(title: "Run", image: UIImage(systemName: "play.fill"), handler: { [weak self] _ in
                    guard let self = self else { return }
                    /* fork: a Python project runs its script, there is nothing to build */
                    if ForkPython.isPythonProject(project) {
                        ForkPython.runProject(project, from: self)
                        return
                    }
                    buildProjectWithArgumentUI(targetViewController: self, project: project, buildType: .run) { result, execPath in
                        if result {
                            if project.projectConfig.schemeKind == .app {
                                /* fork: print() output goes to the Console window */
                                let pid = PEProcessManager.shared().spawnProcess(withBundleIdentifier: project.projectConfig.bundleid, withItems: ForkPhoneConsole.shared.itemsForNewRun(name: project.projectConfig.displayName ?? "App"), withKernelSurfaceProcess: nil, doRestartIfRunning: true)
                                ForkPhoneConsole.shared.attach(processIdentifier: pid)
                                ForkDebugSession.shared.start(processIdentifier: pid, project: project)
                            } else if project.projectConfig.schemeKind == .utility, let execPath = execPath {
                                let terminalSession: NXWindowSessionTerminal = NXWindowSessionTerminal(utilityPath: execPath)
                                NXWindowServer.shared().openWindow(with: terminalSession, withCompletion: nil)
                            }
                        }
                    }
                }))
            }
            /* fork: output of the running app */
            projectMenuElements.append(UIAction(title: "Console", image: UIImage(systemName: "terminal"), handler: { _ in
                ForkPhoneConsole.shared.show()
            }))
            projectMenuElements.append(UIAction(title: "Export", image: UIImage(systemName: "archivebox.fill"), handler: { [weak self] _ in
                guard let self = self else { return }
                /* fork: checks and version first */
                ForkExportAssistant.present(from: self, project: project)
            }))
            projectMenuElements.append(UIAction(title: "Issue Navigator", image: UIImage(systemName: "exclamationmark.triangle.fill"), handler: { [weak self] _ in
                guard let self = self else { return }
                let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: project))
                loggerView.modalPresentationStyle = .formSheet
                self.present(loggerView, animated: true)
            }))
            
            rootMenuChildren.append({
                return UIMenu(title: "Project", options: [.displayAsPalette, .displayInline], children: projectMenuElements.reversed())
            }())
        }
        
        /* fork: GitHub sync for the project root */
        if !self.isSublink, let project = self.project {
            rootMenuChildren.append(UIMenu(title: "GitHub", image: UIImage(systemName: "arrow.triangle.2.circlepath"), children: [
                UIAction(title: "Commit and Push…", image: UIImage(systemName: "arrow.up.circle")) { [weak self] _ in
                    self?.forkGitHubPush(project)
                },
                UIAction(title: "Pull", image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
                    self?.forkGitHubPull(project)
                },
                /* fork 1.4.0 */
                UIAction(title: "Branches…", image: UIImage(systemName: "arrow.triangle.branch")) { [weak self] _ in
                    self?.forkGitHubBranches(project)
                },
                UIAction(title: "History", image: UIImage(systemName: "clock.arrow.circlepath")) { [weak self] _ in
                    self?.forkGitHubHistory(project)
                },
                UIAction(title: "Repository…", image: UIImage(systemName: "link")) { [weak self] _ in
                    self?.forkPresentGitHubLinkSettings(project)
                },
                UIAction(title: "Account…", image: UIImage(systemName: "person.crop.circle")) { [weak self] _ in
                    self?.forkPresentGitHubAccount()
                }
            ]))
        }
        
        /* fork: Metal shaders without a Metal compiler */
        if !self.isSublink, let project = self.project {
            rootMenuChildren.append(UIMenu(options: .displayInline, children: [
                UIAction(title: "Add Metal Helper", image: UIImage(systemName: "cube.transparent")) { [weak self] _ in
                    self?.forkAddMetalHelper(project)
                }
            ]))
        }
        
        /* fork: project-wide search and quick open */
        if let project = self.project {
            rootMenuChildren.append(UIMenu(title: "Find", options: [.displayInline], children: [
                UIAction(title: "Search in Project", image: UIImage(systemName: "text.magnifyingglass")) { [weak self] _ in
                    self?.forkPresentProjectSearch(project)
                },
                UIAction(title: "Open Quickly", image: UIImage(systemName: "doc.text.magnifyingglass")) { [weak self] _ in
                    self?.forkPresentQuickOpen(project)
                }
            ]))
        }
        
        if !self.isSublink {
            rootMenuChildren.append(UIMenu(title: "System", options: [.displayInline], children: [
                UIAction(
                    title: "Browse SDK",
                    image: UIImage(systemName: "books.vertical.fill")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    let fileVC = FileListViewController(
                        isSublink: true,
                        project: project,
                        path: NXBootstrap.shared().sdkURL.path,
                        isReadOnly: true
                    )
                    self.navigationController?.pushViewController(fileVC, animated: true)
                },
                UIAction(
                    title: "Browse Cache",
                    image: UIImage(systemName: "folder.fill.badge.person.crop")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    let fileVC = FileListViewController(
                        isSublink: true,
                        project: project,
                        path: project?.cacheURL.path ?? "",
                        isReadOnly: true
                    )
                    self.navigationController?.pushViewController(fileVC, animated: true)
                },
                UIAction(
                    title: "Configure",
                    image: UIImage(systemName: "folder.fill.badge.gearshape")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    guard let project = self.project else { return }
                    let vc: ProjectConfigViewController = ProjectConfigViewController(project: project)
                    let nvc: UINavigationController = UINavigationController(rootViewController: vc)
                    nvc.modalPresentationStyle = .formSheet
                    nvc.isModalInPresentation = true
                    self.present(nvc, animated: true)
                }
            ]))
        }
        
        if !isReadOnly {
            // The generic file system menu
            var fileMenuElements: [UIMenuElement] = []
            var createMenuElements: [UIMenuElement] = []
            createMenuElements.append(UIAction(title: "File", image: UIImage(systemName: "doc.fill"), handler: { [weak self] _ in
                guard let self = self else { return }
                self.createEntry(mode: .file)
            }))
            createMenuElements.append(UIAction(title: "Folder", image: UIImage(systemName: "folder.fill"), handler: { [weak self] _ in
                guard let self = self else { return }
                self.createEntry(mode: .dir)
            }))
            /* fork: files that start with useful code */
            createMenuElements.append(UIMenu(title: "From Template", image: UIImage(systemName: "doc.badge.plus"), children: ForkFileTemplate.all.map { template in
                UIAction(title: template.title, subtitle: template.subtitle, image: UIImage(systemName: template.symbol)) { [weak self] _ in
                    self?.forkCreateFromTemplate(template)
                }
            }))
            fileMenuElements.append(UIMenu(title: "New", image: UIImage(systemName: "plus.circle.fill"), children: createMenuElements))
            fileMenuElements.append(UIAction(title: "Paste", image: UIImage(systemName: "list.bullet.clipboard.fill"), handler: { [weak self] _ in
                guard let self = self else { return }
                PasteBoardServices.paste(path: self.path) { file in
                    self.addFile(destination: file)
                }
            }))
            fileMenuElements.append(UIAction(title: "Import", image: UIImage(systemName: "square.and.arrow.down.fill")) { [weak self] _ in
                guard let self = self else { return }
                let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
                documentPicker.allowsMultipleSelection = true
                documentPicker.modalPresentationStyle = .formSheet
                documentPicker.delegate = self
                self.present(documentPicker, animated: true)
            })
            fileMenuElements.append(UIAction(title: "Select", image: UIImage(systemName: "checkmark.circle.fill")) { [weak self] _ in
                guard let self = self else { return }
                self.toggleSelectionMode()
            })

            rootMenuChildren.append(UIMenu(title: "File", options: [.displayInline], children: fileMenuElements))
        }
        
        return UIMenu(children: rootMenuChildren)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // TODO: Add handling for overwrite and stuff... like keep,rename,overwrite. We also should merge these functions as thats the 3rd time copying those.
        for url in urls {
            let fileName: String = url.lastPathComponent
            let destination: URL = URL(fileURLWithPath: self.path).appendingPathComponent(fileName)
            
            do {
                try FileManager.default.moveItem(at: url, to: destination)
                replaceOrAddFile(destination: destination)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if isSelecting { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] suggestedActions in
            guard let self = self else { return UIMenu() }
            
            let getInfoAction = UIAction(title: "Get Info", image: UIImage(systemName: "info")) { [weak self] action in
                guard let self = self else { return }
                do {
                    let nav: UINavigationController = UINavigationController(rootViewController: try FileInfoViewController(fileEntry: self.entries[indexPath.row]))
                    nav.modalPresentationStyle = .formSheet
                    self.present(nav, animated: true)
                } catch {
                    NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Error Opening File Info View: \(error.localizedDescription)", withDelay: 0.0)
                }
            }
            
            let copyAction = UIAction(title: "Copy", image: UIImage(systemName: "document.on.clipboard")) { [weak self] action in
                guard let self = self else { return }
                PasteBoardServices.copy(mode: .copy, paths: [self.entries[indexPath.row].path])
            }
            let moveAction = UIAction(title: "Move", image: UIImage(systemName: "arrow.right")) { [weak self] action in
                guard let self = self else { return }
                let entry = self.entries[indexPath.row]
                PasteBoardServices.onMove = { [weak self] in
                    guard let self = self else { return }
                    self.entries.removeAll(where: { $0.path == entry.path })
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
                PasteBoardServices.copy(mode: .move, paths: [entry.path])
            }
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis")) { [weak self] action in
                guard let self = self else { return }
                let entry: FileListEntry = self.entries[indexPath.row]
                
                let alert: UIAlertController = UIAlertController(
                    title: "Rename \(entry.type == .dir ? "Folder" : "File")",
                    message: nil,
                    preferredStyle: .alert
                )
                
                alert.addTextField { textField in
                    textField.placeholder = "Filename"
                    textField.text = entry.name
                }
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { [weak self] _ in
                    guard let self = self else { return }
                    let newName = alert.textFields![0].text ?? "0"
                    try? FileManager.default.moveItem(atPath: "\(self.path)/\(entry.name)", toPath: "\(self.path)/\(newName)")
                    
                    if let masterIndex = self.entries.firstIndex(where: { $0.path == entry.path }) {
                        self.entries.remove(at: masterIndex)
                        self.entries.append(FileListEntry.getEntry(ofPath: "\(self.path)/\(newName)"))
                    }
                    self.tableView.reloadData()
                }))
                
                self.present(alert, animated: true)
            }
            let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up.fill")) { [weak self] action in
                guard let self = self else { return }
                let entry: FileListEntry = self.entries[indexPath.row]
                share(url: URL(fileURLWithPath: "\(self.path)/\(entry.name)"), remove: false)
            }
            let deleteAction = UIAction(title: "Remove", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { [weak self] action in
                guard let self = self else { return }
                let entry = self.entries[indexPath.row]
                let fileUrl: URL = URL(fileURLWithPath: "\(self.path)/\(entry.name)")
                if ((try? FileManager.default.removeItem(at: fileUrl)) != nil) {
                    if let project = self.project {
                        let database: DebugDatabase = DebugDatabase.getDatabase(ofPath: project.cacheURL.appendingPathComponent("debug.json").path)
                        NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["close",fileUrl.path])
                        database.removeFileDebug(ofPath: fileUrl.path)
                        database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
                    }
                    if let masterIndex = self.entries.firstIndex(where: { $0.path == entry.path }) {
                        self.entries.remove(at: masterIndex)
                    }
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
            
            var children: [UIMenu] = []
            children.append(UIMenu(options: .displayInline, children: [getInfoAction]))
            /* fork: .jar files and their opened contents */
            let forkEntryURL = URL(fileURLWithPath: self.entries[indexPath.row].path)
            if forkEntryURL.pathExtension.lowercased() == "jar" {
                children.append(UIMenu(options: .displayInline, children: [
                    UIAction(title: "Run (java -jar)", image: UIImage(systemName: "play.fill")) { [weak self] _ in
                        guard let self else { return }
                        ForkJava.runJar(forkEntryURL, project: self.project, from: self)
                    },
                    UIAction(title: "Run in Browser (CheerpJ)", image: UIImage(systemName: "globe")) { [weak self] _ in
                        guard let self else { return }
                        ForkCheerpJ.present(jar: forkEntryURL, from: self)
                    },
                ] + (self.isReadOnly ? [] : [
                    UIAction(title: "Open Contents (to edit)", image: UIImage(systemName: "shippingbox")) { [weak self] _ in
                        guard let self else { return }
                        ForkJarEditor.extract(forkEntryURL, from: self)
                        self.forkReloadEntries()
                    },
                ])))
            } else if !self.isReadOnly, let forkJar = ForkJarEditor.jar(for: forkEntryURL) {
                children.append(UIMenu(options: .displayInline, children: [
                    UIAction(title: "Pack into \(forkJar.lastPathComponent)", image: UIImage(systemName: "shippingbox.and.arrow.backward")) { [weak self] _ in
                        guard let self else { return }
                        ForkJarEditor.pack(forkEntryURL, from: self)
                        self.forkReloadEntries()
                    },
                ]))
            }
            children.append(UIMenu(options: .displayInline, children: self.isReadOnly ? [copyAction] : [copyAction, moveAction, renameAction]))
            children.append(UIMenu(options: .displayInline, children: [shareAction]))
            if !self.isReadOnly {
                children.append(UIMenu(options: .displayInline, children: [deleteAction]))
            }
            return UIMenu(children: children)
        }
    }
    
    // MARK: - Fork: swipe a row — left: Delete; right: Export and Edit

    /// Asks before deleting one entry (swipe left), then removes it like the context menu's Remove.
    private func forkConfirmDelete(_ entry: FileListEntry) {
        let alert = UIAlertController(
            title: "Delete \(entry.type == .dir ? "folder" : "file") \"\(entry.name)\"?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let fileUrl = URL(fileURLWithPath: entry.path)
            guard (try? FileManager.default.removeItem(at: fileUrl)) != nil else {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Could not delete \(entry.name)", withDelay: 0.0)
                return
            }
            if let project = self.project {
                let database: DebugDatabase = DebugDatabase.getDatabase(ofPath: project.cacheURL.appendingPathComponent("debug.json").path)
                NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["close", fileUrl.path])
                database.removeFileDebug(ofPath: fileUrl.path)
                database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
            }
            self.entries.removeAll { $0.path == entry.path }
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    /// Edit: a file opens in the code editor (whatever its type); a folder is renamed.
    private func forkEdit(_ entry: FileListEntry, sourceView: UIView?) {
        switch entry.type {
        case .file:
            if NXApplicationState.fileListRequiresToSendRequests {
                NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open", entry.path, "0", "0", self.isReadOnly ? "1" : "0"])
            } else {
                guard let codeEditor = CodeEditorViewController(project: project, url: URL(fileURLWithPath: entry.path), isReadOnly: self.isReadOnly) else {
                    NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "\(entry.name) cannot be opened as text", withDelay: 0.0)
                    return
                }
                let nav = UINavigationController(rootViewController: codeEditor)
                nav.modalPresentationStyle = .overFullScreen
                present(nav, animated: true)
            }
        case .dir:
            guard !isReadOnly else { return }
            let alert = UIAlertController(title: "Rename Folder", message: nil, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Folder name"
                textField.text = entry.name
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
                guard let self = self else { return }
                let newName = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !newName.isEmpty, newName != entry.name, !newName.contains("/") else { return }
                let destination = URL(fileURLWithPath: self.path).appendingPathComponent(newName)
                guard !FileManager.default.fileExists(atPath: destination.path),
                      (try? FileManager.default.moveItem(atPath: entry.path, toPath: destination.path)) != nil else {
                    NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Could not rename to \(newName)", withDelay: 0.0)
                    return
                }
                self.entries.removeAll { $0.path == entry.path }
                self.entries.append(FileListEntry.getEntry(ofPath: destination.path))
                self.tableView.reloadData()
            })
            present(alert, animated: true)
        }
    }

    /// Swipe to the left: Delete (not in read-only lists, not while selecting).
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isSelecting || isReadOnly || indexPath.row >= entries.count { return nil }
        let entry = entries[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.forkConfirmDelete(entry)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash.fill")
        let configuration = UISwipeActionsConfiguration(actions: [delete])
        /* a long swipe must not delete by itself: it asks first */
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    /// Swipe to the right: Export (share sheet) and Edit.
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isSelecting || indexPath.row >= entries.count { return nil }
        let entry = entries[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)

        let export = UIContextualAction(style: .normal, title: "Export") { _, _, completion in
            share(url: URL(fileURLWithPath: entry.path), remove: false)
            completion(true)
        }
        export.image = UIImage(systemName: "square.and.arrow.up")
        export.backgroundColor = .systemBlue

        var actions: [UIContextualAction] = [export]
        if !(isReadOnly && entry.type == .dir) {
            let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
                self?.forkEdit(entry, sourceView: cell)
                completion(true)
            }
            edit.image = UIImage(systemName: entry.type == .dir ? "pencil" : "square.and.pencil")
            edit.backgroundColor = .systemOrange
            actions.append(edit)
        }
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSelecting {
            selectedPaths.insert(entries[indexPath.row].path)
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            updateSelectAllButton()
            return
        }
        
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        guard !self.navigationItem.hidesBackButton,
              self.navigationItem.leftBarButtonItem?.isEnabled ?? true else {
            return
        }
        
        let fileListEntry: FileListEntry = entries[indexPath.row]
        
        switch(fileListEntry.type) {
        case .dir:
            let fileVC = FileListViewController(isSublink: true, project: project, path: fileListEntry.path, isReadOnly: self.isReadOnly)
            self.navigationController?.pushViewController(fileVC, animated: true)
            break
        case .file:
            if ["zip","ipa"].contains(URL(fileURLWithPath: fileListEntry.path).pathExtension)  {
                let folder: URL = PasteBoardServices.resolvedDestinationURL(for: (fileListEntry.path as NSString).lastPathComponent, inDirectory: self.path)
                if ((try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil) {
                    if(unzipArchiveAtPath(fileListEntry.path, folder.path)) {
                        self.entries.append(FileListEntry.getEntry(ofPath: folder.path))
                        self.tableView.reloadData()
                    } else {
                        NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to unzip \(fileListEntry.path)", withDelay: 0.0)
                    }
                }
            } else if URL(fileURLWithPath: fileListEntry.path).pathExtension.lowercased() == "jar" {
                /* fork: a jar runs here (miniJVM) or in the browser (CheerpJ), or opens to edit */
                ForkJava.presentJarActions(URL(fileURLWithPath: fileListEntry.path), project: project, from: self, sourceView: tableView.cellForRow(at: indexPath))
            } else if URL(fileURLWithPath: fileListEntry.path).pathExtension.lowercased() == "ipynb" {
                /* fork: a Jupyter notebook, with its outputs; "Run as Cells" makes a .py of cells */
                ForkNotebookViewController.open(URL(fileURLWithPath: fileListEntry.path), project: project, from: self)
            } else if ForkQuickLook.canPreview(URL(fileURLWithPath: fileListEntry.path)) {
                /* fork: pictures (plots from Python), PDFs… open in a preview, not as text */
                ForkQuickLook.present(URL(fileURLWithPath: fileListEntry.path), from: self)
            } else {
                if NXApplicationState.fileListRequiresToSendRequests {
                    NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open",fileListEntry.path,"0","0",self.isReadOnly ? "1" : "0"])
                } else {
                    guard let codeEditor = CodeEditorViewController(project: project, url: URL(fileURLWithPath: fileListEntry.path), isReadOnly: self.isReadOnly) else {
                        return
                    }
                    let fileVC = UINavigationController(rootViewController: codeEditor)
                    fileVC.modalPresentationStyle = .overFullScreen
                    self.present(fileVC, animated: true)
                }
            }
        }
    }

    // MARK: - Fork: two-finger slide selects several rows (as in Files and Mail)
    
    override func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        return !isReadOnly && !entries.isEmpty
    }
    
    override func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        if !isSelecting {
            toggleSelectionMode()
        }
    }
    
    override func tableViewDidEndMultipleSelectionInteraction(_ tableView: UITableView) {
        updateSelectAllButton()
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isSelecting {
            selectedPaths.remove(entries[indexPath.row].path)
            
            tableView.cellForRow(at: indexPath)?.accessoryType = (entries[indexPath.row].type == .dir) ? .disclosureIndicator : .none
            updateSelectAllButton()
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell
            
        let entry = entries[indexPath.row]
        cell.configure(with: entry)
        
        /* fork: reused cells must show the checkmark of a selected entry */
        if isSelecting, selectedPaths.contains(entry.path) {
            cell.accessoryType = .checkmark
        }
            
        return cell
    }
    
    ///
    /// Private: Function to add or replace a file or files in the array
    ///
    private func addFile(destination: URL) {
        self.entries.append(FileListEntry.getEntry(ofPath: destination.path))
        let newIndexPath = IndexPath(row: self.entries.count - 1, section: 0)
        self.tableView.insertRows(at: [newIndexPath], with: .automatic)
    }
    
    private func replaceFile(destination: URL) {
        let index = self.entries.firstIndex(where: { $0.name == destination.lastPathComponent} )
        if let index {
            self.entries.remove(at: index)
            let oldIndexPath = IndexPath(row: index, section: 0)
            self.tableView.deleteRows(at: [oldIndexPath], with: .automatic)
        }
        
        self.entries.append(FileListEntry.getEntry(ofPath: destination.path))
        let newIndexPath = IndexPath(row: self.entries.count - 1, section: 0)
        self.tableView.insertRows(at: [newIndexPath], with: .automatic)
    }
    
    private func replaceOrAddFile(destination: URL) {
        if FileManager.default.fileExists(atPath: destination.path) {
            replaceFile(destination: destination)
        } else {
            addFile(destination: destination)
        }
    }
}

func share(url: URL, remove: Bool = false) {
    let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    
    if remove {
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to remove file: \(error)")
            }
        }
    }
    
    activityViewController.modalPresentationStyle = .popover

    DispatchQueue.main.async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = keyWindow.rootViewController else {
            print("No key window or root view controller found.")
            return
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = topController.view
            popoverController.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }

        topController.present(activityViewController, animated: true)
    }
}

// MARK: - Fork: project-wide search (⇧⌘F) and quick open (⇧⌘O)

/// Text files of a project, shared by the project search and quick open.
enum ProjectFileIndex {
    static let textExtensions: Set<String> = [
        "swift", "m", "mm", "c", "cc", "cpp", "cxx", "h", "hpp", "hh",
        "plist", "xml", "json", "txt", "md", "strings", "entitlements", "sh", "py", "metal"
    ]
    
    /// Skips very large files so a search never stalls the device.
    static let maximumFileSize = 2 * 1024 * 1024
    
    static func files(in root: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        
        var result: [URL] = []
        for case let url as URL in enumerator {
            guard textExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  (values.fileSize ?? 0) <= maximumFileSize else { continue }
            result.append(url)
        }
        return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    
    static func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

extension UIViewController {
    /// Opens a project file, at a line if given, the same way the file list does on this device.
    func forkOpenProjectFile(_ url: URL, project: NXProject?, line: Int = 0, column: Int = 0) {
        if NXApplicationState.fileListRequiresToSendRequests {
            NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open", url.path, "\(line)", "\(column)", "0"])
        } else {
            guard let editor = CodeEditorViewController(project: project, url: url, line: line > 0 ? line : nil, column: line > 0 ? max(column, 1) : nil) else { return }
            let navigation = UINavigationController(rootViewController: editor)
            navigation.modalPresentationStyle = .overFullScreen
            self.present(navigation, animated: true)
        }
    }
    
    @objc func forkPresentProjectSearch(_ project: NXProject) {
        guard self.presentedViewController == nil else { return }
        let navigation = UINavigationController(rootViewController: ProjectSearchViewController(project: project))
        navigation.modalPresentationStyle = .formSheet
        self.present(navigation, animated: true)
    }
    
    @objc func forkPresentQuickOpen(_ project: NXProject) {
        guard self.presentedViewController == nil else { return }
        let navigation = UINavigationController(rootViewController: QuickOpenViewController(project: project))
        navigation.modalPresentationStyle = .formSheet
        self.present(navigation, animated: true)
    }
}

/// Searches the text of every file in the project and jumps to a match.
final class ProjectSearchViewController: UITableViewController, UISearchBarDelegate {
    private struct Match {
        let line: Int
        let column: Int
        let preview: String
    }
    
    private struct FileMatches {
        let url: URL
        let relativePath: String
        var matches: [Match]
    }
    
    private static let maximumMatches = 1000
    
    private let project: NXProject
    private let searchBar = UISearchBar()
    private var results: [FileMatches] = []
    private var searchGeneration = 0
    private var statusText = "Type to search every file in the project."
    
    init(project: NXProject) {
        self.project = project
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Search in Project"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        searchBar.placeholder = "Text to find"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.spellCheckingType = .no
        searchBar.smartQuotesType = .no
        searchBar.smartDashesType = .no
        searchBar.delegate = self
        searchBar.sizeToFit()
        tableView.tableHeaderView = searchBar
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "match")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        /* debounce typing a little so big projects stay responsive */
        searchGeneration += 1
        let generation = searchGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, generation == self.searchGeneration else { return }
            self.runSearch(searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchGeneration += 1
        runSearch(searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }
    
    private func runSearch(_ query: String) {
        searchGeneration += 1
        let generation = searchGeneration
        let needle = query
        
        guard !needle.isEmpty else {
            results = []
            statusText = "Type to search every file in the project."
            tableView.reloadData()
            return
        }
        
        statusText = "Searching…"
        tableView.reloadData()
        
        let root: URL = project.url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var found: [FileMatches] = []
            var total = 0
            var truncated = false
            
            fileLoop: for url in ProjectFileIndex.files(in: root) {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                var matches: [Match] = []
                var lineNumber = 0
                for lineText in text.components(separatedBy: "\n") {
                    lineNumber += 1
                    guard let range = lineText.range(of: needle, options: [.caseInsensitive]) else { continue }
                    let column = lineText.distance(from: lineText.startIndex, to: range.lowerBound) + 1
                    let preview = lineText.trimmingCharacters(in: .whitespaces)
                    matches.append(Match(line: lineNumber, column: column, preview: String(preview.prefix(200))))
                    total += 1
                    if total >= ProjectSearchViewController.maximumMatches {
                        truncated = true
                        break
                    }
                }
                if !matches.isEmpty {
                    found.append(FileMatches(url: url, relativePath: ProjectFileIndex.relativePath(url, root: root), matches: matches))
                }
                if truncated { break fileLoop }
            }
            
            DispatchQueue.main.async {
                guard let self = self, generation == self.searchGeneration else { return }
                self.results = found
                if total == 0 {
                    self.statusText = "No results for \"\(needle)\"."
                } else {
                    let fileWord = found.count == 1 ? "file" : "files"
                    self.statusText = "\(total)\(truncated ? "+" : "") result\(total == 1 ? "" : "s") in \(found.count) \(fileWord)" + (truncated ? " (showing the first \(ProjectSearchViewController.maximumMatches))" : "")
                }
                self.tableView.reloadData()
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return max(results.count, 1)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.isEmpty ? 0 : results[section].matches.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return results.isEmpty ? nil : "\(results[section].relativePath) • \(results[section].matches.count)"
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == max(results.count, 1) - 1 ? statusText : nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "match", for: indexPath)
        let match = results[indexPath.section].matches[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = match.preview.isEmpty ? " " : match.preview
        content.textProperties.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        content.textProperties.numberOfLines = 2
        content.secondaryText = "Line \(match.line)"
        content.secondaryTextProperties.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let file = results[indexPath.section]
        let match = file.matches[indexPath.row]
        open(file.url, line: match.line, column: match.column)
    }
    
    private func open(_ url: URL, line: Int, column: Int) {
        let project = self.project
        if NXApplicationState.fileListRequiresToSendRequests {
            /* iPad: the workspace behind this sheet opens the tab */
            self.forkOpenProjectFile(url, project: project, line: line, column: column)
            self.dismiss(animated: true)
        } else {
            /* iPhone: open the editor on top of whatever presented this sheet */
            let presenter = self.presentingViewController
            self.dismiss(animated: true) {
                presenter?.forkOpenProjectFile(url, project: project, line: line, column: column)
            }
        }
    }
}

/// Finds a project file by typing part of its name (characters in order, like Xcode's Open Quickly).
final class QuickOpenViewController: UITableViewController, UISearchBarDelegate {
    private struct Entry {
        let url: URL
        let name: String
        let relativePath: String
    }
    
    private let project: NXProject
    private let searchBar = UISearchBar()
    private var allEntries: [Entry] = []
    private var visibleEntries: [Entry] = []
    
    init(project: NXProject) {
        self.project = project
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Open Quickly"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        searchBar.placeholder = "File name"
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.spellCheckingType = .no
        searchBar.delegate = self
        searchBar.sizeToFit()
        tableView.tableHeaderView = searchBar
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "file")
        
        let root: URL = project.url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let entries = ProjectFileIndex.files(in: root).map {
                Entry(url: $0, name: $0.lastPathComponent, relativePath: ProjectFileIndex.relativePath($0, root: root))
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.allEntries = entries
                self.applyFilter(self.searchBar.text ?? "")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let first = visibleEntries.first {
            open(first)
        }
    }
    
    /// Lower score is better; nil means the query's characters do not appear in order.
    private static func score(_ name: String, _ query: String) -> Int? {
        let haystack = Array(name.lowercased())
        let needle = Array(query.lowercased())
        if needle.isEmpty { return 0 }
        if name.lowercased().hasPrefix(query.lowercased()) { return 0 }
        if name.lowercased().contains(query.lowercased()) { return 1 }
        
        var index = 0
        var gaps = 0
        for character in needle {
            var found = false
            while index < haystack.count {
                if haystack[index] == character {
                    found = true
                    index += 1
                    break
                }
                gaps += 1
                index += 1
            }
            if !found { return nil }
        }
        return 2 + gaps
    }
    
    private func applyFilter(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            visibleEntries = allEntries
        } else {
            visibleEntries = allEntries
                .compactMap { entry -> (Entry, Int)? in
                    guard let score = QuickOpenViewController.score(entry.name, trimmed) else { return nil }
                    return (entry, score)
                }
                .sorted { lhs, rhs in
                    lhs.1 != rhs.1 ? lhs.1 < rhs.1 : lhs.0.name.count < rhs.0.name.count
                }
                .map { $0.0 }
        }
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleEntries.count
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return visibleEntries.isEmpty ? "No matching files." : nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "file", for: indexPath)
        let entry = visibleEntries[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = entry.name
        content.secondaryText = entry.relativePath
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: "doc.text")
        cell.contentConfiguration = content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        open(visibleEntries[indexPath.row])
    }
    
    private func open(_ entry: Entry) {
        let project = self.project
        if NXApplicationState.fileListRequiresToSendRequests {
            self.forkOpenProjectFile(entry.url, project: project)
            self.dismiss(animated: true)
        } else {
            let presenter = self.presentingViewController
            self.dismiss(animated: true) {
                presenter?.forkOpenProjectFile(entry.url, project: project)
            }
        }
    }
}

// MARK: - Fork: GitHub sync (REST API, no git binary needed)

/// Stores the GitHub personal access token in the Keychain (never in project files).
enum GitHubTokenStore {
    private static let service = "org.emexlabs.nyxian.fork.github"
    private static let account = "personal-access-token"
    
    static var token: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    @discardableResult
    static func save(_ token: String) -> Bool {
        remove()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8)
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Per-project link to a repository, kept in Config/GitHub.plist (no secrets, never pushed).
struct GitHubLink: Codable {
    var owner: String
    var repo: String
    var branch: String
    /// Commit this project was last synced with.
    var lastCommit: String?
    /// Git blob SHA of every file at the last sync, by project-relative path.
    var files: [String: String] = [:]
    
    static let fileName = "GitHub.plist"
    
    static func url(for project: NXProject) -> URL {
        let root: URL = project.url
        return root.appendingPathComponent("Config").appendingPathComponent(fileName)
    }
    
    static func load(for project: NXProject) -> GitHubLink? {
        guard let data = try? Data(contentsOf: url(for: project)) else { return nil }
        return try? PropertyListDecoder().decode(GitHubLink.self, from: data)
    }
    
    func save(for project: NXProject) throws {
        let data = try PropertyListEncoder().encode(self)
        try data.write(to: GitHubLink.url(for: project), options: .atomic)
    }
}

enum GitHubSyncError: LocalizedError {
    case noToken
    case http(Int, String)
    case emptyRepository
    case remoteChanged
    case invalidResponse
    case notAProject
    
    var errorDescription: String? {
        switch self {
        case .noToken: return "Add a GitHub token first (⋯ > GitHub > Account)."
        case .http(let code, let message): return "GitHub answered \(code): \(message)"
        case .emptyRepository: return "The repository is empty. Create it on GitHub with a README first, then push again."
        case .remoteChanged: return "GitHub has commits this project does not have yet. Pull first, then push."
        case .invalidResponse: return "Unexpected answer from GitHub."
        case .notAProject: return "The repository is neither a Nyxian project (Config/Project.plist) nor a Swift Playgrounds app (Package.swift)."
        }
    }
}

/// Minimal GitHub client over the REST "Git Data" API: commit + push, pull, and clone.
struct GitHubSync {
    let token: String
    let owner: String
    let repo: String
    let branch: String
    
    /// Files larger than this are skipped (the API limit is higher, but the device memory is not).
    static let maximumFileSize = 25 * 1024 * 1024
    
    // MARK: HTTP
    
    func request(_ method: String, _ path: String, body: [String: Any]? = nil, allow404: Bool = false) async throws -> Any? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)\(path)") else { throw GitHubSyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Nyxian-fork", forHTTPHeaderField: "User-Agent")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubSyncError.invalidResponse }
        if http.statusCode == 404 && allow404 { return nil }
        if http.statusCode == 409 { throw GitHubSyncError.emptyRepository }
        guard (200..<300).contains(http.statusCode) else {
            let message = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["message"] as? String ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GitHubSyncError.http(http.statusCode, message)
        }
        return data.isEmpty ? nil : try JSONSerialization.jsonObject(with: data)
    }
    
    // MARK: helpers
    
    /// The SHA git uses for a blob: sha1("blob <size>\0<content>").
    static func blobSHA(_ data: Data) -> String {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("blob \(data.count)\0".utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
    
    /// Project files to sync, by relative path (hidden files and the sync state are left out).
    static func localFiles(in root: URL) -> [String: URL] {
        var result: [String: URL] = [:]
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [:] }
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  (values.fileSize ?? 0) <= maximumFileSize else { continue }
            let relative = ProjectFileIndex.relativePath(url, root: root)
            if relative == "Config/\(GitHubLink.fileName)" { continue }
            result[relative] = url
        }
        return result
    }
    
    /// Remote head commit and its tree, or nil when the branch does not exist yet.
    func head() async throws -> (commit: String, tree: String)? {
        guard let ref = try await request("GET", "/git/ref/heads/\(branch)", allow404: true) as? [String: Any],
              let object = ref["object"] as? [String: Any],
              let commitSHA = object["sha"] as? String,
              let commit = try await request("GET", "/git/commits/\(commitSHA)") as? [String: Any],
              let tree = (commit["tree"] as? [String: Any])?["sha"] as? String else { return nil }
        return (commitSHA, tree)
    }
    
    /// path -> blob SHA of every file in a tree.
    func remoteFiles(tree: String) async throws -> [String: String] {
        guard let json = try await request("GET", "/git/trees/\(tree)?recursive=1") as? [String: Any],
              let entries = json["tree"] as? [[String: Any]] else { throw GitHubSyncError.invalidResponse }
        var files: [String: String] = [:]
        for entry in entries where (entry["type"] as? String) == "blob" {
            if let path = entry["path"] as? String, let sha = entry["sha"] as? String {
                files[path] = sha
            }
        }
        return files
    }
    
    func downloadBlob(_ sha: String) async throws -> Data {
        guard let json = try await request("GET", "/git/blobs/\(sha)") as? [String: Any],
              let content = json["content"] as? String,
              let data = Data(base64Encoded: content.replacingOccurrences(of: "\n", with: "")) else { throw GitHubSyncError.invalidResponse }
        return data
    }
    
    // MARK: operations
    
    struct Summary {
        var uploaded = 0
        var downloaded = 0
        var deleted = 0
        var conflicts: [String] = []
        var commit: String?
    }
    
    /// Commits the whole project as the new state of the branch.
    func push(root: URL, link: inout GitHubLink, message: String) async throws -> Summary {
        var summary = Summary()
        let current = try await head()
        if let current = current, let last = link.lastCommit, current.commit != last {
            throw GitHubSyncError.remoteChanged
        }
        var remote: [String: String] = [:]
        if let current = current {
            remote = try await remoteFiles(tree: current.tree)
        }
        /* first push into a branch that already exists (e.g. created with a README): keep its files */
        let keepRemoteOnlyFiles = (current != nil && link.lastCommit == nil)
        
        var treeEntries: [[String: Any]] = []
        var newState: [String: String] = [:]
        for (path, url) in GitHubSync.localFiles(in: root).sorted(by: { $0.key < $1.key }) {
            let data = try Data(contentsOf: url)
            let sha = GitHubSync.blobSHA(data)
            if remote[path] != sha {
                guard let blob = try await request("POST", "/git/blobs", body: ["content": data.base64EncodedString(), "encoding": "base64"]) as? [String: Any],
                      let uploaded = blob["sha"] as? String else { throw GitHubSyncError.invalidResponse }
                summary.uploaded += 1
                newState[path] = uploaded
            } else {
                newState[path] = sha
            }
            treeEntries.append(["path": path, "mode": "100644", "type": "blob", "sha": newState[path]!])
        }
        if keepRemoteOnlyFiles {
            for (path, sha) in remote where newState[path] == nil {
                treeEntries.append(["path": path, "mode": "100644", "type": "blob", "sha": sha])
                newState[path] = sha
            }
        }
        summary.deleted = Set(remote.keys).subtracting(newState.keys).count
        
        /* a full tree (no base_tree): files deleted locally disappear from the branch too */
        guard let tree = try await request("POST", "/git/trees", body: ["tree": treeEntries]) as? [String: Any],
              let treeSHA = tree["sha"] as? String else { throw GitHubSyncError.invalidResponse }
        if let current = current, current.tree == treeSHA {
            link.lastCommit = current.commit
            link.files = newState
            summary.commit = current.commit
            return summary
        }
        
        var commitBody: [String: Any] = ["message": message, "tree": treeSHA]
        if let current = current { commitBody["parents"] = [current.commit] }
        guard let commit = try await request("POST", "/git/commits", body: commitBody) as? [String: Any],
              let commitSHA = commit["sha"] as? String else { throw GitHubSyncError.invalidResponse }
        
        if current != nil {
            _ = try await request("PATCH", "/git/refs/heads/\(branch)", body: ["sha": commitSHA, "force": false])
        } else {
            _ = try await request("POST", "/git/refs", body: ["ref": "refs/heads/\(branch)", "sha": commitSHA])
        }
        
        link.lastCommit = commitSHA
        link.files = newState
        summary.commit = commitSHA
        return summary
    }
    
    /// Brings remote changes in. Files changed on both sides are kept as they are and reported.
    func pull(root: URL, link: inout GitHubLink) async throws -> Summary {
        var summary = Summary()
        guard let current = try await head() else { return summary }
        let remote = try await remoteFiles(tree: current.tree)
        let local = GitHubSync.localFiles(in: root)
        
        var newState = link.files
        for (path, remoteSHA) in remote.sorted(by: { $0.key < $1.key }) {
            let localURL = root.appendingPathComponent(path)
            let localSHA = local[path].flatMap { try? Data(contentsOf: $0) }.map { GitHubSync.blobSHA($0) }
            if localSHA == remoteSHA {
                newState[path] = remoteSHA
                continue
            }
            let lastSynced = link.files[path]
            let changedLocally = localSHA != nil && localSHA != lastSynced
            if changedLocally {
                summary.conflicts.append(path)
                continue
            }
            let data = try await downloadBlob(remoteSHA)
            try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: localURL, options: .atomic)
            newState[path] = remoteSHA
            summary.downloaded += 1
        }
        /* files deleted on GitHub are removed here only if they were not edited locally */
        for (path, lastSHA) in link.files where remote[path] == nil {
            if let url = local[path], let data = try? Data(contentsOf: url), GitHubSync.blobSHA(data) == lastSHA {
                try? FileManager.default.removeItem(at: url)
                summary.deleted += 1
            }
            newState.removeValue(forKey: path)
        }
        
        if summary.conflicts.isEmpty {
            link.lastCommit = current.commit
        }
        link.files = newState
        summary.commit = current.commit
        return summary
    }
    
    /// Downloads the branch into an empty folder.
    func download(into folder: URL) async throws -> (commit: String, files: [String: String]) {
        guard let current = try await head() else { throw GitHubSyncError.emptyRepository }
        let remote = try await remoteFiles(tree: current.tree)
        for (path, sha) in remote {
            let data = try await downloadBlob(sha)
            let url = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
        return (current.commit, remote)
    }
}

// MARK: - Fork: GitHub UI

extension UIViewController {
    func forkGitHubAlert(_ title: String, _ message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    /// Asks for (or replaces / removes) the token kept in the Keychain.
    func forkPresentGitHubAccount() {
        let hasToken = GitHubTokenStore.token != nil
        let alert = UIAlertController(
            title: "GitHub Account",
            message: "Paste a personal access token with \"Contents: Read and write\" permission for your repositories. It is stored in the Keychain on this device only." + (hasToken ? "\n\nA token is already saved." : ""),
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "github_pat_…"
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if hasToken {
            alert.addAction(UIAlertAction(title: "Remove Token", style: .destructive) { _ in
                GitHubTokenStore.remove()
            })
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let token = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
            if !GitHubTokenStore.save(token) {
                self?.forkGitHubAlert("GitHub", "The token could not be saved in the Keychain.")
            }
        })
        self.present(alert, animated: true)
    }
    
    /// Shows a small "working" alert while `work` runs, then the result.
    func forkRunGitHubTask(_ title: String, finished: (() -> Void)? = nil, _ work: @escaping () async throws -> String) {
        let progress = UIAlertController(title: title, message: "Talking to GitHub…", preferredStyle: .alert)
        self.present(progress, animated: true)
        Task { @MainActor [weak self] in
            var resultTitle = title
            var resultMessage: String
            do {
                resultMessage = try await work()
            } catch {
                resultTitle = "\(title) Failed"
                resultMessage = error.localizedDescription
            }
            progress.dismiss(animated: true) {
                finished?()
                self?.forkGitHubAlert(resultTitle, resultMessage)
            }
        }
    }
}

extension FileListViewController {
    /// Repository settings for this project (owner/repo and branch).
    func forkPresentGitHubLinkSettings(_ project: NXProject) {
        let link = GitHubLink.load(for: project)
        let alert = UIAlertController(title: "GitHub Repository", message: "Link this project to a repository you own, as owner/repo.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "owner/repo"
            field.text = link.map { "\($0.owner)/\($0.repo)" }
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addTextField { field in
            field.placeholder = "branch (main)"
            field.text = link?.branch ?? "main"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let parts = (alert?.textFields?[0].text ?? "").trimmingCharacters(in: .whitespaces).split(separator: "/").map(String.init)
            let branch = (alert?.textFields?[1].text ?? "").trimmingCharacters(in: .whitespaces)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                self?.forkGitHubAlert("GitHub Repository", "Write it as owner/repo.")
                return
            }
            var updated = link ?? GitHubLink(owner: parts[0], repo: parts[1], branch: "main")
            if updated.owner != parts[0] || updated.repo != parts[1] {
                /* a different repository starts a new sync history */
                updated = GitHubLink(owner: parts[0], repo: parts[1], branch: "main")
            }
            updated.branch = branch.isEmpty ? "main" : branch
            do {
                try updated.save(for: project)
            } catch {
                self?.forkGitHubAlert("GitHub Repository", error.localizedDescription)
            }
        })
        self.present(alert, animated: true)
    }
    
    private func forkGitHubContext(_ project: NXProject) -> (GitHubSync, GitHubLink)? {
        guard let token = GitHubTokenStore.token else {
            forkPresentGitHubAccount()
            return nil
        }
        guard let link = GitHubLink.load(for: project) else {
            forkPresentGitHubLinkSettings(project)
            return nil
        }
        return (GitHubSync(token: token, owner: link.owner, repo: link.repo, branch: link.branch), link)
    }
    
    func forkGitHubPush(_ project: NXProject) {
        guard let context = forkGitHubContext(project) else { return }
        let (sync, link) = context
        /* fork: review what changed before committing */
        NXDocumentManager.shared().saveAll {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let root: URL = project.url
                let changes = GitHubChange.localChanges(root: root, link: link)
                guard !changes.isEmpty else {
                    self.forkGitHubAlert("Nothing to Push", "No file changed since the last sync with \(link.owner)/\(link.repo).")
                    return
                }
                let review = GitHubChangesViewController(sync: sync, link: link, root: root, changes: changes) { [weak self] in
                    self?.forkGitHubCommitAndPush(project, sync: sync, link: link)
                }
                let navigation = UINavigationController(rootViewController: review)
                navigation.modalPresentationStyle = .formSheet
                self.present(navigation, animated: true)
            }
        }
    }
    
    private func forkGitHubCommitAndPush(_ project: NXProject, sync: GitHubSync, link: GitHubLink) {
        let alert = UIAlertController(title: "Commit and Push", message: "\(link.owner)/\(link.repo) • \(link.branch)", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Commit message"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Push", style: .default) { [weak self, weak alert] _ in
            let typed = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let message = typed.isEmpty ? "Update from Nyxian" : typed
            NXDocumentManager.shared().saveAll {
                DispatchQueue.main.async {
                    self?.forkRunGitHubTask("Push") {
                        var state = link
                        let root: URL = project.url
                        let summary = try await sync.push(root: root, link: &state, message: message)
                        try state.save(for: project)
                        return "\(summary.uploaded) file\(summary.uploaded == 1 ? "" : "s") uploaded, \(summary.deleted) removed.\nCommit \(String((summary.commit ?? "").prefix(7)))"
                    }
                }
            }
        })
        self.present(alert, animated: true)
    }
    
    func forkGitHubPull(_ project: NXProject) {
        guard let context = forkGitHubContext(project) else { return }
        let (sync, link) = context
        NXDocumentManager.shared().saveAll { [weak self] in
            DispatchQueue.main.async {
                self?.forkRunGitHubTask("Pull", finished: { [weak self] in self?.performRefresh() }) {
                    var state = link
                    let root: URL = project.url
                    let summary = try await sync.pull(root: root, link: &state)
                    try state.save(for: project)
                    var text = "\(summary.downloaded) file\(summary.downloaded == 1 ? "" : "s") updated, \(summary.deleted) removed."
                    if !summary.conflicts.isEmpty {
                        text += "\n\nChanged here and on GitHub, kept as they are here:\n" + summary.conflicts.prefix(10).joined(separator: "\n")
                    }
                    text += "\n\nClose and reopen open tabs to see the new contents."
                    return text
                }
            }
        }
    }
}

// MARK: - Fork: review changes before pushing

struct GitHubChange {
    enum Kind: Int { case modified, added, deleted }
    let path: String
    let kind: Kind
    let localURL: URL?
    let baseSHA: String?
    
    /// Differences between the project now and the state of the last sync.
    static func localChanges(root: URL, link: GitHubLink) -> [GitHubChange] {
        let local = GitHubSync.localFiles(in: root)
        var changes: [GitHubChange] = []
        for (path, url) in local {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let base = link.files[path] {
                if GitHubSync.blobSHA(data) != base {
                    changes.append(GitHubChange(path: path, kind: .modified, localURL: url, baseSHA: base))
                }
            } else {
                changes.append(GitHubChange(path: path, kind: .added, localURL: url, baseSHA: nil))
            }
        }
        for (path, sha) in link.files where local[path] == nil {
            changes.append(GitHubChange(path: path, kind: .deleted, localURL: nil, baseSHA: sha))
        }
        return changes.sorted { $0.kind.rawValue != $1.kind.rawValue ? $0.kind.rawValue < $1.kind.rawValue : $0.path < $1.path }
    }
}

/// Line diff (longest common subsequence), enough for reviewing edits.
enum LineDiff {
    enum Op { case same, removed, added }
    
    static let maximumLines = 4000
    
    static func diff(_ old: [String], _ new: [String]) -> [(Op, String)]? {
        guard old.count <= maximumLines, new.count <= maximumLines else { return nil }
        /* trim the common head and tail, then LCS on the middle */
        var head = 0
        while head < old.count, head < new.count, old[head] == new[head] { head += 1 }
        var tail = 0
        while tail < old.count - head, tail < new.count - head, old[old.count - 1 - tail] == new[new.count - 1 - tail] { tail += 1 }
        let a = Array(old[head..<(old.count - tail)])
        let b = Array(new[head..<(new.count - tail)])
        guard a.count * b.count <= 4_000_000 else { return nil }
        
        var table = [[Int32]](repeating: [Int32](repeating: 0, count: b.count + 1), count: a.count + 1)
        if !a.isEmpty && !b.isEmpty {
            for i in stride(from: a.count - 1, through: 0, by: -1) {
                for j in stride(from: b.count - 1, through: 0, by: -1) {
                    table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
        var result: [(Op, String)] = old[0..<head].map { (Op.same, $0) }
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count, j < b.count, a[i] == b[j] {
                result.append((.same, a[i])); i += 1; j += 1
            } else if j < b.count, i == a.count || table[i][j + 1] >= table[i + 1][j] {
                result.append((.added, b[j])); j += 1
            } else {
                result.append((.removed, a[i])); i += 1
            }
        }
        result.append(contentsOf: old[(old.count - tail)...].map { (Op.same, $0) })
        return result
    }
    
    static func lines(_ data: Data) -> [String]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.components(separatedBy: "\n")
    }
}

final class GitHubChangesViewController: UITableViewController {
    private let sync: GitHubSync
    private let link: GitHubLink
    private let root: URL
    private var sections: [(GitHubChange.Kind, [GitHubChange])]
    private var counts: [String: (added: Int, removed: Int)] = [:]
    private let onPush: () -> Void
    
    init(sync: GitHubSync, link: GitHubLink, root: URL, changes: [GitHubChange], onPush: @escaping () -> Void) {
        self.sync = sync
        self.link = link
        self.root = root
        self.onPush = onPush
        let kinds: [GitHubChange.Kind] = [.modified, .added, .deleted]
        self.sections = kinds.compactMap { kind in
            let items = changes.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Review Changes"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "change")
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Commit…", image: nil, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            let onPush = self.onPush
            self.dismiss(animated: true) { onPush() }
        }, menu: nil)
        loadCounts()
    }
    
    /// +/− per file, computed in the background (base versions come from GitHub).
    private func loadCounts() {
        let sync = self.sync
        let items = sections.flatMap { $0.1 }
        Task { [weak self] in
            for change in items {
                var added = 0, removed = 0
                switch change.kind {
                case .added:
                    if let url = change.localURL, let data = try? Data(contentsOf: url), let lines = LineDiff.lines(data) { added = lines.count }
                case .deleted:
                    if let sha = change.baseSHA, let data = try? await sync.downloadBlob(sha), let lines = LineDiff.lines(data) { removed = lines.count }
                case .modified:
                    guard let sha = change.baseSHA, let url = change.localURL,
                          let base = try? await sync.downloadBlob(sha), let now = try? Data(contentsOf: url),
                          let old = LineDiff.lines(base), let new = LineDiff.lines(now),
                          let ops = LineDiff.diff(old, new) else { continue }
                    added = ops.filter { $0.0 == .added }.count
                    removed = ops.filter { $0.0 == .removed }.count
                }
                await MainActor.run {
                    guard let self else { return }
                    self.counts[change.path] = (added, removed)
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let (kind, items) = sections[section]
        let name = kind == .modified ? "Modified" : kind == .added ? "Added" : "Deleted"
        return "\(name) (\(items.count))"
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == sections.count - 1 else { return nil }
        return "Compared with the last sync of \(link.owner)/\(link.repo) (\(link.branch)). Tap a file to see its lines."
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].1.count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "change", for: indexPath)
        let change = sections[indexPath.section].1[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = change.path
        content.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        content.textProperties.lineBreakMode = .byTruncatingHead
        content.textProperties.numberOfLines = 1
        switch change.kind {
        case .modified:
            content.image = UIImage(systemName: "pencil.circle.fill")
            content.imageProperties.tintColor = .systemOrange
        case .added:
            content.image = UIImage(systemName: "plus.circle.fill")
            content.imageProperties.tintColor = .systemGreen
        case .deleted:
            content.image = UIImage(systemName: "minus.circle.fill")
            content.imageProperties.tintColor = .systemRed
        }
        if let count = counts[change.path] {
            let text = NSMutableAttributedString()
            if count.added > 0 || change.kind == .added {
                text.append(NSAttributedString(string: "+\(count.added) ", attributes: [.foregroundColor: UIColor.systemGreen]))
            }
            if count.removed > 0 || change.kind == .deleted {
                text.append(NSAttributedString(string: "−\(count.removed)", attributes: [.foregroundColor: UIColor.systemRed]))
            }
            content.secondaryAttributedText = text
        } else {
            content.secondaryText = "…"
            content.secondaryTextProperties.color = .tertiaryLabel
        }
        content.prefersSideBySideTextAndSecondaryText = true
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let change = sections[indexPath.section].1[indexPath.row]
        navigationController?.pushViewController(GitHubDiffViewController(sync: sync, change: change), animated: true)
    }
    
    /* fork 1.4.0: swipe to put a file back as it was at the last sync */
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let change = sections[indexPath.section].1[indexPath.row]
        let discard = UIContextualAction(style: .destructive, title: "Discard") { [weak self] _, _, completion in
            guard let self else { completion(false); return }
            let what = change.kind == .added ? "delete this new file" : "put back the version of the last sync"
            let alert = UIAlertController(title: "Discard Changes", message: "\(change.path)\n\nThis will \(what). It cannot be undone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
            alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
                self.discard(change) { ok in completion(ok) }
            })
            self.present(alert, animated: true)
        }
        discard.image = UIImage(systemName: "arrow.uturn.backward")
        return UISwipeActionsConfiguration(actions: [discard])
    }
    
    private func discard(_ change: GitHubChange, completion: @escaping (Bool) -> Void) {
        let sync = self.sync
        let target = root.appendingPathComponent(change.path)
        Task { [weak self] in
            var failure: String?
            do {
                if change.kind == .added {
                    try FileManager.default.removeItem(at: target)
                } else if let sha = change.baseSHA {
                    let data = try await sync.downloadBlob(sha)
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: target, options: .atomic)
                }
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run {
                guard let self else { return }
                if let failure {
                    self.forkGitHubAlert("Discard Failed", failure)
                    completion(false)
                    return
                }
                /* an open tab of that file shows the restored text */
                if let live = LiveEditorRegistry.editor(forPath: target.path), change.kind != .added,
                   let text = try? String(contentsOf: target, encoding: .utf8) {
                    live.replaceWholeText(text)
                }
                for index in self.sections.indices {
                    self.sections[index].1.removeAll { $0.path == change.path }
                }
                self.sections.removeAll { $0.1.isEmpty }
                self.tableView.reloadData()
                completion(true)
                if self.sections.isEmpty {
                    self.dismiss(animated: true)
                }
            }
        }
    }
}

final class GitHubDiffViewController: UIViewController {
    private let sync: GitHubSync
    private let change: GitHubChange
    private let textView = UITextView()
    
    init(sync: GitHubSync, change: GitHubChange) {
        self.sync = sync
        self.change = change
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = (change.path as NSString).lastPathComponent
        view.backgroundColor = .systemBackground
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        textView.text = "Loading…"
        load()
    }
    
    private func load() {
        let sync = self.sync
        let change = self.change
        Task { [weak self] in
            var old: [String] = []
            var new: [String] = []
            var failure: String?
            do {
                if let sha = change.baseSHA {
                    let data = try await sync.downloadBlob(sha)
                    guard let lines = LineDiff.lines(data) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                    old = lines
                }
                if let url = change.localURL {
                    let data = try Data(contentsOf: url)
                    guard let lines = LineDiff.lines(data) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                    new = lines
                }
            } catch let error as CocoaError where error.code == .fileReadInapplicableStringEncoding {
                failure = "Binary file — no line view."
            } catch {
                failure = error.localizedDescription
            }
            let rendered = failure == nil ? GitHubDiffViewController.render(old: old, new: new) : nil
            await MainActor.run {
                guard let self else { return }
                if let rendered {
                    self.textView.attributedText = rendered
                } else {
                    self.textView.text = failure ?? "The file is too large to compare here."
                }
            }
        }
    }
    
    /// Unified view: changed lines with 3 lines of context, "⋯" between hunks.
    static func render(old: [String], new: [String]) -> NSAttributedString? {
        guard let ops = LineDiff.diff(old, new) else { return nil }
        let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let output = NSMutableAttributedString()
        let context = 3
        var keep = [Bool](repeating: false, count: ops.count)
        for (index, op) in ops.enumerated() where op.0 != .same {
            for k in max(0, index - context)...min(ops.count - 1, index + context) { keep[k] = true }
        }
        var oldLine = 0, newLine = 0
        var skipped = false
        for (index, op) in ops.enumerated() {
            switch op.0 {
            case .same: oldLine += 1; newLine += 1
            case .removed: oldLine += 1
            case .added: newLine += 1
            }
            guard keep[index] else { skipped = true; continue }
            if skipped {
                output.append(NSAttributedString(string: "⋯\n", attributes: [.font: font, .foregroundColor: UIColor.tertiaryLabel]))
                skipped = false
            }
            let number = op.0 == .removed ? oldLine : newLine
            let prefix = op.0 == .added ? "+" : op.0 == .removed ? "−" : " "
            let line = String(format: "%5d %@ ", number, prefix) + op.1 + "\n"
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
            if op.0 == .added { attributes[.backgroundColor] = UIColor.systemGreen.withAlphaComponent(0.18) }
            if op.0 == .removed { attributes[.backgroundColor] = UIColor.systemRed.withAlphaComponent(0.18) }
            if op.0 == .same { attributes[.foregroundColor] = UIColor.secondaryLabel }
            output.append(NSAttributedString(string: line, attributes: attributes))
        }
        if output.length == 0 {
            output.append(NSAttributedString(string: "Only line endings or whitespace at the end changed.", attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel]))
        }
        return output
    }
}

// MARK: - Fork: iPhone console for the running app

/// Keeps one console for the app run from the iPhone project menu; shown as its own window in the switcher.
final class ForkPhoneConsole: NSObject, PEProcessObserver {
    static let shared = ForkPhoneConsole()
    
    private(set) lazy var console: NXConsoleView = {
        /* its initializer is failable in Swift; it only fails when out of memory */
        guard let console = NXConsoleView() else { fatalError("NXConsoleView could not be created") }
        console.isEditable = true
        console.isSelectable = true
        console.backgroundColor = LDETheme.currentTheme?.backgroundColor
        console.textColor = LDETheme.currentTheme?.textColor
        return console
    }()
    private weak var session: ForkConsoleSession?
    private(set) weak var process: PEProcess?
    
    /// Spawn items that send stdout / stderr to the console and stdin from it.
    func itemsForNewRun(name: String) -> [AnyHashable: Any] {
        let console = self.console
        console.clearConsole()
        console.writeMessage(toConsole: "▶︎ \(name)", with: .secondaryLabel)
        guard let table = PEFileTable.empty() else { return [:] }
        table.appendFileDescriptor(console.pipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDOUT_FILENO)
        table.appendFileDescriptor(console.pipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDERR_FILENO)
        table.appendFileDescriptor(console.stdinPipe.fileHandleForReading.fileDescriptor, withMappingToLoc: STDIN_FILENO)
        table.appendFileDescriptor(console.pipe.fileHandleForReading.fileDescriptor, withMappingToLoc: 100)
        table.appendFileDescriptor(console.stdinPipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: 101)
        return ["PEFileTable": table]
    }
    
    func attach(processIdentifier: pid_t) {
        process?.remove(self)
        process = nil
        guard processIdentifier > 0, let new = PEProcessManager.shared().process(forProcessIdentifier: processIdentifier) else {
            console.writeMessage(toConsole: "failed to spawn process", with: .systemRed)
            return
        }
        new.add(self)
        process = new
    }
    
    func process(_ process: PEProcess!, didExitWithWait4Code code: Int32) {
        ForkDebugSession.shared.processExited(process)
        DispatchQueue.main.async {
            let signal = code & 0x7F
            if signal == 0 {
                let exit = (code >> 8) & 0xFF
                self.console.writeMessage(toConsole: "process did exit with code: \(exit)", with: exit == 0 ? .systemGreen : .systemRed)
            } else if signal != 0x7F {
                self.console.writeMessage(toConsole: "process was killed by signal: \(signal) (\(PosixSignal(rawValue: signal)?.description ?? "SIGUNKNOWN"))", with: signal == 9 ? .systemRed : .systemYellow)
            }
        }
    }
    
    /// Opens the Console window, or brings it to the front.
    func show() {
        let server = NXWindowServer.shared()
        if let session, session.window != nil {
            server?.activateWindow(forIdentifier: session.windowIdentifier, animated: true, withCompletion: nil)
            return
        }
        let session = ForkConsoleSession()
        self.session = session
        server?.openWindow(with: session, withCompletion: nil)
    }
}

final class ForkConsoleSession: NXWindowSession {
    override var windowName: String! {
        get { "Console" }
        set { super.windowName = newValue }
    }
    
    override func openWindow() -> Bool {
        guard super.openWindow() else { return false }
        let console = ForkPhoneConsole.shared.console
        console.removeFromSuperview()
        console.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = console.backgroundColor
        view.addSubview(console)
        NSLayoutConstraint.activate([
            console.topAnchor.constraint(equalTo: view.topAnchor),
            console.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            console.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            console.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        /* fork: CPU / memory of the app this console belongs to */
        let bar = ForkRuntimeBar { ForkPhoneConsole.shared.process }
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
        ])
        return true
    }
    
    override func closeWindow() -> Bool {
        _ = super.closeWindow()
        ForkPhoneConsole.shared.console.removeFromSuperview()
        return true
    }
}

// MARK: - Fork: branches and history

extension GitHubSync {
    func branches() async throws -> [String] {
        guard let list = try await request("GET", "/branches?per_page=100") as? [[String: Any]] else { throw GitHubSyncError.invalidResponse }
        return list.compactMap { $0["name"] as? String }.sorted()
    }
    
    /// A new branch at `commit`.
    func createBranch(_ name: String, at commit: String) async throws {
        _ = try await request("POST", "/git/refs", body: ["ref": "refs/heads/\(name)", "sha": commit])
    }
    
    /// Replaces the synced files with those of this sync's branch (no local changes allowed).
    func checkout(root: URL, link: inout GitHubLink) async throws -> Int {
        guard let current = try await head() else { throw GitHubSyncError.emptyRepository }
        let remote = try await remoteFiles(tree: current.tree)
        var written = 0
        for (path, sha) in remote where link.files[path] != sha {
            let data = try await downloadBlob(sha)
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            written += 1
        }
        for path in link.files.keys where remote[path] == nil {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(path))
            written += 1
        }
        link.branch = branch
        link.lastCommit = current.commit
        link.files = remote
        return written
    }
    
    struct CommitSummary {
        let sha: String
        let message: String
        let author: String
        let date: Date?
    }
    
    func history(limit: Int = 50) async throws -> [CommitSummary] {
        let encoded = branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? branch
        guard let list = try await request("GET", "/commits?sha=\(encoded)&per_page=\(limit)") as? [[String: Any]] else { throw GitHubSyncError.invalidResponse }
        let formatter = ISO8601DateFormatter()
        return list.compactMap { item in
            guard let sha = item["sha"] as? String, let commit = item["commit"] as? [String: Any] else { return nil }
            let author = commit["author"] as? [String: Any]
            return CommitSummary(
                sha: sha,
                message: commit["message"] as? String ?? "",
                author: author?["name"] as? String ?? "",
                date: (author?["date"] as? String).flatMap { formatter.date(from: $0) })
        }
    }
    
    struct CommitFile {
        let path: String
        let status: String
        let additions: Int
        let deletions: Int
        let patch: String?
    }
    
    func commitFiles(_ sha: String) async throws -> [CommitFile] {
        guard let commit = try await request("GET", "/commits/\(sha)") as? [String: Any],
              let files = commit["files"] as? [[String: Any]] else { throw GitHubSyncError.invalidResponse }
        return files.map {
            CommitFile(path: $0["filename"] as? String ?? "",
                       status: $0["status"] as? String ?? "",
                       additions: $0["additions"] as? Int ?? 0,
                       deletions: $0["deletions"] as? Int ?? 0,
                       patch: $0["patch"] as? String)
        }
    }
}

extension FileListViewController {
    func forkGitHubBranches(_ project: NXProject) {
        guard let context = forkGitHubContext(project) else { return }
        let (sync, link) = context
        let list = GitHubBranchesViewController(project: project, sync: sync, link: link) { [weak self] in
            self?.performRefresh()
        }
        let navigation = UINavigationController(rootViewController: list)
        navigation.modalPresentationStyle = .formSheet
        present(navigation, animated: true)
    }
    
    func forkGitHubHistory(_ project: NXProject) {
        guard let context = forkGitHubContext(project) else { return }
        let (sync, link) = context
        let navigation = UINavigationController(rootViewController: GitHubHistoryViewController(sync: sync, link: link))
        navigation.modalPresentationStyle = .formSheet
        present(navigation, animated: true)
    }
}

final class GitHubBranchesViewController: UITableViewController {
    private let project: NXProject
    private var sync: GitHubSync
    private var link: GitHubLink
    private var branches: [String] = []
    private let onSwitch: () -> Void
    
    init(project: NXProject, sync: GitHubSync, link: GitHubLink, onSwitch: @escaping () -> Void) {
        self.project = project
        self.sync = sync
        self.link = link
        self.onSwitch = onSwitch
        super.init(style: .insetGrouped)
        title = "Branches"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "branch")
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.promptNewBranch() })
        reload()
    }
    
    private func reload() {
        let sync = self.sync
        Task { [weak self] in
            do {
                let names = try await sync.branches()
                await MainActor.run {
                    self?.branches = names
                    self?.tableView.reloadData()
                }
            } catch {
                await MainActor.run { self?.forkGitHubAlert("Branches", error.localizedDescription) }
            }
        }
    }
    
    private var hasLocalChanges: Bool {
        let root: URL = project.url
        return !GitHubChange.localChanges(root: root, link: link).isEmpty
    }
    
    private func promptNewBranch() {
        let alert = UIAlertController(title: "New Branch", message: "Starts from \(link.branch) as it is now. Your files stay as they are; the next push goes to the new branch.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "feature-name"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let name = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "-")
            guard !name.isEmpty else { return }
            let sync = self.sync
            let base = self.link.lastCommit
            Task { [weak self] in
                do {
                    var start = base
                    if start == nil { start = try await sync.head()?.commit }
                    guard let commit = start else { throw GitHubSyncError.emptyRepository }
                    try await sync.createBranch(name, at: commit)
                    await MainActor.run {
                        guard let self else { return }
                        self.link.branch = name
                        try? self.link.save(for: self.project)
                        self.sync = GitHubSync(token: sync.token, owner: sync.owner, repo: sync.repo, branch: name)
                        self.reload()
                    }
                } catch {
                    await MainActor.run { self?.forkGitHubAlert("New Branch", error.localizedDescription) }
                }
            }
        })
        present(alert, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { branches.count }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "\(link.owner)/\(link.repo). Switching downloads the other branch's files; it needs no unpushed changes."
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "branch", for: indexPath)
        let name = branches[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = name
        content.image = UIImage(systemName: "arrow.triangle.branch")
        cell.contentConfiguration = content
        cell.accessoryType = name == link.branch ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let name = branches[indexPath.row]
        guard name != link.branch else { return }
        guard !hasLocalChanges else {
            forkGitHubAlert("Unpushed Changes", "Push or discard your changes (Commit and Push… > swipe a file) before switching to \(name).")
            return
        }
        let target = GitHubSync(token: sync.token, owner: sync.owner, repo: sync.repo, branch: name)
        let project = self.project
        let current = self.link
        let onSwitch = self.onSwitch
        forkRunGitHubTask("Switch to \(name)", finished: { [weak self] in
            if let updated = GitHubLink.load(for: project) { self?.link = updated }
            self?.sync = target
            self?.tableView.reloadData()
            onSwitch()
        }) {
            var state = current
            let root: URL = project.url
            let changed = try await target.checkout(root: root, link: &state)
            try state.save(for: project)
            return "\(changed) file\(changed == 1 ? "" : "s") changed. Close and reopen open tabs to see the new contents."
        }
    }
}

final class GitHubHistoryViewController: UITableViewController {
    private let sync: GitHubSync
    private let link: GitHubLink
    private var commits: [GitHubSync.CommitSummary] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(sync: GitHubSync, link: GitHubLink) {
        self.sync = sync
        self.link = link
        super.init(style: .insetGrouped)
        title = "History · \(link.branch)"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "commit")
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        let sync = self.sync
        Task { [weak self] in
            do {
                let list = try await sync.history()
                await MainActor.run {
                    self?.commits = list
                    self?.tableView.reloadData()
                }
            } catch {
                await MainActor.run { self?.forkGitHubAlert("History", error.localizedDescription) }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { commits.count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "commit", for: indexPath)
        let commit = commits[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = commit.message.components(separatedBy: "\n").first ?? commit.message
        var detail = String(commit.sha.prefix(7)) + " · " + commit.author
        if let date = commit.date { detail += " · " + dateFormatter.string(from: date) }
        if commit.sha == link.lastCommit { detail += " · this project" }
        content.secondaryText = detail
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(GitHubCommitViewController(sync: sync, commit: commits[indexPath.row]), animated: true)
    }
}

/// One commit: its files with +/− and GitHub's patch, colored.
final class GitHubCommitViewController: UIViewController {
    private let sync: GitHubSync
    private let commit: GitHubSync.CommitSummary
    private let textView = UITextView()
    
    init(sync: GitHubSync, commit: GitHubSync.CommitSummary) {
        self.sync = sync
        self.commit = commit
        super.init(nibName: nil, bundle: nil)
        title = String(commit.sha.prefix(7))
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        textView.text = "Loading…"
        let sync = self.sync
        let commit = self.commit
        Task { [weak self] in
            do {
                let files = try await sync.commitFiles(commit.sha)
                let rendered = GitHubCommitViewController.render(commit: commit, files: files)
                await MainActor.run { self?.textView.attributedText = rendered }
            } catch {
                await MainActor.run { self?.textView.text = error.localizedDescription }
            }
        }
    }
    
    static func render(commit: GitHubSync.CommitSummary, files: [GitHubSync.CommitFile]) -> NSAttributedString {
        let mono = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let bold = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        let output = NSMutableAttributedString()
        output.append(NSAttributedString(string: commit.message + "\n\n", attributes: [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.label]))
        for file in files {
            output.append(NSAttributedString(string: "\(file.status.capitalized)  \(file.path)  ", attributes: [.font: bold, .foregroundColor: UIColor.label]))
            output.append(NSAttributedString(string: "+\(file.additions) ", attributes: [.font: bold, .foregroundColor: UIColor.systemGreen]))
            output.append(NSAttributedString(string: "−\(file.deletions)\n", attributes: [.font: bold, .foregroundColor: UIColor.systemRed]))
            guard let patch = file.patch else {
                output.append(NSAttributedString(string: "(no line view: binary or too large)\n\n", attributes: [.font: mono, .foregroundColor: UIColor.secondaryLabel]))
                continue
            }
            for line in patch.components(separatedBy: "\n") {
                var attributes: [NSAttributedString.Key: Any] = [.font: mono, .foregroundColor: UIColor.secondaryLabel]
                if line.hasPrefix("+") {
                    attributes[.foregroundColor] = UIColor.label
                    attributes[.backgroundColor] = UIColor.systemGreen.withAlphaComponent(0.18)
                } else if line.hasPrefix("-") {
                    attributes[.foregroundColor] = UIColor.label
                    attributes[.backgroundColor] = UIColor.systemRed.withAlphaComponent(0.18)
                } else if line.hasPrefix("@@") {
                    attributes[.foregroundColor] = UIColor.systemBlue
                }
                output.append(NSAttributedString(string: line + "\n", attributes: attributes))
            }
            output.append(NSAttributedString(string: "\n", attributes: [.font: mono]))
        }
        return output
    }
}

// MARK: - Fork: export assistant

/// Version, build number and pre-flight checks before Nyxian builds the .ipa.
final class ForkExportAssistant: UITableViewController {
    struct Check {
        let title: String
        let detail: String
        let ok: Bool
        let fix: (() -> Void)?
    }
    
    /// API used in the code -> Info.plist key it needs, with a starting text.
    private static let permissionHints: [(token: String, key: String, text: String)] = [
        ("AVCaptureDevice", "NSCameraUsageDescription", "This app uses the camera."),
        ("AVCaptureSession", "NSCameraUsageDescription", "This app uses the camera."),
        ("UIImagePickerController", "NSCameraUsageDescription", "This app uses the camera."),
        ("requestRecordPermission", "NSMicrophoneUsageDescription", "This app uses the microphone."),
        ("AVAudioRecorder", "NSMicrophoneUsageDescription", "This app uses the microphone."),
        ("PHPhotoLibrary", "NSPhotoLibraryUsageDescription", "This app reads your photo library."),
        ("CLLocationManager", "NSLocationWhenInUseUsageDescription", "This app uses your location."),
        ("CNContactStore", "NSContactsUsageDescription", "This app reads your contacts."),
        ("EKEventStore", "NSCalendarsFullAccessUsageDescription", "This app uses your calendar."),
        ("LAContext", "NSFaceIDUsageDescription", "This app uses Face ID."),
        ("CBCentralManager", "NSBluetoothAlwaysUsageDescription", "This app uses Bluetooth."),
        ("SFSpeechRecognizer", "NSSpeechRecognitionUsageDescription", "This app recognizes speech."),
        ("CMMotionManager", "NSMotionUsageDescription", "This app uses motion data."),
        ("CMPedometer", "NSMotionUsageDescription", "This app uses motion data."),
        ("HKHealthStore", "NSHealthShareUsageDescription", "This app reads health data.")
    ]
    
    private let project: NXProject
    private weak var presenter: UIViewController?
    private var version = "1.0"
    private var build = "1"
    private var checks: [Check] = []
    
    static func present(from presenter: UIViewController, project: NXProject) {
        let assistant = ForkExportAssistant(project: project, presenter: presenter)
        let navigation = UINavigationController(rootViewController: assistant)
        navigation.modalPresentationStyle = .formSheet
        presenter.present(navigation, animated: true)
    }
    
    private init(project: NXProject, presenter: UIViewController) {
        self.project = project
        self.presenter = presenter
        super.init(style: .insetGrouped)
        title = "Export .ipa"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private var plistURL: URL {
        let root: URL = project.url
        return root.appendingPathComponent("Config/Project.plist")
    }
    
    private func readPlist() -> [String: Any] {
        guard let data = try? Data(contentsOf: plistURL),
              let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return [:] }
        return plist
    }
    
    private func writeVersions() {
        var plist = readPlist()
        guard !plist.isEmpty else { return }
        plist["NXBundleShortVersion"] = version
        plist["NXBundleVersion"] = build
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: plistURL, options: .atomic)
        }
        _ = project.reload()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let plist = readPlist()
        build = plist["NXBundleVersion"] as? String ?? "1"
        version = plist["NXBundleShortVersion"] as? String ?? build
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Export", image: nil, primaryAction: UIAction { [weak self] _ in self?.export() }, menu: nil)
        runChecks()
    }
    
    private func runChecks() {
        let config = project.projectConfig!
        let info = config.infoDictionary ?? [:]
        var result: [Check] = []
        
        let bundleID = config.bundleid ?? ""
        let defaultID = bundleID.isEmpty || bundleID.hasPrefix("com.example.")
        result.append(Check(title: "Bundle identifier", detail: bundleID.isEmpty ? "missing" : bundleID, ok: !defaultID, fix: nil))
        
        let hasIcon = info["CFBundleIcons"] != nil || info["CFBundleIconFiles"] != nil
        result.append(Check(title: "App icon", detail: hasIcon ? "set" : "none — long-press the project in the list > Set App Icon…", ok: hasIcon, fix: nil))
        
        /* permissions the code uses but the Info.plist does not explain (iOS closes the app when it asks) */
        let root: URL = project.url
        var sources = ""
        for url in ProjectFileIndex.files(in: root) where ["swift", "m", "mm", "c", "cpp", "h"].contains(url.pathExtension.lowercased()) {
            sources += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            sources += "\n"
        }
        var seenKeys: Set<String> = []
        for hint in Self.permissionHints where sources.contains(hint.token) && !seenKeys.contains(hint.key) {
            seenKeys.insert(hint.key)
            let present = (info[hint.key] as? String).map { !$0.isEmpty } ?? false
            let project = self.project
            result.append(Check(
                title: hint.key,
                detail: present ? "described" : "\(hint.token) is used but there is no description — the app would crash when it asks",
                ok: present,
                fix: present ? nil : { [weak self] in
                    self?.promptDescription(key: hint.key, text: hint.text, project: project)
                }))
        }
        if sources.contains("BGTaskScheduler") {
            let ok = info["BGTaskSchedulerPermittedIdentifiers"] != nil && info["UIBackgroundModes"] != nil
            result.append(Check(title: "Background tasks", detail: ok ? "identifiers and modes set" : "BGTaskScheduler needs BGTaskSchedulerPermittedIdentifiers and UIBackgroundModes in the Info.plist (Config/Project.plist > NXBundleInfo)", ok: ok, fix: nil))
        }
        checks = result
        tableView.reloadData()
    }
    
    private func promptDescription(key: String, text: String, project: NXProject) {
        let alert = UIAlertController(title: key, message: "The sentence iOS shows when the app asks for permission.", preferredStyle: .alert)
        alert.addTextField { $0.text = text }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !value.isEmpty else { return }
            var values: [String: Any] = [key: value]
            if key == "NSCalendarsFullAccessUsageDescription" { values["NSCalendarsUsageDescription"] = value }
            ForkCapabilities.mergeIntoBundleInfo(values, project: project)
            self?.runChecks()
        })
        present(alert, animated: true)
    }
    
    private func export() {
        view.endEditing(true)
        writeVersions()
        let project = self.project
        let presenter = self.presenter
        dismiss(animated: true) {
            guard let presenter else { return }
            buildProjectWithArgumentUI(targetViewController: presenter, project: project, buildType: .export)
        }
    }
    
    // MARK: table
    
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Version", "Checks", nil][section]
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Saved in the project. Raise the build number for every .ipa you install over an older one."
        case 2: return "Nyxian builds the app and packs it as an .ipa that is not signed for distribution: sign it with your own certificate (or a signing service) to install it outside Nyxian. TestFlight / App Store uploads need Xcode or Transporter on a Mac."
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [2, checks.count, 1][section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        cell.accessoryType = .none
        cell.selectionStyle = .default
        switch indexPath.section {
        case 0:
            content.text = indexPath.row == 0 ? "Version" : "Build"
            content.secondaryText = indexPath.row == 0 ? version : build
            content.prefersSideBySideTextAndSecondaryText = true
            cell.accessoryType = .disclosureIndicator
        case 1:
            let check = checks[indexPath.row]
            content.text = check.title
            content.secondaryText = check.detail
            content.secondaryTextProperties.color = check.ok ? .secondaryLabel : .systemOrange
            content.image = UIImage(systemName: check.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            content.imageProperties.tintColor = check.ok ? .systemGreen : .systemOrange
            if check.fix != nil { cell.accessoryType = .disclosureIndicator } else { cell.selectionStyle = .none }
        default:
            content.text = "Export .ipa"
            content.textProperties.color = .tintColor
            content.image = UIImage(systemName: "archivebox.fill")
        }
        cell.contentConfiguration = content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let isVersion = indexPath.row == 0
            let alert = UIAlertController(title: isVersion ? "Version" : "Build", message: isVersion ? "Shown to people, e.g. 1.2.0" : "A number that grows with every build, e.g. 7", preferredStyle: .alert)
            alert.addTextField { field in
                field.text = isVersion ? self.version : self.build
                field.keyboardType = isVersion ? .numbersAndPunctuation : .numberPad
            }
            if !isVersion, let number = Int(build) {
                alert.addAction(UIAlertAction(title: "Use \(number + 1)", style: .default) { [weak self] _ in
                    self?.build = "\(number + 1)"
                    self?.tableView.reloadData()
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
                let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
                guard let self, !value.isEmpty else { return }
                if isVersion { self.version = value } else { self.build = value }
                self.tableView.reloadData()
            })
            present(alert, animated: true)
        case 1:
            checks[indexPath.row].fix?()
        default:
            export()
        }
    }
}

// MARK: - Fork: profiler (CPU, memory, threads)

/// A small pill with live numbers of the running app; tap for the last minute as graphs.
final class ForkProfilerView: UIControl {
    struct Sample {
        let cpu: Double
        let memory: Double
        let threads: Int
    }
    
    private let provider: () -> PEProcess?
    private let label = UILabel()
    private var timer: Timer?
    private(set) var samples: [Sample] = []
    private weak var graphs: ForkProfilerGraphsViewController?
    
    init(provider: @escaping () -> PEProcess?) {
        self.provider = provider
        super.init(frame: .zero)
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        layer.cornerRadius = 11
        layer.cornerCurve = .continuous
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9)
        ])
        isHidden = true
        addAction(UIAction { [weak self] _ in self?.showGraphs() }, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// Pins the pill to the top-right corner of `container`.
    func attach(to container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 8),
            trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor, constant: -10)
        ])
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    
    private func tick() {
        guard let process = provider() else {
            isHidden = true
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let usage = process.forkResourceUsage()
            DispatchQueue.main.async {
                guard let self else { return }
                guard let usage,
                      let cpu = usage["cpu"]?.doubleValue,
                      let memory = usage["memory"]?.doubleValue,
                      let threads = usage["threads"]?.intValue else {
                    self.isHidden = true
                    return
                }
                self.samples.append(Sample(cpu: cpu, memory: memory, threads: threads))
                if self.samples.count > 60 { self.samples.removeFirst(self.samples.count - 60) }
                self.label.text = String(format: "CPU %.0f%%  ·  %@  ·  %d threads", cpu, ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory), threads)
                self.isHidden = false
                self.superview?.bringSubviewToFront(self)
                self.graphs?.update(self.samples)
            }
        }
    }
    
    private func showGraphs() {
        guard let presenter = sequence(first: self as UIResponder, next: { $0.next }).first(where: { $0 is UIViewController }) as? UIViewController else { return }
        let graphs = ForkProfilerGraphsViewController()
        graphs.update(samples)
        self.graphs = graphs
        let navigation = UINavigationController(rootViewController: graphs)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        presenter.present(navigation, animated: true)
    }
}

final class ForkProfilerGraphsViewController: UIViewController {
    private let cpuGraph = ForkSparklineView(color: .systemTeal)
    private let memoryGraph = ForkSparklineView(color: .systemPurple)
    private let cpuLabel = UILabel()
    private let memoryLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if title == nil { title = "Profiler" }
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        /* fork: every process, from the profiler of one */
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "All Processes", image: UIImage(systemName: "cpu"), primaryAction: UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(ForkProcessMonitorViewController(style: .insetGrouped), animated: true)
        })
        for label in [cpuLabel, memoryLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            label.numberOfLines = 2
        }
        let note = UILabel()
        note.text = "Last 60 seconds, one sample per second. CPU 100% = one core fully busy."
        note.font = .preferredFont(forTextStyle: .footnote)
        note.textColor = .secondaryLabel
        note.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [cpuLabel, cpuGraph, memoryLabel, memoryGraph, note])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(22, after: cpuGraph)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            cpuGraph.heightAnchor.constraint(equalToConstant: 110),
            memoryGraph.heightAnchor.constraint(equalToConstant: 110)
        ])
    }
    
    func update(_ samples: [ForkProfilerView.Sample]) {
        loadViewIfNeeded()
        let cpu = samples.map { $0.cpu }
        let memory = samples.map { $0.memory }
        cpuGraph.values = cpu
        memoryGraph.values = memory
        let peakCPU = cpu.max() ?? 0
        let peakMemory = memory.max() ?? 0
        cpuLabel.text = String(format: "CPU  now %.0f%%   peak %.0f%%", cpu.last ?? 0, peakCPU)
        memoryLabel.text = "Memory  now \(ByteCountFormatter.string(fromByteCount: Int64(memory.last ?? 0), countStyle: .memory))   peak \(ByteCountFormatter.string(fromByteCount: Int64(peakMemory), countStyle: .memory))"
    }
}

final class ForkSparklineView: UIView {
    private let color: UIColor
    var values: [Double] = [] { didSet { setNeedsDisplay() } }
    
    init(color: UIColor) {
        self.color = color
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        clipsToBounds = true
        contentMode = .redraw
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func draw(_ rect: CGRect) {
        guard values.count > 1 else { return }
        let inset = bounds.insetBy(dx: 6, dy: 8)
        let top = max(values.max() ?? 1, 1)
        let step = inset.width / CGFloat(max(59, values.count - 1))
        let startX = inset.maxX - step * CGFloat(values.count - 1)
        let line = UIBezierPath()
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: startX + step * CGFloat(index), y: inset.maxY - inset.height * CGFloat(value / top))
            index == 0 ? line.move(to: point) : line.addLine(to: point)
        }
        let area = line.copy() as! UIBezierPath
        area.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        area.addLine(to: CGPoint(x: startX, y: inset.maxY))
        area.close()
        color.withAlphaComponent(0.18).setFill()
        area.fill()
        color.setStroke()
        line.lineWidth = 2
        line.lineJoinStyle = .round
        line.stroke()
    }
}

// MARK: - Fork: Metal helper file

extension FileListViewController {
    func forkAddMetalHelper(_ project: NXProject) {
        let root: URL = project.url
        let helper = root.appendingPathComponent("MetalLibrary+App.swift")
        let shader = root.appendingPathComponent("Shaders.metal")
        let fm = FileManager.default
        if !fm.fileExists(atPath: helper.path) {
            try? """
            import Metal
            
            extension MTLDevice {
                /// The app's shaders. Built by Xcode: the compiled default library.
                /// Built by Nyxian (no Metal compiler on iOS): the .metal sources of the project,
                /// which Nyxian copies into the app as NyxianShaders.metal, compiled here at run time.
                func makeAppLibrary() throws -> MTLLibrary {
                    if let library = makeDefaultLibrary() {
                        return library
                    }
                    guard let url = Bundle.main.url(forResource: "NyxianShaders", withExtension: "metal") else {
                        throw NSError(domain: "Metal", code: 1, userInfo: [NSLocalizedDescriptionKey: "No shaders: add a .metal file to the project."])
                    }
                    return try makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
                }
            }
            
            """.write(to: helper, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: shader.path) {
            try? """
            #include <metal_stdlib>
            using namespace metal;
            
            // Example: a full-color fragment function. Load it with
            // try device.makeAppLibrary().makeFunction(name: "solidColor")
            fragment float4 solidColor() {
                return float4(0.2, 0.6, 1.0, 1.0);
            }
            
            """.write(to: shader, atomically: true, encoding: .utf8)
        }
        performRefresh()
        forkGitHubAlert("Metal Helper", "Added MetalLibrary+App.swift and Shaders.metal. Load your shaders with:\n\nlet library = try device.makeAppLibrary()\n\nNyxian puts every .metal file of the project into the app and compiles them on the device; Xcode builds still use the compiled library.")
    }
}

// MARK: - Fork: debugger (breakpoints, session, controls)

/// Line breakpoints per project, by project-relative path. Kept in UserDefaults.
enum ForkBreakpoints {
    static let changed = Notification.Name("ForkBreakpointsChanged")
    
    private static func key(_ project: NXProject) -> String {
        let root: URL = project.url
        return "fork.breakpoints." + root.lastPathComponent
    }
    
    private static func load(_ project: NXProject) -> [String: [Int]] {
        UserDefaults.standard.dictionary(forKey: key(project)) as? [String: [Int]] ?? [:]
    }
    
    static func lines(project: NXProject, url: URL) -> [Int] {
        let root: URL = project.url
        return (load(project)[ProjectFileIndex.relativePath(url, root: root)] ?? []).sorted()
    }
    
    static func toggle(project: NXProject, url: URL, line: Int) {
        let root: URL = project.url
        let relative = ProjectFileIndex.relativePath(url, root: root)
        var all = load(project)
        var lines = Set(all[relative] ?? [])
        if lines.contains(line) { lines.remove(line) } else { lines.insert(line) }
        all[relative] = lines.isEmpty ? nil : Array(lines).sorted()
        UserDefaults.standard.set(all, forKey: key(project))
        NotificationCenter.default.post(name: changed, object: project)
    }
    
    static func removeAll(project: NXProject) {
        UserDefaults.standard.removeObject(forKey: key(project))
        NotificationCenter.default.post(name: changed, object: project)
    }
    
    /// For NXForkDebugger: absolute paths and lines.
    static func all(project: NXProject) -> [[String: Any]] {
        let root: URL = project.url
        return load(project).sorted { $0.key < $1.key }.flatMap { relative, lines in
            lines.map { ["path": root.appendingPathComponent(relative).path, "line": $0] }
        }
    }
}

/// Attaches the debugger to each app Nyxian runs and relays its stops to the UI.
final class ForkDebugSession {
    static let shared = ForkDebugSession()
    static let stateChanged = Notification.Name("ForkDebuggerStateChanged")
    static let stopped = Notification.Name("ForkDebuggerStopped")
    
    private(set) var project: NXProject?
    private(set) var lastStop: [String: Any]?
    private(set) var stopNumber = 0
    private weak var process: PEProcess?
    private var observer: NSObjectProtocol?
    
    /// Customization > "Debugger" (on by default)
    /// Off by default since 1.28: its debug info made every build slower.
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: "fork.debugger") }
    var debugger: NXForkDebugger { NXForkDebugger.shared() }
    
    private init() {
        debugger.stopHandler = { [weak self] stop in
            guard let self else { return }
            self.stopNumber += 1
            self.lastStop = stop
            if UIDevice.current.userInterfaceIdiom != .pad {
                ForkPhoneConsole.shared.show()
            } else if let threads = stop["threads"] as? [[String: Any]],
                      let index = stop["thread"] as? Int, index < threads.count,
                      let frames = threads[index]["frames"] as? [[String: Any]],
                      let top = frames.first(where: { $0["file"] != nil }),
                      let file = top["file"] as? String, let line = top["line"] as? Int,
                      FileManager.default.fileExists(atPath: file) {
                /* iPad: show the line in the editor */
                NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open", file, "\(line)", "1", "0"])
            }
            NotificationCenter.default.post(name: ForkDebugSession.stopped, object: nil)
        }
        debugger.stateHandler = { [weak self] in
            guard let self else { return }
            if !self.debugger.stopped { self.lastStop = nil }
            NotificationCenter.default.post(name: ForkDebugSession.stateChanged, object: nil)
        }
        observer = NotificationCenter.default.addObserver(forName: ForkBreakpoints.changed, object: nil, queue: .main) { [weak self] note in
            guard let self, let project = self.project, let changed = note.object as? NXProject,
                  (changed.url as URL).path == (project.url as URL).path else { return }
            self.debugger.setBreakpoints(ForkBreakpoints.all(project: project))
        }
    }
    
    /// Called right after a run spawned the app.
    func start(processIdentifier pid: pid_t, project: NXProject) {
        guard isEnabled, pid > 0 else { return }
        self.project = project
        self.lastStop = nil
        let executable = (project.machoURL as URL).path
        let objects = (project.cacheURL as URL).path
        let breakpoints = ForkBreakpoints.all(project: project)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.debugger.setBreakpoints(breakpoints)
            /* the task port reaches Nyxian a moment after the spawn */
            for _ in 0..<50 {
                if let process = PEProcessManager.shared().process(forProcessIdentifier: pid) {
                    self.process = process
                    if self.debugger.attach(to: process, executablePath: executable, objectRoot: objects) { return }
                }
                usleep(100_000)
            }
        }
    }
    
    func processExited(_ process: PEProcess?) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            if process == nil || process === self.process {
                self.debugger.detach()
            }
        }
    }
}

/// Pause / Continue and the current state, left of the profiler pill.
final class ForkDebugControlView: UIView {
    private let button = UIButton(type: .system)
    private let label = UILabel()
    private var presentedStop = 0
    private var observers: [NSObjectProtocol] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        layer.cornerRadius = 11
        layer.cornerCurve = .continuous
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.lineBreakMode = .byTruncatingMiddle
        button.addAction(UIAction { [weak self] _ in self?.tapped() }, for: .touchUpInside)
        let details = UIButton(type: .system)
        details.setImage(UIImage(systemName: "list.bullet.rectangle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
        details.addAction(UIAction { [weak self] _ in self?.showStop(force: true) }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [button, label, details])
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 220)
        ])
        for name in [ForkDebugSession.stateChanged, ForkDebugSession.stopped] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.refresh()
                if note.name == ForkDebugSession.stopped { self?.showStop(force: false) }
            })
        }
        refresh()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
        /* a stop that happened while this window was being opened */
        if window != nil, ForkDebugSession.shared.lastStop != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showStop(force: false) }
        }
    }
    
    private func refresh() {
        let debugger = NXForkDebugger.shared()
        isHidden = !debugger.attached
        let symbol = debugger.stopped ? "play.fill" : "pause.fill"
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)), for: .normal)
        button.tintColor = debugger.stopped ? .systemGreen : .label
        label.text = debugger.stopped ? (ForkDebugSession.shared.lastStop?["message"] as? String ?? "Stopped") : debugger.status
        label.textColor = debugger.stopped ? .systemOrange : .secondaryLabel
    }
    
    private func tapped() {
        let debugger = NXForkDebugger.shared()
        if debugger.stopped {
            debugger.resume()
        } else {
            DispatchQueue.global(qos: .userInitiated).async { _ = debugger.pause() }
        }
    }
    
    private func showStop(force: Bool) {
        let session = ForkDebugSession.shared
        guard window != nil, let stop = session.lastStop else { return }
        guard force || presentedStop != session.stopNumber else { return }
        guard let presenter = sequence(first: self as UIResponder, next: { $0.next }).first(where: { $0 is UIViewController }) as? UIViewController,
              presenter.presentedViewController == nil else { return }
        presentedStop = session.stopNumber
        let navigation = UINavigationController(rootViewController: ForkStopViewController(stop: stop, project: session.project))
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        presenter.present(navigation, animated: true)
    }
}

/// Debugger controls + profiler, side by side.
final class ForkRuntimeBar: UIStackView {
    init(provider: @escaping () -> PEProcess?) {
        super.init(frame: .zero)
        axis = .horizontal
        spacing = 8
        alignment = .center
        addArrangedSubview(ForkDebugControlView())
        addArrangedSubview(ForkProfilerView(provider: provider))
    }
    
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Where the app stopped: every thread with its frames; tap a frame with source to open it.
final class ForkStopViewController: UITableViewController {
    private let stop: [String: Any]
    private let project: NXProject?
    private let threads: [(name: String, frames: [[String: Any]])]
    
    init(stop: [String: Any], project: NXProject?) {
        self.stop = stop
        self.project = project
        var list: [(String, [[String: Any]])] = []
        let raw = stop["threads"] as? [[String: Any]] ?? []
        let stoppedIndex = stop["thread"] as? Int ?? 0
        for (index, thread) in raw.enumerated() {
            let entry = (thread["name"] as? String ?? "Thread", thread["frames"] as? [[String: Any]] ?? [])
            if index == stoppedIndex { list.insert(entry, at: 0) } else { list.append(entry) }
        }
        self.threads = list.map { (name: $0.0, frames: $0.1) }
        super.init(style: .insetGrouped)
        let reason = stop["reason"] as? String ?? ""
        title = reason == "breakpoint" ? "Breakpoint" : reason == "pause" ? "Paused" : "Stopped"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "frame")
        navigationItem.prompt = stop["message"] as? String
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Continue", image: UIImage(systemName: "play.fill"), primaryAction: UIAction { [weak self] _ in
            NXForkDebugger.shared().resume()
            self?.dismiss(animated: true)
        }, menu: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { threads.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 && (stop["reason"] as? String) != "pause" ? threads[section].name + " — stopped here" : threads[section].name
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { threads[section].frames.count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "frame", for: indexPath)
        let frame = threads[indexPath.section].frames[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = "\(indexPath.row)  " + (frame["symbol"] as? String ?? "?")
        content.textProperties.font = .monospacedSystemFont(ofSize: 12, weight: frame["file"] != nil ? .semibold : .regular)
        content.textProperties.color = frame["file"] != nil ? .label : .secondaryLabel
        content.textProperties.numberOfLines = 2
        if let file = frame["file"] as? String, let line = frame["line"] as? Int {
            content.secondaryText = "\((file as NSString).lastPathComponent):\(line)"
            content.secondaryTextProperties.color = .systemBlue
            cell.accessoryType = .disclosureIndicator
        } else {
            content.secondaryText = nil
            cell.accessoryType = .none
        }
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.contentConfiguration = content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let frame = threads[indexPath.section].frames[indexPath.row]
        guard let file = frame["file"] as? String, let line = frame["line"] as? Int, FileManager.default.fileExists(atPath: file) else { return }
        if UIDevice.current.userInterfaceIdiom == .pad {
            dismiss(animated: true) {
                NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open", file, "\(line)", "1", "0"])
            }
        } else if let editor = CodeEditorViewController(project: project, url: URL(fileURLWithPath: file), line: line, column: 1, isReadOnly: true) {
            navigationController?.pushViewController(editor, animated: true)
        }
    }
}

// MARK: - Fork: preview of pictures and documents

import QuickLook

/// Pictures (a plot saved by a Python script), PDFs and other documents open
/// in Quick Look — share, save to Photos or mark up from there.
final class ForkQuickLook: NSObject, QLPreviewControllerDataSource {
    private static let previewable: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "tif", "tiff", "bmp", "webp", "svg", "pdf", "usdz", "mov", "mp4", "m4a", "mp3", "wav"]
    private static var current: ForkQuickLook?
    private let urls: [URL]
    
    private init(urls: [URL]) { self.urls = urls }
    
    static func canPreview(_ url: URL) -> Bool {
        previewable.contains(url.pathExtension.lowercased())
    }
    
    static func present(_ url: URL, from presenter: UIViewController) {
        present([url], from: presenter)
    }
    
    /// Several files: swipe between them (the figures of one plt.show()).
    static func present(_ urls: [URL], from presenter: UIViewController) {
        guard !urls.isEmpty else { return }
        let source = ForkQuickLook(urls: urls)
        current = source
        let preview = QLPreviewController()
        preview.dataSource = source
        var host = presenter
        while let shown = host.presentedViewController, !shown.isBeingDismissed { host = shown }
        if host is QLPreviewController {
            /* a newer plt.show(): replace the preview that is open */
            host.dismiss(animated: false) { presenter.present(preview, animated: true) }
            return
        }
        host.present(preview, animated: true)
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        urls[index] as NSURL
    }
}

// MARK: - Fork: file templates

/// Files that start with working code. (No @Observable / #Preview: those macros
/// need plugins that only ship with Xcode, so ObservableObject and PreviewProvider.)
struct ForkFileTemplate {
    let title: String
    let subtitle: String
    let symbol: String
    let fileExtension: String
    let placeholder: String
    let body: (String) -> String
    
    /// Names of system types the templates use or that a type should not shadow.
    static let reservedNames: Set<String> = [
        "ObservableObject", "Published", "View", "App", "Scene", "Codable", "Identifiable", "Hashable", "Equatable",
        "Comparable", "Decodable", "Encodable", "Sendable", "Error", "Text", "Image", "List", "Button", "Color",
        "Data", "Date", "URL", "UUID", "String", "Int", "Double", "Bool", "Array", "Set", "Dictionary", "Optional",
        "NavigationStack", "NavigationLink", "VStack", "HStack", "ZStack", "State", "Binding", "Environment",
        "PreviewProvider", "JSONDecoder", "JSONEncoder", "Combine", "Foundation", "SwiftUI", "Observable", "Model"
    ]
    
    /// Added to a reserved name: "ObservableObject" -> "ObservableObjectModel".
    var suffix: String {
        switch title {
        case "Observable Model": return "Model"
        case "Codable Model": return "Record"
        default: return "View"
        }
    }
    
    /// "my view" -> "MyView" (types) or "my_view" (Python modules).
    static func identifier(from text: String, type: Bool) -> String {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !words.isEmpty else { return type ? "NewFile" : "new_file" }
        var name = type ? words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined() : words.map { $0.lowercased() }.joined(separator: "_")
        if let first = name.first, first.isNumber { name = (type ? "T" : "m_") + name }
        return name
    }
    
    static let all: [ForkFileTemplate] = [
        ForkFileTemplate(title: "SwiftUI View", subtitle: "A view with its preview", symbol: "rectangle.on.rectangle", fileExtension: "swift", placeholder: "ContentView") { name in
            """
            import SwiftUI

            struct \(name): View {
                var body: some View {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                        Text("\(name)")
                            .font(.title2)
                    }
                    .padding()
                }
            }

            struct \(name)_Previews: PreviewProvider {
                static var previews: some View {
                    \(name)()
                }
            }

            """
        },
        ForkFileTemplate(title: "List and Detail", subtitle: "NavigationStack, a list and a detail view", symbol: "list.bullet.rectangle", fileExtension: "swift", placeholder: "ItemsView") { name in
            """
            import SwiftUI

            struct \(name): View {
                @State private var items: [String] = ["Primero", "Segundo", "Tercero"]
                @State private var search = ""

                private var shown: [String] {
                    search.isEmpty ? items : items.filter { $0.localizedCaseInsensitiveContains(search) }
                }

                var body: some View {
                    NavigationStack {
                        List {
                            ForEach(shown, id: \\.self) { item in
                                NavigationLink(item) {
                                    Text(item)
                                        .font(.largeTitle)
                                        .navigationTitle(item)
                                }
                            }
                            .onDelete { offsets in items.remove(atOffsets: offsets) }
                        }
                        .searchable(text: $search)
                        .navigationTitle("\(name)")
                        .toolbar {
                            Button("Add", systemImage: "plus") {
                                items.append("Item \\(items.count + 1)")
                            }
                        }
                    }
                }
            }

            struct \(name)_Previews: PreviewProvider {
                static var previews: some View {
                    \(name)()
                }
            }

            """
        },
        ForkFileTemplate(title: "Observable Model", subtitle: "ObservableObject with @Published, for @StateObject", symbol: "cube.box", fileExtension: "swift", placeholder: "Model") { name in
            """
            import Foundation
            import Combine

            final class \(name): ObservableObject {
                @Published var items: [String] = []
                @Published var isLoading = false

                func add(_ item: String) {
                    items.append(item)
                }

                func remove(at offsets: IndexSet) {
                    items.remove(atOffsets: offsets)
                }
            }

            """
        },
        ForkFileTemplate(title: "Codable Model", subtitle: "Struct that reads and writes JSON", symbol: "curlybraces", fileExtension: "swift", placeholder: "Record") { name in
            """
            import Foundation

            struct \(name): Codable, Identifiable, Hashable {
                var id = UUID()
                var name: String
                var date: Date = .now

                static func load(from url: URL) throws -> [\(name)] {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode([\(name)].self, from: Data(contentsOf: url))
                }

                static func save(_ records: [\(name)], to url: URL) throws {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    try encoder.encode(records).write(to: url, options: .atomic)
                }
            }

            """
        },
        ForkFileTemplate(title: "Python Script", subtitle: "With main() and arguments", symbol: "chevron.left.forwardslash.chevron.right", fileExtension: "py", placeholder: "script") { name in
            """
            import sys


            def main(args):
                print("Hola desde \(name).py", args)
                return 0


            if __name__ == "__main__":
                sys.exit(main(sys.argv[1:]))

            """
        },
        ForkFileTemplate(title: "Python Notebook", subtitle: "Cells (# %%) to run one by one with ⌘↩", symbol: "square.grid.3x1.below.line.grid.1x2", fileExtension: "py", placeholder: "analysis") { name in
            """
            # %% Datos
            import numpy as np
            import pandas as pd

            datos = pd.DataFrame({"x": np.arange(10), "y": np.random.default_rng(0).normal(size=10)})
            datos.describe()

            # %% Cálculo
            datos["y2"] = datos["y"] ** 2
            datos.head()

            # %% Gráfica
            import matplotlib.pyplot as plt

            plt.plot(datos["x"], datos["y"], marker="o")
            plt.title("\(name)")
            plt.show()

            """
        },
        ForkFileTemplate(title: "Python Module", subtitle: "A class with a test at the end", symbol: "shippingbox", fileExtension: "py", placeholder: "module") { name in
            """
            from dataclasses import dataclass, field


            @dataclass
            class Registro:
                nombre: str
                valores: list[float] = field(default_factory=list)

                def promedio(self) -> float:
                    return sum(self.valores) / len(self.valores) if self.valores else 0.0


            if __name__ == "__main__":
                r = Registro("\(name)", [1.0, 2.0, 3.0])
                assert r.promedio() == 2.0
                print(r, r.promedio())

            """
        },
    ]
}
