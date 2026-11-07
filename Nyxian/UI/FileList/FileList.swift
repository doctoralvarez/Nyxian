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
 Fork doctoralvarez/Nyxian — version 1.2.0
 Changelog:
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
    
    @objc func performRefresh() {
        if !self.isSublink, let project = self.project {
            if project.reload() {
                self.title = project.projectConfig.displayName
            }
        }
        
        self.entries = FileListEntry.getEntries(ofPath: self.path)
        self.refreshControl?.endRefreshing()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.tableView.visibleCells.forEach { cell in
                cell.alpha = 0
            }
            
            self.tableView.reloadData()
            
            self.tableView.layoutIfNeeded()
            
            guard let visibleCells = self.tableView.visibleCells as? [FileListCell] else { return }
            
            visibleCells.forEach { cell in
                cell.transform = CGAffineTransform(translationX: -30, y: 0)
                cell.alpha = 0
            }
            
            for (index, cell) in visibleCells.enumerated() {
                let delay = Double(index) * 0.02
                UIView.animate(withDuration: 0.6, delay: delay, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
                    cell.transform = .identity
                    cell.alpha = 1
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
        
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

        navigationItem.rightBarButtonItem?.isEnabled = !isSelecting

        if isSelecting {
            let deleteButton = UIBarButtonItem(title: "Delete", style: .plain, target: self, action: #selector(deleteSelected))
            deleteButton.tintColor = .systemRed
            let copyButton = UIBarButtonItem(title: "Copy", style: .plain, target: self, action: #selector(copySelected))
            let shareButton = UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(shareSelected))
            let selectAllButton = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(toggleSelectAll))
            self.selectAllButton = selectAllButton
            self.updateSelectAllButton()
            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            
            setToolbarItems([deleteButton, spacer, selectAllButton, spacer, copyButton, spacer, shareButton], animated: true)
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
    
    func generateMenu() -> UIMenu {
        var rootMenuChildren: [UIMenu] = []
        
        // Project Roots Menu in case its the root of the project obviously
        if !self.isSublink, UIDevice.current.userInterfaceIdiom != .pad, let project = self.project {
            var projectMenuElements: [UIMenuElement] = []
            if !NXApplicationState.extensionLessMode {
                projectMenuElements.append(UIAction(title: "Run", image: UIImage(systemName: "play.fill"), handler: { [weak self] _ in
                    guard let self = self else { return }
                    buildProjectWithArgumentUI(targetViewController: self, project: project, buildType: .run) { result, execPath in
                        if result {
                            if project.projectConfig.schemeKind == .app {
                                PEProcessManager.shared().spawnProcess(withBundleIdentifier: project.projectConfig.bundleid, withItems: [:], withKernelSurfaceProcess: nil, doRestartIfRunning: true)
                            } else if project.projectConfig.schemeKind == .utility, let execPath = execPath {
                                let terminalSession: NXWindowSessionTerminal = NXWindowSessionTerminal(utilityPath: execPath)
                                NXWindowServer.shared().openWindow(with: terminalSession, withCompletion: nil)
                            }
                        }
                    }
                }))
            }
            projectMenuElements.append(UIAction(title: "Export", image: UIImage(systemName: "archivebox.fill"), handler: { [weak self] _ in
                guard let self = self else { return }
                buildProjectWithArgumentUI(targetViewController: self, project: project, buildType: .export)
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
                UIAction(title: "Repository…", image: UIImage(systemName: "link")) { [weak self] _ in
                    self?.forkPresentGitHubLinkSettings(project)
                },
                UIAction(title: "Account…", image: UIImage(systemName: "person.crop.circle")) { [weak self] _ in
                    self?.forkPresentGitHubAccount()
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
            children.append(UIMenu(options: .displayInline, children: self.isReadOnly ? [copyAction] : [copyAction, moveAction, renameAction]))
            children.append(UIMenu(options: .displayInline, children: [shareAction]))
            if !self.isReadOnly {
                children.append(UIMenu(options: .displayInline, children: [deleteAction]))
            }
            return UIMenu(children: children)
        }
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
    
    private func request(_ method: String, _ path: String, body: [String: Any]? = nil, allow404: Bool = false) async throws -> Any? {
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
    private func head() async throws -> (commit: String, tree: String)? {
        guard let ref = try await request("GET", "/git/ref/heads/\(branch)", allow404: true) as? [String: Any],
              let object = ref["object"] as? [String: Any],
              let commitSHA = object["sha"] as? String,
              let commit = try await request("GET", "/git/commits/\(commitSHA)") as? [String: Any],
              let tree = (commit["tree"] as? [String: Any])?["sha"] as? String else { return nil }
        return (commitSHA, tree)
    }
    
    /// path -> blob SHA of every file in a tree.
    private func remoteFiles(tree: String) async throws -> [String: String] {
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
    
    private func downloadBlob(_ sha: String) async throws -> Data {
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
