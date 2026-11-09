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
 Fork doctoralvarez/Nyxian — version 1.19.0
 Changelog:
  - 1.19.0 (2026-11-08): the runtime comes with numpy, scipy, pandas,
    matplotlib and scikit-learn; on an update they join the kept packages
    once (never over your own versions); bundled binaries are signed once;
    no PYTHONPYCACHEPREFIX (the runtime ships its bytecode).
  - 1.18.1 (2026-11-08): pip also looks in Flet's index of mobile wheels
    (scipy, scikit-learn, … for iOS); "Install Science Pack" in Packages.
  - 1.18.0 (2026-11-08): Python cells (# %%) run in a console that stays open
    per project (runCell); Packages… (installed list, upgrade, uninstall,
    install, requirements.txt); installRequirements.
  - 1.17.0 (2026-11-08): plt.show() previews its figures (nyxian_mplbackend);
    ForkPythonJedi (python3 with nyxian_jedi, no window: completion with jedi,
    syntax checks); a run that ends with an error marks its line in the editor
    (ForkPythonIssues) and, on iPad, opens the file there.
  - 1.16.0 (2026-11-08): when a .py run ends, the files the script made are
    copied into the project by themselves (and listed in the terminal); a
    file the script wrote again (a new plot) replaces the project's copy.
  - 1.15.0 (2026-11-08): packages installed with pip survive Nyxian updates
    (site-packages is kept when the runtime is unpacked again); signing of new
    package binaries is saved file by file and a file that was being signed
    when Nyxian closed is skipped next time (no crash loop); pip starts after
    its prompt has gone and the progress alert never comes from an alert;
    ForkOrientation (Automatic / Portrait / Landscape).
  - 1.14.0 (2026-11-08): "Python" project template (a command line tool
    project without sources, with main.py and a marker), its own "Python"
    section in the project list, ▶ / ⌘R run the .py on screen.
  - 1.13.0 (2026-11-08): projects in Apple's Files app ("Show in Files" in a
    project's menu, "Project Names.txt" says which UUID folder is which);
    running a .py file copies the project in the background (without reading
    big files into memory, skipping build folders), closes the editor's
    keyboard first and presents from the top screen; pip runs through
    nyxian_pip (says it started, shows it is still working, prints where it
    waits after a long silence); the console compiles pip in the background
    once, so the first pip install does not spend minutes doing it.
  - 1.12.0 (2026-11-08): binary packages load (numpy, matplotlib…): they
    link @rpath/Python.framework/Python, now a link to libpython found
    through libpython's rpath; pip also looks for iOS wheels on this fork's
    "ios-wheels" release (matplotlib 3.11 for Python 3.14, built by CI).
  - 1.11.0 (2026-11-08): pasting code into the Python console works:
    bracketed paste (the block arrives whole), cleaned (line ends of any
    kind, non-breaking / look-alike spaces, zero-width characters, curly
    quotes, tabs, common indentation) and run statement by statement
    (blank lines inside a def and code after a block are fine). Python
    font: 24 pt on iPad, 18 on iPhone by default.
  - 1.10.2 (2026-11-08): opt/python/bin is on PATH in Python windows, so pip
    no longer warns that the scripts it installs are "not on PATH".
  - 1.10.1 (2026-11-08): pip installs again: python3 may write all of
    opt/python (pip also writes bin/ — "Operation not permitted" on
    bin/idna); signing revision 3 signs Python again once.
  - 1.10.0 (2026-11-08): Python windows use a larger font (30 pt on iPad,
    22 on iPhone; Settings → Customization → Python Font Size, or A−/A+ in
    the key bar); the Python Console window closes with Ctrl-D / exit().
    Line editor: ← → move the cursor, Home/End, Ctrl-A/E/K/W, Ctrl-L clears
    the screen, Delete erases forward.
  - 1.9.3 (2026-11-08): Python REPL indents by itself inside blocks (one
    level more after ":", an empty Enter ends the block, ⌫ removes a whole
    level), pasted blocks keep their own indentation, and curly quotes
    typed on the keyboard become straight ones.
  - 1.9.2 (2026-11-07): Python terminal I/O made robust: sys.stdout and
    sys.stderr write straight to the terminal, the REPL writes results and
    errors itself and flushes after every line, Enter accepts CR, LF and
    CR LF, Ctrl-\ prints where Python is stuck, and a "Python Keyboard
    Test" menu item shows the code of every key Python receives.
  - 1.9.1 (2026-11-07): the launcher is signed last, from a pristine copy,
    and signed again from that copy before every install retry (1.9.0 only
    asked again with the same refused signature, so all retries failed).
  - 1.9.0 (2026-11-07): Python Console uses Nyxian's REPL (nyxian_repl /
    nyxian_lineedit in site-packages): echo, backspace, history (↑↓), Tab
    indents, Ctrl-C / Ctrl-D; input() echoes in scripts (sitecustomize). The
    launcher install is retried up to 5 times (the first call after launch
    could miss the service's 2 s answer window).
  - 1.8.1 (2026-11-07): the python3 launcher is signed with NXT2
    entitlements for its files (read: <rootfs>/opt/python; read-write:
    site-packages and <rootfs>/var/mobile) — without them dyld could not read
    libpython ("blocked by sandbox"). Existing installs are signed again.
  - 1.8.0 (2026-11-07): packages with native code — pip also looks in
    BeeWare's index of iOS builds (numpy, Pillow, …) and every new binary
    module in site-packages is signed before the next Python run.
  - 1.7.1 (2026-11-07): build fix — the terminal session initializer is
    failable.
  - 1.7.0 (2026-11-07): Python 3 (ForkPython) — the CPython runtime that
    ships in the app (Shared/python-ios.zip) is unpacked into Nyxian's rootfs
    and signed on first use, with pip from ensurepip's wheel. Projects screen:
    "Python" menu (Python Console, Install Package…, Reinstall Runtime).
  - 1.6.0 (2026-11-07): ForkSDKPatches — the iOS 27 SDK declares @State as a
    macro (SwiftUIMacros.StateMacro) next to the State property wrapper; the
    macro wins and its plugin only ships with Xcode, so every @State failed.
    On launch the SDK's SwiftUI interfaces get that macro renamed once, and
    the cached SwiftUI modules are rebuilt: @State is the property wrapper
    again (as with SDK 26.5).
  - 1.5.0 (2026-11-07): app icons — the importer turns the package's AppIcon
    into a real icon (CFBundleIcons + PNGs in Resources), "Set App Icon…" for
    any project, and the exporter writes an AppIcon.appiconset
    (appIcon: .asset("AppIcon")). Permissions — capabilities with a
    purposeString become Info.plist usage descriptions on import and go back
    to capabilities on export (the original block is reused when there is
    one). "Update from .swiftpm…" re-imports a package into an existing
    project (ForkProjectPicker).
  - 1.4.2 (2026-11-07): exported Package.swift failed in Swift Playgrounds
    ("PlaceholderIcon has no member 'gear'"); the default icon is now .leaf.
    The importer keeps the original manifest in Config/SwiftPlaygrounds-
    Package.swift.txt; the exporter reuses its placeholder icon and accent color.
  - 1.4.1 (2026-11-07): imported .swiftpm apps whose name has spaces failed to
    link ("failed to open …/Payload/ZCS Explorer.app/ZCSExplorer"); the
    importer now writes NXOutputPath with $(NXExecutable).app (see NXProject.m).
  - 1.4.0 (2026-11-07): export a project as a Swift Playgrounds app (.swiftpm,
    SwiftPlaygroundsExporter at the end of this file); swipe a project left to
    delete it and right to export it (.zip or .swiftpm); the long-press menu
    gains "Export as Swift Playgrounds App".
  - 1.3.0 (2026-11-07): the import button is now a menu: "Import File…" or
    "Clone from GitHub…" (a Nyxian project stays linked to the repository; a
    Swift Playgrounds package is converted). "GitHub Account…" is there too.
  - 1.2.0 (2026-11-07): the shortcut list honours its Customization toggle;
    Spanish names for Format Document and Rename Symbol.
  - 1.1.0 (2026-11-07): holding ⌘ alone for 2 seconds shows the keyboard
    shortcuts of the current screen (KeyboardShortcutsHUD); editor font size
    defaults to 20 (ForkDefaults, one-time move from the old default 12).
  - 1.0.0 (2026-11-07): Import Swift Playgrounds app packages (.swiftpm,
    as a folder or zipped) with the existing import button; they become a
    SwiftUI app project (SwiftPlaygroundsImporter at the end of this file).
*/

import Foundation
import SwiftUI
import UIKit
import GameController
import UniformTypeIdentifiers

@objc class ContentViewController: NXUITableViewController, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
    var sessionIndex: IndexPath? = nil
    /* fork: what the next document picker result is for */
    var forkPickPurpose: ForkProjectPicker.Purpose = .importProject
    var projectsList: [String:[NXProject]] = [:]
    
    @objc init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadProjectsFromDisk() {
        let rawProjectsList = NXProject.listProjects(at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects")) as! [String: [NXProject]]
        var buckets: [String: [NXProject]] = [:]
        
        for project in rawProjectsList.values.flatMap({ $0 }) {
            let key = Self.sectionKey(for: project)
            buckets[key, default: []].append(project)
        }
        
        self.projectsList = buckets
        self.tableView.reloadData()
        ForkFilesApp.writeProjectIndex(rawProjectsList.values.flatMap { $0 })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(ProjectTableCell.self, forCellReuseIdentifier: ProjectTableCell.reuseIdentifier)
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.title = "Projects"

        let createItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(presentProjectCreationSheet)
        )
        /* fork: import a file, or clone a repository from GitHub */
        let importItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down.fill"),
            menu: UIMenu(children: [
                UIAction(title: "Import File…", image: UIImage(systemName: "doc.zipper")) { [weak self] _ in
                    self?.presentImportPicker()
                },
                UIAction(title: "Clone from GitHub…", image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
                    self?.forkPresentGitHubClone()
                },
                UIAction(title: "GitHub Account…", image: UIImage(systemName: "person.crop.circle")) { [weak self] _ in
                    self?.forkPresentGitHubAccount()
                }
            ])
        )
        /* fork: Python 3 */
        let pythonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"),
            menu: UIMenu(title: "Python 3", children: [
                UIAction(title: "Python Console", image: UIImage(systemName: "terminal")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.openConsole(from: self)
                },
                UIAction(title: "Python Keyboard Test", image: UIImage(systemName: "keyboard")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.openKeyboardTest(from: self)
                },
                UIAction(title: "Packages…", image: UIImage(systemName: "shippingbox.circle")) { [weak self] _ in
                    guard let self else { return }
                    let manager = UINavigationController(rootViewController: ForkPythonPackagesViewController())
                    manager.modalPresentationStyle = .formSheet
                    self.present(manager, animated: true)
                },
                UIAction(title: "Install Package (pip)…", image: UIImage(systemName: "shippingbox")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.promptInstallPackage(from: self)
                },
                UIAction(title: "Reinstall Python Runtime", image: UIImage(systemName: "arrow.clockwise"), attributes: .destructive) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.reinstall(from: self)
                }
            ])
        )
        self.navigationItem.setRightBarButtonItems([createItem, importItem, pythonItem], animated: false)
        
        /* fork: hold ⌘ for the shortcut list; editor font size 20 by default */
        KeyboardShortcutsHUD.shared.start()
        ForkDefaults.apply()
        ForkSDKPatches.apply()
        
        reloadProjectsFromDisk()
    }

    @objc private func presentProjectCreationSheet() {
        let model = ProjectTemplateOptionsModel(schemeKind: .app)
        let view = ProjectCreationSheetView(
            model: model,
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            },
            onCreate: { [weak self] in
                guard let self = self else { return }
                if self.createProject(from: model) {
                    self.dismiss(animated: true)
                }
            }
        )
        
        _ = view.presentationBackground(Color(uiColor: LDETheme.currentTheme!.backgroundColor))

        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        hostingController.view.backgroundColor = LDETheme.currentTheme!.backgroundColor;
        present(hostingController, animated: true)
    }

    @objc private func presentImportPicker() {
        forkPickPurpose = .importProject
        /* fork: also Swift Playgrounds app packages (.swiftpm folders) */
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip, .folder, .package], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true)
    }
    
    func addProject(_ project: NXProject) {
        let key = {
            switch project.projectConfig.schemeKind {
            case .app: return "applications"
            case .utility: return "utilities"
            case .kSurfaceKext: return "kernel extension"
            default: return "unknown"
            }
        }()
        
        let oldSections = projectsList.keys.sorted { sortKeys($0, $1) }
        let oldSectionForKey = oldSections.firstIndex(of: key)
        
        if var list = self.projectsList[key] {
            list.append(project)
            self.projectsList[key] = list
        } else {
            self.projectsList[key] = [project]
        }
        
        let newSections = updateSections()
        let newSectionForKey = newSections.firstIndex(of: key)
        
        tableView.performBatchUpdates({
            if let oldIndex = oldSectionForKey, let newIndex = newSectionForKey {
                if oldIndex != newIndex {
                    tableView.deleteSections(IndexSet(integer: oldIndex), with: .fade)
                    tableView.insertSections(IndexSet(integer: newIndex), with: .fade)
                }
            } else if let newIndex = newSectionForKey {
                tableView.insertSections(IndexSet(integer: newIndex), with: .fade)
            }
            
            if let newIndex = newSectionForKey, let count = self.projectsList[key]?.count {
                let rowIndex = count - 1
                tableView.insertRows(at: [IndexPath(row: rowIndex, section: newIndex)], with: .automatic)
            }
        }, completion: { _ in
            if let newIndex = newSectionForKey {
                self.tableView.reloadSections(IndexSet(integer: newIndex), with: .none)
            }
        })
    }

    func removeProject(_ project: NXProject) {
        project.remove()
        let key = {
            switch project.projectConfig.schemeKind {
            case .app: return "applications"
            case .utility: return "utilities"
            case .kSurfaceKext: return "kernel extension"
            default: return "unknown"
            }
        }()
        
        guard var list = self.projectsList[key] else { return }
        
        let oldSections = projectsList.keys.sorted { sortKeys($0, $1) }
        let oldSectionForKey = oldSections.firstIndex(of: key)
        let oldRow = list.firstIndex { $0.url == project.url }
        
        list.removeAll { $0.url == project.url }
        
        if list.isEmpty {
            self.projectsList.removeValue(forKey: key)
        } else {
            self.projectsList[key] = list
        }
        
        let newSections = updateSections()
        let newSectionForKey = newSections.firstIndex(of: key)
        
        tableView.performBatchUpdates({
            if let oldIndex = oldSectionForKey, let oldRow = oldRow {
                tableView.deleteRows(at: [IndexPath(row: oldRow, section: oldIndex)], with: .automatic)
            }
            
            if let oldIndex = oldSectionForKey, let newIndex = newSectionForKey, oldIndex != newIndex {
                tableView.deleteSections(IndexSet(integer: oldIndex), with: .fade)
                tableView.insertSections(IndexSet(integer: newIndex), with: .fade)
            } else if oldSectionForKey != nil && newSectionForKey == nil {
                tableView.deleteSections(IndexSet(integer: oldSectionForKey!), with: .fade)
            }
        }, completion: { _ in
            if let newIndex = newSectionForKey {
                self.tableView.reloadSections(IndexSet(integer: newIndex), with: .none)
            }
        })
    }

    private func updateSections() -> [String] {
        return projectsList
            .filter { !$0.value.isEmpty }
            .sorted { sortKeys($0.key, $1.key) }
            .map { $0.key }
    }
    
    private func sortKeys(_ a: String, _ b: String) -> Bool {
        let keyA = a.lowercased()
        let keyB = b.lowercased()
        if keyA == "applications" { return true }
        if keyB == "applications" { return false }
        if keyA == "utilities" { return true }
        if keyB == "utilities" { return false }
        if keyA == "unknown" { return false }
        if keyB == "unknown" { return true }
        return keyA < keyB
    }
    
    private func createProject(from optionsModel: ProjectTemplateOptionsModel) -> Bool {
        let name = optionsModel.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Product name is required", withDelay: 0.0)
            return false
        }
        
        optionsModel.saveOrganizationIdentifier()
        
        guard let project = NXProject.createProject(
            at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects"),
            withName: name,
            withOrganizationIdentifier: optionsModel.normalizedOrganizationIdentifier,
            withBundleIdentifier: optionsModel.bundleIdentifier,
            withSchemeKind: optionsModel.schemeKind,
            withLanguageKind: optionsModel.selectedLanguage,
            withInterfaceKind: optionsModel.selectedInterface) else
        {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Failed to create project", withDelay: 0.0)
            return false
        }
        
        /* fork: Python template */
        if optionsModel.isPython {
            ForkPython.makePythonProject(project, name: name)
        }
        
        addProject(project)
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if sessionIndex != nil {
            reloadProjectsFromDisk()
        }
    }
    
    private var sortedSectionKeys: [String] {
        projectsList.keys.sorted(by: sortKeys)
    }
    
    private static func sectionKey(for project: NXProject) -> String {
        if ForkPython.isPythonProject(project) { return "python" }
        switch project.projectConfig.schemeKind {
        case .app: return "applications"
        case .utility: return "utilities"
        case .kSurfaceKext: return "kernel extension"
        default: return "unknown"
        }
    }
    
    private func sectionTitle(for key: String) -> String {
        switch key {
        case "applications": return "Applications"
        case "utilities": return "Utilities"
        case "kernel extension": return "Kernel Extensions"
        case "python": return "Python"
        default: return key.capitalized
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let key = sortedSectionKeys[section]
        let sectionProjects = self.projectsList[key] ?? []
        return "\(sectionTitle(for: key)) (\(sectionProjects.count))"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = sortedSectionKeys[section]
        let sectionProjects = self.projectsList[key] ?? []
        return sectionProjects.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.projectsList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let key = sortedSectionKeys[indexPath.section]
        let sectionProjects = self.projectsList[key] ?? []
        let project: NXProject = sectionProjects[indexPath.row]
        let cell: ProjectTableCell = self.tableView.dequeueReusableCell(withIdentifier: ProjectTableCell.reuseIdentifier) as! ProjectTableCell
        let icon: UIImage? = {
            switch project.projectConfig.schemeKind {
            case .app: return ForkAppIcon.sourceImage(of: project) /* fork: the project's own icon, if it has one */
            case .kSurfaceKext: return UIImage(systemName: "puzzlepiece.extension.fill")
            default: return UIImage(named: "UtilityIcon")
            }
        }()
        cell.configure(displayName: project.projectConfig.displayName, bundleIdentifier: project.projectConfig.bundleid, appIcon: icon, showArrow: UIDevice.current.userInterfaceIdiom != .pad)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        sessionIndex = indexPath
        
        let key = sortedSectionKeys[indexPath.section]
        let sectionProjects = self.projectsList[key] ?? []
        
        let selectedProject: NXProject = sectionProjects[indexPath.row]
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            let padFileVC: MainSplitViewController = MainSplitViewController(project: selectedProject)
            padFileVC.modalPresentationStyle = .fullScreen
            self.present(padFileVC, animated: true)
        } else {
            let fileVC = FileListViewController(project: selectedProject)
            self.navigationController?.pushViewController(fileVC, animated: true)
        }
    }
    
    /* fork: the project shown at a row */
    private func forkProject(at indexPath: IndexPath) -> NXProject? {
        let keys = sortedSectionKeys
        guard indexPath.section < keys.count else { return nil }
        let sectionProjects = self.projectsList[keys[indexPath.section]] ?? []
        guard indexPath.row < sectionProjects.count else { return nil }
        return sectionProjects[indexPath.row]
    }
    
    /* fork: Nyxian's own export, a zipped project folder */
    private func forkExportZip(_ project: NXProject) {
        DispatchQueue.global().async {
            let zipPath: String = "\(NSTemporaryDirectory())/\(project.projectConfig.displayName!).zip"
            zipDirectoryAtPath(project.url.path, zipPath, true)
            share(url: URL(fileURLWithPath: zipPath), remove: true)
        }
    }
    
    /* fork: swipe left to delete */
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let project = forkProject(at: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            self.presentConfirmationAlert(
                title: "Warning",
                message: "Are you sure you want to remove \"\(project.projectConfig.displayName!)\"?",
                confirmTitle: "Remove",
                confirmStyle: .destructive)
            {
                self.removeProject(project)
            }
            completion(false)
        }
        delete.image = UIImage(systemName: "trash.fill")
        let configuration = UISwipeActionsConfiguration(actions: [delete])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    /* fork: swipe right to export */
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let project = forkProject(at: indexPath) else { return nil }
        let export = UIContextualAction(style: .normal, title: "Export") { [weak self] _, sourceView, completion in
            guard let self = self else { completion(false); return }
            let sheet = UIAlertController(title: "Export \"\(project.projectConfig.displayName ?? "Project")\"", message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Nyxian Project (.zip)", style: .default) { _ in
                self.forkExportZip(project)
            })
            sheet.addAction(UIAlertAction(title: "Swift Playgrounds App (.swiftpm)", style: .default) { _ in
                self.forkExportSwiftPlaygrounds(project)
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = tableView.cellForRow(at: indexPath) ?? sourceView
                popover.sourceRect = popover.sourceView?.bounds ?? .zero
            }
            self.present(sheet, animated: true)
            completion(true)
        }
        export.backgroundColor = .systemBlue
        export.image = UIImage(systemName: "square.and.arrow.up.fill")
        let configuration = UISwipeActionsConfiguration(actions: [export])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            let export: UIAction = UIAction(title: "Export", image: UIImage(systemName: "square.and.arrow.up.fill")) { _ in
                guard let project = self.forkProject(at: indexPath) else { return }
                self.forkExportZip(project)
            }
            
            /* fork */
            let exportSwiftPM: UIAction = UIAction(title: "Export as Swift Playgrounds App", image: UIImage(systemName: "swift")) { _ in
                guard let project = self.forkProject(at: indexPath) else { return }
                self.forkExportSwiftPlaygrounds(project)
            }
            
            let item: UIAction = UIAction(title: "Remove", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { _ in
                let key = self.sortedSectionKeys[indexPath.section]
                let sectionProjects = self.projectsList[key] ?? []
                let project = sectionProjects[indexPath.row]
                
                self.presentConfirmationAlert(
                    title: "Warning",
                    message: "Are you sure you want to remove \"\(project.projectConfig.displayName!)\"?",
                    confirmTitle: "Remove",
                    confirmStyle: .destructive)
                {
                    self.removeProject(project)
                }
            }
            
            /* fork */
            let updateSwiftPM: UIAction = UIAction(title: "Update from .swiftpm…", image: UIImage(systemName: "arrow.triangle.2.circlepath")) { _ in
                guard let project = self.forkProject(at: indexPath) else { return }
                self.forkPresentPicker(.updateFromSwiftPM(project))
            }
            let setIcon: UIAction = UIAction(title: "Set App Icon…", image: UIImage(systemName: "app.badge")) { _ in
                guard let project = self.forkProject(at: indexPath) else { return }
                self.forkPresentPicker(.appIcon(project))
            }
            
            let showInFiles: UIAction = UIAction(title: "Show in Files", image: UIImage(systemName: "folder")) { _ in
                guard let project = self.forkProject(at: indexPath) else { return }
                ForkFilesApp.open(project.url, from: self)
            }
            
            return UIMenu(children: [export, exportSwiftPM, updateSwiftPM, setIcon, showInFiles, item])
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        /* fork: the picker may have been opened for an update or an icon */
        let purpose = forkPickPurpose
        forkPickPurpose = .importProject
        if case .importProject = purpose {} else {
            if let url = urls.first { forkHandlePicked(url, for: purpose) }
            return
        }
        do {
            guard let selectedURL = urls.first else { return }
            
            /* fork: a .swiftpm package (or any folder with Package.swift) picked directly */
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                importSwiftPlaygroundsPackage(at: selectedURL)
                try? FileManager.default.removeItem(at: selectedURL)
                return
            }
            
            let extractFirst = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Proj")
            
            if FileManager.default.fileExists(atPath: extractFirst.path) {
                try FileManager.default.removeItem(at: extractFirst)
            }
            try FileManager.default.createDirectory(at: extractFirst, withIntermediateDirectories: true)
            
            guard unzipArchiveAtPath(selectedURL.path, extractFirst.path) else {
                try? FileManager.default.removeItem(at: extractFirst)
                throw CocoaError(.fileReadCorruptFile)
            }
            
            let items = try FileManager.default.contentsOfDirectory(atPath: extractFirst.path).filter { !$0.hasPrefix("__") && !$0.hasPrefix(".") }
            
            guard let firstItem = items.first else {
                try? FileManager.default.removeItem(at: extractFirst)
                throw CocoaError(.fileReadNoSuchFile)
            }
            
            /* fork: a zipped .swiftpm package is converted instead of being taken as a Nyxian project */
            let extractedItem = extractFirst.appendingPathComponent(firstItem)
            if !FileManager.default.fileExists(atPath: extractedItem.appendingPathComponent("Config/Project.plist").path),
               SwiftPlaygroundsImporter.packageRoot(in: extractedItem) != nil {
                importSwiftPlaygroundsPackage(at: extractedItem)
                try? FileManager.default.removeItem(at: extractFirst)
                return
            }
            
            let projectPath = "\(NXBootstrap.shared().rootURL.appendingPathComponent("/Projects").path)/\(UUID().uuidString)"
            
            do {
                try FileManager.default.moveItem(
                    atPath: extractFirst.appendingPathComponent(firstItem).path,
                    toPath: projectPath
                )
            } catch {
                try? FileManager.default.removeItem(at: extractFirst)
                throw error
            }
            
            try? FileManager.default.removeItem(at: extractFirst)
            
            if let project = NXProject(url: URL(fileURLWithPath: projectPath)) {
                addProject(project)
            }
        } catch {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: error.localizedDescription, withDelay: 0.0)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if #available(iOS 26.0, *) {
            return 80
        } else {
            return 70
        }
    }
}

final class ProjectTemplateOptionsModel: ObservableObject {
    private static let organizationIdentifierDefaultsKey = "LDEOrganizationPrefix"
    private static let defaultOrganizationIdentifier = "com.example"
    private static let allowedIdentifierCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")

    @Published var step: ProjectCreationStep = .template
    @Published private(set) var schemeKind: NXProjectSchemeKind
    /* fork: the "Python" template (made as a command line tool without sources) */
    @Published private(set) var isPython = false
    private let appLanguages: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "Swift", title: "Swift"),
        ProjectTemplatePickerOption(id: "ObjC", title: "Objective-C")
    ]
    private let utilityLanguages: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "Swift", title: "Swift"),
        ProjectTemplatePickerOption(id: "ObjC", title: "Objective-C"),
        ProjectTemplatePickerOption(id: "C++", title: "C++"),
        ProjectTemplatePickerOption(id: "C", title: "C")
    ]
    private let kextLanguages: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "C", title: "C")
    ]
    private let interfaces: [ProjectTemplatePickerOption] = [
        ProjectTemplatePickerOption(id: "SwiftUI", title: "SwiftUI"),
        ProjectTemplatePickerOption(id: "UIKit", title: "UIKit")
    ]

    @Published var productName = ""
    @Published var organizationIdentifier: String
    @Published private var selectedLanguageID = "Swift"
    @Published private var selectedInterfaceID = "SwiftUI"

    init(schemeKind: NXProjectSchemeKind) {
        self.schemeKind = schemeKind
        self.organizationIdentifier = UserDefaults.standard.string(forKey: Self.organizationIdentifierDefaultsKey) ?? Self.defaultOrganizationIdentifier
    }

    var showsAppOptions: Bool {
        return schemeKind == .app && !isPython
    }
    
    var showLanguageOptions: Bool {
        return schemeKind != .kSurfaceKext && !isPython
    }
    
    func selectPython() {
        isPython = true
        schemeKind = .utility
        selectedLanguageID = "C"
        if productName.trimmingCharacters(in: .whitespaces).isEmpty { productName = "Pythons" }
    }

    var normalizedOrganizationIdentifier: String {
        return Self.organizationIdentifier(from: organizationIdentifier)
    }

    var bundleIdentifier: String {
        let productIdentifier = Self.productIdentifier(from: productName)
        return [normalizedOrganizationIdentifier, productIdentifier]
            .filter { !$0.isEmpty }
            .joined(separator: ".")
    }

    var selectedLanguage: NXProjectLanguageKind {
        switch selectedLanguageID {
        case "ObjC": return .objectiveC
        case "C++": return .CXX
        case "C": return .C
        default: return .swift
        }
    }

    var selectedInterface: NXProjectInterfaceKind {
        guard schemeKind == .app else { return .unknown }
        return selectedInterfaceID == "SwiftUI" ? .swiftUI : .uiKit
    }

    var languageSelection: String {
        get { selectedLanguageID }
        set { selectLanguage(id: newValue) }
    }

    var interfaceSelection: String {
        get { selectedInterfaceID }
        set { selectInterface(id: newValue) }
    }

    var languageOptions: [ProjectTemplatePickerOption] {
        if schemeKind == .utility {
            return utilityLanguages
        } else if schemeKind == .kSurfaceKext {
            return kextLanguages
        }
        return appLanguages
    }
    
    var interfaceDisabledIDs: Set<String> {
        selectedLanguageID == "ObjC" ? ["SwiftUI"] : []
    }

    var interfaceOptions: [ProjectTemplatePickerOption] {
        return interfaces
    }

    func selectProjectType(_ schemeKind: NXProjectSchemeKind) {
        if isPython, productName == "Pythons" { productName = "" }
        isPython = false
        self.schemeKind = schemeKind
        if schemeKind == .app {
            switch selectedLanguageID {
            case "Swift", "ObjC":
                break
            default:
                selectedLanguageID = "Swift"
            }
        }

        if selectedInterfaceID == "SwiftUI" {
            selectedLanguageID = "Swift"
        }
    }

    func saveOrganizationIdentifier() {
        let value = normalizedOrganizationIdentifier
        guard !value.isEmpty else { return }
        organizationIdentifier = value
        UserDefaults.standard.set(value, forKey: Self.organizationIdentifierDefaultsKey)
    }

    private func selectLanguage(id: String) {
        selectedLanguageID = id
        if selectedLanguageID == "ObjC" {
            selectedInterfaceID = "UIKit"
        }
    }

    private func selectInterface(id: String) {
        selectedInterfaceID = id
        if selectedInterfaceID == "SwiftUI" {
            selectedLanguageID = "Swift"
        }
    }

    private static func organizationIdentifier(from value: String) -> String {
        return value
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { productIdentifier(from: String($0).lowercased()) }
            .filter { !$0.isEmpty }
            .joined(separator: ".")
    }

    private static func productIdentifier(from value: String) -> String {
        let source = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        var lastWasReplacement = false

        for scalar in source.unicodeScalars {
            if allowedIdentifierCharacters.contains(scalar) {
                output.unicodeScalars.append(scalar)
                lastWasReplacement = false
            } else if !lastWasReplacement {
                output.append("-")
                lastWasReplacement = true
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

struct ProjectTemplateOptionsView: View {
    @ObservedObject var model: ProjectTemplateOptionsModel
    
    private var textColor: Color { Color(uiColor: LDETheme.currentTheme!.textColor) }
    private var hairlineColor: Color { Color(uiColor: LDETheme.currentTheme!.gutterHairlineColor) }
    private var groupBackground: Color { textColor.opacity(0.05) }
    private var secondaryTextColor: Color { textColor.opacity(0.6) }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                templateTextField(
                    label: "Product Name",
                    placeholder: "Product Name",
                    text: $model.productName
                )
                themedDivider
                templateTextField(
                    label: "Organization Identifier",
                    placeholder: "com.example",
                    text: $model.organizationIdentifier,
                    keyboardType: .URL
                )
                themedDivider
                generatedIdentifierRow
            }
            .background(groupBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            VStack(spacing: 8) {
                if model.showsAppOptions {
                    ProjectTemplatePickerRow(
                        title: "Interface:",
                        options: model.interfaceOptions,
                        disabledIDs: model.interfaceDisabledIDs,
                        selectionID: $model.interfaceSelection
                    )
                }
                
                if model.showLanguageOptions {
                    ProjectTemplatePickerRow(
                        title: "Language:",
                        options: model.languageOptions,
                        selectionID: $model.languageSelection
                    )
                }
            }
        }
        .padding(.top, 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if model.schemeKind == .kSurfaceKext {
                model.languageSelection = "C"
            }
        }
    }
    
    private var themedDivider: some View {
        Rectangle()
            .fill(hairlineColor)
            .frame(height: 1 / UIScreen.main.scale)
            .padding(.leading, 12)
    }
    
    private var generatedIdentifierRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Bundle Identifier")
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
            Text(model.bundleIdentifier.isEmpty ? " " : model.bundleIdentifier)
                .font(.callout)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func templateTextField(label: String,
                                   placeholder: String,
                                   text: Binding<String>,
                                   keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(textColor)
                .tint(textColor)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Fork: import Swift Playgrounds app packages (.swiftpm)

/// Converts a Swift Playgrounds app package (Package.swift + Swift sources) into a Nyxian SwiftUI app project.
enum SwiftPlaygroundsImporter {
    struct Result {
        let project: NXProject
        let swiftFileCount: Int
        let resourceCount: Int
        let warnings: [String]
    }
    
    enum ImportError: LocalizedError {
        case notAPackage
        case noSwiftSources
        case projectCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .notAPackage: return "This folder has no Package.swift, so it is not a Swift Playgrounds app."
            case .noSwiftSources: return "No Swift source files were found in the package."
            case .projectCreationFailed: return "Nyxian could not create the project."
            }
        }
    }
    
    /// Folders that belong to the package tooling, never to the app.
    private static let ignoredNames: Set<String> = [".swiftpm", ".build", ".git", "Package.swift", "Package.resolved", "__MACOSX"]
    
    /// Returns the package root inside `url`: `url` itself, or a single nested folder that holds Package.swift.
    static func packageRoot(in url: URL) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return url
        }
        let children = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for child in children where !child.lastPathComponent.hasPrefix("__") {
            if fm.fileExists(atPath: child.appendingPathComponent("Package.swift").path) {
                return child
            }
        }
        return nil
    }
    
    static func importPackage(at packageURL: URL, intoProjectsAt projectsURL: URL, updating existing: NXProject? = nil) throws -> Result {
        let fm = FileManager.default
        guard let root = packageRoot(in: packageURL) else { throw ImportError.notAPackage }
        
        let manifest = (try? String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)) ?? ""
        var warnings: [String] = []
        
        /* identity from the .iOSApplication product, falling back to the folder name */
        let folderName = root.deletingPathExtension().lastPathComponent
        let displayName = firstCapture(in: manifest, pattern: #"\.iOSApplication\s*\(\s*name\s*:\s*"([^"]+)""#)
            ?? firstCapture(in: manifest, pattern: #"name\s*:\s*"([^"]+)""#)
            ?? folderName
        let executableName = sanitizedIdentifier(displayName)
        let bundleIdentifier = firstCapture(in: manifest, pattern: #"bundleIdentifier\s*:\s*"([^"]+)""#)
            ?? "com.example.\(executableName)"
        let displayVersion = firstCapture(in: manifest, pattern: #"displayVersion\s*:\s*"([^"]+)""#)
        let bundleVersion = firstCapture(in: manifest, pattern: #"bundleVersion\s*:\s*"([^"]+)""#)
        
        if manifest.range(of: #"\.package\s*\("#, options: .regularExpression) != nil {
            warnings.append("The package depends on other Swift packages. Nyxian cannot download them, so code that imports them will not compile until you add their sources to the project.")
        }
        
        /* collect sources and resources */
        var swiftFiles: [(source: URL, relative: String)] = []
        var resourceFiles: [(source: URL, relative: String)] = []
        var assetCatalogs: [URL] = []
        var usesBundleModule = false
        
        let keys: [URLResourceKey] = [.isDirectoryKey]
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                if ignoredNames.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }
                let isDirectory = (try? url.resourceValues(forKeys: Set(keys)).isDirectory) ?? false
                if isDirectory {
                    if url.pathExtension == "xcassets" {
                        assetCatalogs.append(url)
                        enumerator.skipDescendants()
                    }
                    continue
                }
                
                let relative = ProjectFileIndex.relativePath(url, root: root)
                if url.pathExtension.lowercased() == "swift" {
                    swiftFiles.append((source: url, relative: relative))
                    if !usesBundleModule,
                       let text = try? String(contentsOf: url, encoding: .utf8),
                       text.contains("Bundle.module") {
                        usesBundleModule = true
                    }
                } else {
                    /* everything that is not code ships in the app bundle; a leading "Resources/" folder is flattened */
                    var resourceRelative = relative
                    if resourceRelative.hasPrefix("Resources/") {
                        resourceRelative = String(resourceRelative.dropFirst("Resources/".count))
                    }
                    resourceFiles.append((source: url, relative: resourceRelative))
                }
            }
        }
        
        guard !swiftFiles.isEmpty else { throw ImportError.noSwiftSources }
        
        if usesBundleModule {
            warnings.append("The code uses Bundle.module, which only exists in Swift packages. Replace it with Bundle.main.")
        }
        
        /* a regular SwiftUI app project to fill (or the project being updated) */
        guard let project = existing ?? NXProject.createProject(
            at: projectsURL,
            withName: executableName,
            withOrganizationIdentifier: organizationPrefix(of: bundleIdentifier),
            withBundleIdentifier: bundleIdentifier,
            withSchemeKind: .app,
            withLanguageKind: .swift,
            withInterfaceKind: .swiftUI) else {
            throw ImportError.projectCreationFailed
        }
        
        do {
            /* the template's own Swift files (or the previous version's) would clash with the imported @main app */
            for templateFile in ProjectFileIndex.files(in: project.url) where templateFile.pathExtension == "swift" {
                try? fm.removeItem(at: templateFile)
            }
            
            for file in swiftFiles {
                try copy(file.source, to: project.url.appendingPathComponent(file.relative))
            }
            
            var resourceCount = 0
            for file in resourceFiles {
                try copy(file.source, to: project.resourcesURL.appendingPathComponent(file.relative))
                resourceCount += 1
            }
            
            /* the app icon, as loose PNGs the system can read without actool */
            var iconImported = false
            for catalog in assetCatalogs where !iconImported {
                if let iconSet = appIconSet(in: catalog), let image = largestImage(in: iconSet) {
                    iconImported = (try? ForkAppIcon.install(image, in: project)) != nil
                }
            }
            
            for catalog in assetCatalogs {
                let converted = convertAssetCatalogImages(catalog, into: project.resourcesURL)
                resourceCount += converted.images
                if converted.skipped > 0 {
                    warnings.append("\(catalog.lastPathComponent): \(converted.skipped) item(s) such as colors or symbol images were not converted, because asset catalogs cannot be compiled on the device. Images were copied as plain files, so Image(\"name\") should still find them.")
                }
            }
            
            updateProjectConfig(project, displayName: displayName, displayVersion: displayVersion, bundleVersion: bundleVersion)
            let permissions = ForkCapabilities.usageDescriptions(fromManifest: manifest)
            if !permissions.mapped.isEmpty {
                ForkCapabilities.mergeIntoBundleInfo(permissions.mapped, project: project)
            }
            if !permissions.unmapped.isEmpty {
                warnings.append("These capabilities have no Info.plist equivalent here and were not carried over: " + permissions.unmapped.joined(separator: ", ") + ".")
            }
            /* kept so an export back to .swiftpm can reuse its icon and accent color */
            try? manifest.write(to: project.url.appendingPathComponent("Config/\(SwiftPlaygroundsExporter.originalManifestName)"), atomically: true, encoding: .utf8)
            _ = project.reload()
            
            return Result(project: project, swiftFileCount: swiftFiles.count, resourceCount: resourceCount, warnings: warnings)
        } catch {
            if existing == nil { project.remove() }
            throw error
        }
    }
    
    // MARK: helpers
    
    private static func appIconSet(in catalog: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: catalog, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        for case let url as URL in enumerator where url.pathExtension == "appiconset" {
            return url
        }
        return nil
    }
    
    /// The biggest light-mode image of an icon set (single-size 1024 sets and legacy multi-size sets).
    private static func largestImage(in iconSet: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: iconSet.appendingPathComponent("Contents.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["images"] as? [[String: Any]] else { return nil }
        var best: UIImage?
        for entry in entries {
            guard let filename = entry["filename"] as? String, entry["appearances"] == nil,
                  let image = UIImage(contentsOfFile: iconSet.appendingPathComponent(filename).path) else { continue }
            if best == nil || image.size.width * image.scale > best!.size.width * best!.scale {
                best = image
            }
        }
        return best
    }
    
    private static func copy(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }
    
    /// Copies the image files of every imageset as loose files named after the set ("logo.png", "logo@2x.png").
    private static func convertAssetCatalogImages(_ catalog: URL, into resources: URL) -> (images: Int, skipped: Int) {
        let fm = FileManager.default
        var images = 0
        var skipped = 0
        guard let enumerator = fm.enumerator(at: catalog, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return (0, 0) }
        
        for case let url as URL in enumerator {
            let ext = url.pathExtension
            guard ["imageset", "colorset", "appiconset", "symbolset", "dataset"].contains(ext) else { continue }
            enumerator.skipDescendants()
            /* fork: the app icon is handled by ForkAppIcon */
            if ext == "appiconset" { continue }
            
            guard ext == "imageset" else {
                skipped += 1
                continue
            }
            
            let setName = url.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: url.appendingPathComponent("Contents.json")),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entries = json["images"] as? [[String: Any]] else {
                skipped += 1
                continue
            }
            
            var copiedAny = false
            for entry in entries {
                guard let filename = entry["filename"] as? String else { continue }
                let source = url.appendingPathComponent(filename)
                guard fm.fileExists(atPath: source.path) else { continue }
                let scale = (entry["scale"] as? String) ?? "1x"
                let suffix = scale == "1x" ? "" : "@\(scale)"
                let fileExtension = source.pathExtension.isEmpty ? "png" : source.pathExtension
                let destination = resources.appendingPathComponent("\(setName)\(suffix).\(fileExtension)")
                if (try? copy(source, to: destination)) != nil {
                    copiedAny = true
                }
            }
            if copiedAny { images += 1 } else { skipped += 1 }
        }
        return (images, skipped)
    }
    
    private static func updateProjectConfig(_ project: NXProject, displayName: String, displayVersion: String?, bundleVersion: String?) {
        let plistURL = project.url.appendingPathComponent("Config/Project.plist")
        guard let data = try? Data(contentsOf: plistURL),
              var plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return }
        plist["NXDisplayName"] = displayName
        /* the builder makes <executable>.app, so the binary must go there even when the display name differs */
        plist["NXOutputPath"] = "$(CACHEROOT)/Payload/$(NXExecutable).app/$(NXExecutable)"
        if let displayVersion { plist["NXBundleShortVersion"] = displayVersion }
        if let bundleVersion { plist["NXBundleVersion"] = bundleVersion }
        if let output = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? output.write(to: plistURL, options: .atomic)
        }
    }
    
    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
    
    /// Executable / module names must be plain identifiers.
    private static func sanitizedIdentifier(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        var result = String(name.unicodeScalars.filter { allowed.contains($0) && $0.isASCII })
        if result.isEmpty { result = "ImportedApp" }
        if let first = result.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
            result = "App" + result
        }
        return result
    }
    
    private static func organizationPrefix(of bundleIdentifier: String) -> String {
        let parts = bundleIdentifier.split(separator: ".")
        return parts.count > 1 ? parts.dropLast().joined(separator: ".") : "com.example"
    }
}

extension ContentViewController {
    /// Imports a .swiftpm package and reports what was converted.
    func importSwiftPlaygroundsPackage(at url: URL) {
        do {
            let result = try SwiftPlaygroundsImporter.importPackage(
                at: url,
                intoProjectsAt: NXBootstrap.shared().rootURL.appendingPathComponent("Projects")
            )
            addProject(result.project)
            
            var message = "\(result.swiftFileCount) Swift file\(result.swiftFileCount == 1 ? "" : "s") and \(result.resourceCount) resource\(result.resourceCount == 1 ? "" : "s") imported."
            if !result.warnings.isEmpty {
                message += "\n\n" + result.warnings.map { "• " + $0 }.joined(separator: "\n\n")
            }
            let alert = UIAlertController(title: "Imported \"\(result.project.projectConfig.displayName ?? "App")\"", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        } catch {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: error.localizedDescription, withDelay: 0.0)
        }
    }
}

// MARK: - Fork: export as a Swift Playgrounds app package (.swiftpm)

/// Writes a Nyxian app project as a Swift Playgrounds app package (the reverse of SwiftPlaygroundsImporter).
enum SwiftPlaygroundsExporter {
    struct Result {
        let packageURL: URL
        let swiftFileCount: Int
        let imageCount: Int
        let resourceCount: Int
        let warnings: [String]
    }
    
    enum ExportError: LocalizedError {
        case notAnApp
        case noSwiftSources
        
        var errorDescription: String? {
            switch self {
            case .notAnApp: return "Only app projects can become Swift Playgrounds apps."
            case .noSwiftSources: return "The project has no Swift files. Swift Playgrounds only compiles Swift."
            }
        }
    }
    
    /// The imported package's own manifest, kept in Config/ by SwiftPlaygroundsImporter.
    static let originalManifestName = "SwiftPlaygrounds-Package.swift.txt"
    
    private static let cFamilyExtensions: Set<String> = ["c", "m", "mm", "cpp", "cc", "cxx", "h", "hpp", "hh", "s"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "pdf"]
    private static let ignoredNames: Set<String> = ["Config", ".git", ".build", ".swiftpm", "Package.swift", "Package.resolved"]
    
    static func export(_ project: NXProject, into folder: URL) throws -> Result {
        guard project.projectConfig.schemeKind == .app else { throw ExportError.notAnApp }
        let fm = FileManager.default
        let root: URL = project.url
        var warnings: [String] = []
        
        /* identity, from Config/Project.plist */
        let config = project.projectConfig!
        let displayName = config.displayName ?? config.executable ?? "App"
        let rawPlist = (try? Data(contentsOf: root.appendingPathComponent("Config/Project.plist")))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] } ?? [:]
        let bundleVersion = (rawPlist["NXBundleVersion"] as? String) ?? "1.0"
        let displayVersion = (rawPlist["NXBundleShortVersion"] as? String) ?? bundleVersion
        
        var packageName = displayName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        if packageName.isEmpty { packageName = "App" }
        let package = folder.appendingPathComponent("\(packageName).swiftpm")
        if fm.fileExists(atPath: package.path) { try fm.removeItem(at: package) }
        try fm.createDirectory(at: package, withIntermediateDirectories: true)
        
        /* collect files */
        var swiftCount = 0
        var resourceCount = 0
        var skippedCFamily = 0
        var hasAppLifecycle = false
        var images: [(source: URL, set: String, scale: String)] = []
        
        let keys: [URLResourceKey] = [.isDirectoryKey]
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let relative = ProjectFileIndex.relativePath(url, root: root)
                if ignoredNames.contains(url.lastPathComponent) && !relative.contains("/") {
                    enumerator.skipDescendants()
                    continue
                }
                let isDirectory = (try? url.resourceValues(forKeys: Set(keys)).isDirectory) ?? false
                if isDirectory {
                    if url.pathExtension == "xcassets" {
                        try copy(url, to: package.appendingPathComponent(url.lastPathComponent))
                        enumerator.skipDescendants()
                    }
                    continue
                }
                
                let ext = url.pathExtension.lowercased()
                if ext == "swift" {
                    try copy(url, to: package.appendingPathComponent(relative))
                    swiftCount += 1
                    if !hasAppLifecycle, let text = try? String(contentsOf: url, encoding: .utf8),
                       text.range(of: #"@main[\s\S]{0,200}?:\s*App\b"#, options: .regularExpression) != nil {
                        hasAppLifecycle = true
                    }
                } else if cFamilyExtensions.contains(ext) {
                    skippedCFamily += 1
                } else if imageExtensions.contains(ext) && ForkAppIcon.isGeneratedIconFile(url.lastPathComponent) {
                    /* the PNGs made by ForkAppIcon come back as an app icon set below */
                    continue
                } else if imageExtensions.contains(ext) {
                    /* loose images become an asset catalog, so Image("name") keeps working */
                    var base = url.deletingPathExtension().lastPathComponent
                    var scale = "1x"
                    for candidate in ["@2x", "@3x"] where base.hasSuffix(candidate) {
                        base = String(base.dropLast(candidate.count))
                        scale = String(candidate.dropFirst())
                    }
                    images.append((url, base, scale))
                } else {
                    var resourceRelative = relative
                    if resourceRelative.hasPrefix("Resources/") {
                        resourceRelative = String(resourceRelative.dropFirst("Resources/".count))
                    }
                    try copy(url, to: package.appendingPathComponent("Resources").appendingPathComponent(resourceRelative))
                    resourceCount += 1
                }
            }
        }
        
        guard swiftCount > 0 else {
            try? fm.removeItem(at: package)
            throw ExportError.noSwiftSources
        }
        
        /* asset catalog for the images */
        var imageSetCount = 0
        if !images.isEmpty {
            let catalog = package.appendingPathComponent("Assets.xcassets")
            try fm.createDirectory(at: catalog, withIntermediateDirectories: true)
            let catalogInfo = catalog.appendingPathComponent("Contents.json")
            if !fm.fileExists(atPath: catalogInfo.path) {
                try json(["info": ["author": "xcode", "version": 1]]).write(to: catalogInfo)
            }
            let grouped = Dictionary(grouping: images, by: { $0.set })
            for (setName, files) in grouped.sorted(by: { $0.key < $1.key }) {
                let set = catalog.appendingPathComponent("\(setName).imageset")
                guard !fm.fileExists(atPath: set.path) else {
                    warnings.append("\(setName): an image set with that name already exists in Assets.xcassets, so the loose file was not added.")
                    continue
                }
                try fm.createDirectory(at: set, withIntermediateDirectories: true)
                var entries: [[String: Any]] = []
                for file in files {
                    let name = file.source.lastPathComponent
                    try copy(file.source, to: set.appendingPathComponent(name))
                    var entry: [String: Any] = ["idiom": "universal", "filename": name]
                    if file.source.pathExtension.lowercased() != "pdf" { entry["scale"] = file.scale }
                    entries.append(entry)
                }
                var contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
                if files.contains(where: { $0.source.pathExtension.lowercased() == "pdf" }) {
                    contents["properties"] = ["preserves-vector-representation": true]
                }
                try json(contents).write(to: set.appendingPathComponent("Contents.json"))
                imageSetCount += 1
            }
        }
        
        /* manifest; icon and accent color come from the original package when there was one */
        let hasResources = resourceCount > 0
        let original = (try? String(contentsOf: root.appendingPathComponent("Config/\(originalManifestName)"), encoding: .utf8)) ?? ""
        var appIcon = firstMatch(in: original, pattern: #"\.placeholder\s*\(\s*icon\s*:\s*\.[A-Za-z]+\s*\)"#) ?? ".placeholder(icon: .leaf)"
        if let iconImage = ForkAppIcon.sourceImage(of: project) {
            try ForkAppIcon.writeAppIconSet(iconImage, into: package.appendingPathComponent("Assets.xcassets"))
            appIcon = ".asset(\"AppIcon\")"
        }
        let info = project.projectConfig.infoDictionary ?? [:]
        let capabilities = ForkCapabilities.capabilitiesBlock(original: original, info: info)
        let accentColor = firstMatch(in: original, pattern: #"\.presetColor\s*\(\s*\.[A-Za-z]+\s*\)"#) ?? ".presetColor(.blue)"
        try manifest(name: displayName,
                     bundleIdentifier: config.bundleid ?? "com.example.\(packageName)",
                     displayVersion: displayVersion,
                     bundleVersion: bundleVersion,
                     appIcon: appIcon,
                     accentColor: accentColor,
                     capabilities: capabilities.block,
                     resources: hasResources)
            .write(to: package.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        
        /* what Swift Playgrounds will not take as is */
        if skippedCFamily > 0 {
            warnings.append("\(skippedCFamily) C / Objective-C file(s) were left out: Swift Playgrounds only compiles Swift.")
        }
        if !hasAppLifecycle {
            warnings.append("No SwiftUI \"@main struct …: App\" was found. Swift Playgrounds apps start from a SwiftUI App, so a UIKit app delegate needs a small SwiftUI wrapper.")
        }
        if hasResources {
            warnings.append("\(resourceCount) non-image resource(s) are in Resources/. In a Swift package they are read with Bundle.module instead of Bundle.main.")
        }
        if !capabilities.unmapped.isEmpty {
            warnings.append("Add these again in Swift Playgrounds > App Settings > Capabilities: " + capabilities.unmapped.joined(separator: ", ") + ".")
        }
        
        return Result(packageURL: package, swiftFileCount: swiftCount, imageCount: imageSetCount, resourceCount: resourceCount, warnings: warnings)
    }
    
    // MARK: helpers
    
    private static func copy(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: source, to: destination)
    }
    
    private static func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
    
    /// A Swift string literal.
    private static func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    
    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }
    
    private static func manifest(name: String, bundleIdentifier: String, displayVersion: String, bundleVersion: String, appIcon: String, accentColor: String, capabilities: String?, resources: Bool) -> String {
        let capabilitiesLine = capabilities.map { ",\n                    capabilities: " + $0 } ?? ""
        let resourcesLine = resources ? ",\n            resources: [\n                .process(\"Resources\")\n            ]" : ""
        return """
        // swift-tools-version: 5.9

        // WARNING:
        // This file is automatically generated.
        // Do not edit it by hand because the contents will be replaced.

        import PackageDescription
        import AppleProductTypes

        let package = Package(
            name: \(literal(name)),
            platforms: [
                .iOS("17.0")
            ],
            products: [
                .iOSApplication(
                    name: \(literal(name)),
                    targets: ["AppModule"],
                    bundleIdentifier: \(literal(bundleIdentifier)),
                    teamIdentifier: "",
                    displayVersion: \(literal(displayVersion)),
                    bundleVersion: \(literal(bundleVersion)),
                    appIcon: \(appIcon),
                    accentColor: \(accentColor),
                    supportedDeviceFamilies: [
                        .pad,
                        .phone
                    ],
                    supportedInterfaceOrientations: [
                        .portrait,
                        .landscapeRight,
                        .landscapeLeft,
                        .portraitUpsideDown(.when(deviceFamilies: [.pad]))
                    ]\(capabilitiesLine)
                )
            ],
            targets: [
                .executableTarget(
                    name: "AppModule",
                    path: "."\(resourcesLine)
                )
            ]
        )

        """
    }
}

/// Saves the exported package with the system "Export to Files" sheet, then reports and cleans up.
final class SwiftPlaygroundsExportDelegate: NSObject, UIDocumentPickerDelegate {
    private static var current: SwiftPlaygroundsExportDelegate?
    
    private let temporaryFolder: URL
    private let summary: String
    private weak var presenter: UIViewController?
    
    init(temporaryFolder: URL, summary: String, presenter: UIViewController) {
        self.temporaryFolder = temporaryFolder
        self.summary = summary
        self.presenter = presenter
    }
    
    func present(_ packageURL: URL) {
        Self.current = self
        let picker = UIDocumentPickerViewController(forExporting: [packageURL], asCopy: true)
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let presenter = self.presenter
        let summary = self.summary
        finish()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            presenter?.forkGitHubAlert("Exported", summary + "\n\nOpen it from Files with Swift Playgrounds.")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish()
    }
    
    private func finish() {
        try? FileManager.default.removeItem(at: temporaryFolder)
        Self.current = nil
    }
}

extension ContentViewController {
    /// Builds the .swiftpm package in a temporary folder and offers to save it in Files.
    func forkExportSwiftPlaygrounds(_ project: NXProject) {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SwiftPMExport-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            let result = try SwiftPlaygroundsExporter.export(project, into: temp)
            var summary = "\(result.swiftFileCount) Swift file\(result.swiftFileCount == 1 ? "" : "s"), \(result.imageCount) image\(result.imageCount == 1 ? "" : "s") in Assets.xcassets, \(result.resourceCount) other resource\(result.resourceCount == 1 ? "" : "s")."
            if !result.warnings.isEmpty {
                summary += "\n\n" + result.warnings.map { "• " + $0 }.joined(separator: "\n\n")
            }
            SwiftPlaygroundsExportDelegate(temporaryFolder: temp, summary: summary, presenter: self).present(result.packageURL)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: error.localizedDescription, withDelay: 0.0)
        }
    }
}

// MARK: - Fork: app icon without asset catalogs

/// Icons as loose PNGs + CFBundleIcons (no actool on the device). The 1024 source lives in Config/AppIcon.png.
enum ForkAppIcon {
    /// name, pixel size
    private static let renditions: [(String, CGFloat)] = [
        ("AppIcon60x60@2x.png", 120),
        ("AppIcon60x60@3x.png", 180),
        ("AppIcon76x76@2x~ipad.png", 152),
        ("AppIcon83.5x83.5@2x~ipad.png", 167)
    ]
    
    static func isGeneratedIconFile(_ name: String) -> Bool {
        name.hasPrefix("AppIcon60x60") || name.hasPrefix("AppIcon76x76") || name.hasPrefix("AppIcon83.5x83.5")
    }
    
    private static func sourceURL(of project: NXProject) -> URL {
        let root: URL = project.url
        return root.appendingPathComponent("Config/AppIcon.png")
    }
    
    static func sourceImage(of project: NXProject) -> UIImage? {
        UIImage(contentsOfFile: sourceURL(of: project).path)
    }
    
    /// Square, opaque rendition (icons with transparency show black corners).
    private static func render(_ image: UIImage, pixels: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: pixels, height: pixels)
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    static func install(_ image: UIImage, in project: NXProject) throws {
        guard let source = render(image, pixels: 1024) else { throw CocoaError(.fileWriteUnknown) }
        try source.write(to: sourceURL(of: project), options: .atomic)
        let resources: URL = project.resourcesURL
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        for (name, pixels) in renditions {
            guard let data = render(image, pixels: pixels) else { continue }
            try data.write(to: resources.appendingPathComponent(name), options: .atomic)
        }
        ForkCapabilities.mergeIntoBundleInfo([
            "CFBundleIcons": ["CFBundlePrimaryIcon": ["CFBundleIconFiles": ["AppIcon60x60"]]],
            "CFBundleIcons~ipad": ["CFBundlePrimaryIcon": ["CFBundleIconFiles": ["AppIcon60x60", "AppIcon76x76", "AppIcon83.5x83.5"]]]
        ], project: project)
    }
    
    /// A single-size (1024) AppIcon.appiconset for a Swift Playgrounds package.
    static func writeAppIconSet(_ image: UIImage, into catalog: URL) throws {
        let fm = FileManager.default
        let set = catalog.appendingPathComponent("AppIcon.appiconset")
        try fm.createDirectory(at: set, withIntermediateDirectories: true)
        let catalogInfo = catalog.appendingPathComponent("Contents.json")
        let info: [String: Any] = ["author": "xcode", "version": 1]
        if !fm.fileExists(atPath: catalogInfo.path) {
            try JSONSerialization.data(withJSONObject: ["info": info], options: [.prettyPrinted, .sortedKeys]).write(to: catalogInfo)
        }
        guard let png = render(image, pixels: 1024) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: set.appendingPathComponent("AppIcon.png"))
        let contents: [String: Any] = [
            "images": [["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]],
            "info": info
        ]
        try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: set.appendingPathComponent("Contents.json"))
    }
}

// MARK: - Fork: Swift Playgrounds capabilities <-> Info.plist usage descriptions

enum ForkCapabilities {
    /// capability name -> Info.plist keys it stands for (first one is the main key)
    private static let map: [(String, [String])] = [
        ("camera", ["NSCameraUsageDescription"]),
        ("microphone", ["NSMicrophoneUsageDescription"]),
        ("photoLibrary", ["NSPhotoLibraryUsageDescription"]),
        ("photoLibraryAdd", ["NSPhotoLibraryAddUsageDescription"]),
        ("locationWhenInUse", ["NSLocationWhenInUseUsageDescription"]),
        ("locationAlwaysAndWhenInUse", ["NSLocationAlwaysAndWhenInUseUsageDescription"]),
        ("contacts", ["NSContactsUsageDescription"]),
        ("calendars", ["NSCalendarsUsageDescription", "NSCalendarsFullAccessUsageDescription"]),
        ("reminders", ["NSRemindersUsageDescription", "NSRemindersFullAccessUsageDescription"]),
        ("motion", ["NSMotionUsageDescription"]),
        ("faceID", ["NSFaceIDUsageDescription"]),
        ("bluetoothAlways", ["NSBluetoothAlwaysUsageDescription"]),
        ("speechRecognition", ["NSSpeechRecognitionUsageDescription"]),
        ("localNetwork", ["NSLocalNetworkUsageDescription"]),
        ("appleMusic", ["NSAppleMusicUsageDescription"]),
        ("homeKit", ["NSHomeKitUsageDescription"])
    ]
    
    /// The `[...]` after `capabilities:` in a manifest, brackets included.
    static func capabilitiesArray(in manifest: String) -> String? {
        guard let label = manifest.range(of: #"capabilities\s*:\s*\["#, options: .regularExpression) else { return nil }
        let chars = Array(manifest[manifest.index(before: label.upperBound)...])
        var depth = 0
        var inString = false
        var escaped = false
        for (i, c) in chars.enumerated() {
            if inString {
                if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
                continue
            }
            if c == "\"" { inString = true }
            else if c == "[" || c == "(" { depth += 1 }
            else if c == "]" || c == ")" {
                depth -= 1
                if depth == 0 { return String(chars[0...i]) }
            }
        }
        return nil
    }
    
    /// Top-level elements of the array, trimmed.
    private static func elements(of array: String) -> [String] {
        let inner = Array(array.dropFirst().dropLast())
        var result: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        var escaped = false
        for c in inner {
            if inString {
                if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
                current.append(c)
                continue
            }
            if c == "\"" { inString = true }
            if c == "[" || c == "(" { depth += 1 }
            if c == "]" || c == ")" { depth -= 1 }
            if c == "," && depth == 0 {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(c)
            }
        }
        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty { result.append(last) }
        return result.filter { !$0.isEmpty }
    }
    
    static func usageDescriptions(fromManifest manifest: String) -> (mapped: [String: Any], unmapped: [String]) {
        guard let array = capabilitiesArray(in: manifest) else { return ([:], []) }
        var mapped: [String: Any] = [:]
        var unmapped: [String] = []
        for element in elements(of: array) {
            guard let nameRange = element.range(of: #"^\.\w+"#, options: .regularExpression) else { continue }
            let name = String(element[nameRange].dropFirst())
            let purpose = element.range(of: #"purposeString\s*:\s*"((?:[^"\\]|\\.)*)""#, options: .regularExpression).map { range -> String in
                let match = String(element[range])
                let start = match.firstIndex(of: "\"")!
                return String(match[match.index(after: start)..<match.index(before: match.endIndex)])
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }
            if let keys = map.first(where: { $0.0 == name })?.1, let purpose {
                for key in keys { mapped[key] = purpose }
            } else {
                unmapped.append(name)
            }
        }
        return (mapped, unmapped)
    }
    
    /// The original manifest's capabilities when there was one, otherwise built from the usage descriptions.
    static func capabilitiesBlock(original: String, info: [AnyHashable: Any]) -> (block: String?, unmapped: [String]) {
        if let array = capabilitiesArray(in: original) { return (array, []) }
        var items: [String] = []
        var unmapped: [String] = []
        let usage = info.compactMap { (key, value) -> (String, String)? in
            guard let key = key as? String, key.hasSuffix("UsageDescription"), let value = value as? String else { return nil }
            return (key, value)
        }.sorted { $0.0 < $1.0 }
        for (key, value) in usage {
            if let entry = map.first(where: { $0.1.first == key }) {
                let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                items.append(".\(entry.0)(purposeString: \"\(escaped)\")")
            } else if !map.contains(where: { $0.1.contains(key) }) {
                unmapped.append(key)
            }
        }
        guard !items.isEmpty else { return (nil, unmapped) }
        return ("[\n" + items.map { "                        " + $0 }.joined(separator: ",\n") + "\n                    ]", unmapped)
    }
    
    /// Adds keys to NXBundleInfo in Config/Project.plist (the app's Info.plist).
    static func mergeIntoBundleInfo(_ values: [String: Any], project: NXProject) {
        let root: URL = project.url
        let plistURL = root.appendingPathComponent("Config/Project.plist")
        guard let data = try? Data(contentsOf: plistURL),
              var plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return }
        var info = plist["NXBundleInfo"] as? [String: Any] ?? [:]
        for (key, value) in values { info[key] = value }
        plist["NXBundleInfo"] = info
        if let output = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? output.write(to: plistURL, options: .atomic)
        }
        _ = project.reload()
    }
}

// MARK: - Fork: Python help for the editor (jedi, without a window)

/// A python3 running nyxian_jedi in the background: completion (jedi) and
/// syntax checks for .py files. Started on first use, again if it ends.
final class ForkPythonJedi {
    static let shared = ForkPythonJedi()
    
    private let lock = NSLock()
    private var toChild: Pipe?
    private var fromChild: Pipe?
    private var errors: Pipe?
    private var pid: pid_t = -1
    private var buffer = Data()
    private var nextID = 0
    private var lastFailure: Date?
    
    /// Suggestions at a 1-based line and 0-based column (Unicode scalars), in the format of the editor's engines.
    func completions(source: String, line: Int, column: Int, path: String?, root: String?) -> [[String: Any]]? {
        var body: [String: Any] = ["op": "complete", "source": source, "line": line, "column": column]
        if let path { body["path"] = path }
        if let root { body["root"] = root }
        return request(body, timeout: 4)?["items"] as? [[String: Any]]
    }
    
    /// Syntax errors and warnings: (line, column, isError, message).
    func problems(source: String, path: String?) -> [(Int, Int, Bool, String)]? {
        var body: [String: Any] = ["op": "diagnose", "source": source]
        if let path { body["path"] = path }
        guard let list = request(body, timeout: 3)?["problems"] as? [[String: Any]] else { return nil }
        return list.compactMap { entry in
            guard let line = entry["line"] as? Int else { return nil }
            return (line, entry["column"] as? Int ?? 1, (entry["level"] as? String) != "warning", entry["message"] as? String ?? "")
        }
    }
    
    private func request(_ body: [String: Any], timeout: TimeInterval) -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        guard ensureRunning(), let input = toChild?.fileHandleForWriting, let output = fromChild?.fileHandleForReading else { return nil }
        nextID += 1
        let id = nextID
        var message = body
        message["id"] = id
        guard var data = try? JSONSerialization.data(withJSONObject: message) else { return nil }
        data.append(0x0a)
        do { try input.write(contentsOf: data) } catch { stop(); return nil }
        let deadline = Date().addingTimeInterval(timeout)
        var chunk = [UInt8](repeating: 0, count: 65536)
        while true {
            if let end = buffer.firstIndex(of: 0x0a) {
                let line = Data(buffer[buffer.startIndex..<end])
                buffer.removeSubrange(buffer.startIndex...end)
                /* an answer that came too late for an earlier request is dropped */
                if let answer = try? JSONSerialization.jsonObject(with: line) as? [String: Any], (answer["id"] as? Int) == id {
                    return answer
                }
                continue
            }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return nil }
            var descriptor = pollfd(fd: output.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, Int32(max(1, remaining * 1000)))
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0 else { return nil }
            let count = read(output.fileDescriptor, &chunk, chunk.count)
            guard count > 0 else { stop(); return nil }
            buffer.append(contentsOf: chunk[0..<count])
        }
    }
    
    private func ensureRunning() -> Bool {
        if pid > 0, PEProcessManager.shared().process(forProcessIdentifier: pid) != nil { return true }
        stop()
        if let failure = lastFailure, Date().timeIntervalSince(failure) < 20 { return false }
        guard let launcher = ForkPython.readyLauncher(),
              let homePath = LDEApplicationWorkspace.shared().utilityHomePath() else {
            lastFailure = Date()
            return false
        }
        let toChild = Pipe(), fromChild = Pipe(), errors = Pipe()
        errors.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
        guard let table = PEFileTable.empty() else {
            lastFailure = Date()
            return false
        }
        table.appendFileDescriptor(toChild.fileHandleForReading.fileDescriptor, withMappingToLoc: STDIN_FILENO)
        table.appendFileDescriptor(fromChild.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDOUT_FILENO)
        table.appendFileDescriptor(errors.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDERR_FILENO)
        var environment = ForkPython.baseEnvironment(workingDirectory: nil)
        environment["HOME"] = homePath
        environment["CFFIXED_USER_HOME"] = homePath
        environment["TMPDIR"] = (homePath as NSString).appendingPathComponent("Tmp")
        let spawned = PEProcessManager.shared().spawnProcess(withItems: [
            "PEExecutablePath": launcher,
            "PEArguments": [launcher, "-q", "-m", "nyxian_jedi"],
            "PEEnvironment": environment,
            "PEWorkingDirectory": homePath,
            "PEFileTable": table
        ], withKernelSurfaceProcess: nil)
        guard spawned > 0 else {
            lastFailure = Date()
            return false
        }
        self.toChild = toChild
        self.fromChild = fromChild
        self.errors = errors
        self.pid = spawned
        self.buffer = Data()
        return true
    }
    
    private func stop() {
        if pid > 0, let process = PEProcessManager.shared().process(forProcessIdentifier: pid) {
            process.terminate()
        }
        errors?.fileHandleForReading.readabilityHandler = nil
        toChild = nil
        fromChild = nil
        errors = nil
        pid = -1
        buffer = Data()
    }
}

/// Python packages: what is installed, upgrade, uninstall, install (also from a requirements file).
final class ForkPythonPackagesViewController: UITableViewController, UISearchResultsUpdating, UIDocumentPickerDelegate {
    private var all: [ForkPython.InstalledPackage] = []
    private var shown: [ForkPython.InstalledPackage] = []
    private let search = UISearchController(searchResultsController: nil)
    
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Python Packages"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "plus"), menu: UIMenu(children: [
                UIAction(title: "Install Package…", image: UIImage(systemName: "shippingbox")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.promptInstallPackage(from: self)
                },
                UIAction(title: "Install Science Pack", subtitle: "numpy · scipy · pandas · matplotlib · scikit-learn", image: UIImage(systemName: "function")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.pip(["install", "numpy", "scipy", "pandas", "matplotlib", "scikit-learn"], title: "pip install (science pack)", from: self)
                },
                UIAction(title: "Install from requirements.txt…", image: UIImage(systemName: "doc.text")) { [weak self] _ in
                    guard let self else { return }
                    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText, .text, .data], asCopy: true)
                    picker.delegate = self
                    self.present(picker, animated: true)
                }
            ])),
            UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [weak self] _ in self?.reload() })
        ]
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search installed packages"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "package")
        reload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }
    
    private func reload() {
        all = ForkPython.installedPackages()
        updateSearchResults(for: search)
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let text = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        shown = text.isEmpty ? all : all.filter { $0.name.lowercased().contains(text) || $0.summary.lowercased().contains(text) }
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        all.isEmpty ? "No packages yet — + installs one" : "\(all.count) installed · swipe to upgrade or uninstall"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let package = shown[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = "\(package.name)  \(package.version)"
        content.secondaryText = package.summary.isEmpty ? nil : package.summary
        content.secondaryTextProperties.numberOfLines = 2
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let package = shown[indexPath.row]
        let uninstall = UIContextualAction(style: .destructive, title: "Uninstall") { [weak self] _, _, done in
            guard let self else { return done(false) }
            ForkPython.pip(["uninstall", "-y", package.name], title: "pip uninstall \(package.name)", from: self)
            done(true)
        }
        let upgrade = UIContextualAction(style: .normal, title: "Upgrade") { [weak self] _, _, done in
            guard let self else { return done(false) }
            ForkPython.pip(["install", "-U", package.name], title: "pip install -U \(package.name)", from: self)
            done(true)
        }
        upgrade.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [uninstall, upgrade])
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let package = shown[indexPath.row]
        let sheet = UIAlertController(title: "\(package.name) \(package.version)", message: package.summary, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Upgrade", style: .default) { [weak self] _ in
            guard let self else { return }
            ForkPython.pip(["install", "-U", package.name], title: "pip install -U \(package.name)", from: self)
        })
        sheet.addAction(UIAlertAction(title: "Uninstall", style: .destructive) { [weak self] _ in
            guard let self else { return }
            ForkPython.pip(["uninstall", "-y", package.name], title: "pip uninstall \(package.name)", from: self)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(sheet, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let file = urls.first else { return }
        ForkPython.installRequirements(file, from: self)
    }
}

/// The error a Python run ended with, by file: the editor marks its line.
enum ForkPythonIssues {
    static let changed = Notification.Name("ForkPythonIssuesChanged")
    private static let lock = NSLock()
    private static var runtime: [String: (line: Int, message: String)] = [:]
    
    private static func key(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }
    
    static func setRuntime(file: URL, line: Int, message: String) {
        lock.lock(); runtime[key(file)] = (line, message); lock.unlock()
        DispatchQueue.main.async { NotificationCenter.default.post(name: changed, object: nil) }
    }
    
    static func runtimeIssue(for file: URL) -> (line: Int, message: String)? {
        lock.lock(); defer { lock.unlock() }
        return runtime[key(file)]
    }
    
    static func clearRuntime(for file: URL) {
        lock.lock(); let removed = runtime.removeValue(forKey: key(file)) != nil; lock.unlock()
        if removed { DispatchQueue.main.async { NotificationCenter.default.post(name: changed, object: nil) } }
    }
    
    static func clearRuntime(under root: URL) {
        let prefix = key(root)
        lock.lock(); let before = runtime.count; runtime = runtime.filter { !$0.key.hasPrefix(prefix) }; let removed = before != runtime.count; lock.unlock()
        if removed { DispatchQueue.main.async { NotificationCenter.default.post(name: changed, object: nil) } }
    }
}

// MARK: - Fork: orientation (Settings → Customization → Orientation)

/// 0 automatic (landscape too, also on iPhone), 1 portrait, 2 landscape.
/// The app delegate (BootViewController.swift) reads the same key.
enum ForkOrientation {
    static let key = "fork.orientation"
    static let options = ["Automatic", "Portrait", "Landscape"]
    
    static var mask: UIInterfaceOrientationMask {
        switch UserDefaults.standard.integer(forKey: key) {
        case 1: return .portrait
        case 2: return .landscape
        default: return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
    }
    
    /// Turns the screen now when the choice no longer allows the current orientation.
    static func apply() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                NSLog("[ForkOrientation] %@", error.localizedDescription)
            }
        }
    }
}

// MARK: - Fork: projects in Apple's Files app

/// Nyxian's Documents folder is shared with the Files app (UIFileSharingEnabled):
/// On My iPhone/iPad › Nyxian › Projects. Project folders are named by UUID, so
/// a list of names next to them says which is which.
enum ForkFilesApp {
    static let indexName = "Project Names.txt"
    
    static func writeProjectIndex(_ projects: [NXProject]) {
        let folder = NXBootstrap.shared().rootURL.appendingPathComponent("Projects")
        var lines = ["Nyxian projects — the folder of each project in Projects/", ""]
        let named = projects.map { (($0.projectConfig.displayName ?? "") as String, ($0.url as URL).lastPathComponent) }
        for (name, folderName) in named.sorted(by: { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }) {
            lines.append("\(name.isEmpty ? "(no name)" : name)  →  Projects/\(folderName)")
        }
        let text = lines.joined(separator: "\n") + "\n"
        let target = folder.deletingLastPathComponent().appendingPathComponent(indexName)
        if (try? String(contentsOf: target, encoding: .utf8)) == text { return }
        try? text.write(to: target, atomically: true, encoding: .utf8)
    }
    
    /// Opens the Files app at a folder of Nyxian's Documents.
    static func open(_ folder: URL, from presenter: UIViewController) {
        var path = folder.resolvingSymlinksInPath().standardizedFileURL.path
        if path.hasPrefix("/var/") { path = "/private" + path }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "#?"))
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "shareddocuments://" + encoded) else { return }
        UIApplication.shared.open(url) { opened in
            guard !opened else { return }
            presenter.forkGitHubAlert("Files", "Open the Files app › On My \(UIDevice.current.model) › Nyxian › Projects › \(folder.lastPathComponent).")
        }
    }
}

// MARK: - Fork: pickers for "Update from .swiftpm…" and "Set App Icon…"

enum ForkProjectPicker {
    enum Purpose {
        case importProject
        case updateFromSwiftPM(NXProject)
        case appIcon(NXProject)
    }
}

extension ContentViewController {
    func forkPresentPicker(_ purpose: ForkProjectPicker.Purpose) {
        let types: [UTType]
        switch purpose {
        case .importProject:
            return
        case .updateFromSwiftPM(let project):
            /* replacing every Swift file is not undoable, so ask first */
            let name = project.projectConfig.displayName ?? "the project"
            presentConfirmationAlert(
                title: "Update from .swiftpm",
                message: "All Swift files of \"\(name)\" are replaced by the package's. Resources with the same name are overwritten; Config and the rest stay.",
                confirmTitle: "Choose Package",
                confirmStyle: .default)
            {
                self.forkPickPurpose = purpose
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip, .folder, .package], asCopy: true)
                picker.delegate = self
                self.present(picker, animated: true)
            }
            return
        case .appIcon:
            types = [.image]
        }
        forkPickPurpose = purpose
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        forkPickPurpose = .importProject
    }
    
    func forkHandlePicked(_ url: URL, for purpose: ForkProjectPicker.Purpose) {
        defer { try? FileManager.default.removeItem(at: url) }
        switch purpose {
        case .importProject:
            return
        case .appIcon(let project):
            guard let image = UIImage(contentsOfFile: url.path) else {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "That file is not an image.", withDelay: 0.0)
                return
            }
            do {
                try ForkAppIcon.install(image, in: project)
                tableView.reloadData()
                forkGitHubAlert("App Icon", "Saved. Build and run the app again to see it on the app. A square image of 1024 × 1024 works best.")
            } catch {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: error.localizedDescription, withDelay: 0.0)
            }
        case .updateFromSwiftPM(let project):
            let fm = FileManager.default
            var temp: URL?
            defer { if let temp { try? fm.removeItem(at: temp) } }
            do {
                var source = url
                var isDirectory: ObjCBool = false
                if !(fm.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue) {
                    let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SwiftPMUpdate-\(UUID().uuidString)")
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                    temp = folder
                    guard unzipArchiveAtPath(url.path, folder.path) else { throw CocoaError(.fileReadCorruptFile) }
                    source = folder
                }
                let result = try SwiftPlaygroundsImporter.importPackage(
                    at: source,
                    intoProjectsAt: NXBootstrap.shared().rootURL.appendingPathComponent("Projects"),
                    updating: project)
                reloadProjectsFromDisk()
                var message = "\(result.swiftFileCount) Swift file\(result.swiftFileCount == 1 ? "" : "s") and \(result.resourceCount) resource\(result.resourceCount == 1 ? "" : "s") updated."
                if !result.warnings.isEmpty {
                    message += "\n\n" + result.warnings.map { "• " + $0 }.joined(separator: "\n\n")
                }
                forkGitHubAlert("Updated \"\(result.project.projectConfig.displayName ?? "App")\"", message)
            } catch {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: error.localizedDescription, withDelay: 0.0)
            }
        }
    }
}

// MARK: - Fork: clone from GitHub

extension ContentViewController {
    /// Asks for owner/repo and branch, then downloads it as a new project.
    func forkPresentGitHubClone() {
        guard GitHubTokenStore.token != nil else {
            forkPresentGitHubAccount()
            return
        }
        let alert = UIAlertController(title: "Clone from GitHub", message: "A Nyxian project (with Config/Project.plist) or a Swift Playgrounds app (with Package.swift).", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "owner/repo"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addTextField { field in
            field.placeholder = "branch (main)"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clone", style: .default) { [weak self, weak alert] _ in
            var text = (alert?.textFields?[0].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            /* accept a pasted https://github.com/owner/repo(.git) link too */
            for prefix in ["https://github.com/", "http://github.com/", "github.com/"] where text.lowercased().hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
            }
            if text.hasSuffix(".git") { text = String(text.dropLast(4)) }
            let parts = text.split(separator: "/").map(String.init)
            var branch = (alert?.textFields?[1].text ?? "").trimmingCharacters(in: .whitespaces)
            if branch.isEmpty { branch = "main" }
            guard parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                self?.forkGitHubAlert("Clone from GitHub", "Write it as owner/repo.")
                return
            }
            self?.forkCloneGitHubRepository(owner: parts[0], repo: parts[1], branch: branch)
        })
        self.present(alert, animated: true)
    }
    
    private func forkCloneGitHubRepository(owner: String, repo: String, branch: String) {
        guard let token = GitHubTokenStore.token else { return }
        let projectsURL = NXBootstrap.shared().rootURL.appendingPathComponent("Projects")
        var clonedProjectURL: URL?
        
        forkRunGitHubTask("Clone from GitHub", finished: { [weak self] in
            if let url = clonedProjectURL, let project = NXProject(url: url) {
                self?.addProject(project)
            }
        }) {
            let sync = GitHubSync(token: token, owner: owner, repo: repo, branch: branch)
            let fm = FileManager.default
            let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GitHubClone-\(UUID().uuidString)")
            try fm.createDirectory(at: temp, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: temp) }
            
            let downloaded = try await sync.download(into: temp)
            
            if fm.fileExists(atPath: temp.appendingPathComponent("Config/Project.plist").path) {
                /* a Nyxian project: keep it linked so Pull / Commit and Push work right away */
                let destination = projectsURL.appendingPathComponent(UUID().uuidString)
                try fm.moveItem(at: temp, to: destination)
                guard let project = NXProject(url: destination) else { throw GitHubSyncError.notAProject }
                var link = GitHubLink(owner: owner, repo: repo, branch: branch)
                link.lastCommit = downloaded.commit
                link.files = downloaded.files
                try link.save(for: project)
                clonedProjectURL = destination
                return "\(downloaded.files.count) file\(downloaded.files.count == 1 ? "" : "s") downloaded from \(owner)/\(repo) (\(branch)). The project is linked: use ⋯ > GitHub to pull and push."
            }
            
            if SwiftPlaygroundsImporter.packageRoot(in: temp) != nil {
                /* a Swift Playgrounds app: converted, so it is not linked */
                let result = try SwiftPlaygroundsImporter.importPackage(at: temp, intoProjectsAt: projectsURL)
                clonedProjectURL = result.project.url
                var message = "Swift Playgrounds app converted: \(result.swiftFileCount) Swift file\(result.swiftFileCount == 1 ? "" : "s"), \(result.resourceCount) resource\(result.resourceCount == 1 ? "" : "s"). It is not linked to the repository because its layout changed."
                if !result.warnings.isEmpty {
                    message += "\n\n" + result.warnings.map { "• " + $0 }.joined(separator: "\n\n")
                }
                return message
            }
            
            throw GitHubSyncError.notAProject
        }
    }
}

// MARK: - Fork: keyboard shortcut overlay (hold ⌘ for 2 seconds)

extension UIResponder {
    /// Target of a nil-targeted action: whoever receives it is the first responder.
    @objc func nx_captureFirstResponder(_ sender: Any?) {
        KeyboardShortcutsHUD.capturedResponder = self
    }
}

/// Shows the shortcuts available on the current screen while ⌘ is held alone for 2 seconds.
final class KeyboardShortcutsHUD {
    static let shared = KeyboardShortcutsHUD()
    fileprivate static weak var capturedResponder: UIResponder?
    
    private static let holdDelay: TimeInterval = 2.0
    
    private var started = false
    private var commandDown = false
    private var pendingShow: DispatchWorkItem?
    private weak var overlay: UIView?
    
    /// Spanish names for the commands this app registers (others keep their own title).
    private static let spanishTitles: [String: String] = [
        "Save File": "Guardar archivo",
        "Find": "Buscar en el archivo",
        "Find Next": "Buscar siguiente",
        "Find Previous": "Buscar anterior",
        "Find and Replace": "Buscar y reemplazar",
        "Go to Line": "Ir a línea",
        "Shift Right": "Indentar",
        "Shift Left": "Quitar indentación",
        "Duplicate Line": "Duplicar línea",
        "Move Line Up": "Mover línea arriba",
        "Move Line Down": "Mover línea abajo",
        "Toggle Comment": "Comentar / descomentar",
        "Close": "Cerrar pestaña",
        "Run": "Compilar y ejecutar",
        "Build": "Compilar",
        "Show Issues": "Ver incidencias",
        "Search in Project": "Buscar en el proyecto",
        "Open Quickly": "Abrir archivo rápido",
        "Accept Suggestion": "Aceptar sugerencia",
        "Dismiss Suggestions": "Cerrar sugerencias",
        "Previous Suggestion": "Sugerencia anterior",
        "Next Suggestion": "Sugerencia siguiente",
        "Format Document": "Formatear código",
        "Rename Symbol": "Renombrar símbolo",
        "Show Signature": "Ver parámetros",
        "Dismiss Parameter Help": "Cerrar ayuda de parámetros",
        "Fix Issue": "Arreglar la línea",
        "Fix All Issues": "Arreglar todo el archivo",
        "Document Symbols": "Símbolos del archivo",
        "Previous File": "Pestaña anterior",
        "Least Recent File": "Pestaña más antigua",
        "Show Console": "Mostrar consola",
        "Review Changes": "Revisar cambios",
        "Jump to Definition": "Ir a definición",
        "Find References": "Buscar referencias",
        "Run Preview": "Ejecutar preview",
        "Toggle Breakpoint": "Poner/quitar breakpoint",
        "Pause or Continue": "Pausar o continuar",
        "Run Python File": "Ejecutar archivo Python",
        "Run Cell": "Ejecutar celda (# %%)",
        "Stop Live Preview": "Detener vista previa en vivo",
        "Run File in Console": "Ejecutar archivo en la consola",
        "Copy Python Output to Project": "Traer resultados de Python al proyecto"
    ]
    
    func start() {
        guard !started else { return }
        started = true
        install(on: GCKeyboard.coalesced)
        NotificationCenter.default.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] notification in
            self?.install(on: notification.object as? GCKeyboard)
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.commandDown = false
            self?.cancelAndHide()
        }
    }
    
    private func install(on keyboard: GCKeyboard?) {
        keyboard?.keyboardInput?.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            DispatchQueue.main.async {
                self?.handle(keyCode: keyCode, pressed: pressed)
            }
        }
    }
    
    private func handle(keyCode: GCKeyCode, pressed: Bool) {
        if keyCode == .leftGUI || keyCode == .rightGUI {
            if pressed {
                commandDown = true
                scheduleShow()
            } else {
                commandDown = false
                cancelAndHide()
            }
            return
        }
        /* any other key (a shortcut, or another modifier) cancels and closes the list */
        if pressed {
            cancelAndHide()
        }
    }
    
    private func scheduleShow() {
        pendingShow?.cancel()
        /* Settings > Customization > "Shortcut List (hold ⌘)" */
        guard booleanDefaults(key: "fork.shortcutHUD", defaultValue: true) else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.commandDown else { return }
            self.show()
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + KeyboardShortcutsHUD.holdDelay, execute: work)
    }
    
    private func cancelAndHide() {
        pendingShow?.cancel()
        pendingShow = nil
        guard let overlay = overlay else { return }
        self.overlay = nil
        UIView.animate(withDuration: 0.15, animations: { overlay.alpha = 0 }) { _ in
            overlay.removeFromSuperview()
        }
    }
    
    // MARK: collecting shortcuts
    
    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    private func currentCommands(in window: UIWindow) -> [(keys: String, title: String)] {
        /* start at the first responder, or at the top-most screen when nothing is focused */
        KeyboardShortcutsHUD.capturedResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.nx_captureFirstResponder(_:)), to: nil, from: nil, for: nil)
        var responder: UIResponder? = KeyboardShortcutsHUD.capturedResponder
        if responder == nil {
            var top = window.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            responder = top
        }
        
        var seen = Set<String>()
        var result: [(keys: String, title: String)] = []
        while let current = responder {
            for command in current.keyCommands ?? [] {
                let rawTitle = command.discoverabilityTitle ?? command.title
                guard !rawTitle.isEmpty else { continue }
                let keys = KeyboardShortcutsHUD.describe(command)
                guard seen.insert(keys).inserted else { continue }
                result.append((keys, KeyboardShortcutsHUD.spanishTitles[rawTitle] ?? rawTitle))
            }
            responder = current.next
        }
        return result
    }
    
    private static func describe(_ command: UIKeyCommand) -> String {
        var text = ""
        let flags = command.modifierFlags
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.alternate) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        
        let input = command.input ?? ""
        switch input {
        case UIKeyCommand.inputUpArrow: text += "↑"
        case UIKeyCommand.inputDownArrow: text += "↓"
        case UIKeyCommand.inputLeftArrow: text += "←"
        case UIKeyCommand.inputRightArrow: text += "→"
        case UIKeyCommand.inputEscape: text += "Esc"
        case "\t": text += "Tab"
        case "\r": text += "Return"
        case " ": text += "Espacio"
        default: text += input.uppercased()
        }
        return text
    }
    
    // MARK: overlay
    
    private func show() {
        guard overlay == nil, let window = keyWindow() else { return }
        let commands = currentCommands(in: window)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alpha = 0
        container.isUserInteractionEnabled = false
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        container.addSubview(blur)
        
        let title = UILabel()
        title.text = "Atajos de teclado"
        title.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 6
        
        if commands.isEmpty {
            let empty = UILabel()
            empty.text = "No hay atajos en esta pantalla."
            empty.textColor = .secondaryLabel
            empty.font = UIFont.systemFont(ofSize: 14)
            grid.addArrangedSubview(empty)
        }
        
        for command in commands {
            let keys = UILabel()
            keys.text = command.keys
            keys.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
            keys.textAlignment = .right
            keys.setContentHuggingPriority(.required, for: .horizontal)
            keys.widthAnchor.constraint(equalToConstant: 96).isActive = true
            
            let name = UILabel()
            name.text = command.title
            name.font = UIFont.systemFont(ofSize: 14)
            name.textColor = .label
            
            let row = UIStackView(arrangedSubviews: [keys, name])
            row.axis = .horizontal
            row.spacing = 14
            grid.addArrangedSubview(row)
        }
        
        let content = UIStackView(arrangedSubviews: [title, grid])
        content.axis = .vertical
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = true
        scroll.addSubview(content)
        blur.contentView.addSubview(scroll)
        
        window.addSubview(container)
        
        let maxHeight = container.heightAnchor.constraint(lessThanOrEqualTo: window.safeAreaLayoutGuide.heightAnchor, multiplier: 0.8)
        let fitHeight = scroll.heightAnchor.constraint(equalTo: content.heightAnchor)
        fitHeight.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            container.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, constant: -32),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            maxHeight,
            
            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            scroll.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 20),
            scroll.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -20),
            scroll.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -24),
            fitHeight,
            
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        
        overlay = container
        UIView.animate(withDuration: 0.2) { container.alpha = 1 }
    }
}

// MARK: - Fork: one-time defaults

// MARK: - Fork: Python 3

/// CPython for iOS run as a Nyxian utility in a terminal window.
/// Layout: <rootfs>/opt/python (PYTHONHOME: libpython, lib/python3.x, bin/python3).
/// Utilities can only reach Nyxian's rootfs, so scripts run from a copy of their
/// project in <rootfs>/var/mobile/Python/<project>.
enum ForkPython {
    static let version = "3.14"
    
    enum Failure: LocalizedError {
        case notBundled, signing(String), fastpath
        var errorDescription: String? {
            switch self {
            case .notBundled: return "This build of Nyxian has no Python runtime (Shared/python-ios.zip)."
            case .signing(let file): return "Could not sign \(file). Check that signing is set up (Settings > Certificate)."
            case .fastpath: return "Nyxian could not install the python3 launcher."
            }
        }
    }
    
    static var rootfs: URL { NXBootstrap.shared().rootfsURL }
    static var home: URL { rootfs.appendingPathComponent("opt/python") }
    static var sitePackages: URL { home.appendingPathComponent("lib/python\(version)/site-packages") }
    private static var bundledZip: URL { Bundle.main.bundleURL.appendingPathComponent("Shared/python-ios.zip") }
    private static let stampKey = "fork.python.stamp"
    private static let launcherKey = "fork.python.launcher"
    private static let signedKey = "fork.python.signedPackageBinaries"
    private static let signingRevision = 3  /* 3: pip may write all of opt/python */

    /// Python files Nyxian adds to site-packages: the line editor, the REPL, input() with echo.
    private static let helperFiles: [String: String] = [
        "nyxian_lineedit.py": #"""
# Nyxian line editor: Nyxian's terminal hands keys over raw (no echo, no line
# editing), so Python does both here. Used by input() and the Nyxian REPL.
# NYXIAN_KEYDEBUG=1 shows the code of every byte received.
import codecs
import os
import select
import sys

_history = []
_debug = os.environ.get("NYXIAN_KEYDEBUG") == "1"


def _write(text, fd=1):
    data = text.encode("utf-8", "replace")
    while data:
        try:
            written = os.write(fd, data)
        except InterruptedError:
            continue
        except OSError:
            return
        if written <= 0:
            return
        data = data[written:]


def _flush():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.flush()
        except Exception:
            pass


_pending = bytearray()  # bytes already read from the terminal, not used yet


def _read_byte():
    if _pending:
        byte = bytes(_pending[:1])
        del _pending[:1]
        return byte
    while True:
        try:
            return os.read(0, 1)
        except InterruptedError:
            continue


def _read_chunk():
    if _pending:
        chunk = bytes(_pending)
        _pending.clear()
        return chunk
    while True:
        try:
            return os.read(0, 4096)
        except InterruptedError:
            continue


def _swallow_lf():
    # CR LF from the terminal is one Enter, not two
    if _pending:
        if _pending[0] == 10:
            del _pending[:1]
        return
    try:
        ready, _, _ = select.select([0], [], [], 0.02)
    except Exception:
        return
    if not ready:
        return
    data = _read_byte()
    if data and data[0] != 10:
        _pending.extend(data)


# Bracketed paste: the terminal marks pasted text with ESC[200~ … ESC[201~,
# so a pasted block arrives whole instead of as typed lines.
_PASTE_END = b"\x1b[201~"
_paste_mode = False


def _enable_paste_mode():
    global _paste_mode
    if not _paste_mode:
        _paste_mode = True
        _write("\x1b[?2004h")
        import atexit
        atexit.register(lambda: _write("\x1b[?2004l"))


def _read_paste():
    data = bytearray()
    while _PASTE_END not in data:
        chunk = _read_chunk()
        if not chunk:
            break
        data.extend(chunk)
    end = data.find(_PASTE_END)
    if end >= 0:
        _pending[:0] = data[end + len(_PASTE_END):]
        del data[end:]
    return data.decode("utf-8", "replace")


_INVISIBLE_SPACES = "\u00a0\u2007\u202f\u2002\u2003\u2004\u2005\u2006\u2008\u2009\u200a\u3000"
_ZERO_WIDTH = "\u200b\u200c\u200d\u2060\ufeff"


def clean_paste(text, code=True):
    """Pasted code from web pages, chats or notes: line ends of any kind,
    non-breaking and other look-alike spaces, zero-width characters, curly
    quotes, tabs in the indentation, and the indentation common to all
    lines (code copied from inside a block)."""
    import textwrap
    # the terminal turns CR into LF, so CR LF line ends arrive as two LF: when
    # every line end is doubled, they were CR LF
    parts = text.split("\n\n")
    if len(parts) > 1 and not any("\n" in part for part in parts):
        text = "\n".join(parts)
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\u2028", "\n").replace("\u2029", "\n")
    for ch in _INVISIBLE_SPACES:
        text = text.replace(ch, " ")
    for ch in _ZERO_WIDTH:
        text = text.replace(ch, "")
    if code:
        text = "".join(_QUOTES.get(ch, ch) for ch in text)
        lines = []
        for line in text.split("\n"):
            stripped = line.lstrip(" \t")
            lines.append(line[: len(line) - len(stripped)].expandtabs(4) + stripped)
        text = textwrap.dedent("\n".join(lines))
        text = "\n".join(line.rstrip() for line in text.split("\n"))
    return text.strip("\n")


class Pasted(str):
    """A block of several pasted lines, returned whole by read_line."""


def _input_waiting():
    if _pending:
        return True
    try:
        ready, _, _ = select.select([0], [], [], 0)
    except Exception:
        return False
    return bool(ready)


_QUOTES = {"\u201c": '"', "\u201d": '"', "\u201e": '"', "\u2018": "'", "\u2019": "'"}


def read_line(prompt="", indent="", code=False):
    """Reads one line. indent is shown and kept in front of the line (not
    when text was pasted or typed ahead); code=True turns curly quotes from
    the keyboard into straight ones.
    Keys: ← → move, Home/End and Ctrl-A/Ctrl-E jump, ↑ ↓ history,
    ⌫ / Delete erase, Ctrl-W erases a word, Ctrl-K to the end of the line,
    Ctrl-L clears the screen, Tab indents."""
    _flush()
    _enable_paste_mode()
    if prompt:
        _write(prompt)
    buffer = []
    state = {"pos": 0}
    if indent and not _input_waiting():
        buffer.extend(indent)
        state["pos"] = len(buffer)
        _write(indent)
    index = len(_history)
    decoder = codecs.getincrementaldecoder("utf-8")("replace")

    def insert(text):
        pos = state["pos"]
        tail = buffer[pos:]
        buffer[pos:pos] = list(text)
        state["pos"] = pos + len(text)
        _write(text + "".join(tail) + "\b" * len(tail))

    def erase_before(count):
        pos = state["pos"]
        count = min(count, pos)
        if count <= 0:
            return
        tail = buffer[pos:]
        del buffer[pos - count:pos]
        state["pos"] = pos - count
        _write("\b" * count + "".join(tail) + " " * count + "\b" * (len(tail) + count))

    def erase_at():
        pos = state["pos"]
        if pos >= len(buffer):
            return
        del buffer[pos]
        tail = buffer[pos:]
        _write("".join(tail) + " " + "\b" * (len(tail) + 1))

    def move(to):
        pos = state["pos"]
        to = max(0, min(len(buffer), to))
        if to < pos:
            _write("\b" * (pos - to))
        elif to > pos:
            _write("".join(buffer[pos:to]))
        state["pos"] = to

    def replace_all(chars):
        move(len(buffer))
        _write("\b \b" * len(buffer))
        buffer[:] = list(chars)
        state["pos"] = len(buffer)
        _write("".join(buffer))

    while True:
        data = _read_byte()
        if not data:
            if not buffer:
                raise EOFError
            break
        c = data[0]
        if _debug:
            _write("[%d]" % c)
        if c in (10, 13):
            if c == 13:
                _swallow_lf()
            move(len(buffer))
            _write("\n")
            break
        if c in (8, 127):
            pos = state["pos"]
            count = 1
            if pos and all(ch == " " for ch in buffer[:pos]):
                count = (pos - 1) % 4 + 1
            erase_before(count)
            continue
        if c == 3:
            move(len(buffer))
            _write("^C\n")
            raise KeyboardInterrupt
        if c == 4:
            if not buffer:
                _write("\n")
                raise EOFError
            erase_at()
            continue
        if c == 1:
            move(0)
            continue
        if c == 5:
            move(len(buffer))
            continue
        if c == 11:
            pos = state["pos"]
            count = len(buffer) - pos
            del buffer[pos:]
            _write(" " * count + "\b" * count)
            continue
        if c == 12:
            _write("\x1b[2J\x1b[H" + prompt + "".join(buffer) + "\b" * (len(buffer) - state["pos"]))
            continue
        if c == 23:
            pos = state["pos"]
            start = pos
            while start and buffer[start - 1] == " ":
                start -= 1
            while start and buffer[start - 1] != " ":
                start -= 1
            erase_before(pos - start)
            continue
        if c == 9:
            insert("    ")
            continue
        if c == 27:
            kind = _read_byte()
            if kind not in (b"[", b"O"):
                continue
            params = b""
            final = _read_byte()
            while final and final in b"0123456789;":
                params += final
                final = _read_byte()
            if final in (b"A", b"B"):
                if _history:
                    index = max(0, index - 1) if final == b"A" else min(len(_history), index + 1)
                    replace_all(_history[index] if index < len(_history) else "")
            elif final == b"C":
                move(state["pos"] + 1)
            elif final == b"D":
                move(state["pos"] - 1)
            elif final == b"H" or (final == b"~" and params in (b"1", b"7")):
                move(0)
            elif final == b"F" or (final == b"~" and params in (b"4", b"8")):
                move(len(buffer))
            elif final == b"~" and params == b"3":
                erase_at()
            elif final == b"~" and params == b"200":
                text = clean_paste(_read_paste(), code)
                if code and "\n" in text:
                    # a block: shown with "... " in front, run whole by the REPL
                    move(len(buffer))
                    lines = text.split("\n")
                    _write(lines[0] + "".join("\n... " + line for line in lines[1:]) + "\n")
                    source = "".join(buffer) + text
                    if source.strip():
                        _history.append(source)
                    return Pasted(source)
                insert(text.replace("\n", " ") if text else "")
            continue
        if c < 32:
            continue
        text = decoder.decode(data)
        if text:
            if code:
                text = "".join(_QUOTES.get(ch, ch) for ch in text)
            insert(text)
    line = "".join(buffer)
    if line.strip():
        _history.append(line)
    return line
"""#,
        "nyxian_repl.py": #"""
# The REPL of Python in Nyxian: the standard interactive console with
# Nyxian's line editor (echo, backspace, history, Tab indents, automatic
# indentation inside blocks: an empty Enter ends the block). Results and
# errors are written straight to the terminal and flushed after every line.
import code
import os
import sys
import traceback

from nyxian_lineedit import Pasted, _flush, _write, read_line


class NyxianConsole(code.InteractiveConsole):
    _last = ""

    def raw_input(self, prompt=""):
        # inside a block (prompt "... "), keep the indentation of the line
        # above, one level more after a line ending in ":"; a line with only
        # spaces ends the block
        indent = ""
        if self.buffer:
            last = self._last
            indent = last[: len(last) - len(last.lstrip(" \t"))]
            if last.rstrip().endswith(":"):
                indent += "    "
        line = read_line(prompt, indent, code=True)
        if isinstance(line, Pasted):
            source = "\n".join(self.buffer + [str(line)])
            self.resetbuffer()
            self._last = ""
            self.run_block(source)
            return ""
        if self.buffer and not line.strip():
            line = ""
        self._last = line
        return line

    def run_block(self, source):
        """Runs pasted code statement by statement, like typed lines, so
        blank lines inside a def and code after a block are fine, and the
        value of an expression is shown."""
        import ast
        try:
            tree = ast.parse(source, "<stdin>", "exec")
        except SyntaxError:
            self.showsyntaxerror("<stdin>")
            return
        for node in tree.body:
            try:
                compiled = compile(ast.Interactive([node]), "<stdin>", "single")
                exec(compiled, self.locals)
            except SystemExit:
                raise
            except SyntaxError:
                self.showsyntaxerror("<stdin>")
                return
            except BaseException:
                self.showtraceback()
                return
            finally:
                _flush()

    def write(self, data):
        _flush()
        _write(data, 2)

    def push(self, line, *args, **kwargs):
        try:
            return super().push(line, *args, **kwargs)
        except SystemExit:
            raise
        except BaseException:
            self.resetbuffer()
            self.write("".join(traceback.format_exception(*sys.exc_info())))
            return False
        finally:
            _flush()


def _warm_pip():
    # compiles pip once in the background, so the first pip install does not
    # spend its first minutes doing it
    try:
        import compileall
        import importlib.util
        spec = importlib.util.find_spec("pip")
        if not spec or not spec.submodule_search_locations:
            return
        folder = list(spec.submodule_search_locations)[0]
        marker = os.path.join(sys.pycache_prefix or folder, ".nyxian-pip-compiled-%s" % sys.version.split()[0])
        if os.path.exists(marker):
            return
        compileall.compile_dir(folder, quiet=2, workers=1)
        os.makedirs(os.path.dirname(marker), exist_ok=True)
        open(marker, "w").close()
    except Exception:
        pass


def main():
    import threading
    threading.Thread(target=_warm_pip, daemon=True).start()
    banner = (
        "Python %s on Nyxian (%s)\n"
        "Type help(), copyright(), credits() or license(). Ctrl-D or exit() quits."
        % (sys.version.split()[0], sys.platform)
    )
    console = NyxianConsole(locals={"__name__": "__main__", "__doc__": None})
    args = sys.argv[1:]
    if "--cell" in args and args.index("--cell") + 1 < len(args):
        # cells of a .py file (# %%), sent by Nyxian's editor: the first one
        # comes as a file, the next ones are pasted into this console
        path = args[args.index("--cell") + 1]
        _write("Python %s · cells (# %%%%) of the editor run here; their variables stay.\n" % sys.version.split()[0])
        try:
            with open(path, encoding="utf-8") as handle:
                source = handle.read()
            if source.strip():
                lines = source.rstrip("\n").split("\n")
                _write(">>> " + lines[0] + "".join("\n... " + line for line in lines[1:]) + "\n")
                console.run_block(source)
        except OSError as error:
            _write("Could not read the cell: %s\n" % error, 2)
        console.interact(banner="", exitmsg="")
        return
    console.interact(banner=banner, exitmsg="")


if __name__ == "__main__":
    main()
"""#,
        "nyxian_keytest.py": #"""
# Keyboard test of Nyxian's Python terminal: shows the code of every byte
# Python receives, so a key that does nothing can be told apart.
import os
import sys

from nyxian_lineedit import _write

NAMES = {3: "Ctrl-C", 4: "Ctrl-D", 9: "Tab", 10: "LF (Enter)", 13: "CR (Enter)", 27: "Esc", 127: "Backspace"}


def main():
    _write("Python keyboard test: press keys, Enter included. Ctrl-D twice quits.\n")
    try:
        _write("stdin isatty=%s stdout isatty=%s\n" % (os.isatty(0), os.isatty(1)))
        import termios
        attrs = termios.tcgetattr(0)
        _write("iflag=%#x oflag=%#x lflag=%#x\n" % (attrs[0], attrs[1], attrs[3]))
    except Exception as error:
        _write("termios: %r\n" % (error,))
    print("print() works", flush=True)
    sys.stderr.write("sys.stderr works\n")
    sys.stderr.flush()
    last = None
    while True:
        data = os.read(0, 64)
        if not data:
            _write("EOF\n")
            break
        for c in data:
            _write("byte %3d %s\n" % (c, NAMES.get(c, repr(chr(c)) if 32 <= c < 127 else "")))
            if c == 4 and last == 4:
                return
            last = c


if __name__ == "__main__":
    main()
"""#,
        "nyxian_pip.py": #"""
# pip in Nyxian: says at once that it started, shows that it is still working
# when pip prints nothing for a while, and after a long silence prints where
# it is waiting (to report it). Run as: python3 -m nyxian_pip install NAME…
import faulthandler
import os
import sys
import threading
import time

from nyxian_lineedit import _write

QUIET_NOTE = 20     # seconds without output before "still working"
STUCK_DUMP = 180    # seconds without output before printing where pip waits


class _Tracking:
    def __init__(self, stream, state):
        self._stream = stream
        self._state = state

    def write(self, text):
        self._state["last"] = time.monotonic()
        return self._stream.write(text)

    def __getattr__(self, name):
        return getattr(self._stream, name)


def _watch(state):
    dumped = False
    while not state["done"]:
        time.sleep(2)
        quiet = time.monotonic() - state["last"]
        total = int(time.monotonic() - state["start"])
        if quiet >= QUIET_NOTE and int(quiet) % QUIET_NOTE < 2:
            _write("  … still working (%d s)\n" % total, 2)
        if quiet >= STUCK_DUMP and not dumped:
            dumped = True
            _write("\n[pip has printed nothing for %d s. Where it is waiting:]\n" % int(quiet), 2)
            faulthandler.dump_traceback(file=sys.__stderr__, all_threads=True)
            _write("[You can wait, or close with ✕ and try again]\n\n", 2)


def main():
    args = sys.argv[1:] or ["--help"]
    _write("pip %s\n" % " ".join(args))
    _write("Starting pip… (the first time after an update it takes a little longer)\n")
    state = {"start": time.monotonic(), "last": time.monotonic(), "done": False}
    sys.stdout = _Tracking(sys.stdout, state)
    sys.stderr = _Tracking(sys.stderr, state)
    threading.Thread(target=_watch, args=(state,), daemon=True).start()
    try:
        from pip._internal.cli.main import main as pip_main
        code = pip_main(args)
    finally:
        state["done"] = True
    _write("\n%s in %d s.\n" % ("Done" if not code else "pip ended with errors", time.monotonic() - state["start"]))
    if not code and args and args[0] == "install":
        _write("New binary modules are signed the next time Python opens.\n")
    sys.exit(code)


if __name__ == "__main__":
    main()
"""#,
        "nyxian_mplbackend.py": #"""
# matplotlib in Nyxian: plt.show() saves the open figures as PNG (in
# figures/ of the run folder, copied into the project when the run ends) and
# asks Nyxian's terminal to show them.
import os
import sys

from matplotlib.backend_bases import FigureManagerBase as FigureManager  # noqa: F401
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas  # noqa: F401


def _folder():
    folder = os.environ.get("NYXIAN_PLOT_DIR") or os.path.join(os.getcwd(), "figures")
    os.makedirs(folder, exist_ok=True)
    return folder


def show(*args, **kwargs):
    import matplotlib.pyplot as plt
    from matplotlib import _pylab_helpers

    managers = _pylab_helpers.Gcf.get_all_fig_managers()
    if not managers:
        return
    paths = []
    for manager in managers:
        path = os.path.join(_folder(), "figure-%s.png" % manager.num)
        manager.canvas.figure.savefig(path, dpi=144, bbox_inches="tight")
        paths.append(path)
    plt.close("all")
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.flush()
        except Exception:
            pass
    # private sequence, taken out by Nyxian's terminal before it is drawn
    os.write(1, ("\x1b]7770;nyxian-preview;%s\x07" % "|".join(paths)).encode("utf-8"))
    names = ", ".join(os.path.relpath(path) for path in paths)
    os.write(1, ("[figure: %s]\n" % names).encode("utf-8"))
"""#,
        "nyxian_jedi.py": #"""
# Python help for Nyxian's editor, without a window: one JSON request per
# line on stdin, one JSON answer per line on stdout.
#   complete: suggestions at a position (jedi)
#   diagnose: syntax errors and warnings of the text (the compiler itself)
import json
import os
import sys
import warnings

_LIB = os.path.join(sys.prefix, "lib", "nyxian")
if os.path.isdir(_LIB) and _LIB not in sys.path:
    sys.path.append(_LIB)

try:
    import jedi
    jedi.settings.cache_directory = os.path.join(os.environ.get("HOME") or "/tmp", "Library", "Caches", "jedi")
    _JEDI_ERROR = None
except Exception as error:  # completion off, diagnostics still work
    jedi = None
    _JEDI_ERROR = repr(error)

_projects = {}

KINDS = {"function": 11, "class": 10, "module": 3, "keyword": 1, "instance": 12, "statement": 12, "param": 12, "property": 12, "path": 3}


def _project(root):
    if not root or jedi is None:
        return None
    if root not in _projects:
        try:
            _projects[root] = jedi.Project(path=root, added_sys_path=[root])
        except Exception:
            _projects[root] = None
    return _projects[root]


def complete(request):
    script = jedi.Script(code=request["source"], path=request.get("path") or None, project=_project(request.get("root")))
    items = []
    for index, completion in enumerate(script.complete(request["line"], request["column"])):
        if index >= 600:
            break
        kind = completion.type
        item = {"text": completion.name, "display": completion.name, "type": kind, "kind": KINDS.get(kind, 0)}
        if index < 20:
            try:
                signatures = completion.get_signatures() if kind in ("function", "class") else []
                if signatures:
                    item["display"] = signatures[0].to_string()[:90]
                text = completion.docstring(raw=True) or ""
                summary = " ".join(text.strip().split("\n\n")[0].split())
                if summary:
                    item["doc"] = summary[:220]
            except Exception:
                pass
        if kind == "function":
            item["insert"] = completion.name + "()"
            item["cursor"] = len(completion.name) + 1
        items.append(item)
    return items


def diagnose(request):
    source = request["source"]
    path = request.get("path") or "<editor>"
    problems = []
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        try:
            compile(source, path, "exec", dont_inherit=True)
        except SyntaxError as error:
            problems.append({"line": error.lineno or 1, "column": error.offset or 1, "level": "error",
                             "message": "%s: %s" % (type(error).__name__, error.msg)})
        except ValueError as error:
            problems.append({"line": 1, "column": 1, "level": "error", "message": str(error)})
        for warning in caught:
            if issubclass(warning.category, SyntaxWarning):
                problems.append({"line": warning.lineno or 1, "column": 1, "level": "warning",
                                 "message": "SyntaxWarning: %s" % warning.message})
    return problems


def main():
    for raw in sys.stdin.buffer:
        try:
            request = json.loads(raw)
        except Exception:
            continue
        answer = {"id": request.get("id")}
        try:
            op = request.get("op")
            if op == "ping":
                answer.update(ok=jedi is not None, error=_JEDI_ERROR, jedi=getattr(jedi, "__version__", None))
            elif op == "diagnose":
                answer["problems"] = diagnose(request)
            elif op == "complete":
                answer["items"] = complete(request) if jedi is not None else []
                if jedi is None:
                    answer["error"] = _JEDI_ERROR
        except Exception as error:
            answer["error"] = repr(error)
        data = (json.dumps(answer) + "\n").encode("utf-8")
        while data:
            data = data[os.write(1, data):]


if __name__ == "__main__":
    main()
"""#,
        "sitecustomize.py": #"""
# Nyxian: only when Python runs in a Nyxian terminal window, input() echoes
# what you type (the terminal does not), sys.stdout / sys.stderr write
# straight to the terminal, and Ctrl-\ prints where Python is stuck.
import os

import sys

if os.environ.get("NYXIAN_TERMINAL") == "1":
    try:
        import io

        def _stream(fd):
            raw = io.FileIO(fd, "w", closefd=False)
            return io.TextIOWrapper(raw, encoding="utf-8", errors="backslashreplace", line_buffering=True, write_through=True)

        sys.stdout = sys.__stdout__ = _stream(1)
        sys.stderr = sys.__stderr__ = _stream(2)
    except Exception:
        pass
    try:
        import faulthandler
        import signal

        faulthandler.register(signal.SIGQUIT, file=sys.stderr, all_threads=True, chain=False)
    except Exception:
        pass
    if os.environ.get("NYXIAN_ERROR_FILE"):
        # a script that ends with an error tells Nyxian's editor the line
        try:
            _previous_hook = sys.excepthook

            def _nyxian_excepthook(kind, value, tb):
                try:
                    import json
                    import traceback
                    folder = os.getcwd()
                    frames = [frame for frame in traceback.extract_tb(tb) if frame.filename.startswith(folder)]
                    if isinstance(value, SyntaxError) and value.filename and value.filename.startswith(folder):
                        where = {"file": value.filename, "line": value.lineno or 1}
                    elif frames:
                        where = {"file": frames[-1].filename, "line": frames[-1].lineno or 1}
                    else:
                        where = None
                    if where:
                        where["message"] = "".join(traceback.format_exception_only(kind, value)).strip()
                        with open(os.environ["NYXIAN_ERROR_FILE"], "w") as handle:
                            json.dump(where, handle)
                except Exception:
                    pass
                _previous_hook(kind, value, tb)

            sys.excepthook = _nyxian_excepthook
        except Exception:
            pass
    try:
        import builtins
        from nyxian_lineedit import read_line

        def _nyxian_input(prompt=""):
            return read_line(str(prompt))

        builtins.input = _nyxian_input
    except Exception:
        pass
"""#
    ]
    
    private static func writeHelperFiles() {
        try? FileManager.default.createDirectory(at: sitePackages, withIntermediateDirectories: true)
        for (name, text) in helperFiles {
            let url = sitePackages.appendingPathComponent(name)
            if (try? String(contentsOf: url, encoding: .utf8)) != text {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    /// The pristine launcher, kept before signing so every attempt signs a fresh copy.
    private static var launcherOriginal: URL { home.appendingPathComponent("bin/.python3.original") }
    
    private static func signLauncher(_ launcher: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: launcherOriginal.path) {
            try? fm.removeItem(at: launcher)
            guard (try? fm.copyItem(at: launcherOriginal, to: launcher)) != nil else { return false }
        }
        guard LCUtils.signMachO(at: launcher) else { return false }
        _ = trust_nxt2_sign(launcher.path, launcherEntitlements as CFDictionary, true, nil)
        return true
    }
    
    /*
     * The installing service checks the launcher's signature; the first signature made
     * right after unpacking can be refused, which is why a second full install used to
     * work. Each retry signs a fresh copy again (what that second install did), then
     * asks again. The service also only waits 2 s for the answer.
     */
    private static func fastpath(_ launcher: URL, progress: (String) -> Void) -> String? {
        for attempt in 1...6 {
            if let path = LDEApplicationWorkspace.shared().fastpathUtility(launcher.path) { return path }
            progress("Installing python3… (attempt \(attempt + 1))")
            Thread.sleep(forTimeInterval: 0.5)
            _ = signLauncher(launcher)
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }
    
    /*
     * What the python3 process may touch. Nyxian gives a utility file access only to
     * the paths its NXT2 entitlements list (with the file-system sandbox on), so
     * without these dyld cannot even read libpython ("blocked by sandbox").
     */
    private static var launcherEntitlements: [String: Any] {
        [
            "org.emexlabs.nyxian.get-task-allow": true,   /* debugger and profiler */
            "org.emexlabs.nyxian.sandbox.file.read": [
                "$(NXROOT)/opt/python"
            ],
            "org.emexlabs.nyxian.sandbox.file.read-write": [
                /* pip writes site-packages and also bin/ (command scripts), share/, include/ */
                "$(NXROOT)/opt/python",
                "$(NXROOT)/var/mobile"   /* home, run folders, caches */
            ]
        ]
    }
    
    /// Wheels for iOS load @rpath/Python.framework/Python; libpython's rpath
    /// (@loader_path/Frameworks) finds this link to libpython itself.
    private static func linkPythonFramework() {
        let fm = FileManager.default
        let framework = home.appendingPathComponent("Frameworks/Python.framework")
        let link = framework.appendingPathComponent("Python")
        if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil { return }
        try? fm.removeItem(at: link)
        try? fm.createDirectory(at: framework, withIntermediateDirectories: true)
        try? fm.createSymbolicLink(atPath: link.path, withDestinationPath: "../../libpython\(version).dylib")
    }
    
    /// Binary modules pip put in site-packages since the last run (numpy, Pillow…) get signed, or iOS refuses to load them.
    private static func signNewPackageBinaries(progress: (String) -> Void) throws {
        let fm = FileManager.default
        var signed = UserDefaults.standard.dictionary(forKey: signedKey) as? [String: Double] ?? [:]
        var pending: [(URL, Double)] = []
        if let enumerator = fm.enumerator(at: sitePackages, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey]) {
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]), values.isRegularFile == true else { continue }
                let ext = url.pathExtension.lowercased()
                guard ext == "so" || ext == "dylib" || url.path.contains(".framework/") else { continue }
                let stamp = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                if signed[url.path] == stamp || !isMachO(url) { continue }
                pending.append((url, stamp))
            }
        }
        guard !pending.isEmpty else { return }
        /* a file Nyxian was signing when it closed last time is left out, so a
           binary that makes signing fail cannot make every Python launch fail */
        let defaults = UserDefaults.standard
        var skipped = defaults.stringArray(forKey: skippedKey) ?? []
        if let interrupted = defaults.string(forKey: signingNowKey) {
            defaults.removeObject(forKey: signingNowKey)
            if !skipped.contains(interrupted) { skipped.append(interrupted) }
            defaults.set(skipped, forKey: skippedKey)
            NSLog("[ForkPython] signing was interrupted at %@; it is skipped from now on", interrupted)
        }
        for (index, entry) in pending.enumerated() {
            if skipped.contains(entry.0.path) { continue }
            progress("Signing installed packages… \(index + 1)/\(pending.count)\n\(entry.0.lastPathComponent)")
            defaults.set(entry.0.path, forKey: signingNowKey)
            defaults.synchronize()
            let ok = LCUtils.signMachOWithoutPatch(at: entry.0)
            if ok { _ = trust_nxt2_sign(entry.0.path, [String: Any]() as CFDictionary, true, nil) }
            defaults.removeObject(forKey: signingNowKey)
            guard ok else { throw Failure.signing(entry.0.lastPathComponent) }
            /* the signature changes the file: remember its new date, file by file */
            let date = (try? entry.0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? entry.1
            signed[entry.0.path] = date
            defaults.set(signed, forKey: signedKey)
        }
    }
    private static let signingNowKey = "fork.python.signingNow"
    private static let bundledMergedKey = "fork.python.bundledMerged"
    private static let skippedKey = "fork.python.signingSkipped"
    private static let queue = DispatchQueue(label: "fork.python.install")
    
    private static func isMachO(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4), data.count == 4 else { return false }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return magic == 0xfeedfacf || magic == 0xcffaedfe || magic == 0xbebafeca || magic == 0xcafebabe
    }
    
    /// Unpacks and signs the runtime when the bundled one changed; returns the launcher to run.
    static func prepare(progress: @escaping (String) -> Void) throws -> String {
        try queue.sync {
            let fm = FileManager.default
            guard let attributes = try? fm.attributesOfItem(atPath: bundledZip.path) else { throw Failure.notBundled }
            /* the suffix changes whenever the way Python is signed changes, so devices sign again */
            let stamp = "\((attributes[.size] as? NSNumber)?.intValue ?? 0)-\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)-\(signingRevision)"
            let defaults = UserDefaults.standard
            if defaults.string(forKey: stampKey) == stamp,
               let launcher = defaults.string(forKey: launcherKey),
               fm.fileExists(atPath: launcher),
               fm.fileExists(atPath: home.appendingPathComponent("libpython\(version).dylib").path) {
                linkPythonFramework()
                writeHelperFiles()
                try signNewPackageBinaries(progress: progress)
                return launcher
            }
            
            progress("Unpacking Python \(version)…")
            defaults.removeObject(forKey: signedKey)
            defaults.removeObject(forKey: skippedKey)
            let opt = home.deletingLastPathComponent()
            /* packages installed with pip survive a new runtime (every Nyxian update unpacks it again) */
            let kept = opt.appendingPathComponent(".site-packages-kept")
            if fm.fileExists(atPath: sitePackages.path) {
                try? fm.removeItem(at: kept)
                try? fm.moveItem(at: sitePackages, to: kept)
            }
            try? fm.removeItem(at: home)
            try fm.createDirectory(at: opt, withIntermediateDirectories: true)
            guard unzipArchiveAtPath(bundledZip.path, opt.path) else { throw Failure.notBundled }
            linkPythonFramework()
            
            /* every binary has to carry Nyxian's signature to be loaded */
            progress("Signing Python…")
            var binaries: [URL] = []
            if let enumerator = fm.enumerator(at: home, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let url as URL in enumerator where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true && isMachO(url) {
                    binaries.append(url)
                }
            }
            let launcherURL = home.appendingPathComponent("bin/python3")
            /* libraries first, the launcher last */
            binaries.removeAll { $0.path == launcherURL.path }
            for (index, url) in binaries.enumerated() {
                if index % 10 == 0 { progress("Signing Python… \(index)/\(binaries.count)") }
                guard LCUtils.signMachOWithoutPatch(at: url) else { throw Failure.signing(url.lastPathComponent) }
                _ = trust_nxt2_sign(url.path, [String: Any]() as CFDictionary, true, nil)
            }
            /* bundled packages were just signed: not again when site-packages is put together */
            var signedNow: [String: Double] = [:]
            for url in binaries where url.path.hasPrefix(sitePackages.path + "/") {
                signedNow[url.path] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
            }
            defaults.set(signedNow, forKey: signedKey)
            progress("Signing python3…")
            try? fm.removeItem(at: launcherOriginal)
            try? fm.copyItem(at: launcherURL, to: launcherOriginal)
            guard signLauncher(launcherURL) else { throw Failure.signing("python3") }
            
            /* pip, straight from ensurepip's bundled wheel (ensurepip itself needs subprocesses) */
            let bundledList = (try? String(contentsOf: home.appendingPathComponent("BUNDLED_PACKAGES"), encoding: .utf8)) ?? ""
            if fm.fileExists(atPath: kept.path) {
                progress("Keeping your packages…")
                /* packages that come with the runtime (numpy, scipy, …) join the kept ones, once per
                   new set — never over a version installed by you, and not again after you uninstalled them */
                if defaults.string(forKey: bundledMergedKey) != bundledList {
                    func distribution(_ name: String) -> String {
                        String(name.prefix { $0 != "-" }).lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: ".", with: "_")
                    }
                    let keptItems = Set((try? fm.contentsOfDirectory(atPath: kept.path)) ?? [])
                    let keptDistributions = Set(keptItems.filter { $0.hasSuffix(".dist-info") }.map(distribution))
                    for item in (try? fm.contentsOfDirectory(atPath: sitePackages.path)) ?? [] {
                        if keptItems.contains(item) { continue }
                        if item.hasSuffix(".dist-info"), keptDistributions.contains(distribution(item)) { continue }
                        try? fm.moveItem(at: sitePackages.appendingPathComponent(item), to: kept.appendingPathComponent(item))
                    }
                }
                try? fm.removeItem(at: sitePackages)
                try? fm.createDirectory(at: sitePackages.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.moveItem(at: kept, to: sitePackages)
            }
            defaults.set(bundledList, forKey: bundledMergedKey)
            if !fm.fileExists(atPath: sitePackages.appendingPathComponent("pip").path) {
                progress("Installing pip…")
                try? fm.createDirectory(at: sitePackages, withIntermediateDirectories: true)
                let bundled = home.appendingPathComponent("lib/python\(version)/ensurepip/_bundled")
                if let wheels = try? fm.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil) {
                    for wheel in wheels where wheel.pathExtension == "whl" && wheel.lastPathComponent.hasPrefix("pip-") {
                        _ = unzipArchiveAtPath(wheel.path, sitePackages.path)
                    }
                }
            }
            
            writeHelperFiles()
            /* kept packages are signed again for the new runtime */
            try signNewPackageBinaries(progress: progress)
            guard let launcher = fastpath(launcherURL, progress: progress) else { throw Failure.fastpath }
            defaults.set(stamp, forKey: stampKey)
            defaults.set(launcher, forKey: launcherKey)
            return launcher
        }
    }
    
    /// Same files in a folder Python can read, keeping unchanged files untouched.
    // MARK: Python projects (template "Python")
    
    private static let projectMarker = "Config/.nyxian-python"
    
    static func isPythonProject(_ project: NXProject) -> Bool {
        FileManager.default.fileExists(atPath: (project.url as URL).appendingPathComponent(projectMarker).path)
    }
    
    /// Turns a new command line tool project into a Python one: its template
    /// sources go, main.py comes, and a marker says what it is.
    static func makePythonProject(_ project: NXProject, name: String) {
        let fm = FileManager.default
        let root = project.url as URL
        let sources: Set<String> = ["c", "h", "m", "mm", "cpp", "cc", "cxx", "hpp", "swift"]
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "Config" { enumerator.skipDescendants(); continue }
                if sources.contains(url.pathExtension.lowercased()) { try? fm.removeItem(at: url) }
            }
        }
        let main = """
        # \(name) — main.py
        #
        # Python \(version) en Nyxian.
        #   ▶ (o ⌘R) corre el archivo .py abierto.
        #   Crea más archivos con New › File (nombre.py) en este proyecto.
        #   Paquetes: menú </> › Install Package (pip)…
        #   Archivos que el script cree: "Copy Python Output to Project" (⇧⌘R).

        import sys

        nombre = input("¿Cómo te llamas? ")
        print(f"Hola {nombre}, esto es Python {sys.version.split()[0]}")

        """
        try? main.write(to: root.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        fm.createFile(atPath: root.appendingPathComponent(projectMarker).path, contents: Data("python\n".utf8))
    }
    
    /// ▶ / ⌘R in a Python project: the .py on screen, else main.py, else the first .py.
    static func runProject(_ project: NXProject, from presenter: UIViewController) {
        let root = project.url as URL
        let script = LiveEditorRegistry.visiblePythonFile(under: root)
            ?? [root.appendingPathComponent("main.py")].first { FileManager.default.fileExists(atPath: $0.path) }
            ?? ProjectFileIndex.files(in: root).first { $0.pathExtension.lowercased() == "py" }
        guard let script else {
            presenter.forkGitHubAlert("Python", "This project has no .py file yet. Make one with New › File (name.py).")
            return
        }
        run(script: script, project: project, from: presenter)
    }
    
    /// Folder a project (or a loose script's folder) runs in: a copy under the rootfs.
    static func mirrorFolder(project root: URL) -> URL {
        rootfs.appendingPathComponent("var/mobile/Python").appendingPathComponent(root.lastPathComponent)
    }
    
    /// Copies the project into its run folder: files in open editors as they
    /// are now, the others only when changed (size or date), without reading
    /// them into memory; build folders and very large files are left out.
    static func mirror(project root: URL, openTexts: [String: Data] = [:]) throws -> URL {
        let fm = FileManager.default
        let destination = mirrorFolder(project: root)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let skippedFolders: Set<String> = ["Config", ".build", "build", "Previews", "__pycache__", ".git", "DerivedData", "node_modules"]
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return destination }
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true {
                if skippedFolders.contains(url.lastPathComponent) || url.pathExtension == "app" { enumerator.skipDescendants() }
                continue
            }
            guard values.isRegularFile == true else { continue }
            let relative = ProjectFileIndex.relativePath(url, root: root)
            let target = destination.appendingPathComponent(relative)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let text = openTexts[url.resolvingSymlinksInPath().standardizedFileURL.path] {
                if let existing = try? Data(contentsOf: target), existing == text { continue }
                try text.write(to: target, options: .atomic)
                continue
            }
            if (values.fileSize ?? 0) > 100 * 1024 * 1024 { continue }
            if let existing = try? target.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
               existing.fileSize == values.fileSize,
               let a = existing.contentModificationDate, let b = values.contentModificationDate, a >= b {
                continue
            }
            try? fm.removeItem(at: target)
            try fm.copyItem(at: url, to: target)
        }
        return destination
    }
    
    /// Opens python3 with `arguments` in a terminal window.
    /// UserDefaults key of the font size of Python windows (Settings → Customization, A−/A+ in the key bar).
    static let fontSizeKey = "fork.python.fontSize.v2"   /* v2: new defaults, earlier sizes are not kept */
    /// 24 pt on iPad, 18 on iPhone (Nyxian's terminal: 14 and 10).
    static var defaultFontSize: Int { UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18 }
    static var fontSize: Int {
        let saved = UserDefaults.standard.integer(forKey: fontSizeKey)
        return saved > 0 ? saved : defaultFontSize
    }
    
    private static var pathWithPythonBin: String {
        let bin = home.appendingPathComponent("bin").path
        var entries = [bin]
        if bin.hasPrefix("/private/") {
            entries.append(String(bin.dropFirst("/private".count)))
        } else if bin.hasPrefix("/var/") {
            entries.append("/private" + bin)
        }
        entries.append(contentsOf: ["/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"])
        return entries.joined(separator: ":")
    }
    
    /// The controller to present from: the top one shown over `presenter`.
    private static func host(for presenter: UIViewController) -> UIViewController {
        var top: UIViewController = presenter.viewIfLoaded?.window != nil ? presenter : (presenter.view.window?.rootViewController ?? presenter)
        while let shown = top.presentedViewController,
              !shown.isBeingDismissed, !shown.isBeingPresented,
              !(shown is UIAlertController) {
            top = shown
        }
        return top
    }
    
    /// Environment of every python3 Nyxian starts (windows and the editor's helper).
    static func baseEnvironment(workingDirectory: URL?) -> [String: String] {
        var environment = [
            "PYTHONHOME": home.path,
            "PYTHONUNBUFFERED": "1",
            "PIP_DISABLE_PIP_VERSION_CHECK": "1",
            /* iOS builds of numpy, Pillow, … (BeeWare's index) and scipy, scikit-learn, … (Flet's index of mobile wheels) */
            "PIP_EXTRA_INDEX_URL": "https://pypi.anaconda.org/beeware/simple https://pypi.flet.dev",
            "PIP_PREFER_BINARY": "1",
            /* wheels for iOS built by this fork's CI (matplotlib…), see .github/workflows/ios-wheels.yml */
            "PIP_FIND_LINKS": "https://github.com/doctoralvarez/Nyxian/releases/expanded_assets/ios-wheels",
            /* plt.show() saves the figures and Nyxian shows them (nyxian_mplbackend) */
            "MPLBACKEND": "module://nyxian_mplbackend",
            /* no PYTHONPYCACHEPREFIX: the runtime ships its bytecode in __pycache__ (compiled by CI),
               and opt/python is writable for the rest */
            "TERM": "xterm-256color",
            /* scripts pip installs (idna, normalizer, …) live in bin/; on PATH pip
               does not warn. Both spellings: pip compares paths as text and
               reports them with /private in front. */
            "PATH": pathWithPythonBin
        ]
        if let workingDirectory { environment["PYTHONPATH"] = workingDirectory.path }
        return environment
    }
    
    /// The signed launcher when Python is ready to start without unpacking or signing anything.
    static func readyLauncher() -> String? {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: stampKey) != nil,
              let launcher = defaults.string(forKey: launcherKey),
              FileManager.default.fileExists(atPath: launcher),
              FileManager.default.fileExists(atPath: home.appendingPathComponent("libpython\(version).dylib").path) else { return nil }
        return launcher
    }
    
    static func launch(from presenter: UIViewController, arguments: [String], workingDirectory: URL?, title: String, closeOnExit: Bool = false, extraEnvironment: [String: String] = [:], beforeLaunch: (() throws -> Void)? = nil, onExit: ((Int32) -> String?)? = nil, onSession: ((NXWindowSessionTerminal) -> Void)? = nil) {
        let progress = UIAlertController(title: "Python \(version)", message: "Preparing…", preferredStyle: .alert)
        let host = host(for: presenter)
        host.present(progress, animated: true)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let launcher = try prepare { message in
                    DispatchQueue.main.async { progress.message = message }
                }
                if let beforeLaunch {
                    DispatchQueue.main.async { progress.message = "Copying the project…" }
                    try beforeLaunch()
                }
                DispatchQueue.main.async {
                    progress.dismiss(animated: true) {
                        guard let session = NXWindowSessionTerminal(utilityPath: launcher) else { return }
                        session.arguments = [launcher] + arguments
                        var environment = baseEnvironment(workingDirectory: workingDirectory)
                        environment["NYXIAN_TERMINAL"] = "1"
                        environment.merge(extraEnvironment) { _, new in new }
                        session.extraEnvironment = environment
                        session.workingDirectory = workingDirectory?.path
                        session.title = title
                        session.closeOnExit = closeOnExit
                        session.fontSize = CGFloat(fontSize)
                        session.fontSizeDefaultsKey = fontSizeKey
                        if let onExit { session.exitHandler = { code in onExit(code) } }
                        NXWindowServer.shared().openWindow(with: session, withCompletion: nil)
                        onSession?(session)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    progress.dismiss(animated: true) {
                        host.forkGitHubAlert("Python", error.localizedDescription)
                    }
                }
            }
        }
    }
    
    /// Files a script created or rewrote in its run folder (plots, CSV…) are copied into the project; .py files are never overwritten.
    @discardableResult
    static func copyOutput(project root: URL) -> [String] {
        let fm = FileManager.default
        let mirror = rootfs.appendingPathComponent("var/mobile/Python").appendingPathComponent(root.lastPathComponent)
        var copied: [String] = []
        guard let enumerator = fm.enumerator(at: mirror, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        for case let url as URL in enumerator {
            if url.lastPathComponent == "__pycache__" { enumerator.skipDescendants(); continue }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]), values.isRegularFile == true else { continue }
            let relative = ProjectFileIndex.relativePath(url, root: mirror)
            if relative.hasPrefix("Config/") { continue }
            let target = root.appendingPathComponent(relative)
            if fm.fileExists(atPath: target.path) {
                /* a file the script wrote again (a new plot) replaces the project's copy;
                   source files (.py) are never replaced — the editor owns them */
                guard url.pathExtension.lowercased() != "py",
                      let made = values.contentModificationDate,
                      let current = (try? target.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      made.timeIntervalSince(current) > 1 else { continue }
                try? fm.removeItem(at: target)
            }
            try? fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? fm.copyItem(at: url, to: target)) != nil { copied.append(relative) }
        }
        return copied
    }
    
    static func openConsole(from presenter: UIViewController) {
        let folder = rootfs.appendingPathComponent("var/mobile/Python")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        /* Nyxian's REPL: the built-in one expects a terminal that echoes and edits lines */
        launch(from: presenter, arguments: ["-q", "-m", "nyxian_repl"], workingDirectory: folder, title: "Python \(version)", closeOnExit: true)
    }
    
    /// Shows the code of every key Python receives (for keys that seem to do nothing).
    static func openKeyboardTest(from presenter: UIViewController) {
        let folder = rootfs.appendingPathComponent("var/mobile/Python")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        launch(from: presenter, arguments: ["-q", "-m", "nyxian_keytest"], workingDirectory: folder, title: "Python Keyboard Test", closeOnExit: true)
    }
    
    /// Runs a .py file from a copy of its project (or of its folder).
    static func run(script: URL, project: NXProject?, from presenter: UIViewController) {
        /* the editor's keyboard goes away before the terminal takes over */
        presenter.view.window?.endEditing(true)
        let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
        let relative = ProjectFileIndex.relativePath(script, root: root)
        let openTexts = LiveEditorRegistry.openTexts()
        let runFolder = mirrorFolder(project: root)
        let errorFile = runFolder.appendingPathComponent(".nyxian-error.json")
        ForkPythonIssues.clearRuntime(under: root)
        launch(from: presenter, arguments: [relative], workingDirectory: runFolder, title: "python3 \(script.lastPathComponent)", extraEnvironment: ["NYXIAN_ERROR_FILE": errorFile.path], beforeLaunch: {
            _ = try mirror(project: root, openTexts: openTexts)
            try? FileManager.default.removeItem(at: errorFile)
        }, onExit: { _ in
            /* an error that ended the script: its line is marked in the editor */
            if let data = try? Data(contentsOf: errorFile),
               let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let file = info["file"] as? String, let line = info["line"] as? Int {
                let relative = ProjectFileIndex.relativePath(URL(fileURLWithPath: file), root: runFolder)
                let source = root.appendingPathComponent(relative)
                ForkPythonIssues.setRuntime(file: source, line: line, message: info["message"] as? String ?? "Error")
                DispatchQueue.main.async {
                    if UIDevice.current.userInterfaceIdiom == .pad, FileManager.default.fileExists(atPath: source.path) {
                        NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open", source.path, "\(line)", "1", "0"])
                    }
                }
            }
            /* files the script made (plots, CSV…) come into the project by themselves */
            let copied = copyOutput(project: root)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil)
            }
            guard !copied.isEmpty else { return nil }
            let list = copied.prefix(10).joined(separator: ", ") + (copied.count > 10 ? " … (+\(copied.count - 10))" : "")
            return "[copied to the project: \(list) — tap it in the file list to see it]"
        })
    }
    
    // MARK: cells (# %%) in a console that stays open, one per project
    
    private static var cellConsoles: [String: NXWindowSessionTerminal] = [:]
    
    /// Runs code of the editor (a cell, a selection, the whole file) in the
    /// project's cell console: its variables stay from one cell to the next.
    static func runCell(_ code: String, script: URL, project: NXProject?, from presenter: UIViewController) {
        let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
        let key = root.resolvingSymlinksInPath().standardizedFileURL.path
        let runFolder = mirrorFolder(project: root)
        let openTexts = LiveEditorRegistry.openTexts()
        if let console = cellConsoles[key], console.forkIsRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                _ = try? mirror(project: root, openTexts: openTexts)
                DispatchQueue.main.async {
                    /* pasted (bracketed paste): Nyxian's REPL runs the block whole */
                    if console.forkSendText("\u{1b}[200~" + code + "\n\u{1b}[201~") {
                        console.forkBringToFront()
                    } else {
                        cellConsoles[key] = nil
                        runCell(code, script: script, project: project, from: presenter)
                    }
                }
            }
            return
        }
        cellConsoles[key] = nil
        let cellFile = runFolder.appendingPathComponent(".nyxian-cell.py")
        presenter.view.window?.endEditing(true)
        launch(from: presenter, arguments: ["-q", "-m", "nyxian_repl", "--cell", cellFile.path], workingDirectory: runFolder, title: "Cells · \(script.lastPathComponent)", closeOnExit: true, beforeLaunch: {
            _ = try mirror(project: root, openTexts: openTexts)
            try code.write(to: cellFile, atomically: true, encoding: .utf8)
        }, onExit: { _ in
            copyOutput(project: root)
            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil) }
            return nil
        }, onSession: { session in
            cellConsoles[key] = session
        })
    }
    
    // MARK: packages
    
    struct InstalledPackage {
        let name: String
        let version: String
        let summary: String
    }
    
    /// What pip installed, read from the .dist-info folders (no Python needed).
    static func installedPackages() -> [InstalledPackage] {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: sitePackages, includingPropertiesForKeys: nil) else { return [] }
        var packages: [InstalledPackage] = []
        for folder in folders where folder.pathExtension == "dist-info" {
            guard let text = try? String(contentsOf: folder.appendingPathComponent("METADATA"), encoding: .utf8) else { continue }
            var name = "", version = "", summary = ""
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                if line.isEmpty { break }
                if line.hasPrefix("Name: ") { name = String(line.dropFirst(6)) }
                else if line.hasPrefix("Version: ") { version = String(line.dropFirst(9)) }
                else if line.hasPrefix("Summary: ") { summary = String(line.dropFirst(9)) }
            }
            if !name.isEmpty { packages.append(InstalledPackage(name: name, version: version, summary: summary)) }
        }
        return packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    static func pip(_ arguments: [String], title: String, from presenter: UIViewController) {
        launch(from: presenter, arguments: ["-m", "nyxian_pip"] + arguments, workingDirectory: nil, title: title)
    }
    
    /// pip install -r of a requirements file (copied where Python may read it).
    static func installRequirements(_ file: URL, from presenter: UIViewController) {
        let folder = rootfs.appendingPathComponent("var/mobile/Python/.requirements")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent(UUID().uuidString + "-" + file.lastPathComponent)
        let text = LiveEditorRegistry.openTexts()[file.resolvingSymlinksInPath().standardizedFileURL.path] ?? (try? Data(contentsOf: file))
        guard let text, (try? text.write(to: copy)) != nil else {
            presenter.forkGitHubAlert("pip", "Could not read \(file.lastPathComponent).")
            return
        }
        pip(["install", "-r", copy.path], title: "pip install -r \(file.lastPathComponent)", from: presenter)
    }
    
    static func promptInstallPackage(from presenter: UIViewController) {
        let alert = UIAlertController(title: "Install Package", message: "pip install … — pure-Python packages come from PyPI; packages with native code (numpy, Pillow, …) install when an iOS build exists (PyPI or BeeWare's index). Several names can go separated by spaces.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "requests"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Install", style: .default) { [weak alert] _ in
            let names = (alert?.textFields?.first?.text ?? "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
            guard !names.isEmpty else { return }
            /* after the prompt has gone, so the progress alert is not shown while it is being dismissed */
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                launch(from: presenter, arguments: ["-m", "nyxian_pip", "install"] + names, workingDirectory: nil, title: "pip install")
            }
        })
        presenter.present(alert, animated: true)
    }
    
    static func reinstall(from presenter: UIViewController) {
        UserDefaults.standard.removeObject(forKey: stampKey)
        launch(from: presenter, arguments: ["-c", "import sys; print('Python', sys.version)"], workingDirectory: nil, title: "Python \(version)")
    }
}

/// One-time edits of Nyxian's own copy of the iOS SDK so it builds without Xcode-only compiler plugins.
enum ForkSDKPatches {
    private static let markerName = ".nyxian-fork-sdk-patches"
    private static let version = "1"
    
    /// Swift macros whose implementation only ships inside Xcode, renamed so the
    /// declaration with the same name that does not need a plugin is used.
    private static let xcodeOnlyMacros = ["State"]
    
    static func apply() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let sdk: URL = NXBootstrap.shared().sdkURL
            let marker = sdk.appendingPathComponent(markerName)
            guard fm.fileExists(atPath: sdk.path),
                  (try? String(contentsOf: marker, encoding: .utf8)) != version else { return }
            
            var patchedFiles = 0
            for framework in ["SwiftUICore", "SwiftUI"] {
                let modules = sdk.appendingPathComponent("System/Library/Frameworks/\(framework).framework/Modules")
                guard let enumerator = fm.enumerator(at: modules, includingPropertiesForKeys: nil) else { continue }
                for case let url as URL in enumerator where url.pathExtension == "swiftinterface" {
                    guard var text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    let original = text
                    for name in xcodeOnlyMacros {
                        /* "public macro State() = #externalMacro(module: "SwiftUIMacros", …)" */
                        text = text.replacingOccurrences(of: #"\bmacro\s+"# + name + #"(?=\s*[(<])"#, with: "macro __NyxianXcodeOnly" + name, options: .regularExpression)
                    }
                    if text != original, (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil {
                        patchedFiles += 1
                    }
                }
            }
            
            /* modules built from the old interfaces must be rebuilt */
            let cache: URL = NXBootstrap.shared().swiftModuleCacheURL
            if patchedFiles > 0, let enumerator = fm.enumerator(at: cache, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    let name = url.lastPathComponent
                    if name.hasPrefix("SwiftUI-") || name.hasPrefix("SwiftUICore-") || name.hasPrefix("SwiftUI.") || name.hasPrefix("SwiftUICore.") {
                        try? fm.removeItem(at: url)
                    }
                }
            }
            try? version.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}

enum ForkDefaults {
    /// Editor font size 20 by default; an earlier untouched default of 12 is moved to 20 once.
    static func apply() {
        let defaults = UserDefaults.standard
        let migrationKey = "fork.defaults.fontSize20"
        guard !defaults.bool(forKey: migrationKey) else { return }
        if defaults.object(forKey: "LDEFontSize") == nil || defaults.integer(forKey: "LDEFontSize") == 12 {
            defaults.set(20, forKey: "LDEFontSize")
        }
        defaults.set(true, forKey: migrationKey)
    }
}
