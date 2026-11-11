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
 Fork doctoralvarez/Nyxian — version 1.35.0
 Changelog:
  - 1.35.0 (2026-11-10): the "Preparing…" window of Python and Node.js has
    "Hide (keeps preparing)": no more closing Nyxian when it takes long; a
    notice says when it is ready. The signing report is written in the
    background and only reads the NXT2 blobs (it could hang a launch).
    "Java in Shell" is an interactive Shell that starts with java -version
    (NYXIAN_SHELL_INIT) instead of a window that ended at once.
    ForkFastpath: installing a launcher in usr/bin waits at most 12 s per
    attempt (a call that never answered kept Python on "Installing python3…").
  - 1.34.0 (2026-11-10): ForkRuntimeLock: Python, Node.js and Java are
    prepared (unpacked, signed) one at a time; opening Python while Node.js or
    Java was signing in the background could leave it stuck on "Preparing…"
    or "Installing…". Java's environment asks mimalloc for 64 MiB
    reservations and no warnings.
  - 1.33.0 (2026-11-10): python3 may also read usr/bin (launcherRevision 2):
    Nyxian's posix_spawn maps the program from inside python3 to check its
    signature, and python3's file sandbox did not include usr/bin, so every
    program the Shell started was refused (EPERM) before Nyxian saw it.
  - 1.32.0 (2026-11-10): Nyxian Shell starts programs through Nyxian's own
    posix_spawn (posix_spawn__ptr; else os.posix_spawn). ctypes found the
    system's posix_spawn with dlsym, which skips Nyxian's dyld interposing, and
    iOS refuses that one: every program failed with "Operation not permitted".
  - 1.31.0 (2026-11-10): when a program cannot start, Nyxian Shell also
    prints what the host saw (opt/python/.nyxian-spawn.txt: python3's
    entitlements now, at most, and from its signature).
  - 1.30.0 (2026-11-10): ForkSigningReport: the result of signing each
    launcher's NXT2 entitlements, and how Nyxian sees python3, node and java
    (NXT2 blob, trust level, may start programs), written to
    opt/python/.nyxian-signing.txt each time a terminal opens; Nyxian Shell
    prints it when a program cannot start. Preparing Python says each step
    after "Installing pip…" (it seemed stuck there).
  - 1.29.0 (2026-11-10): Nyxian Shell hands a program only stdin, stdout and
    stderr (POSIX_SPAWN_CLOEXEC_DEFAULT + inherit), not all of python3's
    descriptors; when a program cannot start it says why (error number and
    what Nyxian refused: signature, LiveProcess, ended right away, ...).
  - 1.28.0 (2026-11-10): java in Nyxian Shell ("could not start (Operation
    not permitted)"): miniJVM is now lib/libminijvm.dylib, signed like
    NodeMobile, and bin/java a tiny launcher that loads it. python3 may also
    read opt/node and opt/java (programs the Shell starts get its file
    sandbox); only its launcher is signed again (launcherRevision). The Shell
    says what to try when Nyxian does not let java or node start.
  - 1.27.0 (2026-11-10): Java. ForkJava unpacks and signs miniJVM
    (Shared/java-ios.zip) after Node.js; ▶ runs .java files; Nyxian Shell:
    java (FILE.java, -jar with Main-Class/Class-Path, -cp CLASS), javac
    (janino) and jar (c/t/x/u, f m e v, -C). .jar files: Run, Run in
    Browser with CheerpJ (ForkCheerpJ + a small local HTTP server with
    Range requests: full Java 8–21, Swing), Open Contents / Pack into
    .jar (ForkJarEditor). Java section in the Python panel, Java example.
  - 1.26.0 (2026-11-10): Node.js 18 (nodejs-mobile, no JIT): ForkNode unpacks
    and signs Shared/node-ios.zip once (in the background after Python);
    ▶ runs .js files from a copy of the project; Node.js Console, npm
    install -g, npm ls -g and the NODE_MODULES / node HOME folders in the
    Python panel; Nyxian Shell runs node, npm, npx, node_modules/.bin
    commands, scripts with #! (node, python, sh) and sh FILE / source FILE
    ($1…); node_modules stay in the run folder; two Node.js examples.
  - 1.25.0 (2026-11-10): turtle works: `import turtle` draws in memory and
    done() / the end of the script shows the drawing as PNG (iOS has no Tk);
    a turtle example.
  - 1.24.0 (2026-11-10): Python panel (tap </>): Modules, console, Shell (home
    or Python HOME $), ARGS, examples and tutorials, notebooks, the browser,
    the folders (python HOME, SITE-PACKAGES, STDLIB, SDK sysroot, Projects),
    About This Fork and What's New. Examples become Python projects. .ipynb
    notebooks are shown with their outputs and turn into "# %%" cells (and
    back). A browser for local servers (Flask, Django) and webbrowser.open().
  - 1.23.0 (2026-11-09): Python is signed once, not at every start: the date
    kept for each signed package binary was read before signing (a cached
    value), so the next start signed them all again; now it is the file's
    real date after signing. Unchanged site-packages are not even scanned
    (a stamp of the folder), and Nyxian prepares Python in the background
    as soon as it opens, so Python, the shell, cells and pip start at once.
  - 1.22.0 (2026-11-09): Nyxian Shell (nyxian_shell: built-in ls, cd, grep,
    cat, cp, mv, rm, find…, pipes, redirection, ; && ||, variables, globs,
    programs as processes with ^Z / jobs / fg / bg / kill), in the </> menu
    and per project; python3 may start processes.
    Python debugger (nyxian_pdb, ForkPython.debug):
    runs a script stopping at the editor's breakpoints (⌘\), shows the
    stop line in green, the frame's variables in Show Variables; pdb's
    commands in the terminal.
    Cell outputs, like a notebook: every cell run in the
    cell console keeps its code, output, errors and new figures
    (NYXIAN_CELLS_FILE), shown one under another in Cell Outputs (⌥⌘O); with
    that sheet open the console stays behind the editor.
  - 1.21.0 (2026-11-09): Python's line editor reads in raw mode (the
    terminal now edits lines and echoes by itself, canonical mode): it is
    switched off while input() reads and for the whole REPL session.
  - 1.20.0 (2026-11-09): Python — variable inspector of the cell console
    (nyxian_repl snapshot, ForkPythonVariablesViewController: type, shape,
    dtype, value; DataFrames and arrays as tables); pyflakes linting in
    nyxian_jedi; Run Tests (nyxian_tests: pytest or unittest, failures marked
    on their lines; ForkPythonIssues holds several issues per file); Run with
    Arguments (remembered per file, files of the project offered).
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
import WebKit
import Network

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
    
    func reloadProjectsFromDisk() {
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
        /* fork: Python 3 — a tap opens the Python panel, a long press this menu */
        let pythonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"),
            primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                self.navigationController?.pushViewController(ForkPythonHubViewController(owner: self), animated: true)
            },
            menu: UIMenu(title: "Python 3", children: [
                UIAction(title: "Python Panel", image: UIImage(systemName: "square.grid.2x2")) { [weak self] _ in
                    guard let self else { return }
                    self.navigationController?.pushViewController(ForkPythonHubViewController(owner: self), animated: true)
                },
                UIAction(title: "Python Console", image: UIImage(systemName: "terminal")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.openConsole(from: self)
                },
                UIAction(title: "Shell", image: UIImage(systemName: "apple.terminal")) { [weak self] _ in
                    guard let self else { return }
                    ForkPython.openShell(from: self)
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
            /* fork: Python projects have a section of their own */
            if ForkPython.isPythonProject(project) { return "python" }
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
        /* fork: Python unpacked and signed now, in the background, not when it is first opened */
        ForkPython.warmUp()
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
    /// by file: the error a run ended with, or the failed tests (line, message)
    private static var runtime: [String: [(line: Int, message: String)]] = [:]
    
    private static func key(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }
    
    private static func posted() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: changed, object: nil) }
    }
    
    static func setRuntime(file: URL, line: Int, message: String) {
        lock.lock(); runtime[key(file)] = [(line, message)]; lock.unlock()
        posted()
    }
    
    static func addRuntime(file: URL, line: Int, message: String) {
        lock.lock(); runtime[key(file), default: []].append((line, message)); lock.unlock()
        posted()
    }
    
    static func runtimeIssue(for file: URL) -> (line: Int, message: String)? {
        runtimeIssues(for: file).first
    }
    
    static func runtimeIssues(for file: URL) -> [(line: Int, message: String)] {
        lock.lock(); defer { lock.unlock() }
        return runtime[key(file)] ?? []
    }
    
    static func clearRuntime(for file: URL) {
        lock.lock(); let removed = runtime.removeValue(forKey: key(file)) != nil; lock.unlock()
        if removed { posted() }
    }
    
    static func clearRuntime(under root: URL) {
        let prefix = key(root)
        lock.lock(); let before = runtime.count; runtime = runtime.filter { !$0.key.hasPrefix(prefix) }; let removed = before != runtime.count; lock.unlock()
        if removed { posted() }
    }
}

/// The variables of a project's cell console (snapshot written by nyxian_repl after each command).
/// The cells run in the project's cell console, one under another like a notebook:
/// code, output (errors in red) and the figures each one made. Follows the console live.
final class ForkPythonCellOutputsViewController: UIViewController {
    private let file: URL
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var stamp: Date?
    private var timer: Timer?
    private var count = -1
    
    init(file: URL) {
        self.file = file
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cell Outputs"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "trash"), primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.file)
            self.stamp = nil
            self.reload()
        })
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -14),
        ])
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in self?.reload() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ForkPython.cellOutputsVisible = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ForkPython.cellOutputsVisible = false
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            timer?.invalidate()
        }
    }
    
    private func reload() {
        let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if date != nil, date == stamp { return }
        stamp = date
        var cells: [[String: Any]] = []
        if let data = try? Data(contentsOf: file),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let list = object["cells"] as? [[String: Any]] {
            cells = list
        }
        let grew = cells.count > count
        count = cells.count
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if cells.isEmpty {
            let empty = UILabel()
            empty.text = "Run a cell (⌘↩) and its output and figures show here, one under another, like a notebook.\n\nKeep this sheet half open next to the code: the console stays behind the editor while it is open."
            empty.numberOfLines = 0
            empty.textColor = .secondaryLabel
            empty.font = .preferredFont(forTextStyle: .body)
            stack.addArrangedSubview(empty)
            return
        }
        for cell in cells {
            stack.addArrangedSubview(card(cell))
        }
        if grew {
            view.layoutIfNeeded()
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: true)
        }
    }
    
    private func card(_ cell: [String: Any]) -> UIView {
        let box = UIStackView()
        box.axis = .vertical
        box.spacing = 8
        box.isLayoutMarginsRelativeArrangement = true
        box.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12)
        box.backgroundColor = .secondarySystemGroupedBackground
        box.layer.cornerRadius = 12
        box.layer.cornerCurve = .continuous
        
        let n = cell["n"] as? Int ?? 0
        let seconds = cell["seconds"] as? Double ?? 0
        let failed = cell["failed"] as? Bool ?? false
        let header = UILabel()
        header.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        header.textColor = failed ? .systemRed : .secondaryLabel
        header.text = "In [\(n)]" + String(format: "  ·  %.2f s", seconds) + (failed ? "  ·  error" : "")
        box.addArrangedSubview(header)
        
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12
        let source = (cell["source"] as? String ?? "").trimmingCharacters(in: .newlines)
        let lines = source.components(separatedBy: "\n")
        let code = UILabel()
        code.numberOfLines = 0
        code.font = .monospacedSystemFont(ofSize: size, weight: .regular)
        code.text = lines.count > 14 ? lines.prefix(12).joined(separator: "\n") + "\n… (\(lines.count - 12) more lines)" : source
        let codeBack = UIView()
        codeBack.backgroundColor = .tertiarySystemFill
        codeBack.layer.cornerRadius = 8
        code.translatesAutoresizingMaskIntoConstraints = false
        codeBack.addSubview(code)
        NSLayoutConstraint.activate([
            code.topAnchor.constraint(equalTo: codeBack.topAnchor, constant: 8),
            code.bottomAnchor.constraint(equalTo: codeBack.bottomAnchor, constant: -8),
            code.leadingAnchor.constraint(equalTo: codeBack.leadingAnchor, constant: 8),
            code.trailingAnchor.constraint(equalTo: codeBack.trailingAnchor, constant: -8),
        ])
        box.addArrangedSubview(codeBack)
        
        let output = (cell["output"] as? String ?? "").trimmingCharacters(in: .newlines)
        if !output.isEmpty {
            let text = UILabel()
            text.numberOfLines = 0
            text.font = .monospacedSystemFont(ofSize: size, weight: .regular)
            text.textColor = failed ? .systemRed : .label
            let outLines = output.components(separatedBy: "\n")
            text.text = outLines.count > 200 ? outLines.prefix(200).joined(separator: "\n") + "\n… (\(outLines.count - 200) more lines in the console)" : output
            box.addArrangedSubview(text)
        }
        for path in cell["figures"] as? [String] ?? [] {
            guard let image = UIImage(contentsOfFile: path) else { continue }
            let picture = UIImageView(image: image)
            picture.contentMode = .scaleAspectFit
            picture.backgroundColor = .white
            picture.layer.cornerRadius = 8
            picture.clipsToBounds = true
            picture.isUserInteractionEnabled = true
            let ratio = image.size.width > 0 ? image.size.height / image.size.width : 0.75
            picture.heightAnchor.constraint(equalTo: picture.widthAnchor, multiplier: min(max(ratio, 0.2), 2.0)).isActive = true
            let url = URL(fileURLWithPath: path)
            picture.addGestureRecognizer(ForkTapGesture { [weak self] in
                guard let self else { return }
                ForkQuickLook.present(url, from: self)
            })
            box.addArrangedSubview(picture)
        }
        return box
    }
}

/// A tap gesture with a closure.
final class ForkTapGesture: UITapGestureRecognizer {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
    }
    @objc private func fire() { handler() }
}

final class ForkPythonVariablesViewController: UITableViewController, UISearchResultsUpdating {
    private let file: URL
    private var rows: [[String: Any]] = []
    private var shown: [[String: Any]] = []
    private var stamp: Date?
    private var timer: Timer?
    private let search = UISearchController(searchResultsController: nil)
    
    init(file: URL) {
        self.file = file
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Variables"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search variables"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        reload()
        /* follows the console: a new snapshot after every command */
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.reload() }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true { timer?.invalidate() }
    }
    
    private func reload() {
        let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard date != stamp || stamp == nil else { return }
        stamp = date
        if let data = try? Data(contentsOf: file),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let variables = object["variables"] as? [[String: Any]] {
            rows = variables
        }
        updateSearchResults(for: search)
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let text = (searchController.searchBar.text ?? "").lowercased()
        shown = text.isEmpty ? rows : rows.filter { (($0["name"] as? String) ?? "").lowercased().contains(text) || (($0["type"] as? String) ?? "").lowercased().contains(text) }
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        rows.isEmpty ? "Run a cell (⌘↩) to see its variables here" : "\(rows.count) variables · they follow the cell console"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = shown[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        let name = row["name"] as? String ?? "?"
        var kind = row["type"] as? String ?? ""
        if let shape = row["shape"] as? String { kind += "  [\(shape)]" }
        if let dtype = row["dtype"] as? String, !dtype.isEmpty { kind += "  \(dtype)" }
        content.attributedText = {
            let text = NSMutableAttributedString(string: name, attributes: [.font: UIFont.monospacedSystemFont(ofSize: 16, weight: .semibold)])
            text.append(NSAttributedString(string: "   " + kind, attributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.secondaryLabel]))
            return text
        }()
        content.secondaryText = row["summary"] as? String
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = shown[indexPath.row]
        let detail = UIViewController()
        detail.title = row["name"] as? String
        /* a table (DataFrame, array) keeps its columns: no wrapping, scrolls both ways */
        let scroll = UIScrollView()
        scroll.backgroundColor = .systemBackground
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.text = row["value"] as? String
        label.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16)
        ])
        detail.view = scroll
        detail.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .action, primaryAction: UIAction { [weak detail] _ in
            let share = UIActivityViewController(activityItems: [row["value"] as? String ?? ""], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = detail?.navigationItem.rightBarButtonItem
            detail?.present(share, animated: true)
        })
        navigationController?.pushViewController(detail, animated: true)
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
        "Run with Arguments…": "Ejecutar con argumentos…",
        "Run Tests": "Ejecutar pruebas",
        "Show Variables": "Ver variables",
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
    private static let signingRevision = 4  /* 3: pip may write all of opt/python; 4: may start processes (Nyxian Shell) */
    /// Only python3's own entitlements changed: sign the launcher again, without unpacking Python.
    private static let launcherRevision = 2  /* 1: may read opt/node and opt/java (for the programs Nyxian Shell starts); 2: and usr/bin */
    private static let launcherRevisionKey = "fork.python.launcherRevision"

    /// Python files Nyxian adds to site-packages: the line editor, the REPL, input() with echo.
    private static let helperFiles: [String: String] = [
        "nyxian_lineedit.py": #"""
# Nyxian line editor: echo, ← →, history, paste, indentation. Nyxian's
# terminal edits lines itself too (canonical mode, like macOS), which is
# switched off while this editor reads (raw mode) and back on after.
# Used by input() and the Nyxian REPL (raw for its whole session).
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


_session_raw = False


def _set_raw():
    """Raw mode for this editor: no line editing or echo by the terminal;
    signals (Ctrl-C) stay. Returns the previous settings (None: unchanged)."""
    try:
        import termios
        old = termios.tcgetattr(0)
        if not old[3] & (termios.ICANON | termios.ECHO | termios.ECHONL | termios.IEXTEN):
            return None
        new = [old[0], old[1], old[2], old[3], old[4], old[5], list(old[6])]
        new[3] &= ~(termios.ICANON | termios.ECHO | termios.ECHONL | termios.IEXTEN)
        new[6][termios.VMIN] = 1
        new[6][termios.VTIME] = 0
        termios.tcsetattr(0, termios.TCSANOW, new)
        return old
    except Exception:
        return None


def _restore(old):
    if old is not None:
        try:
            import termios
            termios.tcsetattr(0, termios.TCSANOW, old)
        except Exception:
            pass


def raw_session():
    """Raw mode until Python exits (the REPL: keys typed while code runs
    wait for the editor instead of being echoed by the terminal)."""
    global _session_raw
    if _session_raw:
        return
    old = _set_raw()
    _session_raw = True
    if old is not None:
        import atexit
        atexit.register(_restore, old)


def read_line(prompt="", indent="", code=False):
    old = None if _session_raw else _set_raw()
    try:
        return _read_line(prompt, indent, code)
    finally:
        if not _session_raw:
            _restore(old)


def _read_line(prompt="", indent="", code=False):
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

from nyxian_lineedit import Pasted, _flush, _write, raw_session, read_line


def _describe(value):
    import types
    kind = type(value)
    module = kind.__module__ or ""
    name = kind.__name__ if module in ("builtins", "__main__") else "%s.%s" % (module.split(".")[0], kind.__name__)
    entry = {"type": name}
    shape = getattr(value, "shape", None)
    if isinstance(shape, tuple):
        entry["shape"] = " × ".join(str(n) for n in shape)
    elif isinstance(value, (list, tuple, dict, set, frozenset, str, bytes)):
        entry["shape"] = "%d" % len(value)
    try:
        if isinstance(value, (types.FunctionType, types.BuiltinFunctionType, type)):
            import inspect
            try:
                text = "%s%s" % (value.__name__, inspect.signature(value))
            except (TypeError, ValueError):
                text = value.__name__
            entry["type"] = "class" if isinstance(value, type) else "function"
        elif module.startswith("pandas") and hasattr(value, "to_string"):
            text = value.to_string(max_rows=80, max_cols=30)
        elif module.startswith("numpy"):
            import numpy
            with numpy.printoptions(threshold=400, edgeitems=6, linewidth=160):
                text = repr(value)
            entry["dtype"] = str(getattr(value, "dtype", ""))
        else:
            text = repr(value)
    except Exception as error:
        text = "<cannot show: %s>" % error
    entry["summary"] = " ".join(text.split())[:140]
    entry["value"] = text[:40000]
    return entry


def snapshot(namespace):
    """The variables of the console, for Nyxian's variable inspector (NYXIAN_VARS_FILE)."""
    path = os.environ.get("NYXIAN_VARS_FILE")
    if not path:
        return
    try:
        import json
        import time
        import types
        rows = []
        for name, value in list(namespace.items()):
            if name.startswith("_") or name in ("exit", "quit", "help", "copyright", "credits", "license"):
                continue
            if isinstance(value, types.ModuleType):
                continue
            entry = _describe(value)
            entry["name"] = name
            rows.append(entry)
        rows.sort(key=lambda row: row["name"].lower())
        temporary = path + ".tmp"
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump({"time": time.time(), "variables": rows}, handle)
        os.replace(temporary, path)
    except Exception:
        pass


class _Tee:
    """A stream that also keeps what goes through it (the outputs of a cell)."""

    def __init__(self, stream, sink):
        self._stream = stream
        self._sink = sink

    def write(self, text):
        self._sink.append(text)
        return self._stream.write(text)

    def flush(self):
        return self._stream.flush()

    def __getattr__(self, name):
        return getattr(self._stream, name)


def _figures():
    folder = os.path.join(os.getcwd(), "figures")
    found = {}
    try:
        for name in os.listdir(folder):
            if name.lower().endswith((".png", ".jpg", ".jpeg", ".svg", ".pdf")):
                path = os.path.join(folder, name)
                found[path] = os.stat(path).st_mtime
    except OSError:
        pass
    return found


_cell_count = [0]


def record_cell(source, output, figures, seconds, failed):
    """A cell's code, output and new figures, for Nyxian's cell outputs (NYXIAN_CELLS_FILE)."""
    path = os.environ.get("NYXIAN_CELLS_FILE")
    if not path:
        return
    try:
        import json
        import time
        cells = []
        try:
            with open(path, encoding="utf-8") as handle:
                cells = json.load(handle).get("cells", [])
        except Exception:
            cells = []
        _cell_count[0] = max(_cell_count[0], cells[-1]["n"] if cells else 0) + 1
        if len(output) > 30000:
            output = output[:15000] + "\n… (%d characters left out) …\n" % (len(output) - 30000) + output[-15000:]
        cells.append({"n": _cell_count[0], "time": time.time(), "seconds": round(seconds, 3),
                      "source": source, "output": output, "figures": figures, "failed": failed})
        cells = cells[-60:]
        temporary = path + ".tmp"
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump({"time": time.time(), "cells": cells}, handle)
        os.replace(temporary, path)
    except Exception:
        pass


class NyxianConsole(code.InteractiveConsole):
    _last = ""
    _capture = None
    _failed = False

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
        """A cell (or any pasted block); with NYXIAN_CELLS_FILE its output and
        new figures are kept for Nyxian's cell outputs."""
        if not os.environ.get("NYXIAN_CELLS_FILE"):
            return self._run_block(source)
        import time
        captured = []
        before = _figures()
        out, err = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = _Tee(out, captured), _Tee(err, captured)
        self._capture = captured
        self._failed = False
        start = time.time()
        try:
            self._run_block(source)
        finally:
            sys.stdout, sys.stderr = out, err
            self._capture = None
            after = _figures()
            new = sorted(path for path, mtime in after.items() if before.get(path) != mtime)
            record_cell(source, "".join(captured), new, time.time() - start, self._failed)

    def showtraceback(self):
        self._failed = True
        super().showtraceback()

    def showsyntaxerror(self, *args, **kwargs):
        self._failed = True
        super().showsyntaxerror(*args, **kwargs)

    def _run_block(self, source):
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
                snapshot(self.locals)

    def write(self, data):
        _flush()
        if self._capture is not None:
            self._capture.append(data)
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
            if not self.buffer:
                snapshot(self.locals)


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
    raw_session()
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

from nyxian_lineedit import _write, raw_session

NAMES = {3: "Ctrl-C", 4: "Ctrl-D", 9: "Tab", 10: "LF (Enter)", 13: "CR (Enter)", 27: "Esc", 127: "Backspace"}


def main():
    _write("Python keyboard test: press keys, Enter included. Ctrl-D twice quits.\n")
    raw_session()
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
    if not problems:
        problems.extend(lint(source, path))
    return problems


# names that are errors when used (the rest of pyflakes' messages are warnings)
_LINT_ERRORS = ("UndefinedName", "UndefinedLocal", "UndefinedExport", "DuplicateArgument", "ReturnOutsideFunction",
                "YieldOutsideFunction", "ContinueOutsideLoop", "BreakOutsideLoop")


def lint(source, path):
    """pyflakes: unused imports and variables, misspelled names, … (without running the code)."""
    try:
        import ast
        from pyflakes import checker
    except Exception:
        return []
    try:
        tree = ast.parse(source, filename=path)
        found = checker.Checker(tree, filename=path)
    except Exception:
        return []
    problems = []
    for message in sorted(found.messages, key=lambda m: (m.lineno, getattr(m, "col", 0))):
        kind = type(message).__name__
        try:
            text = message.message % message.message_args
        except Exception:
            text = str(message)
        problems.append({"line": message.lineno or 1, "column": (getattr(message, "col", 0) or 0) + 1,
                         "level": "error" if kind in _LINT_ERRORS else "warning", "message": text})
    return problems[:200]


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
        "nyxian_shell.py": #"""
# Nyxian Shell: a small shell for Nyxian's terminal, written in Python (iOS
# has no /bin/sh for apps). Built-in commands (ls, cd, cat, grep, cp, mv, rm,
# mkdir, find, head, tail, wc, …), pipes (|), redirection (> >> < 2> 2>&1),
# ; && ||, $VARIABLES, ~, *.globs, and programs (python3, your command line
# tools) started as processes of their own with job control: ^Z stops the
# one in front, jobs / fg / bg / kill, "&" starts one in the background.
# Run as: python3 -m nyxian_shell
import ctypes
import errno
import fnmatch
import glob
import io
import os
import re
import shutil
import signal
import stat
import sys
import threading
import time

VERSION = "1.0"
_status = [0]
_jobs = {}          # number -> {"pids": [...], "pgid": n, "command": text, "state": "Running"/"Stopped"}
_history = []


def _out(text, stream=None):
    stream = stream or sys.stdout
    stream.write(text)
    stream.flush()


# ---------------------------------------------------------------- processes

class _Spawner:
    """posix_spawn through ctypes (CPython on iOS has no fork, and Nyxian's
    kernel runs every program as a process of its own)."""
    SETPGROUP = 0x02
    SETSIGDEF = 0x04
    CLOEXEC_DEFAULT = 0x4000   # Darwin: only the descriptors named below reach the program
    DARWIN = sys.platform in ("darwin", "ios")

    ARGTYPES = [ctypes.POINTER(ctypes.c_int), ctypes.c_char_p, ctypes.c_void_p, ctypes.c_void_p,
                ctypes.POINTER(ctypes.c_char_p), ctypes.POINTER(ctypes.c_char_p)]

    def __init__(self):
        self.libc = ctypes.CDLL(None, use_errno=True)
        self.libc.posix_spawn.argtypes = self.ARGTYPES
        # Nyxian starts programs through its own posix_spawn, which it puts in place of the
        # system's with dyld interposing; ctypes looks symbols up with dlsym, which does not
        # see that, and the system's posix_spawn is refused on iOS ("Operation not permitted").
        # Nyxian keeps a pointer to its version in posix_spawn__ptr.
        self.nyxian = []
        self.used = "?"
        handles = [None]
        if self.DARWIN:
            handles.append(ctypes.c_void_p(-2).value)   # RTLD_DEFAULT: every loaded image
        for handle in handles:
            try:
                library = ctypes.CDLL(None, handle=handle) if handle is not None else self.libc
                self.nyxian.append(ctypes.c_void_p.in_dll(library, "posix_spawn__ptr"))
                break
            except (ValueError, OSError, AttributeError):
                continue

    def _posix_spawn(self):
        """Nyxian's posix_spawn when there is one, else the system's."""
        for pointer in self.nyxian:
            if pointer.value:
                self.used = "Nyxian's posix_spawn"
                return ctypes.CFUNCTYPE(ctypes.c_int, *self.ARGTYPES, use_errno=True)(pointer.value)
        if hasattr(os, "posix_spawn") and self.DARWIN:
            self.used = "os.posix_spawn"
            return None   # caller uses os.posix_spawn (CPython's own call is interposed)
        self.used = "the system's posix_spawn"
        return self.libc.posix_spawn

    def spawn(self, path, argv, env, fds, pgid=0):
        """fds: {0: fd, 1: fd, 2: fd}; pgid 0 = a new process group led by the child."""
        actions = ctypes.create_string_buffer(512)
        attributes = ctypes.create_string_buffer(512)
        libc = self.libc
        libc.posix_spawn_file_actions_init(actions)
        libc.posix_spawnattr_init(attributes)
        try:
            for target, fd in sorted(fds.items()):
                if fd != target:
                    libc.posix_spawn_file_actions_adddup2(actions, fd, target)
                elif self.DARWIN:
                    libc.posix_spawn_file_actions_addinherit_np(actions, target)
            # the shell ignores ^Z for itself; its programs must not inherit that
            defaults = ctypes.create_string_buffer(256)
            libc.sigemptyset(defaults)
            for name in ("SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGINT", "SIGQUIT", "SIGPIPE"):
                if hasattr(signal, name):
                    libc.sigaddset(defaults, int(getattr(signal, name)))
            libc.posix_spawnattr_setsigdefault(attributes, defaults)
            # Python's own descriptors (and the shell's pipes) are not handed to the program:
            # Nyxian sends every inherited descriptor to the new process
            flags = self.SETPGROUP | self.SETSIGDEF | (self.CLOEXEC_DEFAULT if self.DARWIN else 0)
            libc.posix_spawnattr_setflags(attributes, ctypes.c_short(flags))
            libc.posix_spawnattr_setpgroup(attributes, pgid)
            c_argv = (ctypes.c_char_p * (len(argv) + 1))(*[os.fsencode(a) for a in argv], None)
            items = ["%s=%s" % pair for pair in env.items()]
            c_env = (ctypes.c_char_p * (len(items) + 1))(*[os.fsencode(e) for e in items], None)
            pid = ctypes.c_int(0)
            function = self._posix_spawn()
            if function is None:
                return self._os_spawn(path, argv, env, fds, pgid)
            error = function(ctypes.byref(pid), os.fsencode(path), actions, attributes, c_argv, c_env)
            if error:
                raise OSError(error, os.strerror(error))
            return pid.value
        finally:
            libc.posix_spawn_file_actions_destroy(actions)
            libc.posix_spawnattr_destroy(attributes)

    def _os_spawn(self, path, argv, env, fds, pgid):
        """os.posix_spawn: no CLOEXEC_DEFAULT there, so the shell's other descriptors are closed."""
        actions = [(os.POSIX_SPAWN_DUP2, fd, target) for target, fd in sorted(fds.items()) if fd != target]
        defaults = [getattr(signal, name) for name in ("SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGINT", "SIGQUIT", "SIGPIPE")
                    if hasattr(signal, name)]
        return os.posix_spawn(path, list(argv), dict(env), file_actions=actions or None,
                              setpgroup=pgid, setsigdef=defaults)


_spawner = None


def spawner():
    global _spawner
    if _spawner is None:
        _spawner = _Spawner()
    return _spawner


def _terminal_group(pgid):
    """Gives the terminal to a process group (^C / ^Z go to it)."""
    try:
        if os.isatty(0):
            old = signal.signal(signal.SIGTTOU, signal.SIG_IGN) if hasattr(signal, "SIGTTOU") else None
            try:
                os.tcsetpgrp(0, pgid)
            finally:
                if old is not None:
                    signal.signal(signal.SIGTTOU, old)
    except (OSError, AttributeError):
        pass


def _wait_job(number):
    """Waits for the job in front; returns its status. ^Z: it becomes Stopped."""
    job = _jobs[number]
    _terminal_group(job["pgid"])
    status = 0
    try:
        while job["pids"]:
            try:
                pid, code = os.waitpid(-job["pgid"] if job["pgid"] else job["pids"][0], os.WUNTRACED)
            except ChildProcessError:
                job["pids"] = []
                break
            except InterruptedError:
                continue
            if os.WIFSTOPPED(code):
                job["state"] = "Stopped"
                _out("\n[%d]+  Stopped                 %s\n" % (number, job["command"]))
                return 148
            if pid in job["pids"]:
                job["pids"].remove(pid)
            if pid == job["last"]:
                status = os.waitstatus_to_exitcode(code)
                if status < 0:
                    status = 128 - status
    finally:
        _terminal_group(os.getpgrp())
    _jobs.pop(number, None)
    return status


def _reap():
    """Background jobs that ended: told once, like bash."""
    for number, job in list(_jobs.items()):
        if job.get("thread") is not None:
            if not job["thread"].is_alive():
                _out("[%d]+  Done                    %s\n" % (number, job["command"]))
                _jobs.pop(number, None)
            continue
        for pid in list(job["pids"]):
            try:
                done, code = os.waitpid(pid, os.WNOHANG | os.WUNTRACED)
            except ChildProcessError:
                job["pids"].remove(pid)
                continue
            if done == 0:
                continue
            if os.WIFSTOPPED(code):
                job["state"] = "Stopped"
            else:
                job["pids"].remove(pid)
        if not job["pids"]:
            _out("[%d]+  Done                    %s\n" % (number, job["command"]))
            _jobs.pop(number, None)


def _new_job(command):
    number = 1
    while number in _jobs:
        number += 1
    _jobs[number] = {"pids": [], "pgid": 0, "last": 0, "command": command, "state": "Running", "thread": None}
    return number


def _which(name):
    if "/" in name:
        return name if os.path.exists(name) else None
    if name in ("python", "python3", "python3." + str(sys.version_info[1])):
        return sys.executable
    for folder in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(folder, name)
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


# ---------------------------------------------------------------- Node.js

_NODE_TOOLS = {
    "npm": "lib/node_modules/npm/bin/npm-cli.js",
    "npx": "lib/node_modules/npm/bin/npx-cli.js",
    "corepack": "lib/node_modules/corepack/dist/corepack.js",
}


def _node():
    path = os.environ.get("NYXIAN_NODE")
    return path if path else None


def _node_bin(name):
    """A command npm installed: ./node_modules/.bin (here and above), then the global one."""
    folder = os.getcwd()
    while True:
        candidate = os.path.join(folder, "node_modules", ".bin", name)
        if os.path.exists(candidate):
            return candidate
        parent = os.path.dirname(folder)
        if parent == folder:
            break
        folder = parent
    prefix = os.environ.get("npm_config_prefix")
    if prefix:
        candidate = os.path.join(prefix, "bin", name)
        if os.path.exists(candidate):
            return candidate
    return None


def _script_command(path, args):
    """A script with #! (npm's commands, pip's, yours) runs with its interpreter:
    iOS starts only programs, not scripts. None when it is a program."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(256)
    except OSError:
        return None
    if head[:4] in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
        return None
    first = head.split(b"\n", 1)[0]
    lower = path.lower()
    if b"node" in first or lower.endswith((".js", ".mjs", ".cjs")):
        node = _node()
        return [node, path] + args if node else "node"
    if b"python" in first or lower.endswith(".py"):
        return [sys.executable, path] + args
    if first.startswith(b"#!") and (b"sh" in first) or lower.endswith(".sh"):
        return [sys.executable, "-m", "nyxian_shell", path] + args
    return None


# ---------------------------------------------------------------- Java (miniJVM)

_JAVAC_MAIN = "org.codehaus.commons.compiler.tools.Javac"


def _java():
    path = os.environ.get("NYXIAN_JAVA")
    return path if path else None


def _java_lib(name):
    return os.path.join(os.environ.get("NYXIAN_JAVA_HOME", ""), "lib", name)


def _jar_manifest(path):
    """The main attributes of a jar's META-INF/MANIFEST.MF (continuation lines joined)."""
    import zipfile
    try:
        with zipfile.ZipFile(path) as archive:
            text = archive.read("META-INF/MANIFEST.MF").decode("utf-8", "replace")
    except (KeyError, OSError, zipfile.BadZipFile):
        return {}
    attributes, key = {}, None
    for line in text.replace("\r\n", "\n").split("\n"):
        if not line.strip():
            if attributes:
                break
            continue
        if line.startswith(" ") and key:
            attributes[key] += line[1:]
        elif ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            attributes[key] = value.strip()
    return attributes


def _javac_argv(args):
    java = _java()
    rt = _java_lib("minijvm_rt.jar")
    argv = [java, "-bootclasspath", rt, "-cp", _java_lib("janino.jar") + ":" + _java_lib("commons-compiler.jar"),
            _JAVAC_MAIN, "-bootclasspath", rt]
    if not any(a in ("-source", "-target", "--release") for a in args):
        argv += ["-source", "8", "-target", "8"]
    if "-encoding" not in args:
        argv += ["-encoding", "UTF-8"]
    return argv + list(args)


def _java_command(name, args):
    """java / javac for miniJVM. None if not one; a str is an error to show."""
    if name not in ("java", "javac"):
        return None
    java = _java()
    if not java:
        return "%s: Java (miniJVM) is not ready yet (Nyxian prepares it after Python and Node.js)" % name
    if name == "javac":
        if not args:
            return "usage: javac [-d DIR] [-cp PATH] FILE.java… (Java 8 language, miniJVM's class library)"
        return _javac_argv(args)
    vm, classpath, i = [], None, 0
    while i < len(args):
        arg = args[i]
        if arg in ("-cp", "-classpath", "--class-path") and i + 1 < len(args):
            classpath = args[i + 1]
            i += 2
            continue
        if arg == "-jar" and i + 1 < len(args):
            jar = os.path.abspath(os.path.expanduser(args[i + 1]))
            manifest = _jar_manifest(jar)
            main = manifest.get("Main-Class")
            if not main:
                return "java: %s has no Main-Class in META-INF/MANIFEST.MF (run a class: java -cp %s NAME)" % (args[i + 1], args[i + 1])
            folder = os.path.dirname(jar)
            parts = [jar] + [os.path.join(folder, p) for p in manifest.get("Class-Path", "").split() if p]
            return [java, "-bootclasspath", _java_lib("minijvm_rt.jar"), "-cp", ":".join(parts)] + vm + [main] + args[i + 2:]
        if arg in ("-version", "--version"):
            return [java, "-bootclasspath", _java_lib("minijvm_rt.jar"), "-version"]
        if arg.startswith("-X"):
            vm.append(arg)
            i += 1
            continue
        if arg.startswith("-D") or arg.startswith("--") or arg in ("-ea", "-da", "-server", "-client"):
            sys.stderr.write("java: %s is ignored by miniJVM\n" % arg)
            i += 1
            continue
        break
    rest = args[i:]
    if not rest:
        return "usage: java [-cp PATH] CLASS [ARGS] · java -jar FILE.jar [ARGS] · java FILE.java [ARGS]"
    target, program_args = rest[0], rest[1:]
    if target.endswith(".java") and os.path.isfile(target):
        # java FILE.java: compiled first (into a folder of its own), then run
        import hashlib
        source = os.path.abspath(target)
        out = os.path.join(os.environ.get("TMPDIR", "/tmp"), "nyxian-java-" + hashlib.sha1(source.encode()).hexdigest()[:12])
        shutil.rmtree(out, ignore_errors=True)
        os.makedirs(out, exist_ok=True)
        compile_cp = (classpath + ":" if classpath else "") + "."
        status = run_line(" ".join(_quote(a) for a in ["javac", "-cp", compile_cp, "-d", out, target]))
        if status != 0:
            return "status:%d" % status
        stem = os.path.splitext(os.path.basename(target))[0]
        main = stem
        if not os.path.exists(os.path.join(out, stem + ".class")):
            tops = sorted(f[:-6] for f in os.listdir(out) if f.endswith(".class") and "$" not in f)
            main = tops[0] if tops else stem
        classpath = out + ":" + (classpath or ".")
        target = main
    target = target[:-6] if target.endswith(".class") else target
    return [java, "-bootclasspath", _java_lib("minijvm_rt.jar"), "-cp", classpath or os.environ.get("CLASSPATH", ".")] + vm + [target.replace("/", ".")] + program_args


def _quote(text):
    return text if text and all(c.isalnum() or c in "-_./:=+@%," for c in text) else "'" + text.replace("'", "'\"'\"'") + "'"


def b_jar(args, inp, out, err):
    """jar c/t/x/u: make, list, extract and update .jar files (META-INF/MANIFEST.MF first)."""
    import zipfile
    usage = "usage: jar {c|t|x|u}[vfme] [JAR] [MANIFEST] [MAIN] [-C DIR] FILES…  (jar cfe app.jar Main -C classes .)"
    if not args:
        return _err("jar", usage, err)
    mode = args[0].lstrip("-")
    rest = list(args[1:])
    if not mode or mode[0] not in "ctxu":
        return _err("jar", usage, err)
    verbose = "v" in mode
    jarfile = manifest = entry = None
    for letter in mode[1:]:
        if letter == "f" and rest:
            jarfile = rest.pop(0)
        elif letter == "m" and rest:
            manifest = rest.pop(0)
        elif letter == "e" and rest:
            entry = rest.pop(0)
    if not jarfile:
        return _err("jar", "name the jar with f (jar cf app.jar …)", err)
    if mode[0] == "t":
        try:
            with zipfile.ZipFile(jarfile) as archive:
                for info in archive.infolist():
                    out.write(("%8d %s\n" % (info.file_size, info.filename)) if verbose else info.filename + "\n")
        except (OSError, zipfile.BadZipFile) as error:
            return _err("jar", "%s: %s" % (jarfile, error), err)
        return 0
    if mode[0] == "x":
        try:
            with zipfile.ZipFile(jarfile) as archive:
                names = [n for n in archive.namelist() if not rest or any(n == r or n.startswith(r.rstrip("/") + "/") for r in rest)]
                for name in names:
                    archive.extract(name, ".")
                    if verbose:
                        out.write("  extracted: %s\n" % name)
        except (OSError, zipfile.BadZipFile) as error:
            return _err("jar", "%s: %s" % (jarfile, error), err)
        return 0
    # c / u: files (and -C DIR FILES) into the jar
    pairs, base = [], "."
    i = 0
    while i < len(rest):
        if rest[i] == "-C" and i + 1 < len(rest):
            base = rest[i + 1]
            i += 2
            continue
        source = os.path.join(base, rest[i])
        if os.path.isdir(source):
            for folder, dirs, files in os.walk(source):
                dirs.sort()
                for name in sorted(files):
                    path = os.path.join(folder, name)
                    pairs.append((path, os.path.normpath(os.path.relpath(path, base)).replace(os.sep, "/")))
        elif os.path.exists(source):
            pairs.append((source, os.path.normpath(rest[i]).replace(os.sep, "/")))
        else:
            return _err("jar", "%s: no such file or folder" % source, err)
        base = "."   # -C DIR applies to the name after it
        i += 1
    existing = {}
    if mode[0] == "u" and os.path.exists(jarfile):
        with zipfile.ZipFile(jarfile) as archive:
            existing = {n: archive.read(n) for n in archive.namelist()}
    names = {name for _, name in pairs}
    text = None
    if manifest:
        with open(manifest, encoding="utf-8") as handle:
            text = handle.read()
    elif "META-INF/MANIFEST.MF" in names:
        text = None
    elif "META-INF/MANIFEST.MF" in existing:
        text = existing.pop("META-INF/MANIFEST.MF").decode("utf-8", "replace")
    else:
        text = "Manifest-Version: 1.0\nCreated-By: Nyxian Shell\n"
    if text is not None:
        if entry:
            lines = [l for l in text.replace("\r\n", "\n").split("\n") if l and not l.startswith("Main-Class:")]
            text = "\n".join(lines + ["Main-Class: " + entry]) + "\n"
        if not text.endswith("\n"):
            text += "\n"
    temporary = jarfile + ".tmp"
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
        if text is not None:
            archive.writestr("META-INF/MANIFEST.MF", text.replace("\n", "\r\n"))
        for path, name in pairs:
            if name == "META-INF/MANIFEST.MF" and text is not None:
                continue
            if os.path.abspath(path) == os.path.abspath(jarfile):
                continue
            archive.write(path, name)
            existing.pop(name, None)
            if verbose:
                out.write("adding: %s\n" % name)
        for name, data in existing.items():
            archive.writestr(name, data)
    os.replace(temporary, jarfile)
    return 0


def _node_command(name, args):
    """node, npm, npx, corepack — or a command npm installed. None if not one."""
    node = _node()
    home = os.environ.get("NYXIAN_NODE_HOME", "")
    if name in ("node", "nodejs"):
        return [node] + args if node else "node"
    if name in _NODE_TOOLS:
        if not node:
            return "node"
        if name == "npx" and args and not args[0].startswith("-"):
            # npx NAME: a command already installed runs here (npx can not start processes on iOS)
            found = _node_bin(args[0])
            if found:
                return _script_command(found, args[1:]) or [found] + args[1:]
            return "npx:" + args[0]
        return [node, os.path.join(home, _NODE_TOOLS[name])] + args
    found = _node_bin(name) if node else None
    if found:
        return _script_command(found, args) or [found] + args
    return None


# ---------------------------------------------------------------- built-in commands

class Exit(Exception):
    pass


def _err(name, message, err):
    err.write("%s: %s\n" % (name, message))
    return 1


def _flags(args, known):
    flags, rest = set(), []
    for arg in args:
        if arg.startswith("-") and len(arg) > 1 and not rest and all(c in known for c in arg[1:]):
            flags.update(arg[1:])
        else:
            rest.append(arg)
    return flags, rest


def _size(n):
    for unit in ("B", "K", "M", "G"):
        if n < 1024 or unit == "G":
            return ("%d%s" % (n, unit)) if unit == "B" else ("%.1f%s" % (n, unit))
        n /= 1024.0


def b_ls(args, inp, out, err):
    flags, paths = _flags(args, "laF1h")
    paths = paths or ["."]
    status = 0
    for index, path in enumerate(paths):
        if not os.path.exists(path):
            status = _err("ls", "%s: No such file or directory" % path, err)
            continue
        if os.path.isdir(path):
            names = sorted(os.listdir(path), key=str.lower)
            if "a" not in flags:
                names = [n for n in names if not n.startswith(".")]
            if len(paths) > 1:
                out.write("%s%s:\n" % ("\n" if index else "", path))
            entries = [(n, os.path.join(path, n)) for n in names]
        else:
            entries = [(path, path)]
        if "l" in flags:
            for name, full in entries:
                try:
                    info = os.lstat(full)
                except OSError:
                    continue
                kind = "d" if stat.S_ISDIR(info.st_mode) else ("l" if stat.S_ISLNK(info.st_mode) else "-")
                size = _size(info.st_size) if "h" in flags else str(info.st_size)
                when = time.strftime("%d %b %H:%M", time.localtime(info.st_mtime))
                out.write("%s%s %8s %s %s%s\n" % (kind, stat.filemode(info.st_mode)[1:], size, when, name, "/" if kind == "d" else ""))
        else:
            shown = [n + ("/" if os.path.isdir(f) else "") for n, f in entries]
            if "1" in flags or not out.isatty():
                out.write("".join(s + "\n" for s in shown))
            elif shown:
                width = max(len(s) for s in shown) + 2
                columns = max(1, shutil.get_terminal_size((80, 24)).columns // width)
                for row in range(0, len(shown), columns):
                    out.write("".join(s.ljust(width) for s in shown[row:row + columns]).rstrip() + "\n")
    return status


def b_cd(args, inp, out, err):
    target = args[0] if args else os.environ.get("HOME", "/")
    if target == "-":
        target = os.environ.get("OLDPWD", os.getcwd())
    try:
        previous = os.getcwd()
        os.chdir(os.path.expanduser(target))
        os.environ["OLDPWD"] = previous
        os.environ["PWD"] = os.getcwd()
        return 0
    except OSError as error:
        return _err("cd", "%s: %s" % (target, error.strerror), err)


def b_pwd(args, inp, out, err):
    out.write(os.getcwd() + "\n")
    return 0


def _read_inputs(paths, inp, err, name):
    if not paths or paths == ["-"]:
        yield "<stdin>", inp.read()
        return
    for path in paths:
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                yield path, handle.read()
        except OSError as error:
            _err(name, "%s: %s" % (path, error.strerror), err)


def b_cat(args, inp, out, err):
    flags, paths = _flags(args, "n")
    number = 1
    for _, text in _read_inputs(paths, inp, err, "cat"):
        if "n" in flags:
            for line in text.splitlines(True):
                out.write("%6d  %s" % (number, line))
                number += 1
        else:
            out.write(text)
    return 0


def b_echo(args, inp, out, err):
    newline = True
    if args and args[0] == "-n":
        newline, args = False, args[1:]
    out.write(" ".join(args) + ("\n" if newline else ""))
    return 0


def b_mkdir(args, inp, out, err):
    flags, paths = _flags(args, "p")
    status = 0
    for path in paths:
        try:
            os.makedirs(path, exist_ok=True) if "p" in flags else os.mkdir(path)
        except OSError as error:
            status = _err("mkdir", "%s: %s" % (path, error.strerror), err)
    return status


def b_rm(args, inp, out, err):
    flags, paths = _flags(args, "rfR")
    status = 0
    for path in paths:
        try:
            if os.path.isdir(path) and not os.path.islink(path):
                if not flags & {"r", "R"}:
                    status = _err("rm", "%s: is a directory (use rm -r)" % path, err)
                    continue
                shutil.rmtree(path)
            else:
                os.remove(path)
        except OSError as error:
            if "f" not in flags:
                status = _err("rm", "%s: %s" % (path, error.strerror), err)
    return status


def b_rmdir(args, inp, out, err):
    status = 0
    for path in args:
        try:
            os.rmdir(path)
        except OSError as error:
            status = _err("rmdir", "%s: %s" % (path, error.strerror), err)
    return status


def _copy_or_move(args, err, name, move):
    flags, paths = _flags(args, "rRf")
    if len(paths) < 2:
        return _err(name, "usage: %s SOURCE… DESTINATION" % name, err)
    *sources, target = paths
    status = 0
    for source in sources:
        destination = os.path.join(target, os.path.basename(source.rstrip("/"))) if os.path.isdir(target) else target
        try:
            if move:
                shutil.move(source, destination)
            elif os.path.isdir(source):
                if not flags & {"r", "R"}:
                    status = _err(name, "%s: is a directory (use cp -r)" % source, err)
                    continue
                shutil.copytree(source, destination, dirs_exist_ok=True)
            else:
                shutil.copy2(source, destination)
        except OSError as error:
            status = _err(name, "%s: %s" % (source, error.strerror or error), err)
    return status


def b_cp(args, inp, out, err):
    return _copy_or_move(args, err, "cp", False)


def b_mv(args, inp, out, err):
    return _copy_or_move(args, err, "mv", True)


def b_touch(args, inp, out, err):
    for path in args:
        with open(path, "a"):
            os.utime(path, None)
    return 0


def _count_arg(args, default=10):
    count, rest = default, []
    i = 0
    while i < len(args):
        if args[i] == "-n" and i + 1 < len(args):
            count = int(args[i + 1])
            i += 2
            continue
        if re.fullmatch(r"-\d+", args[i]):
            count = int(args[i][1:])
        else:
            rest.append(args[i])
        i += 1
    return count, rest


def b_head(args, inp, out, err):
    count, paths = _count_arg(args)
    for _, text in _read_inputs(paths, inp, err, "head"):
        out.write("".join(text.splitlines(True)[:count]))
    return 0


def b_tail(args, inp, out, err):
    count, paths = _count_arg(args)
    for _, text in _read_inputs(paths, inp, err, "tail"):
        lines = text.splitlines(True)
        out.write("".join(lines[-count:] if count else []))
    return 0


def b_wc(args, inp, out, err):
    flags, paths = _flags(args, "lwc")
    flags = flags or {"l", "w", "c"}
    for name, text in _read_inputs(paths, inp, err, "wc"):
        numbers = []
        if "l" in flags:
            numbers.append(text.count("\n"))
        if "w" in flags:
            numbers.append(len(text.split()))
        if "c" in flags:
            numbers.append(len(text.encode("utf-8")))
        out.write(" ".join("%7d" % n for n in numbers) + ("" if name == "<stdin>" else " " + name) + "\n")
    return 0


def b_grep(args, inp, out, err):
    flags, rest = _flags(args, "invrlcE")
    if not rest:
        return _err("grep", "usage: grep [-i -n -v -r -l -c] PATTERN [FILE…]", err)
    pattern, paths = rest[0], rest[1:]
    try:
        regex = re.compile(pattern, re.IGNORECASE if "i" in flags else 0)
    except re.error as error:
        return _err("grep", "bad pattern: %s" % error, err)
    if "r" in flags:
        expanded = []
        for path in paths or ["."]:
            if os.path.isdir(path):
                for folder, _, names in os.walk(path):
                    expanded.extend(os.path.join(folder, n) for n in sorted(names))
            else:
                expanded.append(path)
        paths = expanded
    found = False
    several = len(paths) > 1
    for name, text in _read_inputs(paths, inp, err, "grep"):
        hits = 0
        for number, line in enumerate(text.splitlines(), 1):
            if bool(regex.search(line)) != ("v" in flags):
                hits += 1
                found = True
                if "l" in flags or "c" in flags:
                    continue
                prefix = (name + ":" if several else "") + ("%d:" % number if "n" in flags else "")
                out.write(prefix + line + "\n")
        if "l" in flags and hits:
            out.write(name + "\n")
        if "c" in flags:
            out.write(((name + ":") if several else "") + str(hits) + "\n")
    return 0 if found else 1


def b_find(args, inp, out, err):
    root = args[0] if args and not args[0].startswith("-") else "."
    pattern = None
    kind = None
    if "-name" in args:
        pattern = args[args.index("-name") + 1]
    if "-type" in args:
        kind = args[args.index("-type") + 1]
    for folder, folders, names in os.walk(root):
        folders.sort()
        for name in ([os.path.basename(folder)] if folder == root else []) + sorted(folders) + sorted(names):
            path = folder if (folder == root and name == os.path.basename(folder)) else os.path.join(folder, name)
            if kind == "f" and not os.path.isfile(path):
                continue
            if kind == "d" and not os.path.isdir(path):
                continue
            if pattern and not fnmatch.fnmatch(os.path.basename(path), pattern):
                continue
            out.write(path + "\n")
    return 0


def b_tree(args, inp, out, err):
    root = args[0] if args else "."

    def walk(folder, prefix):
        try:
            names = sorted((n for n in os.listdir(folder) if not n.startswith(".")), key=str.lower)
        except OSError:
            return
        for index, name in enumerate(names):
            last = index == len(names) - 1
            path = os.path.join(folder, name)
            out.write(prefix + ("└── " if last else "├── ") + name + ("/" if os.path.isdir(path) else "") + "\n")
            if os.path.isdir(path) and not os.path.islink(path):
                walk(path, prefix + ("    " if last else "│   "))
    out.write(root + "\n")
    walk(root, "")
    return 0


def b_sort(args, inp, out, err):
    flags, paths = _flags(args, "rnu")
    lines = []
    for _, text in _read_inputs(paths, inp, err, "sort"):
        lines.extend(text.splitlines())
    key = (lambda s: float(re.match(r"\s*(-?\d+(\.\d+)?)", s).group(1)) if re.match(r"\s*-?\d", s) else 0.0) if "n" in flags else None
    lines.sort(key=key, reverse="r" in flags)
    if "u" in flags:
        lines = list(dict.fromkeys(lines))
    out.write("".join(line + "\n" for line in lines))
    return 0


def b_env(args, inp, out, err):
    for key in sorted(os.environ):
        out.write("%s=%s\n" % (key, os.environ[key]))
    return 0


def b_export(args, inp, out, err):
    for item in args:
        if "=" in item:
            key, value = item.split("=", 1)
            os.environ[key] = value
    return 0


def b_unset(args, inp, out, err):
    for key in args:
        os.environ.pop(key, None)
    return 0


def b_which(args, inp, out, err):
    status = 0
    for name in args:
        if name in BUILTINS:
            out.write("%s: built-in command of Nyxian Shell\n" % name)
        elif name in ("java", "javac") and _java():
            out.write(_java() + "\n")
        elif name in ("node", "nodejs") and _node():
            out.write(_node() + "\n")
        elif name in _NODE_TOOLS and _node():
            out.write(os.path.join(os.environ.get("NYXIAN_NODE_HOME", ""), _NODE_TOOLS[name]) + "\n")
        elif _node() and _node_bin(name):
            out.write(_node_bin(name) + "\n")
        elif _which(name):
            out.write(_which(name) + "\n")
        else:
            status = _err("which", "%s not found" % name, err)
    return status


def b_clear(args, inp, out, err):
    out.write("\033[2J\033[H")
    return 0


def b_history(args, inp, out, err):
    for number, line in enumerate(_history[-200:], max(1, len(_history) - 199)):
        out.write("%5d  %s\n" % (number, line))
    return 0


def b_sleep(args, inp, out, err):
    time.sleep(float(args[0]) if args else 1)
    return 0


def b_true(args, inp, out, err):
    return 0


def b_false(args, inp, out, err):
    return 1


def b_exit(args, inp, out, err):
    raise Exit(int(args[0]) if args else _status[0])


def b_jobs(args, inp, out, err):
    _reap()
    for number, job in sorted(_jobs.items()):
        pids = " ".join(str(p) for p in job["pids"])
        out.write("[%d]  %-8s %s%s\n" % (number, job["state"], job["command"], ("   (PID %s)" % pids) if pids else ""))
    return 0


def _job_number(args):
    if args:
        try:
            return int(args[0].lstrip("%"))
        except ValueError:
            return None
    return max(_jobs) if _jobs else None


def b_fg(args, inp, out, err):
    number = _job_number(args)
    if number not in _jobs:
        return _err("fg", "no such job", err)
    job = _jobs[number]
    out.write(job["command"] + "\n")
    out.flush()
    if job.get("thread") is not None:
        job["thread"].join()
        _jobs.pop(number, None)
        return 0
    job["state"] = "Running"
    try:
        os.killpg(job["pgid"], signal.SIGCONT)
    except OSError:
        for pid in job["pids"]:
            os.kill(pid, signal.SIGCONT)
    return _wait_job(number)


def b_bg(args, inp, out, err):
    number = _job_number(args)
    if number not in _jobs:
        return _err("bg", "no such job", err)
    job = _jobs[number]
    job["state"] = "Running"
    try:
        os.killpg(job["pgid"], signal.SIGCONT)
    except OSError:
        for pid in job["pids"]:
            os.kill(pid, signal.SIGCONT)
    out.write("[%d]+ %s &\n" % (number, job["command"]))
    return 0


def b_kill(args, inp, out, err):
    sig = signal.SIGTERM
    targets = []
    for arg in args:
        if arg.startswith("-") and len(arg) > 1:
            name = arg[1:].upper()
            sig = int(name) if name.isdigit() else getattr(signal, name if name.startswith("SIG") else "SIG" + name, signal.SIGTERM)
        else:
            targets.append(arg)
    status = 0
    for target in targets:
        try:
            if target.startswith("%"):
                job = _jobs[int(target[1:])]
                for pid in job["pids"]:
                    os.kill(pid, sig)
                    if job["state"] == "Stopped" and sig not in (signal.SIGKILL, signal.SIGCONT):
                        os.kill(pid, signal.SIGCONT)
            else:
                os.kill(int(target), sig)
        except (KeyError, ValueError, OSError) as error:
            status = _err("kill", "%s: %s" % (target, error), err)
    return status


def b_help(args, inp, out, err):
    out.write(
        "Nyxian Shell %s — built-in commands:\n"
        "  files    ls [-la] · cd · pwd · cat [-n] · head/tail [-n N] · wc · grep [-inrvlc] · find [-name -type]\n"
        "           tree · sort [-rnu] · mkdir [-p] · rm [-r] · rmdir · cp [-r] · mv · touch\n"
        "  shell    echo · env · export A=b · unset · which · history · clear · sleep · true · false · exit\n"
        "  jobs     jobs · fg [%%n] · bg [%%n] · kill [-9|-STOP|-CONT] PID|%%n · ^Z stops the program in front\n"
        "  programs python3 FILE.py · pip install NAME · your command line tools (by path or PATH)\n"
        "  node     node [FILE.js] · npm install/run/ls … · npx NAME · commands in node_modules/.bin\n"
        "  java     java FILE.java / java -jar APP.jar / java -cp DIR CLASS · javac -d DIR FILES · jar cf/tf/xf/uf (miniJVM: Java 8 subset)\n"
        "  scripts  sh FILE.sh / source FILE: its lines run in Nyxian Shell · ./tool with #! runs with its interpreter\n"
        "  syntax   a | b · > file · >> file · < file · 2> file · 2>&1 · a ; b · a && b · a || b · cmd & · $VAR ~ *.py\n" % VERSION)
    return 0


def b_source(args, inp, out, err):
    """Runs a file's lines in this shell ($1, $2… are its arguments)."""
    if not args:
        return _err("source", "usage: source FILE [ARGS]", err)
    if args[0] == "-c":
        return run_line(" ".join(args[1:]))
    try:
        with open(os.path.expanduser(args[0]), encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        return _err("source", "%s: %s" % (args[0], error.strerror or error), err)
    saved = {}
    for index, value in enumerate(args, start=0):
        key = str(index)
        saved[key] = os.environ.get(key)
        os.environ[key] = value
    status = 0
    try:
        pending = ""
        for line in lines:
            if line.rstrip().endswith("\\"):
                pending += line.rstrip()[:-1] + " "
                continue
            line, pending = pending + line, ""
            if line.strip().startswith("#") or not line.strip():
                continue
            status = run_line(line)
    finally:
        for key, value in saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
    return status


def b_pip(args, inp, out, err):
    python = sys.executable
    return None, [python, "-m", "nyxian_pip"] + args


BUILTINS = {
    "ls": b_ls, "cd": b_cd, "pwd": b_pwd, "cat": b_cat, "echo": b_echo, "mkdir": b_mkdir, "rm": b_rm,
    "rmdir": b_rmdir, "cp": b_cp, "mv": b_mv, "touch": b_touch, "head": b_head, "tail": b_tail, "wc": b_wc,
    "grep": b_grep, "find": b_find, "tree": b_tree, "sort": b_sort, "env": b_env, "export": b_export,
    "unset": b_unset, "which": b_which, "clear": b_clear, "history": b_history, "sleep": b_sleep,
    "true": b_true, "false": b_false, "exit": b_exit, "jobs": b_jobs, "fg": b_fg, "bg": b_bg,
    "kill": b_kill, "help": b_help, "source": b_source, ".": b_source, "sh": b_source, "bash": b_source,
    "jar": b_jar,
}
# changing the shell itself: never in a pipe's thread or the background
_SHELL_STATE = {"cd", "export", "unset", "exit", "fg", "bg", "jobs", "kill", "history", "clear", "source", ".", "sh", "bash"}


# ---------------------------------------------------------------- parsing

_OPERATORS = ("2>&1", "2>>", "&&", "||", ">>", "2>", ">", "<", "|", ";", "&")


class Word(list):
    """A word as typed: parts (text, how) with how = "raw", "single" or "double";
    variables, ~ and globs are expanded when its command runs."""


def tokenize(line):
    tokens, word, i, n = [], None, 0, len(line)

    def add(text, how):
        nonlocal word
        if word is None:
            word = Word()
        if word and word[-1][1] == how and how != "single":
            word[-1] = (word[-1][0] + text, how)
        else:
            word.append((text, how))

    def end_word():
        nonlocal word
        if word is not None:
            tokens.append(word)
            word = None

    while i < n:
        c = line[i]
        if c in " \t\r\n":
            end_word()
            i += 1
        elif c == "#" and word is None:
            break
        elif c == "'":
            close = line.find("'", i + 1)
            if close < 0:
                raise ValueError("missing closing '")
            add(line[i + 1:close], "single")
            i = close + 1
        elif c == '"':
            j, text = i + 1, []
            while j < n and line[j] != '"':
                if line[j] == "\\" and j + 1 < n and line[j + 1] in '"\\$`':
                    text.append(line[j + 1])
                    j += 2
                    continue
                text.append(line[j])
                j += 1
            if j >= n:
                raise ValueError('missing closing "')
            add("".join(text), "double")
            i = j + 1
        elif c == "\\" and i + 1 < n:
            add(line[i + 1], "single")
            i += 2
        else:
            operator = next((op for op in _OPERATORS if line.startswith(op, i)), None)
            if operator and (operator[0] != "2" or word is None):
                end_word()
                tokens.append(operator)
                i += len(operator)
            else:
                add(c, "raw")
                i += 1
    end_word()
    return tokens


def _expand_text(text, home_ok):
    def variable(match):
        name = match.group(1).strip("{}")
        return str(_status[0]) if name == "?" else os.environ.get(name, "")
    text = re.sub(r"\$(\?|\{[A-Za-z_0-9][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*|[0-9])", variable, text)
    if home_ok and (text == "~" or text.startswith("~/")):
        text = os.environ.get("HOME", "~") + text[1:]
    return text


def expand(word):
    """A Word into its argument(s): variables (not in '…'), ~ at the start, globs (unquoted)."""
    if isinstance(word, str):
        return [word]
    text, pattern, globbing = [], [], False
    for index, (part, how) in enumerate(word):
        value = part if how == "single" else _expand_text(part, how == "raw" and index == 0)
        text.append(value)
        if how == "raw" and any(c in value for c in "*?["):
            globbing = True
            pattern.append(value)
        else:
            pattern.append(glob.escape(value))
    joined = "".join(text)
    if globbing:
        matches = sorted(glob.glob("".join(pattern)))
        if matches:
            return matches
    return [joined]


def split_list(tokens):
    """[(connector, tokens of one pipeline, background)] — expanded later, one by one."""
    items, current, connector = [], [], None
    for token in tokens:
        if token in (";", "&&", "||", "&"):
            if current:
                items.append((connector, current, token == "&"))
            current = []
            connector = token if token in ("&&", "||") else None
        else:
            current.append(token)
    if current:
        items.append((connector, current, False))
    return items


def parse_pipeline(tokens):
    """[command]: {"argv": [...], "in": path, "out": (path, append), "err": (path, append) or "out"}."""
    pipeline, command = [], {"argv": []}
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token in (">", ">>", "<", "2>", "2>>"):
            if i + 1 >= len(tokens) or isinstance(tokens[i + 1], str):
                raise ValueError("a file name is missing after %s" % token)
            target = expand(tokens[i + 1])[0]
            if token == "<":
                command["in"] = target
            elif token.startswith("2"):
                command["err"] = (target, token == "2>>")
            else:
                command["out"] = (target, token == ">>")
            i += 2
            continue
        if token == "2>&1":
            command["err"] = "out"
        elif token == "|":
            pipeline.append(command)
            command = {"argv": []}
        else:
            command["argv"].extend(expand(token))
        i += 1
    pipeline.append(command)
    return [c for c in pipeline if c["argv"] or len(c) > 1]


def _display(tokens):
    parts = []
    for token in tokens:
        parts.append(token if isinstance(token, str) else "".join(
            ("'%s'" % t) if how == "single" and (" " in t or not t) else (('"%s"' % t) if how == "double" else t) for t, how in token))
    return " ".join(parts)


# ---------------------------------------------------------------- running

class _FdWriter(io.TextIOWrapper):
    pass


def _open_redirects(command, default_in, default_out, default_err):
    inp, out, err, opened = default_in, default_out, default_err, []
    if "in" in command:
        inp = open(command["in"], encoding="utf-8", errors="replace")
        opened.append(inp)
    if "out" in command:
        path, append = command["out"]
        out = open(path, "a" if append else "w", encoding="utf-8")
        opened.append(out)
    if command.get("err") == "out":
        err = out
    elif "err" in command:
        path, append = command["err"]
        err = open(path, "a" if append else "w", encoding="utf-8")
        opened.append(err)
    return inp, out, err, opened


def _run_builtin(command, inp, out, err):
    name = command["argv"][0]
    local_in, local_out, local_err, opened = _open_redirects(command, inp, out, err)
    try:
        result = BUILTINS[name](command["argv"][1:], local_in, local_out, local_err)
        local_out.flush()
        local_err.flush()
        return result
    except Exit:
        raise
    except KeyboardInterrupt:
        local_err.write("^C\n")
        return 130
    except BrokenPipeError:
        return 141
    except Exception as error:
        local_err.write("%s: %s\n" % (name, error))
        return 1
    finally:
        for handle in opened:
            handle.close()


def _fd_of(handle, mode):
    """A real file descriptor for a stream (programs need one)."""
    try:
        return handle.fileno(), None
    except (AttributeError, io.UnsupportedOperation, ValueError):
        pass
    read, write = os.pipe()
    if mode == "r":
        data = handle.read().encode("utf-8")

        def feed():
            with os.fdopen(write, "wb") as pipe:
                try:
                    pipe.write(data)
                except BrokenPipeError:
                    pass
        threading.Thread(target=feed, daemon=True).start()
        return read, read
    else:
        def drain():
            with os.fdopen(read, "rb") as pipe:
                for chunk in iter(lambda: pipe.read(4096), b""):
                    handle.write(chunk.decode("utf-8", "replace"))
                handle.flush()
        thread = threading.Thread(target=drain, daemon=True)
        thread.start()
        return write, (write, thread)


def run_pipeline(pipeline, background, text):
    """Built-in commands run here (text between them); programs run as
    processes of their own, joined by real pipes."""
    stages = []
    for command in pipeline:
        argv = command["argv"]
        if not argv:
            stages.append(("noop", command, None))
            continue
        name = argv[0]
        node_argv = None if name in BUILTINS or name == "pip" else (_java_command(name, list(argv[1:])) or _node_command(name, list(argv[1:])))
        if name == "pip":
            stages.append(("program", command, [sys.executable, "-m", "nyxian_pip"] + argv[1:]))
        elif name in BUILTINS:
            stages.append(("builtin", command, None))
        elif isinstance(node_argv, str) and node_argv.startswith("status:"):
            return int(node_argv[7:])
        elif isinstance(node_argv, str) and not node_argv.startswith("npx:") and node_argv != "node":
            sys.stderr.write(node_argv + "\n")
            return 2 if node_argv.startswith("usage") else 127
        elif isinstance(node_argv, str):
            if node_argv.startswith("npx:"):
                sys.stderr.write("npx: %s is not installed here: npm install %s (then npx %s, or just %s)\n"
                                 % ((node_argv[4:],) * 4))
                return 127
            sys.stderr.write("%s: Node.js is not ready yet (Nyxian prepares it after Python; or open </> › Node.js)\n" % name)
            return 127
        elif node_argv:
            stages.append(("program", command, node_argv))
        else:
            path = _which(name)
            if path is None:
                sys.stderr.write("%s: command not found (help lists the built-in commands)\n" % name)
                return 127
            argv = list(argv)
            if path == sys.executable:
                argv[0] = "python3"
                stages.append(("program", command, [path] + argv[1:]))
                continue
            script = _script_command(path, argv[1:])
            if script == "node":
                sys.stderr.write("%s: needs Node.js, which is not ready yet\n" % name)
                return 127
            stages.append(("program", command, script or [path] + argv[1:]))

    # only built-ins: text flows from one to the next
    if all(kind != "program" for kind, _, _ in stages):
        if background:
            if any(c["argv"] and c["argv"][0] in _SHELL_STATE for _, c, _ in stages):
                sys.stderr.write("%s: cannot run in the background\n" % text)
                return 1
            number = _new_job(text)
            thread = threading.Thread(target=lambda: _builtin_chain(stages), daemon=True)
            _jobs[number]["thread"] = thread
            thread.start()
            _out("[%d] (built-in)\n" % number)
            return 0
        return _builtin_chain(stages)

    # programs: every stage gets real descriptors
    number = _new_job(text)
    job = _jobs[number]
    env = dict(os.environ)
    previous_read = None
    waits = []
    status = 0
    for index, (kind, command, argv) in enumerate(stages):
        last = index == len(stages) - 1
        if last:
            next_read, next_write = None, None
        else:
            next_read, next_write = os.pipe()
        stdin_handle = os.fdopen(os.dup(previous_read), "r", encoding="utf-8", errors="replace", closefd=True) if previous_read is not None else sys.stdin
        stdout_handle = os.fdopen(os.dup(next_write), "w", encoding="utf-8", closefd=True) if next_write is not None else sys.stdout
        local_in, local_out, local_err, opened = _open_redirects(command, stdin_handle, stdout_handle, sys.stderr)
        try:
            if kind == "program":
                fd_in, keep_in = _fd_of(local_in, "r")
                fd_out, keep_out = _fd_of(local_out, "w")
                fd_err, keep_err = _fd_of(local_err, "w") if local_err is not local_out else (fd_out, None)
                try:
                    pid = spawner().spawn(argv[0], argv, env, {0: fd_in, 1: fd_out, 2: fd_err}, job["pgid"])
                except OSError as error:
                    sys.stderr.write("%s: could not start (%s, error %s)\n" % (command["argv"][0], error.strerror or error, error.errno))
                    why = {
                        getattr(errno, "EAUTH", -1): "Nyxian refused its signature or entitlements",
                        getattr(errno, "EBADEXEC", -1): "Nyxian could not open a process for it (LiveProcess)",
                        errno.ECHILD: "it ended as soon as it started",
                        errno.EBUSY: "too many programs are running",
                        errno.EINVAL: "the process group was refused",
                        errno.EPERM: "Nyxian refused it (python3's sandbox or permission to start programs)",
                        errno.EACCES: "python3's sandbox does not let it read the program",
                        errno.EROFS: "its signature is not valid here and python3 may not sign it again",
                    }.get(error.errno)
                    if why:
                        sys.stderr.write("  %s\n" % why)
                    sys.stderr.write("  (started with %s)\n" % spawner().used)
                    reports = [("what Nyxian saw", os.path.join(os.environ.get("PYTHONHOME", ""), ".nyxian-spawn.txt")),
                               ("signatures", os.environ.get("NYXIAN_SIGNING_REPORT", ""))]
                    for title, report in reports:
                        if report and os.path.isfile(report):
                            sys.stderr.write("  --- %s (send this to fix it) ---\n" % title)
                            with open(report, encoding="utf-8", errors="replace") as handle:
                                sys.stderr.write("".join("  " + line for line in handle))
                    if command["argv"][0] in ("java", "javac", "node", "npm", "npx"):
                        sys.stderr.write("  try Reinstall %s in the Python panel, then open a new terminal\n"
                                         % ("Java" if command["argv"][0].startswith("java") else "Node.js"))
                    status = 126
                    pid = None
                if pid:
                    job["pids"].append(pid)
                    job["last"] = pid
                    if not job["pgid"]:
                        job["pgid"] = pid
                for keep in (keep_in, keep_out, keep_err):
                    if isinstance(keep, tuple):
                        os.close(keep[0])
                        waits.append(keep[1])
                    elif isinstance(keep, int):
                        os.close(keep)
            else:
                _run_builtin(command, local_in, local_out, local_err) if kind == "builtin" else 0
        finally:
            for handle in opened:
                handle.close()
            if stdout_handle is not sys.stdout:
                stdout_handle.close()
            if stdin_handle is not sys.stdin:
                stdin_handle.close()
            if previous_read is not None:
                os.close(previous_read)
            if next_write is not None:
                os.close(next_write)
            previous_read = next_read
    if not job["pids"]:
        _jobs.pop(number, None)
        return status or 0
    if background:
        _out("[%d] %d\n" % (number, job["pids"][-1]))
        return 0
    status = _wait_job(number)
    for thread in waits:
        thread.join(2)
    return status


def _builtin_chain(stages):
    data = None
    status = 0
    for index, (kind, command, _) in enumerate(stages):
        last = index == len(stages) - 1
        inp = io.StringIO(data) if data is not None else sys.stdin
        out = sys.stdout if last else io.StringIO()
        if kind == "builtin":
            status = _run_builtin(command, inp, out, sys.stderr)
        if not last:
            data = out.getvalue()
    return status


def run_line(line):
    line = line.strip()
    if not line:
        return _status[0]
    try:
        items = split_list(tokenize(line))
    except ValueError as error:
        sys.stderr.write("syntax: %s\n" % error)
        _status[0] = 2
        return 2
    for connector, tokens, background in items:
        if connector == "&&" and _status[0] != 0:
            continue
        if connector == "||" and _status[0] == 0:
            continue
        try:
            pipeline = parse_pipeline(tokens)
        except ValueError as error:
            sys.stderr.write("syntax: %s\n" % error)
            _status[0] = 2
            continue
        if not pipeline:
            continue
        text = _display(tokens)
        _status[0] = run_pipeline(pipeline, background, text if not background else text + " &") or 0
    return _status[0]


def _prompt():
    folder = os.getcwd()
    home = os.environ.get("HOME", "")
    if home and (folder == home or folder.startswith(home + "/")):
        folder = "~" + folder[len(home):]
    elif len(folder) > 40:
        folder = "…" + folder[-38:]
    mark = "\033[31m" if _status[0] else "\033[32m"
    return "%s❯\033[0m \033[1m%s\033[0m $ " % (mark, folder)


def main():
    from nyxian_lineedit import read_line
    signal.signal(signal.SIGINT, signal.default_int_handler)
    for name in ("SIGTSTP", "SIGTTOU", "SIGTTIN"):
        if hasattr(signal, name):
            signal.signal(getattr(signal, name), signal.SIG_IGN)
    # the shell leads its own group, so ^Z reaches only the program in front
    try:
        os.setpgid(0, 0)
    except OSError:
        pass
    _terminal_group(os.getpgrp())
    os.environ.setdefault("PWD", os.getcwd())
    os.environ.setdefault("SHELL", "nyxian_shell")
    if len(sys.argv) > 2 and sys.argv[1] == "-c":
        try:
            return run_line(" ".join(sys.argv[2:]))
        except Exit as code:
            return code.args[0]
    if len(sys.argv) > 1 and os.path.isfile(sys.argv[1]):
        try:
            return b_source(sys.argv[1:], sys.stdin, sys.stdout, sys.stderr)
        except Exit as code:
            return code.args[0]
    _out("Nyxian Shell %s · help lists the commands · ^D or exit quits\n" % VERSION)
    # a command to run first, then the prompt (Java in Shell: java -version)
    first = os.environ.pop("NYXIAN_SHELL_INIT", "")
    if first:
        try:
            run_line(first)
        except Exit:
            pass
        except Exception as error:
            _out("%s\n" % error)
    while True:
        _reap()
        try:
            line = read_line(_prompt())
        except KeyboardInterrupt:
            _out("^C\n")
            continue
        except EOFError:
            break
        if line is None:
            break
        text = str(line)
        if text == "\x04":
            break
        if text.strip():
            _history.append(text.strip())
        try:
            run_line(text)
        except Exit as code:
            return code.args[0]
        except KeyboardInterrupt:
            _out("^C\n")
            _status[0] = 130
        finally:
            for stream in (sys.stdout, sys.stderr):
                try:
                    stream.flush()
                except Exception:
                    pass
    _out("exit\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
"""#,
        "nyxian_pdb.py": #"""
# Python debugger of Nyxian: runs a script with the breakpoints set in the
# editor (NYXIAN_BREAKPOINTS: JSON [{"file": path relative to the run folder,
# "line": n}]) and goes straight to the first one. At each stop it tells the
# editor where (NYXIAN_DEBUG_STATE) and writes the frame's variables for the
# variable inspector (NYXIAN_VARS_FILE). Commands are pdb's.
# Run as: python3 -m nyxian_pdb script.py [arguments…]
import json
import os
import pdb
import sys

HELP = ("Debugger · c continue · n next line · s step into · r until return · "
        "p EXPR / pp EXPR show · l list · w where · u / d up / down · "
        "b LINE breakpoint · cl clear · locals · q quit")


def _state(payload):
    path = os.environ.get("NYXIAN_DEBUG_STATE")
    if not path:
        return
    try:
        temporary = path + ".tmp"
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(payload, handle)
        os.replace(temporary, path)
    except Exception:
        pass


class NyxianPdb(pdb.Pdb):
    def __init__(self, script, breakpoints):
        super().__init__(readrc=False)
        self.prompt = "(debug) "
        self._script = os.path.abspath(script)
        self._started = False
        self._wanted = []
        for item in breakpoints:
            path = os.path.abspath(item.get("file", ""))
            line = int(item.get("line", 0))
            if path and line > 0:
                self._wanted.append((path, line))

    def arm(self):
        armed = 0
        for path, line in self._wanted:
            error = self.set_break(self.canonic(path), line)
            if error:
                self.message("breakpoint %s:%d not set: %s" % (os.path.basename(path), line, error))
            else:
                armed += 1
        return armed

    def user_line(self, frame):
        if not self._started:
            # the script's first line: on to the first breakpoint (if any)
            if self.canonic(frame.f_code.co_filename) != self.canonic(self._script):
                return
            self._started = True
            if self.breaks and not self.break_here(frame):
                self.set_continue()
                return
        super().user_line(frame)

    def interaction(self, frame, tb):
        if frame is not None:
            self._report(frame, tb)
        try:
            super().interaction(frame, tb)
        finally:
            _state({"running": True})

    def _report(self, frame, tb):
        stack = []
        current = frame
        while current is not None and len(stack) < 30:
            stack.append({"file": current.f_code.co_filename, "line": current.f_lineno, "function": current.f_code.co_name})
            current = current.f_back
        _state({"running": False, "file": frame.f_code.co_filename, "line": frame.f_lineno,
                "function": frame.f_code.co_name, "exception": tb is not None, "stack": stack})
        try:
            from nyxian_repl import snapshot
            snapshot(dict(frame.f_locals))
        except Exception:
            pass

    def do_locals(self, arg):
        """locals: the variables of the current frame."""
        frame = self.curframe
        for name, value in sorted(frame.f_locals.items()):
            if name.startswith("__"):
                continue
            try:
                text = repr(value)
            except Exception as error:
                text = "<%s>" % error
            self.message("  %s = %s" % (name, " ".join(text.split())[:160]))

    def do_help(self, arg):
        if not arg:
            self.message(HELP)
        return super().do_help(arg)


def main():
    if len(sys.argv) < 2:
        print("usage: python3 -m nyxian_pdb script.py [arguments…]")
        return 2
    script = sys.argv[1]
    try:
        breakpoints = json.loads(os.environ.get("NYXIAN_BREAKPOINTS") or "[]")
    except ValueError:
        breakpoints = []
    sys.argv = sys.argv[1:]
    sys.path.insert(0, os.path.dirname(os.path.abspath(script)))
    debugger = NyxianPdb(script, breakpoints)
    armed = debugger.arm()
    print(HELP)
    print("%d breakpoint%s from the editor%s" % (armed, "" if armed == 1 else "s",
          "" if armed else " — it stops at the first line (set them with ⌘\\ in the editor)"))
    with open(script, "rb") as handle:
        code = compile(handle.read(), os.path.abspath(script), "exec")
    namespace = {"__name__": "__main__", "__file__": os.path.abspath(script), "__builtins__": __builtins__}
    _state({"running": True})
    try:
        debugger.run(code, namespace, namespace)
    except SystemExit:
        pass
    except BaseException:
        import traceback
        traceback.print_exc()
        frame_tb = sys.exc_info()[2]
        print("\nThe script ended with an error: the debugger shows where (q quits).")
        debugger.interaction(None, frame_tb)
    finally:
        _state({"running": False, "ended": True})
    print("[debugging ended]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
"""#,
        "nyxian_tests.py": #"""
# Run Tests in Nyxian: pytest when it is there (it comes with Nyxian),
# unittest otherwise. The failures, with file and line, go to
# NYXIAN_TEST_FILE so the editor marks their lines.
import json
import os
import sys
import traceback


def _inside(path):
    return path and os.path.abspath(path).startswith(os.getcwd())


def _write(failures, passed, failed):
    path = os.environ.get("NYXIAN_TEST_FILE")
    if path:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({"failures": failures, "passed": passed, "failed": failed}, handle)


def with_pytest(target):
    import pytest
    failures = []
    counts = {"passed": 0, "failed": 0}

    class Collector:
        def pytest_runtest_logreport(self, report):
            if report.when == "call" and report.passed:
                counts["passed"] += 1
            if report.failed and report.when in ("setup", "call", "teardown"):
                counts["failed"] += 1
                where_file, where_line = report.location[0], (report.location[1] or 0) + 1
                message = report.head_line or report.nodeid
                try:
                    entries = report.longrepr.reprtraceback.reprentries
                    for entry in reversed(entries):
                        location = getattr(entry, "reprfileloc", None)
                        if location and _inside(location.path):
                            where_file, where_line = location.path, location.lineno
                            message = "%s: %s" % (report.nodeid.split("::")[-1], location.message)
                            break
                except Exception:
                    pass
                failures.append({"test": report.nodeid, "file": os.path.abspath(where_file), "line": where_line, "message": message})

    code = pytest.main(["-q", "-rfE", "--color=yes", "-p", "no:cacheprovider", target], plugins=[Collector()])
    _write(failures, counts["passed"], counts["failed"])
    return int(code)


def with_unittest(target):
    import unittest
    loader = unittest.TestLoader()
    if os.path.isdir(target):
        suite = loader.discover(target, pattern="test*.py")
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(target)))
        suite = loader.loadTestsFromName(os.path.splitext(os.path.basename(target))[0])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    failures = []
    for test, text in result.failures + result.errors:
        line, file = 1, None
        for chunk in text.splitlines():
            chunk = chunk.strip()
            if chunk.startswith('File "'):
                name = chunk.split('"')[1]
                if _inside(name):
                    file = name
                    try:
                        line = int(chunk.split("line ")[1].split(",")[0])
                    except Exception:
                        pass
        message = text.strip().splitlines()[-1] if text.strip() else str(test)
        failures.append({"test": str(test), "file": os.path.abspath(file) if file else None, "line": line, "message": message})
    _write(failures, result.testsRun - len(failures), len(failures))
    return 0 if result.wasSuccessful() else 1


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "."
    try:
        import pytest  # noqa: F401
        has_pytest = True
    except Exception:
        has_pytest = False
    sys.exit(with_pytest(target) if has_pytest else with_unittest(target))


if __name__ == "__main__":
    main()
"""#,
        "nyxian_turtle.py": #"""
# turtle in Nyxian: iOS has no Tk window, so the turtle draws in memory and
# done() / mainloop() / exitonclick() (or the end of the script) saves the
# drawing as PNG (turtle/ in the run folder) and shows it like a plt.show().
# `import turtle` loads this module.
import atexit
import math
import os
import sys

__all__ = ["Turtle", "Pen", "RawTurtle", "Screen", "TurtleScreen", "Vec2D", "done", "mainloop",
           "exitonclick", "bye", "Terminator"]


class Terminator(Exception):
    pass


class Vec2D(tuple):
    def __new__(cls, x, y):
        return tuple.__new__(cls, (x, y))

    def __add__(self, other):
        return Vec2D(self[0] + other[0], self[1] + other[1])

    def __sub__(self, other):
        return Vec2D(self[0] - other[0], self[1] - other[1])

    def __mul__(self, other):
        if isinstance(other, Vec2D):
            return self[0] * other[0] + self[1] * other[1]
        return Vec2D(self[0] * other, self[1] * other)

    __rmul__ = __mul__

    def __abs__(self):
        return math.hypot(self[0], self[1])

    def __neg__(self):
        return Vec2D(-self[0], -self[1])

    def __repr__(self):
        return "(%.2f,%.2f)" % self


def _color(args):
    if not args:
        return None
    if len(args) == 1:
        value = args[0]
    else:
        value = tuple(args)
    if isinstance(value, tuple) and len(value) == 3:
        mode = _screen()._colormode
        if mode == 255:
            value = tuple(c / 255.0 for c in value)
    return value


class TurtleScreen:
    def __init__(self):
        self._turtles = []
        self._bg = "white"
        self._title = "turtle"
        self._colormode = 1.0
        self._shown = False
        self._world = None
        self._size = (800, 600)

    # window-ish settings
    def bgcolor(self, *args):
        if not args:
            return self._bg
        self._bg = _color(args)

    def title(self, text):
        self._title = str(text)

    def setup(self, width=800, height=600, startx=None, starty=None):
        if isinstance(width, int) and isinstance(height, int):
            self._size = (width, height)

    def screensize(self, canvwidth=None, canvheight=None, bg=None):
        if bg is not None:
            self._bg = bg
        if canvwidth and canvheight:
            self._size = (canvwidth, canvheight)
        return self._size

    def setworldcoordinates(self, llx, lly, urx, ury):
        self._world = (llx, lly, urx, ury)

    def colormode(self, mode=None):
        if mode is None:
            return self._colormode
        self._colormode = 255 if mode == 255 else 1.0

    def window_width(self):
        return self._size[0]

    def window_height(self):
        return self._size[1]

    def turtles(self):
        return list(self._turtles)

    def clear(self):
        for t in self._turtles:
            t.clear()

    clearscreen = clear

    def reset(self):
        for t in self._turtles:
            t.reset()

    resetscreen = reset

    # animation and events: the drawing is shown once, at the end
    def tracer(self, n=None, delay=None):
        return 1

    def delay(self, delay=None):
        return 0

    def update(self):
        pass

    def listen(self, xdummy=None, ydummy=None):
        pass

    def onkey(self, fun, key=None):
        pass

    onkeyrelease = onkeypress = onkey

    def onclick(self, fun, btn=1, add=None):
        pass

    onscreenclick = onclick

    def ontimer(self, fun, t=0):
        pass

    def register_shape(self, name, shape=None):
        pass

    addshape = register_shape

    def textinput(self, title, prompt):
        return input("%s: " % prompt)

    def numinput(self, title, prompt, default=None, minval=None, maxval=None):
        text = input("%s: " % prompt)
        try:
            return float(text)
        except ValueError:
            return default

    def mainloop(self):
        self._show()

    done = mainloop

    def exitonclick(self):
        self._show()

    def bye(self):
        self._show()

    def getcanvas(self):
        return None

    # drawing
    def _show(self):
        if self._shown:
            return
        self._shown = True
        if not any(t._items or t._current for t in self._turtles):
            return
        try:
            from matplotlib.backends.backend_agg import FigureCanvasAgg
            from matplotlib.figure import Figure
            from matplotlib.patches import Polygon
        except Exception as error:
            sys.stderr.write("turtle: matplotlib is needed to draw (%s)\n" % error)
            return
        width, height = self._size
        figure = Figure(figsize=(width / 100.0, height / 100.0), dpi=100)
        FigureCanvasAgg(figure)
        figure.patch.set_facecolor(self._bg)
        axes = figure.add_axes([0, 0, 1, 1])
        axes.set_facecolor(self._bg)
        axes.set_axis_off()
        axes.set_aspect("equal" if self._world is None else "auto")
        xs, ys = [0.0], [0.0]
        for t in self._turtles:
            for kind, data in t._items + ([("line", t._current)] if t._current else []):
                if kind == "fill":
                    points, color = data
                    if len(points) > 2:
                        axes.add_patch(Polygon(points, closed=True, facecolor=color, edgecolor="none", zorder=1))
                        xs += [p[0] for p in points]
                        ys += [p[1] for p in points]
                elif kind == "line":
                    points, color, size = data
                    if len(points) > 1:
                        axes.plot([p[0] for p in points], [p[1] for p in points], color=color,
                                  linewidth=size * 0.75, solid_capstyle="round", solid_joinstyle="round", zorder=2)
                        xs += [p[0] for p in points]
                        ys += [p[1] for p in points]
                elif kind == "dot":
                    (x, y), size, color = data
                    axes.scatter([x], [y], s=(size * 0.75) ** 2, c=[color], zorder=3, linewidths=0)
                    xs.append(x)
                    ys.append(y)
                elif kind == "text":
                    (x, y), text, color, align, font = data
                    family, size, style = (list(font) + ["Arial", 8, "normal"][len(font):])[:3]
                    axes.text(x, y, text, color=color, ha={"left": "left", "right": "right"}.get(align, "center"),
                              va="bottom", fontsize=size, fontweight="bold" if "bold" in str(style) else "normal",
                              fontstyle="italic" if "italic" in str(style) else "normal", zorder=4)
                    xs.append(x)
                    ys.append(y)
            if t._visible:
                x, y = t._pos
                a = math.radians(t._heading)
                tip = (x + 10 * math.cos(a), y + 10 * math.sin(a))
                left = (x + 6 * math.cos(a + 2.5), y + 6 * math.sin(a + 2.5))
                right = (x + 6 * math.cos(a - 2.5), y + 6 * math.sin(a - 2.5))
                axes.add_patch(Polygon([tip, left, (x, y), right], closed=True, facecolor=t._fill,
                                       edgecolor=t._pen, zorder=5))
        if self._world:
            llx, lly, urx, ury = self._world
            axes.set_xlim(llx, urx)
            axes.set_ylim(lly, ury)
        else:
            margin = 20
            left, right = min(xs) - margin, max(xs) + margin
            bottom, top = min(ys) - margin, max(ys) + margin
            half_w = max(width / 2.0, abs(left), abs(right))
            half_h = max(height / 2.0, abs(bottom), abs(top))
            axes.set_xlim(-half_w, half_w)
            axes.set_ylim(-half_h, half_h)
        folder = os.environ.get("NYXIAN_PLOT_DIR") or os.path.join(os.getcwd(), "figures")
        os.makedirs(folder, exist_ok=True)
        number = 1
        while os.path.exists(os.path.join(folder, "turtle-%d.png" % number)):
            number += 1
        path = os.path.join(folder, "turtle-%d.png" % number)
        figure.savefig(path, dpi=144, facecolor=figure.get_facecolor())
        for stream in (sys.stdout, sys.stderr):
            try:
                stream.flush()
            except Exception:
                pass
        if os.environ.get("NYXIAN_TERMINAL") == "1":
            os.write(1, ("\x1b]7770;nyxian-preview;%s\x07" % path).encode("utf-8"))
        os.write(1, ("[turtle: %s]\n" % os.path.relpath(path)).encode("utf-8"))


_the_screen = None


def _screen():
    global _the_screen
    if _the_screen is None:
        _the_screen = TurtleScreen()
        atexit.register(_the_screen._show)
    return _the_screen


def Screen():
    return _screen()


class RawTurtle:
    def __init__(self, canvas=None, shape="classic", undobuffersize=1000, visible=True):
        self.screen = _screen()
        self.screen._turtles.append(self)
        self._visible = visible
        self.reset()

    def reset(self):
        self._pos = Vec2D(0.0, 0.0)
        self._heading = 0.0
        self._down = True
        self._pen = "black"
        self._fill = "black"
        self._size = 1
        self._items = []
        self._current = None
        self._filling = None
        self._degrees = 360.0

    def clear(self):
        self._items = []
        self._current = None
        self._filling = None

    # moving
    def _move_to(self, x, y):
        x, y = float(x), float(y)
        if self._down:
            if self._current is None:
                self._current = ([tuple(self._pos)], self._pen, self._size)
            self._current[0].append((x, y))
        if self._filling is not None:
            self._filling.append((x, y))
        self._pos = Vec2D(x, y)

    def _end_line(self):
        if self._current is not None:
            self._items.append(("line", self._current))
            self._current = None

    def forward(self, distance):
        a = math.radians(self._heading)
        self._move_to(self._pos[0] + distance * math.cos(a), self._pos[1] + distance * math.sin(a))

    fd = forward

    def backward(self, distance):
        self.forward(-distance)

    bk = back = backward

    def _unit(self, angle):
        return angle * 360.0 / self._degrees

    def left(self, angle):
        self._heading = (self._heading + self._unit(angle)) % 360

    lt = left

    def right(self, angle):
        self._heading = (self._heading - self._unit(angle)) % 360

    rt = right

    def goto(self, x, y=None):
        if y is None:
            x, y = x
        self._move_to(x, y)

    setpos = setposition = goto

    def teleport(self, x=None, y=None, *, fill_gap=False):
        self._end_line()
        self._pos = Vec2D(self._pos[0] if x is None else float(x), self._pos[1] if y is None else float(y))

    def setx(self, x):
        self._move_to(x, self._pos[1])

    def sety(self, y):
        self._move_to(self._pos[0], y)

    def setheading(self, to_angle):
        self._heading = self._unit(to_angle) % 360

    seth = setheading

    def home(self):
        self._move_to(0, 0)
        self._heading = 0.0

    def circle(self, radius, extent=None, steps=None):
        if extent is None:
            extent = self._degrees
        extent = self._unit(extent)
        if steps is None:
            steps = 1 + int(min(11 + abs(radius) / 6.0, 59.0) * abs(extent) / 360.0)
        step_angle = float(extent) / steps
        length = 2.0 * radius * math.sin(math.radians(step_angle) / 2.0)
        if radius < 0:
            length, step_angle = -length, -step_angle
        self._heading = (self._heading + step_angle / 2.0) % 360
        for _ in range(steps):
            a = math.radians(self._heading)
            self._move_to(self._pos[0] + length * math.cos(a), self._pos[1] + length * math.sin(a))
            self._heading = (self._heading + step_angle) % 360
        self._heading = (self._heading - step_angle / 2.0) % 360

    def dot(self, size=None, *color):
        size = size or max(self._size + 4, 2 * self._size)
        self._items.append(("dot", (tuple(self._pos), size, _color(color) or self._pen)))

    def stamp(self):
        return 0

    def clearstamp(self, stampid):
        pass

    def clearstamps(self, n=None):
        pass

    def undo(self):
        pass

    def speed(self, speed=None):
        return 0

    def degrees(self, fullcircle=360.0):
        self._degrees = float(fullcircle)

    def radians(self):
        self._degrees = 2 * math.pi

    # state
    def position(self):
        return self._pos

    pos = position

    def xcor(self):
        return self._pos[0]

    def ycor(self):
        return self._pos[1]

    def heading(self):
        return self._heading * self._degrees / 360.0

    def towards(self, x, y=None):
        if y is None:
            x, y = x
        return (math.degrees(math.atan2(y - self._pos[1], x - self._pos[0])) % 360) * self._degrees / 360.0

    def distance(self, x, y=None):
        if y is None:
            x, y = x
        return math.hypot(x - self._pos[0], y - self._pos[1])

    # pen
    def penup(self):
        self._end_line()
        self._down = False

    pu = up = penup

    def pendown(self):
        self._down = True

    pd = down = pendown

    def isdown(self):
        return self._down

    def pensize(self, width=None):
        if width is None:
            return self._size
        self._end_line()
        self._size = width

    width = pensize

    def pencolor(self, *args):
        if not args:
            return self._pen
        self._end_line()
        self._pen = _color(args)

    def fillcolor(self, *args):
        if not args:
            return self._fill
        self._fill = _color(args)

    def color(self, *args):
        if not args:
            return self._pen, self._fill
        if len(args) == 2 and not all(isinstance(a, (int, float)) for a in args):
            self.pencolor(args[0])
            self.fillcolor(args[1])
        else:
            self.pencolor(*args)
            self.fillcolor(*args)

    def pen(self, pen=None, **pendict):
        settings = dict(pen or {}, **pendict)
        if "pencolor" in settings:
            self.pencolor(settings["pencolor"])
        if "fillcolor" in settings:
            self.fillcolor(settings["fillcolor"])
        if "pensize" in settings:
            self.pensize(settings["pensize"])
        if settings.get("pendown") is False:
            self.penup()
        elif settings.get("pendown") is True:
            self.pendown()
        return {"pendown": self._down, "pencolor": self._pen, "fillcolor": self._fill, "pensize": self._size}

    def begin_fill(self):
        self._filling = [tuple(self._pos)]

    def end_fill(self):
        if self._filling is not None:
            # the fill goes under the outline drawn so far
            self._end_line()
            self._items.insert(len(self._items) - 1 if self._items else 0, ("fill", (self._filling, self._fill)))
            self._filling = None

    def filling(self):
        return self._filling is not None

    def write(self, arg, move=False, align="left", font=("Arial", 8, "normal")):
        self._items.append(("text", (tuple(self._pos), str(arg), self._pen, align, font)))

    # shape
    def hideturtle(self):
        self._visible = False

    ht = hideturtle

    def showturtle(self):
        self._visible = True

    st = showturtle

    def isvisible(self):
        return self._visible

    def shape(self, name=None):
        return "classic"

    def shapesize(self, *args, **kwargs):
        return (1, 1, 1)

    turtlesize = shapesize

    def getscreen(self):
        return self.screen

    def clone(self):
        other = Turtle()
        other._pos, other._heading, other._pen, other._fill, other._size, other._down = (
            self._pos, self._heading, self._pen, self._fill, self._size, self._down)
        return other

    def onclick(self, fun, btn=1, add=None):
        pass

    onrelease = ondrag = onclick


class Turtle(RawTurtle):
    def __init__(self, shape="classic", undobuffersize=1000, visible=True):
        RawTurtle.__init__(self, None, shape, undobuffersize, visible)


Pen = Turtle
RawPen = RawTurtle

_the_turtle = None


def getturtle():
    global _the_turtle
    if _the_turtle is None:
        _the_turtle = Turtle()
    return _the_turtle


getpen = getturtle


def done():
    _screen().mainloop()


mainloop = done


def exitonclick():
    _screen().exitonclick()


def bye():
    _screen().bye()


def _make(name, owner):
    def function(*args, **kwargs):
        target = getturtle() if owner == "turtle" else _screen()
        return getattr(target, name)(*args, **kwargs)
    function.__name__ = name
    return function


_TURTLE = ["forward", "fd", "backward", "bk", "back", "left", "lt", "right", "rt", "goto", "setpos",
           "setposition", "teleport", "setx", "sety", "setheading", "seth", "home", "circle", "dot", "stamp",
           "clearstamp", "clearstamps", "undo", "speed", "degrees", "radians", "position", "pos", "xcor", "ycor",
           "heading", "towards", "distance", "penup", "pu", "up", "pendown", "pd", "down", "isdown", "pensize",
           "width", "pencolor", "fillcolor", "color", "pen", "begin_fill", "end_fill", "filling", "write",
           "hideturtle", "ht", "showturtle", "st", "isvisible", "shape", "shapesize", "turtlesize", "reset",
           "clear", "onrelease", "ondrag"]
_SCREEN = ["bgcolor", "title", "setup", "screensize", "setworldcoordinates", "colormode", "window_width",
           "window_height", "turtles", "tracer", "delay", "update", "listen", "onkey", "onkeyrelease",
           "onkeypress", "onscreenclick", "ontimer", "register_shape", "addshape", "textinput", "numinput",
           "clearscreen", "resetscreen"]
for _name in _TURTLE:
    globals()[_name] = _make(_name, "turtle")
for _name in _SCREEN:
    globals()[_name] = _make(_name, "screen")
__all__ += _TURTLE + _SCREEN + ["getturtle", "getpen", "RawPen"]
"""#,
        "sitecustomize.py": #"""
# Nyxian: only when Python runs in a Nyxian terminal window, input() uses
# Nyxian's line editor (history, ← →, paste), sys.stdout / sys.stderr write
# straight to the terminal, and Ctrl-\ prints where Python is stuck.
import os

import sys

try:
    # iOS has no Tk: `import turtle` loads Nyxian's turtle, which saves the drawing as PNG
    import importlib.util

    if importlib.util.find_spec("_tkinter") is None:
        class _NyxianTurtleFinder:
            @staticmethod
            def find_spec(name, path=None, target=None):
                if name != "turtle":
                    return None
                return importlib.util.spec_from_file_location(
                    "turtle", os.path.join(os.path.dirname(os.path.abspath(__file__)), "nyxian_turtle.py"))

        sys.meta_path.insert(0, _NyxianTurtleFinder())
except Exception:
    pass

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
    try:
        # webbrowser.open() (Flask, Django, notebooks, your code) opens Nyxian's browser
        import webbrowser

        class _NyxianBrowser(webbrowser.BaseBrowser):
            def open(self, url, new=0, autoraise=True):
                try:
                    sys.stdout.flush()
                except Exception:
                    pass
                os.write(1, ("\x1b]7770;nyxian-open;%s\x07" % url).encode("utf-8"))
                return True

        webbrowser.register("nyxian", _NyxianBrowser, preferred=True)
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
        ForkSigningReport.note("python3", trust_nxt2_sign(launcher.path, launcherEntitlements as CFDictionary, true, nil))
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
            if let path = ForkFastpath.install(launcher.path) { return path }
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
            "org.emexlabs.nyxian.process.spawn": true,    /* Nyxian Shell starts programs (python3, your tools) */
            "org.emexlabs.nyxian.sandbox.file.read": [
                "$(NXROOT)/opt/python",
                /* programs Nyxian Shell starts get python3's file sandbox: node loads
                   opt/node/lib/NodeMobile, java opt/java/lib/libminijvm.dylib and its jars */
                "$(NXROOT)/opt/node",
                "$(NXROOT)/opt/java",
                /* the programs themselves (node, java, …): Nyxian's posix_spawn reads the
                   executable to check its signature, and the program inherits this sandbox */
                "$(NXROOT)/usr/bin"
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
    
    /// The file's modification time as it is on disk now (no cached URL value).
    private static func modificationTime(_ url: URL) -> Double? {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        return Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1_000_000_000
    }
    
    /// site-packages as a whole: its date and what is in it at the top (pip adds or replaces folders there).
    private static func sitePackagesStamp() -> String {
        let fm = FileManager.default
        let items = ((try? fm.contentsOfDirectory(atPath: sitePackages.path)) ?? []).sorted()
        var hasher = Hasher()
        for item in items {
            hasher.combine(item)
            hasher.combine(modificationTime(sitePackages.appendingPathComponent(item)) ?? 0)
        }
        return "\(modificationTime(sitePackages) ?? 0)-\(items.count)-\(hasher.finalize())"
    }
    private static let sitePackagesStampKey = "fork.python.sitePackagesStamp"
    
    /// Binary modules pip put in site-packages since the last run (numpy, Pillow…) get signed, or iOS refuses to load them.
    private static func signNewPackageBinaries(progress: (String) -> Void) throws {
        let defaults = UserDefaults.standard
        /* nothing changed since everything was signed: no need to look at thousands of files */
        let before = sitePackagesStamp()
        if defaults.string(forKey: sitePackagesStampKey) == before { return }
        try signChangedPackageBinaries(progress: progress)
        defaults.set(sitePackagesStamp(), forKey: sitePackagesStampKey)
    }
    
    private static func signChangedPackageBinaries(progress: (String) -> Void) throws {
        let fm = FileManager.default
        var signed = UserDefaults.standard.dictionary(forKey: signedKey) as? [String: Double] ?? [:]
        var pending: [(URL, Double)] = []
        if let enumerator = fm.enumerator(at: sitePackages, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey]) {
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]), values.isRegularFile == true else { continue }
                let ext = url.pathExtension.lowercased()
                guard ext == "so" || ext == "dylib" || url.path.contains(".framework/") else { continue }
                let stamp = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                /* a little slack: dates kept by older versions were rounded differently */
                if let known = signed[url.path], abs(known - stamp) < 0.001 { continue }
                if !isMachO(url) { continue }
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
            /* the signature changes the file: remember its new date, file by file
               (from the file itself — the URL keeps the date it had before signing) */
            signed[entry.0.path] = modificationTime(entry.0) ?? entry.1
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
    
    // MARK: warm-up: Python is prepared once, in the background, when Nyxian opens
    
    private static var warmUpStarted = false
    /// Every window waiting for Python sees the messages of the preparation that runs
    /// (the background one too).
    private static var progressSinks: [UUID: (String) -> Void] = [:]
    private static let progressLock = NSLock()
    
    private static func report(_ message: String) {
        progressLock.lock()
        let sinks = Array(progressSinks.values)
        progressLock.unlock()
        sinks.forEach { $0(message) }
    }
    
    /// Called when the project list first shows: unpacks/signs only if needed (a new Nyxian
    /// version or new packages), so opening Python later starts right away.
    static func warmUp() {
        guard !warmUpStarted, FileManager.default.fileExists(atPath: bundledZip.path) else { return }
        warmUpStarted = true
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            var announced = false
            do {
                _ = try prepare { _ in
                    if !announced {
                        announced = true
                        DispatchQueue.main.async {
                            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Preparing Python in the background (once per Nyxian update)…", withDelay: 0.0)
                        }
                    }
                }
                if announced {
                    DispatchQueue.main.async {
                        NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Python is ready", withDelay: 0.0)
                    }
                }
            } catch {
                NSLog("[ForkPython] background preparation failed: %@", "\(error)")
            }
            /* fork: then Node.js and Java (one signing at a time) */
            ForkNode.warmUp()
            ForkJava.warmUp()
        }
    }
    
    /// Unpacks and signs the runtime when the bundled one changed; returns the launcher to run.
    static func prepare(progress: @escaping (String) -> Void) throws -> String {
        /* the background preparation may be running: show its progress while waiting for it */
        let token = UUID()
        progressLock.lock()
        progressSinks[token] = progress
        progressLock.unlock()
        defer {
            progressLock.lock()
            progressSinks[token] = nil
            progressLock.unlock()
        }
        /* fork: one runtime is signed at a time (Python, Node.js, Java): signing two at once
           could leave Python stuck on "Preparing…" / "Installing…" */
        ForkRuntimeLock.acquire(waiting: { progress("Waiting for Node.js / Java to finish signing…") })
        defer { ForkRuntimeLock.release() }
        return try queue.sync {
            let progress: (String) -> Void = { report($0) }
            let fm = FileManager.default
            guard let attributes = try? fm.attributesOfItem(atPath: bundledZip.path) else { throw Failure.notBundled }
            /* the suffix changes whenever the way Python is signed changes, so devices sign again;
               the runtime is known by its checksum (CI writes it), so a Nyxian update that brings
               the same runtime does not unpack and sign it all again */
            let checksum = (try? String(contentsOf: bundledZip.appendingPathExtension("sha256"), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let identity = (checksum?.count == 64) ? "sha256:\(checksum!)" : "\((attributes[.size] as? NSNumber)?.intValue ?? 0)-\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
            let stamp = "\(identity)-\(signingRevision)"
            let defaults = UserDefaults.standard
            if defaults.string(forKey: stampKey) == stamp,
               let launcher = defaults.string(forKey: launcherKey),
               fm.fileExists(atPath: launcher),
               fm.fileExists(atPath: home.appendingPathComponent("libpython\(version).dylib").path) {
                linkPythonFramework()
                writeHelperFiles()
                try signNewPackageBinaries(progress: progress)
                if defaults.integer(forKey: launcherRevisionKey) != launcherRevision {
                    progress("Signing python3…")
                    let launcherURL = home.appendingPathComponent("bin/python3")
                    guard signLauncher(launcherURL) else { throw Failure.signing("python3") }
                    guard let fresh = fastpath(launcherURL, progress: progress) else { throw Failure.fastpath }
                    defaults.set(launcherRevision, forKey: launcherRevisionKey)
                    defaults.set(fresh, forKey: launcherKey)
                    return fresh
                }
                return launcher
            }
            
            progress("Unpacking Python \(version)…")
            defaults.removeObject(forKey: signedKey)
            defaults.removeObject(forKey: sitePackagesStampKey)
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
                signedNow[url.path] = modificationTime(url) ?? 0
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
            
            progress("Writing Nyxian's Python files…")
            writeHelperFiles()
            /* kept packages are signed again for the new runtime */
            progress("Checking installed packages…")
            try signNewPackageBinaries(progress: progress)
            progress("Installing python3…")
            guard let launcher = fastpath(launcherURL, progress: progress) else { throw Failure.fastpath }
            defaults.set(stamp, forKey: stampKey)
            defaults.set(launcher, forKey: launcherKey)
            defaults.set(launcherRevision, forKey: launcherRevisionKey)
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
            ?? [root.appendingPathComponent("main.js"), root.appendingPathComponent("index.js")].first { FileManager.default.fileExists(atPath: $0.path) }
            ?? ProjectFileIndex.files(in: root).first { ForkNode.isScript($0) }
            ?? [root.appendingPathComponent("Main.java")].first { FileManager.default.fileExists(atPath: $0.path) }
            ?? ProjectFileIndex.files(in: root).first { ForkJava.isSource($0) }
        guard let script else {
            presenter.forkGitHubAlert("Python", "This project has no .py or .js file yet. Make one with New › File (name.py or name.js).")
            return
        }
        if ForkNode.isScript(script) {
            ForkNode.run(script: script, project: project, from: presenter)
            return
        }
        if ForkJava.isSource(script) {
            ForkJava.run(script: script, project: project, from: presenter)
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
        let skippedFolders: Set<String> = ["Config", ".build", "build", "Previews", "__pycache__", ".git", "DerivedData"]
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
            /* fork: Nyxian Shell shows it when a program cannot start */
            "NYXIAN_SIGNING_REPORT": ForkSigningReport.file.path,
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
        /* fork: node, npm and npx in Nyxian Shell (and commands npm install -g puts in .node/bin) */
        /* fork: java, javac (miniJVM) in Nyxian Shell */
        if let java = ForkJava.readyLauncher() {
            environment.merge(ForkJava.environment(launcher: java)) { old, _ in old }
        }
        if let node = ForkNode.readyLauncher() {
            environment.merge(ForkNode.environment(launcher: node)) { old, _ in old }
            environment["PATH"] = ForkNode.globalPrefix.appendingPathComponent("bin").path + ":" + (environment["PATH"] ?? "")
        }
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
        let hidden = ForkHiddenFlag()
        progress.addAction(UIAlertAction(title: "Hide (keeps preparing)", style: .cancel) { _ in hidden.value = true })
        let host = host(for: presenter)
        host.present(progress, animated: true)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let launcher = try prepare { message in
                    DispatchQueue.main.async { progress.message = message }
                }
                if hidden.value {
                    /* the window was hidden: say it is ready instead of opening a terminal later by surprise */
                    DispatchQueue.main.async { NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Python is ready: open it again", withDelay: 0.0) }
                    return
                }
                DispatchQueue.global(qos: .utility).async { ForkSigningReport.write() }
                UserDefaults.standard.set(ForkPython.home.path, forKey: "fork.python.home")
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
            /* npm's packages stay in the run folder (thousands of files; package.json comes back) */
            if url.lastPathComponent == "__pycache__" || url.lastPathComponent == "node_modules" { enumerator.skipDescendants(); continue }
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
    
    /// Nyxian Shell (nyxian_shell): ls, cd, grep, pipes, redirection, programs and job control.
    /// In a project: its run folder (a copy of the project); new files come back when it closes.
    static func openShell(from presenter: UIViewController, project: NXProject? = nil, script: URL? = nil, folder: URL? = nil) {
        if let folder {
            launch(from: presenter, arguments: ["-q", "-m", "nyxian_shell"], workingDirectory: folder, title: "Shell · \(folder.lastPathComponent)", closeOnExit: true)
            return
        }
        let root: URL? = project.map { $0.url as URL } ?? script?.deletingLastPathComponent()
        if let root {
            let openTexts = LiveEditorRegistry.openTexts()
            let runFolder = mirrorFolder(project: root)
            presenter.view.window?.endEditing(true)
            launch(from: presenter, arguments: ["-q", "-m", "nyxian_shell"], workingDirectory: runFolder, title: "Shell · \(root.lastPathComponent)", closeOnExit: true,
                   extraEnvironment: ["HOME": runFolder.path], beforeLaunch: {
                _ = try mirror(project: root, openTexts: openTexts)
            }, onExit: { _ in
                _ = copyOutput(project: root)
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil) }
                return nil
            })
            return
        }
        let folder = rootfs.appendingPathComponent("var/mobile")
        launch(from: presenter, arguments: ["-q", "-m", "nyxian_shell"], workingDirectory: folder, title: "Shell", closeOnExit: true)
    }
    
    /// Shows the code of every key Python receives (for keys that seem to do nothing).
    static func openKeyboardTest(from presenter: UIViewController) {
        let folder = rootfs.appendingPathComponent("var/mobile/Python")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        launch(from: presenter, arguments: ["-q", "-m", "nyxian_keytest"], workingDirectory: folder, title: "Python Keyboard Test", closeOnExit: true)
    }
    
    /// Runs a .py file from a copy of its project (or of its folder).
    // MARK: arguments of a script (remembered per file)
    
    private static func argumentsKey(_ script: URL) -> String { "fork.python.args." + script.resolvingSymlinksInPath().path }
    
    static func savedArguments(for script: URL) -> String {
        UserDefaults.standard.string(forKey: argumentsKey(script)) ?? ""
    }
    
    /// Shell-like split: spaces separate, quotes keep spaces, backslash escapes.
    static func splitArguments(_ text: String) -> [String] {
        var result: [String] = [], current = "", quote: Character? = nil, escaped = false, started = false
        for character in text {
            if escaped { current.append(character); escaped = false; started = true; continue }
            if character == "\\" && quote != "'" { escaped = true; continue }
            if let open = quote {
                if character == open { quote = nil } else { current.append(character) }
                continue
            }
            if character == "\"" || character == "'" { quote = character; started = true; continue }
            if character == " " || character == "\t" {
                if started { result.append(current); current = ""; started = false }
                continue
            }
            current.append(character)
            started = true
        }
        if started { result.append(current) }
        return result
    }
    
    /// ⌥⌘R: asks for the arguments (and offers the project's files), remembers them and runs.
    static func promptArguments(script: URL, project: NXProject?, from presenter: UIViewController, initial: String? = nil) {
        let alert = UIAlertController(title: "Run \(script.lastPathComponent) with Arguments", message: "As in a shell: spaces separate, quotes keep spaces. The script runs in a copy of the project, so files of the project can be named by their path. Remembered for this file.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = initial ?? savedArguments(for: script)
            field.placeholder = "--size 10 data/input.csv"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add a File of the Project…", style: .default) { [weak alert] _ in
            let typed = alert?.textFields?.first?.text ?? ""
            let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
            let files = ProjectFileIndex.files(in: root).filter { !["py", "js", "mjs", "cjs", "java"].contains($0.pathExtension.lowercased()) && !$0.path.contains("/Config/") }.prefix(40)
            let sheet = UIAlertController(title: "File of the Project", message: files.isEmpty ? "No data files in this project yet." : nil, preferredStyle: .actionSheet)
            for file in files {
                let relative = ProjectFileIndex.relativePath(file, root: root)
                sheet.addAction(UIAlertAction(title: relative, style: .default) { _ in
                    let quoted = relative.contains(" ") ? "\"\(relative)\"" : relative
                    promptArguments(script: script, project: project, from: presenter, initial: typed.isEmpty ? quoted : typed + " " + quoted)
                })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                promptArguments(script: script, project: project, from: presenter, initial: typed)
            })
            sheet.popoverPresentationController?.sourceView = presenter.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
            presenter.present(sheet, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Run", style: .default) { [weak alert] _ in
            let text = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespaces)
            UserDefaults.standard.set(text, forKey: argumentsKey(script))
            if ForkNode.isScript(script) {
                ForkNode.run(script: script, project: project, from: presenter)
            } else if ForkJava.isSource(script) {
                ForkJava.run(script: script, project: project, from: presenter)
            } else {
                run(script: script, project: project, from: presenter)
            }
        })
        presenter.present(alert, animated: true)
    }
    
    // MARK: tests
    
    /// ⌘U: pytest (or unittest) on this file when it is a test file, else on the whole project.
    static func runTests(for script: URL?, project: NXProject?, from presenter: UIViewController) {
        presenter.view.window?.endEditing(true)
        guard let root: URL = project.map({ $0.url as URL }) ?? script?.deletingLastPathComponent() else { return }
        let runFolder = mirrorFolder(project: root)
        let resultFile = runFolder.appendingPathComponent(".nyxian-tests.json")
        var target = "."
        if let script {
            let name = script.deletingPathExtension().lastPathComponent
            if name.hasPrefix("test_") || name.hasSuffix("_test") { target = ProjectFileIndex.relativePath(script, root: root) }
        }
        let openTexts = LiveEditorRegistry.openTexts()
        ForkPythonIssues.clearRuntime(under: root)
        launch(from: presenter, arguments: ["-m", "nyxian_tests", target], workingDirectory: runFolder, title: "Tests · \(target == "." ? root.lastPathComponent : URL(fileURLWithPath: target).lastPathComponent)", extraEnvironment: ["NYXIAN_TEST_FILE": resultFile.path], beforeLaunch: {
            _ = try mirror(project: root, openTexts: openTexts)
            try? FileManager.default.removeItem(at: resultFile)
        }, onExit: { _ in
            guard let data = try? Data(contentsOf: resultFile),
                  let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "[no test results — is there a test_*.py?]" }
            let failures = result["failures"] as? [[String: Any]] ?? []
            for failure in failures {
                guard let file = failure["file"] as? String, let line = failure["line"] as? Int else { continue }
                let source = root.appendingPathComponent(ProjectFileIndex.relativePath(URL(fileURLWithPath: file), root: runFolder))
                ForkPythonIssues.addRuntime(file: source, line: line, message: "test failed: " + (failure["message"] as? String ?? (failure["test"] as? String ?? "")))
            }
            let passed = result["passed"] as? Int ?? 0, failed = result["failed"] as? Int ?? failures.count
            DispatchQueue.main.async {
                NXAlertDiagnosticPresenter.notifyUser(with: failed == 0 ? .note : .error, withMessage: failed == 0 ? "Tests passed: \(passed)" : "\(failed) test\(failed == 1 ? "" : "s") failed, \(passed) passed — lines marked in the editor", withDelay: 0.0)
            }
            return failed == 0 ? "[\(passed) passed]" : "[\(failed) failed · \(passed) passed — the failing lines are marked in the editor]"
        })
    }
    
    static func run(script: URL, project: NXProject?, from presenter: UIViewController) {
        /* the editor's keyboard goes away before the terminal takes over */
        presenter.view.window?.endEditing(true)
        let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
        let relative = ProjectFileIndex.relativePath(script, root: root)
        let openTexts = LiveEditorRegistry.openTexts()
        let runFolder = mirrorFolder(project: root)
        let errorFile = runFolder.appendingPathComponent(".nyxian-error.json")
        ForkPythonIssues.clearRuntime(under: root)
        let scriptArguments = splitArguments(savedArguments(for: script))
        let title = "python3 \(script.lastPathComponent)" + (scriptArguments.isEmpty ? "" : " " + scriptArguments.joined(separator: " "))
        launch(from: presenter, arguments: [relative] + scriptArguments, workingDirectory: runFolder, title: title, extraEnvironment: ["NYXIAN_ERROR_FILE": errorFile.path], beforeLaunch: {
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
    
    // MARK: debugger
    
    /// Where the Python debugger stopped, as a file of the project (the editor tints that line green).
    static var debugStop: (file: URL, line: Int)?
    private static var debugTimer: Timer?
    private static var debugStamp: Date?
    
    /// ⌥⌘D: runs the script under nyxian_pdb, stopping at the project's breakpoints in .py files.
    static func debug(script: URL, project: NXProject?, from presenter: UIViewController) {
        presenter.view.window?.endEditing(true)
        let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
        let relative = ProjectFileIndex.relativePath(script, root: root)
        let openTexts = LiveEditorRegistry.openTexts()
        let runFolder = mirrorFolder(project: root)
        let stateFile = runFolder.appendingPathComponent(".nyxian-debug.json")
        var breakpoints: [[String: Any]] = []
        if let project {
            for item in ForkBreakpoints.all(project: project) {
                guard let path = item["path"] as? String, let line = item["line"] as? Int, path.lowercased().hasSuffix(".py") else { continue }
                breakpoints.append(["file": ProjectFileIndex.relativePath(URL(fileURLWithPath: path), root: root), "line": line])
            }
        }
        let json = (try? JSONSerialization.data(withJSONObject: breakpoints)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let scriptArguments = splitArguments(savedArguments(for: script))
        ForkPythonIssues.clearRuntime(under: root)
        launch(from: presenter, arguments: ["-m", "nyxian_pdb", relative] + scriptArguments, workingDirectory: runFolder,
               title: "Debug · \(script.lastPathComponent)",
               extraEnvironment: ["NYXIAN_BREAKPOINTS": json, "NYXIAN_DEBUG_STATE": stateFile.path, "NYXIAN_VARS_FILE": variablesFile(project: root).path],
               beforeLaunch: {
            _ = try mirror(project: root, openTexts: openTexts)
            try? FileManager.default.removeItem(at: stateFile)
            DispatchQueue.main.async { followDebugger(state: stateFile, runFolder: runFolder, root: root) }
        }, onExit: { _ in
            DispatchQueue.main.async { stopFollowingDebugger() }
            _ = copyOutput(project: root)
            return nil
        })
    }
    
    private static func followDebugger(state: URL, runFolder: URL, root: URL) {
        debugTimer?.invalidate()
        debugStamp = nil
        debugTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            let date = (try? state.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let date, date != debugStamp else { return }
            debugStamp = date
            guard let data = try? Data(contentsOf: state),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            var stop: (file: URL, line: Int)?
            if info["running"] as? Bool == false, let file = info["file"] as? String, let line = info["line"] as? Int {
                let path = URL(fileURLWithPath: file).resolvingSymlinksInPath().path
                let folder = runFolder.resolvingSymlinksInPath().path
                if path.hasPrefix(folder + "/") {
                    stop = (root.appendingPathComponent(String(path.dropFirst(folder.count + 1))), line)
                }
            }
            debugStop = stop
            NotificationCenter.default.post(name: ForkDebugSession.stopped, object: nil)
        }
    }
    
    private static func stopFollowingDebugger() {
        debugTimer?.invalidate()
        debugTimer = nil
        debugStop = nil
        NotificationCenter.default.post(name: ForkDebugSession.stopped, object: nil)
    }
    
    /// Where the project's cell console writes its variables (the inspector reads it).
    static func variablesFile(project root: URL) -> URL {
        mirrorFolder(project: root).appendingPathComponent(".nyxian-vars.json")
    }
    
    /// Where the project's cell console writes each cell's output and figures (Cell Outputs reads it).
    static func cellsFile(project root: URL) -> URL {
        mirrorFolder(project: root).appendingPathComponent(".nyxian-cells.json")
    }
    
    /// While Cell Outputs is open the results show there: the console window stays behind.
    static var cellOutputsVisible = false
    
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
                        if !cellOutputsVisible { console.forkBringToFront() }
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
        launch(from: presenter, arguments: ["-q", "-m", "nyxian_repl", "--cell", cellFile.path], workingDirectory: runFolder, title: "Cells · \(script.lastPathComponent)", closeOnExit: true, extraEnvironment: ["NYXIAN_VARS_FILE": variablesFile(project: root).path, "NYXIAN_CELLS_FILE": cellsFile(project: root).path], beforeLaunch: {
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

// MARK: - fork: Node.js (nodejs-mobile, no JIT) — node, npm, .js files

/// Node.js for iOS (Shared/node-ios.zip: nodejs-mobile's library, npm, the
/// `node` launcher), unpacked into opt/node and signed once, like Python.
/// V8 runs without JIT (nodejs-mobile's standard iOS build).
/// fork: installs a launcher in usr/bin through Nyxian's service, but never waits more than
/// `timeout` seconds: a call that does not come back (Python stayed on "Installing python3…"
/// until Nyxian was closed) counts as a failed attempt, so the caller retries or reports it.
enum ForkFastpath {
    static func install(_ path: String, timeout: TimeInterval = 12) -> String? {
        final class Box { var path: String? }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            box.path = LDEApplicationWorkspace.shared().fastpathUtility(path)
            done.signal()
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            NSLog("[Fork] installing %@ did not answer in %.0f s", path, timeout)
            return nil
        }
        return box.path
    }
}

/// fork: set when the person hides a "Preparing…" window (the work goes on).
final class ForkHiddenFlag { var value = false }

/// fork: Python, Node.js and Java are unpacked and signed one at a time (the signer is
/// not made for two at once). Recursive, so a preparation may start another.
enum ForkRuntimeLock {
    private static let lock = NSRecursiveLock()

    static func acquire(waiting: () -> Void) {
        if lock.try() { return }
        waiting()
        lock.lock()
    }

    static func release() { lock.unlock() }
}

/// fork: how Nyxian sees the launchers' signatures (NXT2 blob, identity, may start
/// programs), written next to the runtimes; Nyxian Shell shows it when a program
/// cannot start.
enum ForkSigningReport {
    private static let resultsKey = "fork.signing.results"
    static var file: URL { ForkPython.home.appendingPathComponent(".nyxian-signing.txt") }  /* python3 may read opt/python */

    /// The result of signing a launcher's NXT2 entitlements (KERN_SUCCESS is 0).
    static func note(_ name: String, _ result: kern_return_t) {
        var results = UserDefaults.standard.dictionary(forKey: resultsKey) as? [String: Int] ?? [:]
        results[name] = Int(result)
        UserDefaults.standard.set(results, forKey: resultsKey)
    }

    static func write() {
        let defaults = UserDefaults.standard
        var paths: [String] = []
        for key in ["fork.python.launcher", "fork.node.launcher", "fork.java.launcher"] {
            if let path = defaults.string(forKey: key) { paths.append(path) }
        }
        paths.append(ForkPython.home.appendingPathComponent("bin/python3").path)
        let results = (defaults.dictionary(forKey: resultsKey) as? [String: Int] ?? [:])
            .sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let text = "Nyxian \(version) — last NXT2 signing (0 = ok): \(results.isEmpty ? "-" : results)\n"
            + ((PEForkSigningReport(paths) as String?) ?? "")
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }
}

enum ForkNode {
    static let version = "18.20.4"

    enum Failure: LocalizedError {
        case notBundled, signing(String), fastpath
        var errorDescription: String? {
            switch self {
            case .notBundled: return "This build of Nyxian has no Node.js runtime (Shared/node-ios.zip)."
            case .signing(let file): return "Could not sign \(file). Check that signing is set up (Settings > Certificate)."
            case .fastpath: return "Nyxian could not install the node launcher."
            }
        }
    }

    static var rootfs: URL { NXBootstrap.shared().rootfsURL }
    static var home: URL { rootfs.appendingPathComponent("opt/node") }
    static var userHome: URL { rootfs.appendingPathComponent("var/mobile") }
    /// npm install -g goes here (lib/node_modules, bin), where Node and Nyxian Shell may write.
    static var globalPrefix: URL { userHome.appendingPathComponent(".node") }
    static var globalModules: URL { globalPrefix.appendingPathComponent("lib/node_modules") }
    static var npmCLI: URL { home.appendingPathComponent("lib/node_modules/npm/bin/npm-cli.js") }
    private static var bundledZip: URL { Bundle.main.bundleURL.appendingPathComponent("Shared/node-ios.zip") }
    private static let stampKey = "fork.node.stamp"
    private static let launcherKey = "fork.node.launcher"
    private static let signingRevision = 1
    private static let queue = DispatchQueue(label: "fork.node.install")

    static var isBundled: Bool { FileManager.default.fileExists(atPath: bundledZip.path) }

    /// What the node process may touch (NXT2 entitlements, file-system sandbox on).
    private static var launcherEntitlements: [String: Any] {
        [
            "org.emexlabs.nyxian.get-task-allow": true,
            "org.emexlabs.nyxian.process.spawn": true,
            "org.emexlabs.nyxian.sandbox.file.read": [
                "$(NXROOT)/opt/node"
            ],
            "org.emexlabs.nyxian.sandbox.file.read-write": [
                "$(NXROOT)/var/mobile"   /* home, projects' run folders, npm's cache and global packages */
            ]
        ]
    }

    private static var launcherURL: URL { home.appendingPathComponent("bin/node") }
    private static var launcherOriginal: URL { home.appendingPathComponent("bin/.node.original") }

    private static func signLauncher() -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: launcherOriginal.path) {
            try? fm.removeItem(at: launcherURL)
            guard (try? fm.copyItem(at: launcherOriginal, to: launcherURL)) != nil else { return false }
        }
        guard LCUtils.signMachO(at: launcherURL) else { return false }
        ForkSigningReport.note(launcherURL.lastPathComponent, trust_nxt2_sign(launcherURL.path, launcherEntitlements as CFDictionary, true, nil))
        return true
    }

    private static func fastpath(progress: (String) -> Void) -> String? {
        for attempt in 1...6 {
            if let path = ForkFastpath.install(launcherURL.path) { return path }
            progress("Installing node… (attempt \(attempt + 1))")
            Thread.sleep(forTimeInterval: 0.5)
            _ = signLauncher()
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    private static var identity: String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: bundledZip.path) else { return nil }
        let checksum = (try? String(contentsOf: bundledZip.appendingPathExtension("sha256"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (checksum?.count == 64) ? "sha256:\(checksum!)" : "\((attributes[.size] as? NSNumber)?.intValue ?? 0)-\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
        return "\(base)-\(signingRevision)"
    }

    /// The signed launcher when Node.js is ready without unpacking or signing anything.
    static func readyLauncher() -> String? {
        let defaults = UserDefaults.standard
        guard let stamp = defaults.string(forKey: stampKey), stamp == identity,
              let launcher = defaults.string(forKey: launcherKey),
              FileManager.default.fileExists(atPath: launcher),
              FileManager.default.fileExists(atPath: home.appendingPathComponent("lib/NodeMobile").path) else { return nil }
        return launcher
    }

    /// Unpacks and signs Node.js when the bundled one changed; returns the launcher to run.
    static func prepare(progress: @escaping (String) -> Void) throws -> String {
        ForkRuntimeLock.acquire(waiting: { progress("Waiting for another runtime to finish signing…") })
        defer { ForkRuntimeLock.release() }
        return try queue.sync {
            if let ready = readyLauncher() { return ready }
            guard let stamp = identity else { throw Failure.notBundled }
            let fm = FileManager.default
            progress("Unpacking Node.js \(version)…")
            try? fm.removeItem(at: home)
            let opt = home.deletingLastPathComponent()
            try fm.createDirectory(at: opt, withIntermediateDirectories: true)
            guard unzipArchiveAtPath(bundledZip.path, opt.path) else { throw Failure.notBundled }
            progress("Signing Node.js…")
            let library = home.appendingPathComponent("lib/NodeMobile")
            guard LCUtils.signMachOWithoutPatch(at: library) else { throw Failure.signing("NodeMobile") }
            _ = trust_nxt2_sign(library.path, [String: Any]() as CFDictionary, true, nil)
            progress("Signing node…")
            try? fm.removeItem(at: launcherOriginal)
            try? fm.copyItem(at: launcherURL, to: launcherOriginal)
            guard signLauncher() else { throw Failure.signing("node") }
            try? fm.createDirectory(at: globalModules, withIntermediateDirectories: true)
            try? fm.createDirectory(at: globalPrefix.appendingPathComponent("bin"), withIntermediateDirectories: true)
            guard let launcher = fastpath(progress: progress) else { throw Failure.fastpath }
            UserDefaults.standard.set(stamp, forKey: stampKey)
            UserDefaults.standard.set(launcher, forKey: launcherKey)
            return launcher
        }
    }

    /// After Python's background preparation: Node.js too, once per Nyxian update.
    static func warmUp() {
        guard isBundled, readyLauncher() == nil else { return }
        do {
            var announced = false
            _ = try prepare { _ in
                if !announced {
                    announced = true
                    DispatchQueue.main.async {
                        NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Preparing Node.js in the background (once per Nyxian update)…", withDelay: 0.0)
                    }
                }
            }
            DispatchQueue.main.async {
                NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Node.js is ready: node, npm", withDelay: 0.0)
            }
        } catch {
            NSLog("[ForkNode] background preparation failed: %@", "\(error)")
        }
    }

    /// What node, npm and Nyxian Shell need to find Node.js and its packages.
    static func environment(launcher: String) -> [String: String] {
        let tmp = userHome.appendingPathComponent("tmp")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return [
            "NYXIAN_NODE": launcher,
            "NYXIAN_NODE_HOME": home.path,
            /* require() finds packages installed with npm install -g */
            "NODE_PATH": globalModules.path,
            "NODE_REPL_HISTORY": userHome.appendingPathComponent(".node_repl_history").path,
            "npm_config_prefix": globalPrefix.path,
            "npm_config_cache": userHome.appendingPathComponent(".npm").path,
            /* iOS lets Node start no processes of its own: install scripts can not run */
            "npm_config_ignore_scripts": "true",
            "npm_config_update_notifier": "false",
            "npm_config_fund": "false",
            "npm_config_audit": "false",
            "npm_config_progress": "false",
            "TMPDIR": tmp.path,
        ]
    }

    static func launch(from presenter: UIViewController, arguments: [String], workingDirectory: URL?, title: String, closeOnExit: Bool = false, beforeLaunch: (() throws -> Void)? = nil, onExit: ((Int32) -> String?)? = nil) {
        let progress = UIAlertController(title: "Node.js \(version)", message: "Preparing…", preferredStyle: .alert)
        let hidden = ForkHiddenFlag()
        progress.addAction(UIAlertAction(title: "Hide (keeps preparing)", style: .cancel) { _ in hidden.value = true })
        var host: UIViewController = presenter.viewIfLoaded?.window != nil ? presenter : (presenter.view.window?.rootViewController ?? presenter)
        while let shown = host.presentedViewController, !shown.isBeingDismissed, !(shown is UIAlertController) { host = shown }
        host.present(progress, animated: true)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let launcher = try prepare { message in
                    DispatchQueue.main.async { progress.message = message }
                }
                if hidden.value {
                    DispatchQueue.main.async { NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Node.js is ready: open it again", withDelay: 0.0) }
                    return
                }
                DispatchQueue.global(qos: .utility).async { ForkSigningReport.write() }
                UserDefaults.standard.set(ForkPython.home.path, forKey: "fork.python.home")
                if let beforeLaunch {
                    DispatchQueue.main.async { progress.message = "Copying the project…" }
                    try beforeLaunch()
                }
                DispatchQueue.main.async {
                    progress.dismiss(animated: true) {
                        guard let session = NXWindowSessionTerminal(utilityPath: launcher) else { return }
                        session.arguments = [launcher] + arguments
                        var environment = ForkPython.baseEnvironment(workingDirectory: nil)
                        environment.merge(self.environment(launcher: launcher)) { _, new in new }
                        environment["NYXIAN_TERMINAL"] = "1"
                        environment["HOME"] = userHome.path
                        session.extraEnvironment = environment
                        session.workingDirectory = (workingDirectory ?? userHome).path
                        session.title = title
                        session.closeOnExit = closeOnExit
                        session.fontSize = CGFloat(ForkPython.fontSize)
                        session.fontSizeDefaultsKey = ForkPython.fontSizeKey
                        if let onExit { session.exitHandler = { code in onExit(code) } }
                        NXWindowServer.shared().openWindow(with: session, withCompletion: nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    progress.dismiss(animated: true) {
                        host.forkGitHubAlert("Node.js", error.localizedDescription)
                    }
                }
            }
        }
    }

    static func isScript(_ url: URL) -> Bool { ["js", "mjs", "cjs"].contains(url.pathExtension.lowercased()) }

    /// ▶ on a .js file: node runs it from a copy of its project (files it makes come back).
    static func run(script: URL, project: NXProject?, from presenter: UIViewController) {
        presenter.view.window?.endEditing(true)
        let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
        let relative = ProjectFileIndex.relativePath(script, root: root)
        let openTexts = LiveEditorRegistry.openTexts()
        let runFolder = ForkPython.mirrorFolder(project: root)
        let scriptArguments = ForkPython.splitArguments(ForkPython.savedArguments(for: script))
        let title = "node \(script.lastPathComponent)" + (scriptArguments.isEmpty ? "" : " " + scriptArguments.joined(separator: " "))
        launch(from: presenter, arguments: [relative] + scriptArguments, workingDirectory: runFolder, title: title, beforeLaunch: {
            _ = try ForkPython.mirror(project: root, openTexts: openTexts)
        }, onExit: { _ in
            let copied = ForkPython.copyOutput(project: root)
            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil) }
            guard !copied.isEmpty else { return nil }
            let list = copied.prefix(10).joined(separator: ", ") + (copied.count > 10 ? " … (+\(copied.count - 10))" : "")
            return "[copied to the project: \(list)]"
        })
    }

    /// The Node.js REPL (.help, .editor, Tab completion).
    static func openConsole(from presenter: UIViewController) {
        launch(from: presenter, arguments: [], workingDirectory: userHome, title: "Node.js \(version)", closeOnExit: true)
    }

    /// npm install -g NAME…: require() finds them from any script.
    static func promptInstallPackage(from presenter: UIViewController) {
        let alert = UIAlertController(title: "Install Package (npm)", message: "Package names, separated by spaces. Pure JavaScript packages work; ones that compile native code (.node) or need install scripts do not.", preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "lodash dayjs chalk@4"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Install", style: .default) { [weak alert] _ in
            let names = (alert?.textFields?.first?.text ?? "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
            guard !names.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                launch(from: presenter, arguments: [npmCLI.path, "install", "-g"] + names, workingDirectory: userHome, title: "npm install")
            }
        })
        presenter.present(alert, animated: true)
    }

    /// npm ls -g: what is installed globally.
    static func listPackages(from presenter: UIViewController) {
        launch(from: presenter, arguments: [npmCLI.path, "ls", "-g", "--depth=0"], workingDirectory: userHome, title: "npm ls -g")
    }

    static func reinstall(from presenter: UIViewController) {
        UserDefaults.standard.removeObject(forKey: stampKey)
        launch(from: presenter, arguments: ["-e", "console.log('Node.js', process.version, '· V8', process.versions.v8, '· npm in', process.env.NYXIAN_NODE_HOME)"], workingDirectory: userHome, title: "Node.js")
    }
}

// MARK: - fork: Java (miniJVM, an interpreter) — java, javac, jar, .java files

/// Java for iOS (Shared/java-ios.zip: miniJVM, its class library — a Java 8
/// subset — and the janino compiler), unpacked into opt/java and signed once.
enum ForkJava {
    static let name = "miniJVM"

    enum Failure: LocalizedError {
        case notBundled, server
        var errorDescription: String? {
            switch self {
            case .notBundled: return "This build of Nyxian has no Java runtime (Shared/java-ios.zip)."
            case .server: return "Could not open a local port for CheerpJ."
            }
        }
    }

    static var rootfs: URL { NXBootstrap.shared().rootfsURL }
    static var home: URL { rootfs.appendingPathComponent("opt/java") }
    static var userHome: URL { rootfs.appendingPathComponent("var/mobile") }
    private static var bundledZip: URL { Bundle.main.bundleURL.appendingPathComponent("Shared/java-ios.zip") }
    private static let stampKey = "fork.java.stamp"
    private static let launcherKey = "fork.java.launcher"
    private static let signingRevision = 2  /* 2: miniJVM is lib/libminijvm.dylib, bin/java only loads it */
    private static let queue = DispatchQueue(label: "fork.java.install")

    static var isBundled: Bool { FileManager.default.fileExists(atPath: bundledZip.path) }

    private static var launcherEntitlements: [String: Any] {
        [
            "org.emexlabs.nyxian.get-task-allow": true,
            "org.emexlabs.nyxian.sandbox.file.read": [
                "$(NXROOT)/opt/java"
            ],
            "org.emexlabs.nyxian.sandbox.file.read-write": [
                "$(NXROOT)/var/mobile"   /* home, projects' run folders */
            ]
        ]
    }

    private static var launcherURL: URL { home.appendingPathComponent("bin/java") }
    private static var launcherOriginal: URL { home.appendingPathComponent("bin/.java.original") }
    /// miniJVM itself: the small `java` launcher loads it (like `node` loads NodeMobile).
    private static var library: URL { home.appendingPathComponent("lib/libminijvm.dylib") }

    private static func signLauncher() -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: launcherOriginal.path) {
            try? fm.removeItem(at: launcherURL)
            guard (try? fm.copyItem(at: launcherOriginal, to: launcherURL)) != nil else { return false }
        }
        guard LCUtils.signMachO(at: launcherURL) else { return false }
        ForkSigningReport.note(launcherURL.lastPathComponent, trust_nxt2_sign(launcherURL.path, launcherEntitlements as CFDictionary, true, nil))
        return true
    }

    private static var identity: String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: bundledZip.path) else { return nil }
        let checksum = (try? String(contentsOf: bundledZip.appendingPathExtension("sha256"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (checksum?.count == 64) ? "sha256:\(checksum!)" : "\((attributes[.size] as? NSNumber)?.intValue ?? 0)-\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
        return "\(base)-\(signingRevision)"
    }

    static func readyLauncher() -> String? {
        let defaults = UserDefaults.standard
        guard let stamp = defaults.string(forKey: stampKey), stamp == identity,
              let launcher = defaults.string(forKey: launcherKey),
              FileManager.default.fileExists(atPath: launcher),
              FileManager.default.fileExists(atPath: home.appendingPathComponent("lib/minijvm_rt.jar").path),
              FileManager.default.fileExists(atPath: library.path) else { return nil }
        return launcher
    }

    static func prepare(progress: @escaping (String) -> Void) throws -> String {
        ForkRuntimeLock.acquire(waiting: { progress("Waiting for another runtime to finish signing…") })
        defer { ForkRuntimeLock.release() }
        return try queue.sync {
            if let ready = readyLauncher() { return ready }
            guard let stamp = identity else { throw Failure.notBundled }
            let fm = FileManager.default
            progress("Unpacking Java (\(name))…")
            try? fm.removeItem(at: home)
            let opt = home.deletingLastPathComponent()
            try fm.createDirectory(at: opt, withIntermediateDirectories: true)
            guard unzipArchiveAtPath(bundledZip.path, opt.path) else { throw Failure.notBundled }
            progress("Signing miniJVM…")
            guard fm.fileExists(atPath: library.path), LCUtils.signMachOWithoutPatch(at: library) else { throw ForkNode.Failure.signing("libminijvm.dylib") }
            _ = trust_nxt2_sign(library.path, [String: Any]() as CFDictionary, true, nil)
            progress("Signing java…")
            try? fm.removeItem(at: launcherOriginal)
            try? fm.copyItem(at: launcherURL, to: launcherOriginal)
            guard signLauncher() else { throw ForkNode.Failure.signing("java") }
            var found: String?
            for _ in 1...6 {
                found = ForkFastpath.install(launcherURL.path)
                if found != nil { break }
                Thread.sleep(forTimeInterval: 0.5)
                _ = signLauncher()
                Thread.sleep(forTimeInterval: 0.5)
            }
            guard let launcher = found else { throw ForkNode.Failure.fastpath }
            UserDefaults.standard.set(stamp, forKey: stampKey)
            UserDefaults.standard.set(launcher, forKey: launcherKey)
            return launcher
        }
    }

    /// After Node.js's background preparation.
    static func warmUp() {
        guard isBundled, readyLauncher() == nil else { return }
        do {
            _ = try prepare { _ in }
            DispatchQueue.main.async {
                NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Java is ready: java, javac, jar", withDelay: 0.0)
            }
        } catch {
            NSLog("[ForkJava] background preparation failed: %@", "\(error)")
        }
    }

    static func environment(launcher: String) -> [String: String] {
        let tmp = userHome.appendingPathComponent("tmp")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return [
            "NYXIAN_JAVA": launcher,
            "NYXIAN_JAVA_HOME": home.path,
            "TMPDIR": tmp.path,   /* java FILE.java compiles there */
            /* miniJVM's allocator: iOS refuses its 1 GiB reservations (it then warns and falls back) */
            "MIMALLOC_ARENA_RESERVE": "64MiB",
            "MIMALLOC_SHOW_ERRORS": "0",
        ]
    }

    static func isSource(_ url: URL) -> Bool { url.pathExtension.lowercased() == "java" }

    /// Runs `command` in Nyxian Shell (java needs the shell: -jar, FILE.java) from a copy of the project.
    static func runInShell(_ command: String, title: String, project root: URL, from presenter: UIViewController) {
        let openTexts = LiveEditorRegistry.openTexts()
        let runFolder = ForkPython.mirrorFolder(project: root)
        DispatchQueue.global(qos: .userInitiated).async {
            /* Java is prepared on first use when the background preparation has not finished */
            if readyLauncher() == nil, isBundled { _ = try? prepare { _ in } }
            DispatchQueue.main.async {
                ForkPython.launch(from: presenter, arguments: ["-m", "nyxian_shell", "-c", command], workingDirectory: runFolder, title: title, beforeLaunch: {
                    _ = try ForkPython.mirror(project: root, openTexts: openTexts)
                }, onExit: { _ in
                    let copied = ForkPython.copyOutput(project: root)
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil) }
                    guard !copied.isEmpty else { return nil }
                    let list = copied.prefix(10).joined(separator: ", ") + (copied.count > 10 ? " … (+\(copied.count - 10))" : "")
                    return "[copied to the project: \(list)]"
                })
            }
        }
    }

    static func quote(_ text: String) -> String {
        let plain = text.allSatisfy { $0.isLetter || $0.isNumber || "-_./:=+@%,".contains($0) }
        return plain && !text.isEmpty ? text : "'" + text.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    /// ▶ on a .java file: java FILE.java (compiled with janino, run with miniJVM).
    static func run(script: URL, project: NXProject?, from presenter: UIViewController) {
        presenter.view.window?.endEditing(true)
        let root: URL = project.map { $0.url as URL } ?? script.deletingLastPathComponent()
        let relative = ProjectFileIndex.relativePath(script, root: root)
        let arguments = ForkPython.splitArguments(ForkPython.savedArguments(for: script))
        let command = (["java", relative] + arguments).map(quote).joined(separator: " ")
        runInShell(command, title: "java \(script.lastPathComponent)", project: root, from: presenter)
    }

    /// A .jar in the Files list: java -jar with miniJVM, from its folder.
    static func runJar(_ jar: URL, project: NXProject?, from presenter: UIViewController) {
        let root: URL = project.map { $0.url as URL } ?? jar.deletingLastPathComponent()
        let relative = ProjectFileIndex.relativePath(jar, root: root)
        runInShell("java -jar \(quote(relative))", title: "java -jar \(jar.lastPathComponent)", project: root, from: presenter)
    }

    static func reinstall(from presenter: UIViewController) {
        UserDefaults.standard.removeObject(forKey: stampKey)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = try? prepare { _ in }
            DispatchQueue.main.async {
                ForkPython.launch(from: presenter, arguments: ["-m", "nyxian_shell", "-c", "java -version"], workingDirectory: userHome, title: "Java")
            }
        }
    }

    /// A .jar opened in Files: run it here (miniJVM) or in the browser (CheerpJ, full Java), or open its contents.
    static func presentJarActions(_ jar: URL, project: NXProject?, from presenter: UIViewController, sourceView: UIView?) {
        let sheet = UIAlertController(title: jar.lastPathComponent, message: "miniJVM runs it here, offline (a Java 8 subset, no windows). CheerpJ runs the full Java (8–21, with Swing windows) in Nyxian's browser; it needs the internet.", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Run (java -jar, miniJVM)", style: .default) { _ in runJar(jar, project: project, from: presenter) })
        sheet.addAction(UIAlertAction(title: "Run in Browser (CheerpJ)", style: .default) { _ in ForkCheerpJ.present(jar: jar, from: presenter) })
        sheet.addAction(UIAlertAction(title: "Open Contents (to edit)", style: .default) { _ in
            ForkJarEditor.extract(jar, from: presenter)
            (presenter as? FileListViewController)?.forkReloadEntries()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sourceView ?? presenter.view
        sheet.popoverPresentationController?.sourceRect = sourceView?.bounds ?? CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        presenter.present(sheet, animated: true)
    }
}

/// A .jar is a ZIP: "Open Contents" makes NAME.jar.contents (edit MANIFEST, resources, classes),
/// "Pack into NAME.jar" writes it back (the old jar is kept as NAME.jar.bak).
enum ForkJarEditor {
    static let suffix = ".jar.contents"

    static func contentsFolder(for jar: URL) -> URL {
        jar.deletingLastPathComponent().appendingPathComponent(jar.deletingPathExtension().lastPathComponent + suffix)
    }

    static func jar(for folder: URL) -> URL? {
        let name = folder.lastPathComponent
        guard name.hasSuffix(suffix), name.count > suffix.count else { return nil }
        return folder.deletingLastPathComponent().appendingPathComponent(String(name.dropLast(suffix.count)) + ".jar")
    }

    static func extract(_ jar: URL, from presenter: UIViewController) {
        let folder = contentsFolder(for: jar)
        let fm = FileManager.default
        if fm.fileExists(atPath: folder.path) {
            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "\(folder.lastPathComponent) is already there: edit it, then hold it › Pack into \(jar.lastPathComponent)", withDelay: 0.0)
            return
        }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            presenter.forkGitHubAlert("Open Contents", error.localizedDescription)
            return
        }
        if unzipArchiveAtPathWithoutParentDirectory(jar.path, folder.path) || unzipArchiveAtPath(jar.path, folder.path) {
            NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil)
            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Opened in \(folder.lastPathComponent). Edit its files, then hold the folder › Pack into \(jar.lastPathComponent)", withDelay: 0.0)
        } else {
            try? fm.removeItem(at: folder)
            presenter.forkGitHubAlert("Open Contents", "\(jar.lastPathComponent) is not a readable ZIP/JAR file.")
        }
    }

    static func pack(_ folder: URL, from presenter: UIViewController) {
        guard let jar = jar(for: folder) else { return }
        let fm = FileManager.default
        let temporary = jar.deletingLastPathComponent().appendingPathComponent(".\(jar.lastPathComponent).new")
        try? fm.removeItem(at: temporary)
        guard zipDirectoryAtPath(folder.path, temporary.path, false) else {
            presenter.forkGitHubAlert("Pack into .jar", "Could not write \(jar.lastPathComponent).")
            return
        }
        if fm.fileExists(atPath: jar.path) {
            let backup = jar.appendingPathExtension("bak")
            try? fm.removeItem(at: backup)
            try? fm.moveItem(at: jar, to: backup)
        }
        do {
            try fm.moveItem(at: temporary, to: jar)
            NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil)
            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Packed \(jar.lastPathComponent) (the previous one is \(jar.lastPathComponent).bak)", withDelay: 0.0)
        } catch {
            presenter.forkGitHubAlert("Pack into .jar", error.localizedDescription)
        }
    }
}

// MARK: - fork: CheerpJ — the full Java (8–21, Swing) in Nyxian's browser

/// Serves a jar's folder over http://127.0.0.1 (CheerpJ reads /app/… from the page's server,
/// with Range requests) and shows a page that runs the jar with CheerpJ (loaded from its
/// CDN: free for personal use; needs the internet).
final class ForkCheerpJ: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private static var server: ForkStaticServer?
    private var webView: WKWebView!
    private var jar: URL!
    private var javaVersion = 17
    private var page: URL?

    static func present(jar: URL, from presenter: UIViewController) {
        let controller = ForkCheerpJ()
        controller.jar = jar
        controller.javaVersion = classVersion(of: jar)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .fullScreen
        var top = presenter
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        top.present(navigation, animated: true)
    }

    /// The Java a jar was made for (class file version) → the CheerpJ runtime to use.
    static func classVersion(of jar: URL) -> Int {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("cheerpj-probe-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: folder) }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        guard unzipArchiveAtPathWithoutParentDirectory(jar.path, folder.path) || unzipArchiveAtPath(jar.path, folder.path),
              let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: nil) else { return 17 }
        var highest = 0
        var seen = 0
        for case let url as URL in enumerator where url.pathExtension == "class" {
            if let handle = try? FileHandle(forReadingFrom: url), let head = try? handle.read(upToCount: 8), head.count == 8 {
                highest = max(highest, Int(head[6]) << 8 | Int(head[7]))
                try? handle.close()
            }
            seen += 1
            if seen > 40 { break }
        }
        switch highest {
        case 0...52: return 8
        case 53...55: return 11
        case 56...61: return 17
        case 62...65: return 21
        default: return highest > 65 ? 25 : 17
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = jar.lastPathComponent
        view.backgroundColor = .systemBackground
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "nyxian")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.isInspectable = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.webView.loadHTMLString("", baseURL: nil)
            self?.webView.configuration.userContentController.removeScriptMessageHandler(forName: "nyxian")
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [weak self] _ in self?.start() }),
            UIBarButtonItem(title: "Java \(javaVersion)", image: nil, primaryAction: nil, menu: versionMenu()),
        ]
        start()
    }

    private func versionMenu() -> UIMenu {
        UIMenu(title: "Java runtime (CheerpJ)", children: [8, 11, 17, 21].map { version in
            UIAction(title: "Java \(version)", state: version == javaVersion ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.javaVersion = version
                self.navigationItem.rightBarButtonItems?.last?.title = "Java \(version)"
                self.navigationItem.rightBarButtonItems?.last?.menu = self.versionMenu()
                self.start()
            }
        })
    }

    private func start() {
        do {
            let folder = jar.deletingLastPathComponent()
            let server = try Self.server ?? ForkStaticServer()
            Self.server = server
            server.root = folder
            server.page = pageHTML()
            guard let url = URL(string: "http://127.0.0.1:\(server.port)/") else { return }
            webView.load(URLRequest(url: url))
        } catch {
            webView.loadHTMLString("<p style='font-family:-apple-system;padding:20px'>Could not start the local server: \(error.localizedDescription)</p>", baseURL: nil)
        }
    }

    private func pageHTML() -> String {
        let name = jar.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? jar.lastPathComponent
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(jar.lastPathComponent)</title>
        <style>
          html,body{margin:0;height:100%;background:#1e1e1e;color:#ddd;font:13px -apple-system,sans-serif}
          #display{position:absolute;top:0;left:0;right:0;bottom:34%;background:#2b2b2b}
          #out{position:absolute;left:0;right:0;bottom:0;height:34%;margin:0;padding:8px;overflow:auto;
               box-sizing:border-box;font:12px ui-monospace,Menlo,monospace;white-space:pre-wrap;border-top:1px solid #444}
          .err{color:#ff7b72}.info{color:#8b949e}
        </style>
        <script src="https://cjrtnc.leaningtech.com/5.0/loader.js"></script>
        </head><body>
        <div id="display"></div><pre id="out"><span class="info">CheerpJ · Java \(javaVersion) · \(jar.lastPathComponent)
        Loading the Java runtime from cjrtnc.leaningtech.com (needs the internet; the first time takes a while)…
        </span></pre>
        <script>
        const out = document.getElementById("out");
        function show(text, cls) {
          const span = document.createElement("span");
          if (cls) span.className = cls;
          span.textContent = text + "\\n";
          out.appendChild(span);
          out.scrollTop = out.scrollHeight;
        }
        for (const [name, cls] of [["log", ""], ["info", ""], ["warn", "err"], ["error", "err"]]) {
          const original = console[name].bind(console);
          console[name] = (...args) => { original(...args); show(args.map(String).join(" "), cls); };
        }
        window.addEventListener("error", (e) => show(String(e.message), "err"));
        (async () => {
          if (typeof cheerpjInit !== "function") {
            show("CheerpJ could not be loaded: check the internet connection, then ↻.", "err");
            return;
          }
          try {
            await cheerpjInit({ version: \(javaVersion), status: "default" });
            const box = document.getElementById("display");
            cheerpjCreateDisplay(-1, -1, box);
            show("Running /app/\(name)…", "info");
            const code = await cheerpjRunJar("/app/\(name)");
            show("[exit code " + code + "]", "info");
            window.webkit.messageHandlers.nyxian.postMessage("exit:" + code);
          } catch (e) {
            show(String(e && e.stack || e), "err");
          }
        })();
        </script></body></html>
        """
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nyxian")
    }
}

/// A tiny HTTP server on 127.0.0.1 for CheerpJ: "/" is the page, "/app/…" the jar's folder
/// (GET and HEAD, with Range requests).
final class ForkStaticServer {
    let port: UInt16
    var root: URL = URL(fileURLWithPath: "/")
    var page = ""
    private let listener: NWListener
    private let queue: DispatchQueue

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "fork.cheerpj.server")
        let ready = DispatchSemaphore(value: 0)
        var assigned: UInt16 = 0
        listener.stateUpdateHandler = { state in
            if case .ready = state { assigned = listener.port?.rawValue ?? 0; ready.signal() }
            if case .failed = state { ready.signal() }
        }
        listener.newConnectionHandler = { $0.cancel() }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 3)
        guard assigned != 0 else {
            listener.cancel()
            throw ForkJava.Failure.server
        }
        self.listener = listener
        self.queue = queue
        self.port = assigned
        listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
                self.respond(connection, head: head)
                return
            }
            if complete || error != nil || buffer.count > 65536 { connection.cancel(); return }
            self.receive(connection, buffer: buffer)
        }
    }

    private func respond(_ connection: NWConnection, head: String) {
        let lines = head.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").split(separator: " ")
        let method = parts.first.map(String.init) ?? "GET"
        var path = parts.count > 1 ? String(parts[1]) : "/"
        if let query = path.firstIndex(of: "?") { path = String(path[..<query]) }
        path = path.removingPercentEncoding ?? path
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        var body = Data()
        var status = "200 OK"
        var type = "application/octet-stream"
        var extra = ""
        if path == "/" || path == "/index.html" {
            body = Data(page.utf8)
            type = "text/html; charset=utf-8"
        } else {
            let relative = path.hasPrefix("/app/") ? String(path.dropFirst(5)) : String(path.dropFirst())
            let file = root.appendingPathComponent(relative).standardizedFileURL
            var isFolder: ObjCBool = false
            if !relative.contains(".."), file.path.hasPrefix(root.standardizedFileURL.path),
               FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder), !isFolder.boolValue,
               let data = try? Data(contentsOf: file, options: .mappedIfSafe) {
                type = file.pathExtension == "jar" ? "application/java-archive" : (file.pathExtension == "html" ? "text/html" : "application/octet-stream")
                extra = "Accept-Ranges: bytes\r\n"
                if let range = headers["range"], range.hasPrefix("bytes=") {
                    let bounds = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
                    let total = data.count
                    var start = Int(bounds.first ?? "") ?? 0
                    var end = bounds.count > 1 ? (Int(bounds[1]) ?? total - 1) : total - 1
                    if bounds.first?.isEmpty == true, let suffix = Int(bounds.count > 1 ? bounds[1] : "") { start = max(0, total - suffix); end = total - 1 }
                    end = min(end, total - 1)
                    if start <= end, start < total {
                        body = data.subdata(in: start..<(end + 1))
                        status = "206 Partial Content"
                        extra += "Content-Range: bytes \(start)-\(end)/\(total)\r\n"
                    } else {
                        status = "416 Range Not Satisfiable"
                        extra += "Content-Range: bytes */\(total)\r\n"
                    }
                } else {
                    body = data
                }
            } else {
                status = "404 Not Found"
                body = Data("not found".utf8)
                type = "text/plain"
            }
        }
        var response = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n\(extra)Cache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var payload = Data(response.utf8)
        if method != "HEAD" { payload.append(body) }
        connection.send(content: payload, completion: .contentProcessed { _ in connection.cancel() })
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

// MARK: - fork: Python home (like Python3IDE's main panel)

/// Everything Python in one place: console, shell, packages, arguments, examples,
/// notebooks, the browser, the folders Python uses, and this fork's links.
final class ForkPythonHubViewController: UITableViewController, UIDocumentPickerDelegate {
    private weak var owner: ContentViewController?

    private enum Row {
        case console, shell, shellHome, packages, install, examples, notebook, browser, arguments
        case nodeConsole, npmInstall, npmList, nodeReinstall
        case javaShell, javaReinstall
        case folder(String, String, URL)     /* title, symbol, folder */
        case about, changelog, reinstall
    }
    private var sections: [(title: String, footer: String?, rows: [Row])] = []

    init(owner: ContentViewController?) {
        self.owner = owner
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Python"
        navigationItem.largeTitleDisplayMode = .never
        if presentingViewController != nil && navigationController?.viewControllers.first === self {
            navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        }
        let python = ForkPython.home
        sections = [
            ("Python \(ForkPython.version)", nil, [.console, .packages, .install, .examples, .notebook]),
            ("Terminal", "Shell: ls, cd, grep, pipes, python3, pip, jobs (^Z, fg, bg). Arguments: what sys.argv gets for each script (⌥⌘R in the editor).",
             [.shell, .shellHome, .arguments]),
            ("Node.js \(ForkNode.version)", "JavaScript without JIT (iOS). ▶ runs .js files; in Shell: node, npm, npx. Packages with native code (.node) or install scripts do not work.",
             [.nodeConsole, .npmInstall, .npmList]),
            ("Java (\(ForkJava.name))", "▶ runs .java files (Java 8 language, miniJVM's class library: a subset of the JDK, no windows). In Shell: java, javac, jar. A .jar in Files: run here, in the browser with CheerpJ (full Java 8–21, Swing; needs the internet) or open its contents to edit.",
             [.javaShell]),
            ("Web", "Flask, Django, node servers and webbrowser.open() open here by themselves.", [.browser]),
            ("Folders", "Read-only views of the folders Python and the compiler use (inside Nyxian's root).", [
                .folder("python HOME", "folder", python),
                .folder("python SITE-PACKAGES", "shippingbox", ForkPython.sitePackages),
                .folder("python STDLIB", "books.vertical", python.appendingPathComponent("lib/python\(ForkPython.version)")),
                .folder("node NODE_MODULES (npm install -g)", "shippingbox.fill", ForkNode.globalModules),
                .folder("node HOME (npm, corepack)", "folder", ForkNode.home),
                .folder("java HOME (miniJVM, javac)", "cup.and.saucer", ForkJava.home),
                .folder("Home (var/mobile)", "house", ForkPython.rootfs.appendingPathComponent("var/mobile")),
                .folder("clang / swift SYSROOT (iOS SDK)", "hammer", NXBootstrap.shared().sdkURL),
                .folder("Projects", "folder.badge.gearshape", NXBootstrap.shared().rootURL.appendingPathComponent("Projects")),
            ]),
            ("This Fork", nil, [.about, .changelog, .reinstall, .nodeReinstall, .javaReinstall]),
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { sections[section].footer }

    private func describe(_ row: Row) -> (String, String, String?) {
        switch row {
        case .console: return ("Python Console", "terminal", "The REPL: history, paste, cells' variables")
        case .shell: return ("Shell", "apple.terminal", "Nyxian Shell in your home folder  $")
        case .shellHome: return ("Shell in Python HOME", "apple.terminal.on.rectangle", "opt/python  $")
        case .packages:
            let count = ForkPython.installedPackages().count
            return ("Modules", "shippingbox.circle", count > 0 ? "\(count) installed — pip install, upgrade, uninstall" : "pip install, upgrade, uninstall")
        case .install: return ("Install Package (pip)…", "shippingbox", nil)
        case .examples: return ("Examples and Tutorials", "graduationcap", "numpy, pandas, plots, ML, cells, debugger, Flask…")
        case .notebook: return ("Open Notebook (.ipynb)…", "book.pages", "View it, run it as cells, save it back")
        case .browser: return ("Browser", "safari", "localhost and the web, inside Nyxian")
        case .arguments:
            let count = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("fork.python.args.") }.count
            return ("ARGS", "text.word.spacing", count == 0 ? "No script has arguments yet" : "\(count) script\(count == 1 ? "" : "s") with arguments")
        case .folder(let title, let symbol, let url): return (title, symbol, url.path.replacingOccurrences(of: NXBootstrap.shared().rootURL.path, with: "…"))
        case .about: return ("About This Fork", "info.circle", "doctoralvarez/Nyxian · GitHub · backups · report a problem")
        case .changelog: return ("What's New", "sparkles", nil)
        case .reinstall: return ("Reinstall Python Runtime", "arrow.clockwise", "Unpacks and signs Python again (your packages stay)")
        case .nodeConsole: return ("Node.js Console", "curlybraces", ForkNode.readyLauncher() == nil ? "Prepared on first use (once per update)" : "The REPL: .help, .editor, Tab")
        case .npmInstall: return ("Install Package (npm)…", "shippingbox", "npm install -g: require() finds it from any script")
        case .npmList: return ("Installed Packages (npm ls -g)", "list.bullet", nil)
        case .nodeReinstall: return ("Reinstall Node.js", "arrow.clockwise", "Unpacks and signs Node.js again (your packages stay)")
        case .javaShell: return ("Java in Shell", "cup.and.saucer", "java -version, javac, java -jar")
        case .javaReinstall: return ("Reinstall Java", "arrow.clockwise", "Unpacks and signs miniJVM again")
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let (title, symbol, detail) = describe(row)
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 2
        cell.imageView?.image = UIImage(systemName: symbol)
        if case .reinstall = row { cell.textLabel?.textColor = .systemRed }
        if case .nodeReinstall = row { cell.textLabel?.textColor = .systemRed }
        if case .javaReinstall = row { cell.textLabel?.textColor = .systemRed }
        if case .folder = row { cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 11, weight: .regular) }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .console: ForkPython.openConsole(from: self)
        case .shell: ForkPython.openShell(from: self)
        case .shellHome: ForkPython.openShell(from: self, folder: ForkPython.home)
        case .packages:
            let manager = UINavigationController(rootViewController: ForkPythonPackagesViewController())
            manager.modalPresentationStyle = .formSheet
            present(manager, animated: true)
        case .install: ForkPython.promptInstallPackage(from: self)
        case .examples: navigationController?.pushViewController(ForkPythonExamplesViewController(owner: owner), animated: true)
        case .notebook:
            let types = [UTType(filenameExtension: "ipynb") ?? .json, .json]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            present(picker, animated: true)
        case .browser: ForkBrowserViewController.present(nil, from: self)
        case .arguments: navigationController?.pushViewController(ForkPythonArgumentsViewController(style: .insetGrouped), animated: true)
        case .folder(_, _, let url):
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            navigationController?.pushViewController(FileListViewController(isSublink: true, path: url.path, isReadOnly: true), animated: true)
        case .about: navigationController?.pushViewController(ForkAboutViewController(style: .insetGrouped), animated: true)
        case .changelog: navigationController?.pushViewController(ForkTextViewController(title: "What's New", text: ForkAboutViewController.changelog()), animated: true)
        case .reinstall: ForkPython.reinstall(from: self)
        case .nodeConsole: ForkNode.openConsole(from: self)
        case .npmInstall: ForkNode.promptInstallPackage(from: self)
        case .npmList: ForkNode.listPackages(from: self)
        case .nodeReinstall: ForkNode.reinstall(from: self)
        case .javaShell:
            /* an interactive Shell (it used to run java -version and end, which looked like a failure) */
            ForkPython.launch(from: self, arguments: ["-m", "nyxian_shell"], workingDirectory: ForkJava.userHome, title: "Java",
                              extraEnvironment: ["NYXIAN_SHELL_INIT": "java -version; echo 'Try: java FILE.java · javac -d DIR FILES · java -jar APP.jar · jar tf APP.jar'"])
        case .javaReinstall: ForkJava.reinstall(from: self)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        ForkNotebookViewController.open(url, project: nil, from: self)
    }
}

/// The scripts that have arguments (Run with Arguments), to see, change or clear them.
final class ForkPythonArgumentsViewController: UITableViewController {
    private var items: [(key: String, path: String, value: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ARGS"
        reload()
    }

    private func reload() {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        items = defaults.compactMap { key, value in
            guard key.hasPrefix("fork.python.args."), let text = value as? String, !text.isEmpty else { return nil }
            return (key, String(key.dropFirst("fork.python.args.".count)), text)
        }.sorted { $0.path < $1.path }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(items.count, 1) }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Arguments are kept per script: in the editor, ⌥⌘R (or ⋯ › Run with Arguments). ▶ uses them afterwards. Swipe to clear."
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        guard !items.isEmpty else {
            cell.textLabel?.text = "No script has arguments"
            cell.textLabel?.textColor = .secondaryLabel
            return cell
        }
        let item = items[indexPath.row]
        cell.textLabel?.text = (item.path as NSString).lastPathComponent
        cell.detailTextLabel?.text = item.value
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !items.isEmpty else { return }
        let item = items[indexPath.row]
        let alert = UIAlertController(title: (item.path as NSString).lastPathComponent, message: "sys.argv[1:]", preferredStyle: .alert)
        alert.addTextField { $0.text = item.value; $0.autocapitalizationType = .none; $0.autocorrectionType = .no; $0.font = .monospacedSystemFont(ofSize: 14, weight: .regular) }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            UserDefaults.standard.set(alert.textFields?.first?.text ?? "", forKey: item.key)
            self?.reload()
        })
        present(alert, animated: true)
    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !items.isEmpty else { return nil }
        let key = items[indexPath.row].key
        return UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: "Clear") { [weak self] _, _, done in
            UserDefaults.standard.removeObject(forKey: key)
            self?.reload()
            done(true)
        }])
    }
}

// MARK: - fork: about this fork

final class ForkAboutViewController: UITableViewController {
    static let repository = "doctoralvarez/Nyxian"

    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let fork = info["NXForkVersion"] as? String ?? "?"
        let app = info["CFBundleShortVersionString"] as? String ?? "?"
        return "Fork \(fork) · Nyxian \(app)"
    }

    static var backupRepository: String {
        UserDefaults.standard.string(forKey: "fork.sdk.backupRepo").flatMap { $0.isEmpty ? nil : $0 } ?? "doctoralvarez/nyxian-sdk"
    }

    /// CHANGELOG-FORK.md, copied into the app by CI.
    static func changelog() -> String {
        let url = Bundle.main.bundleURL.appendingPathComponent("Shared/CHANGELOG-FORK.md")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "The list of changes is in CHANGELOG-FORK.md of https://github.com/\(repository)."
    }

    private let links: [(String, String, String)] = [
        ("GitHub: doctoralvarez/Nyxian", "chevron.left.forwardslash.chevron.right", "https://github.com/doctoralvarez/Nyxian/tree/mejoras-editor-ipad"),
        ("Builds (Actions)", "hammer", "https://github.com/doctoralvarez/Nyxian/actions"),
        ("Report a Problem", "exclamationmark.bubble", "https://github.com/doctoralvarez/Nyxian/issues/new"),
        ("Backups (private)", "externaldrive", ""),
        ("Original: emexLabs Nyxian", "building.columns", "https://github.com/emexlab/Nyxian"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "About This Fork"
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [1, links.count, 2][section]
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        [nil, "Links", "Help"][section]
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 2 ? "Nyxian is © emexLabs (EPSL 1.1 — private use and modification). This fork's changes are listed in What's New." : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = Self.version
            cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
            cell.detailTextLabel?.text = "Python \(ForkPython.version) · Swift / C / Objective-C · iOS SDK 27"
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.imageView?.image = UIImage(systemName: "hammer.circle.fill")
            cell.selectionStyle = .none
        case 1:
            let link = links[indexPath.row]
            cell.textLabel?.text = link.0
            cell.imageView?.image = UIImage(systemName: link.1)
            cell.detailTextLabel?.text = link.2.isEmpty ? "github.com/\(Self.backupRepository)/releases" : link.2.replacingOccurrences(of: "https://", with: "")
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryType = .disclosureIndicator
        default:
            cell.textLabel?.text = indexPath.row == 0 ? "What's New" : "Share the Kernel Log"
            cell.imageView?.image = UIImage(systemName: indexPath.row == 0 ? "sparkles" : "square.and.arrow.up")
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 1:
            let link = links[indexPath.row]
            let address = link.2.isEmpty ? "https://github.com/\(Self.backupRepository)/releases" : link.2
            if let url = URL(string: address) { UIApplication.shared.open(url) }
        case 2:
            if indexPath.row == 0 {
                navigationController?.pushViewController(ForkTextViewController(title: "What's New", text: Self.changelog()), animated: true)
            } else {
                let share = UIActivityViewController(activityItems: [ForkKernelLogViewController.currentURL], applicationActivities: nil)
                share.popoverPresentationController?.sourceView = tableView
                share.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
                present(share, animated: true)
            }
        default: break
        }
    }
}

/// A long text (the changelog), with simple Markdown: headings, bold, code, lists.
final class ForkTextViewController: UIViewController {
    private let text: String
    init(title: String, text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let view = UITextView()
        view.isEditable = false
        view.backgroundColor = .systemBackground
        view.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 24, right: 12)
        view.attributedText = Self.render(text)
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.backgroundColor = .systemBackground
        self.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: self.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
        ])
    }

    static func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let body = UIFont.preferredFont(forTextStyle: .body)
        for raw in markdown.components(separatedBy: "\n") {
            var line = raw
            var font = body
            var indent: CGFloat = 0
            if line.hasPrefix("# ") { font = .preferredFont(forTextStyle: .title1).bold(); line.removeFirst(2) }
            else if line.hasPrefix("## ") { font = .preferredFont(forTextStyle: .title3).bold(); line.removeFirst(3) }
            else if line.hasPrefix("### ") { font = .preferredFont(forTextStyle: .headline); line.removeFirst(4) }
            else if let range = line.range(of: #"^\s*[-*] "#, options: .regularExpression) {
                indent = CGFloat(line.distance(from: line.startIndex, to: range.upperBound)) * 6
                line = "•  " + line[range.upperBound...]
            }
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            var attributed = (try? AttributedString(markdown: line, options: options)) ?? AttributedString(line)
            attributed.uiKit.font = font
            for run in attributed.runs {
                if let intent = run.inlinePresentationIntent {
                    if intent.contains(.code) { attributed[run.range].uiKit.font = UIFont.monospacedSystemFont(ofSize: font.pointSize * 0.9, weight: .regular) }
                    else if intent.contains(.stronglyEmphasized) { attributed[run.range].uiKit.font = font.bold() }
                }
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = indent + 16
            paragraph.firstLineHeadIndent = indent
            paragraph.paragraphSpacing = font == body ? 2 : 6
            let piece = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
            piece.addAttributes([.paragraphStyle: paragraph, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: piece.length))
            result.append(piece)
            result.append(NSAttributedString(string: "\n"))
        }
        return result
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - fork: browser (local servers, webbrowser.open, the web)


final class ForkBrowserViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate {
    private static weak var shown: ForkBrowserViewController?
    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let address = UITextField()
    private let progress = UIProgressView(progressViewStyle: .bar)
    private var observation: NSKeyValueObservation?
    private var first: URL?
    private var retries = 0

    /// Opens `url` (default: the last address, else http://127.0.0.1:5000) in the browser,
    /// in the one already open if there is one.
    static func present(_ url: URL?, from presenter: UIViewController) {
        let target = url ?? UserDefaults.standard.url(forKey: "fork.browser.last") ?? URL(string: "http://127.0.0.1:5000")!
        if let shown, shown.view.window != nil {
            shown.load(target)
            return
        }
        let browser = ForkBrowserViewController()
        browser.first = target
        let navigation = UINavigationController(rootViewController: browser)
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.largestUndimmedDetentIdentifier = .medium
        }
        var top = presenter
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        top.present(navigation, animated: true)
        shown = browser
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        address.borderStyle = .roundedRect
        address.keyboardType = .URL
        address.autocapitalizationType = .none
        address.autocorrectionType = .no
        address.returnKeyType = .go
        address.clearButtonMode = .whileEditing
        address.delegate = self
        address.font = .preferredFont(forTextStyle: .subheadline)
        address.frame = CGRect(x: 0, y: 0, width: 600, height: 34)
        navigationItem.titleView = address
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [weak self] _ in self?.retries = 0; self?.webView.reload() }),
            UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: [
                UIAction(title: "Back", image: UIImage(systemName: "chevron.backward")) { [weak self] _ in self?.webView.goBack() },
                UIAction(title: "Forward", image: UIImage(systemName: "chevron.forward")) { [weak self] _ in self?.webView.goForward() },
                UIAction(title: "localhost:5000 (Flask)", image: UIImage(systemName: "flask")) { [weak self] _ in self?.load(URL(string: "http://127.0.0.1:5000")!) },
                UIAction(title: "localhost:8000 (Django)", image: UIImage(systemName: "server.rack")) { [weak self] _ in self?.load(URL(string: "http://127.0.0.1:8000")!) },
                UIAction(title: "Open in Safari", image: UIImage(systemName: "safari")) { [weak self] _ in
                    if let url = self?.webView.url { UIApplication.shared.open(url) }
                },
                UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    guard let self, let url = self.webView.url else { return }
                    let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    share.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItems?.last
                    self.present(share, animated: true)
                },
            ])),
        ]
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(progress)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        observation = webView.observe(\.estimatedProgress) { [weak self] web, _ in
            self?.progress.progress = Float(web.estimatedProgress)
            self?.progress.isHidden = web.estimatedProgress >= 1
        }
        if let first { load(first) }
    }

    func load(_ url: URL) {
        retries = 0
        address.text = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        var text = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return true }
        if !text.contains("://") {
            let local = text.hasPrefix("localhost") || text.hasPrefix("127.") || text.hasPrefix(":")
            if text.hasPrefix(":") { text = "127.0.0.1" + text }
            if !local && !text.contains(".") {
                text = "https://duckduckgo.com/?q=" + (text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text)
            } else {
                text = (local ? "http://" : "https://") + text
            }
        }
        if let url = URL(string: text) { load(url) }
        return true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            address.text = url.absoluteString
            UserDefaults.standard.set(url, forKey: "fork.browser.last")
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        /* a server that is still starting: try again for a few seconds */
        let host = webView.url?.host ?? URL(string: address.text ?? "")?.host ?? ""
        if ["127.0.0.1", "localhost", "::1"].contains(host), retries < 8 {
            retries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self, let url = URL(string: self.address.text ?? "") else { return }
                self.webView.load(URLRequest(url: url))
            }
            return
        }
        let page = """
        <html><head><meta name=viewport content="width=device-width"></head>
        <body style="font-family:-apple-system;padding:24px;color:#555">
        <h3>Could not open \(address.text ?? "")</h3><p>\(error.localizedDescription)</p>
        <p>For a local server: start it in Python first (Flask: <code>app.run(port=5000)</code>), then reload.</p></body></html>
        """
        webView.loadHTMLString(page, baseURL: nil)
    }
}

// MARK: - fork: examples and tutorials

struct ForkPythonExample {
    let title: String
    let detail: String
    let symbol: String
    let files: [String: String]
    let open: String
}

enum ForkPythonExamples {
    static let all: [ForkPythonExample] = [
        ForkPythonExample(title: "Primeros pasos", detail: "input(), variables, listas, diccionarios, funciones y f-strings", symbol: "1.circle", files: ["main.py": #"""
# Primeros pasos con Python — ▶ (⌘R) para correrlo

nombre = input("¿Cómo te llamas? ")
print(f"Hola, {nombre} 👋")

# listas
numeros = [3, 1, 4, 1, 5, 9, 2, 6]
print("ordenados:", sorted(numeros), "| suma:", sum(numeros), "| máximo:", max(numeros))
pares = [n for n in numeros if n % 2 == 0]
print("pares:", pares)

# diccionarios
agudeza = {"OD": "20/20", "OI": "20/25"}
for ojo, valor in agudeza.items():
    print(f"  {ojo}: {valor}")

# funciones
def equivalente_esferico(esfera: float, cilindro: float) -> float:
    """Esfera + cilindro / 2 (dioptrías)."""
    return esfera + cilindro / 2

print("EE de -2.00 -1.50 =", equivalente_esferico(-2.0, -1.5), "D")
"""#], open: "main.py"),
        ForkPythonExample(title: "NumPy", detail: "Arreglos, operaciones vectoriales, álgebra lineal, estadística", symbol: "square.grid.3x3", files: ["main.py": #"""
import numpy as np

a = np.arange(12).reshape(3, 4)
print("a =\n", a)
print("forma:", a.shape, "| media por columna:", a.mean(axis=0))

# operaciones vectoriales (sin bucles)
x = np.linspace(0, 2 * np.pi, 5)
print("sin(x) =", np.round(np.sin(x), 3))

# álgebra lineal: resolver A·v = b
A = np.array([[3.0, 1.0], [1.0, 2.0]])
b = np.array([9.0, 8.0])
v = np.linalg.solve(A, b)
print("solución:", v, "| comprobación:", A @ v)

# estadística de datos simulados
rng = np.random.default_rng(42)
datos = rng.normal(loc=-2.5, scale=1.2, size=1000)   # p. ej. equivalentes esféricos
print(f"media {datos.mean():.2f} D, DE {datos.std():.2f} D, percentil 95 {np.percentile(datos, 95):.2f} D")
"""#], open: "main.py"),
        ForkPythonExample(title: "pandas", detail: "Tabla de datos, filtros, agrupar, describir y guardar CSV", symbol: "tablecells", files: ["main.py": #"""
import pandas as pd

df = pd.DataFrame({
    "paciente": ["A", "B", "C", "D", "E", "F"],
    "ojo": ["OD", "OI", "OD", "OI", "OD", "OI"],
    "kmax": [47.2, 49.8, 52.1, 46.5, 55.3, 48.0],
    "paquimetria": [540, 498, 470, 552, 431, 515],
})
print(df, "\n")
print(df.describe(), "\n")

sospechosos = df[(df.kmax > 49) | (df.paquimetria < 480)]
print("Kmax > 49 D o paquimetría < 480 µm:\n", sospechosos, "\n")

print(df.groupby("ojo")[["kmax", "paquimetria"]].mean().round(1))

df.to_csv("resultados.csv", index=False)
print("\nGuardado resultados.csv (aparece en el proyecto al terminar)")
"""#], open: "main.py"),
        ForkPythonExample(title: "Gráficas (matplotlib)", detail: "Líneas, dispersión e histograma; plt.show() abre la vista previa", symbol: "chart.xyaxis.line", files: ["main.py": #"""
import numpy as np
import matplotlib.pyplot as plt

x = np.linspace(0, 10, 200)
rng = np.random.default_rng(0)

fig, ejes = plt.subplots(1, 3, figsize=(12, 3.6))
ejes[0].plot(x, np.sin(x), label="sin")
ejes[0].plot(x, np.cos(x), label="cos")
ejes[0].legend(); ejes[0].set_title("Líneas")

edad = rng.uniform(8, 18, 80)
miopia = -0.35 * (edad - 8) + rng.normal(0, 0.6, 80)
ejes[1].scatter(edad, miopia, s=12)
ejes[1].set_xlabel("edad (años)"); ejes[1].set_ylabel("EE (D)"); ejes[1].set_title("Dispersión")

ejes[2].hist(rng.normal(550, 35, 500), bins=30, color="tab:green")
ejes[2].set_title("Paquimetría (µm)")

fig.tight_layout()
plt.show()   # la imagen también queda en figures/
"""#], open: "main.py"),
        ForkPythonExample(title: "Tortuga (turtle)", detail: "Dibujos con turtle; done() muestra la imagen", symbol: "scribble.variable", files: ["main.py": #"""
# turtle en Nyxian: iOS no tiene ventanas Tk, así que el dibujo se guarda
# como PNG en figures/ y se abre al llamar done() (o al terminar).
import turtle

pantalla = turtle.Screen()
pantalla.bgcolor("midnightblue")
t = turtle.Turtle()
t.pensize(2)
colores = ["gold", "orange", "tomato", "orchid", "deepskyblue", "lime"]
for i in range(72):
    t.pencolor(colores[i % len(colores)])
    t.circle(120, steps=6)
    t.left(5)
t.penup()
t.goto(0, -200)
t.pencolor("white")
t.write("Hola desde Nyxian", align="center", font=("Arial", 18, "bold"))
t.hideturtle()
turtle.done()
"""#], open: "main.py"),
        ForkPythonExample(title: "JavaScript (Node.js)", detail: "Funciones, clases, async/await, archivos con fs; ▶ corre main.js", symbol: "curlybraces", files: ["main.js": #"""
// JavaScript con Node.js en Nyxian: ▶ (o ⌘R) corre este archivo.
// En el Shell del proyecto: node main.js, npm install NOMBRE, npm run …
const fs = require("fs");
const os = require("os");
const { saludar, Contador } = require("./util");

console.log(saludar("Nyxian"), "— Node", process.version, "en", os.platform());

const c = new Contador();
[3, 1, 4, 1, 5, 9].forEach((n) => c.sumar(n));
console.log("total:", c.total, "promedio:", c.promedio().toFixed(2));

const datos = { fecha: new Date().toISOString(), valores: c.valores };
fs.writeFileSync("datos.json", JSON.stringify(datos, null, 2));
console.log("guardado datos.json (llega al proyecto al terminar)");

const esperar = (ms) => new Promise((listo) => setTimeout(listo, ms));
(async () => {
  for (let i = 3; i > 0; i--) {
    console.log("…", i);
    await esperar(300);
  }
  console.log("¡listo!");
})();
"""#, "util.js": #"""
// Un módulo propio: module.exports y require("./util")
function saludar(nombre) {
  return `Hola, ${nombre}`;
}

class Contador {
  constructor() {
    this.valores = [];
  }
  sumar(n) {
    this.valores.push(n);
  }
  get total() {
    return this.valores.reduce((a, b) => a + b, 0);
  }
  promedio() {
    return this.valores.length ? this.total / this.valores.length : 0;
  }
}

module.exports = { saludar, Contador };
"""#], open: "main.js"),
        ForkPythonExample(title: "Servidor web (Node.js)", detail: "http.createServer: la página se abre sola en el navegador de Nyxian", symbol: "network", files: ["server.js": #"""
// Un servidor web con el módulo http de Node (sin paquetes).
// Al arrancar imprime su dirección y Nyxian la abre en su navegador.
// ■ (Ctrl-C) en la ventana lo detiene.
const http = require("http");

let visitas = 0;
const servidor = http.createServer((req, res) => {
  if (req.url === "/api") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ visitas, hora: new Date().toLocaleTimeString() }));
    return;
  }
  visitas++;
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(`<!doctype html><meta name="viewport" content="width=device-width">
<body style="font-family:-apple-system;padding:2em">
<h1>Hola desde Node.js ${process.version}</h1>
<p>Visitas: ${visitas}</p>
<p><a href="/api">/api</a> devuelve JSON</p></body>`);
  console.log(new Date().toLocaleTimeString(), req.method, req.url);
});

servidor.listen(3000, "127.0.0.1", () => {
  console.log("Servidor en http://127.0.0.1:3000");
});
"""#], open: "server.js"),
        ForkPythonExample(title: "Java (miniJVM)", detail: "Clases, interfaces, lambdas, colecciones y archivos; ▶ corre Main.java", symbol: "cup.and.saucer", files: ["Main.java": #"""
// Java en Nyxian (miniJVM): ▶ (o ⌘R) compila y corre este archivo.
// En el Shell del proyecto: javac -d clases Main.java · java -cp clases Main
// · jar cfe app.jar Main -C clases . · java -jar app.jar
import java.io.*;
import java.util.*;

public class Main {
    interface Figura { double area(); }

    static class Circulo implements Figura {
        final double r;
        Circulo(double r) { this.r = r; }
        public double area() { return Math.PI * r * r; }
        public String toString() { return "Círculo(r=" + r + ")"; }
    }

    static class Rectangulo implements Figura {
        final double a, b;
        Rectangulo(double a, double b) { this.a = a; this.b = b; }
        public double area() { return a * b; }
        public String toString() { return "Rectángulo(" + a + "×" + b + ")"; }
    }

    public static void main(String[] args) throws IOException {
        System.out.println("Hola desde Java en Nyxian. Argumentos: " + Arrays.toString(args));

        List<Figura> figuras = new ArrayList<>();
        figuras.add(new Circulo(1.5));
        figuras.add(new Rectangulo(2, 3));
        figuras.add(new Circulo(0.5));
        Collections.sort(figuras, (x, y) -> Double.compare(x.area(), y.area()));
        double total = 0;
        for (Figura f : figuras) {
            System.out.printf("%-22s área %.3f%n", f, f.area());
            total += f.area();
        }
        System.out.printf("Total: %.3f%n", total);

        Map<String, Integer> cuenta = new TreeMap<>();
        for (String palabra : "el sol y el mar y el cielo".split(" ")) {
            Integer n = cuenta.get(palabra);
            cuenta.put(palabra, n == null ? 1 : n + 1);
        }
        System.out.println("Palabras: " + cuenta);

        FileWriter w = new FileWriter("resultado.txt");
        w.write("total=" + total + "\n");
        w.close();
        System.out.println("Guardado resultado.txt (llega al proyecto al terminar)");
    }
}
"""#], open: "Main.java"),
        ForkPythonExample(title: "SciPy", detail: "Ajuste de curvas, optimización e integración", symbol: "function", files: ["main.py": #"""
import numpy as np
from scipy import optimize, integrate, stats

# ajuste de una curva exponencial a datos con ruido
t = np.linspace(0, 4, 30)
y = 3.0 * np.exp(-0.8 * t) + np.random.default_rng(1).normal(0, 0.05, t.size)
(a, k), _ = optimize.curve_fit(lambda t, a, k: a * np.exp(-k * t), t, y)
print(f"ajuste: y = {a:.2f}·e^(-{k:.2f}·t)")

# mínimo de una función
resultado = optimize.minimize_scalar(lambda x: (x - 2) ** 2 + 1)
print("mínimo en x =", round(resultado.x, 4))

# integral definida
valor, error = integrate.quad(np.sin, 0, np.pi)
print("∫ sin(x) dx de 0 a π =", round(valor, 6))

# prueba t de dos grupos
g1 = np.array([540, 552, 531, 560, 548]); g2 = np.array([498, 470, 512, 485, 501])
print("t de Student:", stats.ttest_ind(g1, g2))
"""#], open: "main.py"),
        ForkPythonExample(title: "Aprendizaje automático (scikit-learn)", detail: "Clasificador con datos incluidos, exactitud y matriz de confusión", symbol: "brain", files: ["main.py": #"""
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report

X, y = load_iris(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=0, stratify=y)

modelo = RandomForestClassifier(n_estimators=200, random_state=0)
modelo.fit(X_train, y_train)
pred = modelo.predict(X_test)

print("exactitud:", round(accuracy_score(y_test, pred), 3))
print("matriz de confusión:\n", confusion_matrix(y_test, pred))
print(classification_report(y_test, pred, target_names=load_iris().target_names))
print("importancia de variables:", dict(zip(load_iris().feature_names, modelo.feature_importances_.round(3))))
"""#], open: "main.py"),
        ForkPythonExample(title: "Celdas tipo notebook", detail: "# %% celdas: ⌘↩ corre una, ⌥⌘O muestra resultados, ⌥⌘V variables", symbol: "rectangle.split.3x1", files: ["cuaderno.py": #"""
# Cada "# %%" empieza una celda. Pon el cursor en una y presiona ⌘↩.
# ⌥⌘O: resultados de cada celda (texto y gráficas) · ⌥⌘V: variables.

# %% Datos
import numpy as np
rng = np.random.default_rng(7)
datos = rng.normal(-2, 1, 300)
datos[:5]

# %% Resumen
print(f"n={datos.size}  media={datos.mean():.2f}  DE={datos.std():.2f}")

# %% Gráfica
import matplotlib.pyplot as plt
plt.hist(datos, bins=25)
plt.title("Distribución")
plt.show()

# %% Un error (para verlo en rojo)
1 / 0
"""#], open: "cuaderno.py"),
        ForkPythonExample(title: "Depurador", detail: "Breakpoints con ⌘\\ y ⌥⌘D: n, s, c, p, locals", symbol: "ladybug", files: ["main.py": #"""
# Depurar:
#   1. Pon el cursor en la línea "total += valor" y presiona ⌘\ (breakpoint).
#   2. Presiona ⌥⌘D (o ⋯ › Debug).
#   3. En la terminal: p valor · locals · n (siguiente) · c (continuar) · q (salir)
#   4. ⌥⌘V muestra las variables donde se detuvo.

def promedio(valores):
    total = 0
    for valor in valores:
        total += valor
    return total / len(valores)

lecturas = [43.5, 44.1, 43.8, 47.9]
print("promedio:", promedio(lecturas))
"""#], open: "main.py"),
        ForkPythonExample(title: "Pruebas (pytest)", detail: "Un módulo y sus pruebas; ⌘U las corre y marca la que falla", symbol: "checkmark.seal", files: [
            "calculos.py": #"""
def equivalente_esferico(esfera, cilindro):
    return esfera + cilindro / 2


def es_alta_miopia(esfera):
    return esfera <= -6.0
"""#,
            "test_calculos.py": #"""
# Abre este archivo y presiona ⌘U (Run Tests).
from calculos import equivalente_esferico, es_alta_miopia


def test_equivalente():
    assert equivalente_esferico(-2.0, -1.0) == -2.5


def test_alta_miopia():
    assert es_alta_miopia(-6.5)
    assert not es_alta_miopia(-3.0)


def test_que_falla():
    # cámbialo para que pase
    assert equivalente_esferico(0, -2) == 0
"""#], open: "test_calculos.py"),
        ForkPythonExample(title: "Argumentos y archivos", detail: "sys.argv (⌥⌘R), leer y escribir archivos", symbol: "doc.text", files: ["main.py": #"""
# Córrelo con ⌥⌘R y escribe por ejemplo:  datos.txt 3
import sys
from pathlib import Path

archivo = sys.argv[1] if len(sys.argv) > 1 else "datos.txt"
veces = int(sys.argv[2]) if len(sys.argv) > 2 else 1
print("argumentos:", sys.argv[1:])

ruta = Path(archivo)
if not ruta.exists():
    ruta.write_text("linea 1\nlinea 2\n", encoding="utf-8")
    print("creado", ruta)

for _ in range(veces):
    with ruta.open("a", encoding="utf-8") as f:
        f.write("otra línea\n")

print(ruta.read_text(encoding="utf-8"))
print("Al terminar, el archivo aparece en el proyecto.")
"""#], open: "main.py"),
        ForkPythonExample(title: "Página web con Flask", detail: "Un servidor local; el navegador de Nyxian se abre solo", symbol: "globe", files: ["app.py": #"""
# ▶ corre el servidor; Nyxian abre su navegador en http://127.0.0.1:5000
# Para detenerlo: ^C en la terminal (o ✕).
from flask import Flask, request

app = Flask(__name__)


@app.route("/")
def inicio():
    nombre = request.args.get("nombre", "mundo")
    return f"""
    <meta name=viewport content="width=device-width">
    <h1>Hola, {nombre}</h1>
    <form><input name=nombre placeholder="tu nombre"> <button>Saludar</button></form>
    <p><a href="/api">/api</a> devuelve JSON</p>
    """


@app.route("/api")
def api():
    return {"estado": "ok", "servidor": "Flask en Nyxian"}


if __name__ == "__main__":
    # sin recargador (iOS no permite fork); solo en este dispositivo
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)
"""#], open: "app.py"),
        ForkPythonExample(title: "Nyxian Shell", detail: "Comandos, tuberías, redirección y trabajos", symbol: "apple.terminal", files: [
            "LEEME.md": #"""
# Nyxian Shell

Ábrelo con ⋯ › Shell in This Project (o el panel Python › Shell). Prueba:

    ls -la
    cat datos.csv | grep -i od | wc -l
    sort -r datos.csv > ordenado.csv && head -n 3 ordenado.csv
    python3 contar.py datos.csv
    python3 -c "import time; [print(i, flush=True) or time.sleep(1) for i in range(30)]"
        (^Z lo detiene · jobs · bg · fg · ^C)
    help
"""#,
            "datos.csv": "paciente,ojo,kmax\nA,OD,47.2\nB,OI,49.8\nC,OD,52.1\nD,OI,46.5\n",
            "contar.py": #"""
import sys
import csv

with open(sys.argv[1] if len(sys.argv) > 1 else "datos.csv", newline="") as f:
    filas = list(csv.DictReader(f))
print(len(filas), "filas;", "Kmax máxima:", max(float(r["kmax"]) for r in filas))
"""#], open: "LEEME.md"),
    ]
}

final class ForkPythonExamplesViewController: UITableViewController {
    private weak var owner: ContentViewController?
    init(owner: ContentViewController?) {
        self.owner = owner
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Examples and Tutorials"
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { ForkPythonExamples.all.count }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Each one becomes a Python project of its own, with comments in Spanish on how to use it."
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let example = ForkPythonExamples.all[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = example.title
        cell.detailTextLabel?.text = example.detail
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 2
        cell.imageView?.image = UIImage(systemName: example.symbol)
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let example = ForkPythonExamples.all[indexPath.row]
        guard let owner else { return }
        let presenterRoot = owner
        presentingViewController?.dismiss(animated: true)
        navigationController?.popToRootViewController(animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            presenterRoot.forkCreateExample(example)
        }
    }
}

extension ContentViewController {
    /// A new Python project with the example's files, opened.
    func forkCreateExample(_ example: ForkPythonExample) {
        let model = ProjectTemplateOptionsModel(schemeKind: .utility)
        model.selectPython()
        var name = example.title.replacingOccurrences(of: #"[^A-Za-zÀ-ÿ0-9 ]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if name.isEmpty { name = "Ejemplo" }
        let existing = Set(projectsList.values.flatMap { $0 }.map { $0.projectConfig.displayName ?? "" })
        var candidate = name
        var number = 2
        while existing.contains(candidate) { candidate = "\(name) \(number)"; number += 1 }
        model.productName = candidate
        guard let project = NXProject.createProject(
            at: NXBootstrap.shared().rootURL.appendingPathComponent("Projects"),
            withName: candidate,
            withOrganizationIdentifier: model.normalizedOrganizationIdentifier,
            withBundleIdentifier: model.bundleIdentifier,
            withSchemeKind: model.schemeKind,
            withLanguageKind: model.selectedLanguage,
            withInterfaceKind: model.selectedInterface) else {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Could not create the example", withDelay: 0.0)
            return
        }
        ForkPython.makePythonProject(project, name: candidate)
        let root = project.url as URL
        if example.files["main.py"] == nil { try? FileManager.default.removeItem(at: root.appendingPathComponent("main.py")) }
        for (file, text) in example.files {
            let url = root.appendingPathComponent(file)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
        reloadProjectsFromDisk()
        forkOpenProject(project, file: root.appendingPathComponent(example.open))
    }

    /// Opens a project as a tap on its row does, then one of its files.
    func forkOpenProject(_ project: NXProject, file: URL?) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let padFileVC = MainSplitViewController(project: project)
            padFileVC.modalPresentationStyle = .fullScreen
            present(padFileVC, animated: true) {
                if let file {
                    NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open", file.path, "0", "0", "0"])
                }
            }
        } else {
            let fileVC = FileListViewController(project: project)
            navigationController?.pushViewController(fileVC, animated: true)
            if let file, let editor = CodeEditorViewController(project: project, url: file, isReadOnly: false) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let navigation = UINavigationController(rootViewController: editor)
                    navigation.modalPresentationStyle = .overFullScreen
                    fileVC.present(navigation, animated: true)
                }
            }
        }
    }
}

// MARK: - fork: Jupyter notebooks (.ipynb)

// BEGIN ForkNotebook
/// A notebook as cells: markdown, code and the outputs it was saved with.
struct ForkNotebook {
    struct Output {
        var text: String = ""
        var image: Data?
        var isError = false
    }
    struct Cell {
        var kind: String          /* "code" or "markdown" (or "raw") */
        var source: String
        var outputs: [Output]
    }
    var cells: [Cell]
    var language = "python"

    private static func joined(_ value: Any?) -> String {
        if let list = value as? [String] { return list.joined() }
        return value as? String ?? ""
    }

    private static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: #"\u001B\[[0-9;]*[A-Za-z]"#, with: "", options: .regularExpression)
    }

    init(cells: [Cell]) { self.cells = cells }

    init?(data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawCells = object["cells"] as? [[String: Any]] else { return nil }
        if let metadata = object["metadata"] as? [String: Any],
           let info = metadata["language_info"] as? [String: Any], let name = info["name"] as? String { language = name }
        cells = rawCells.map { raw in
            var outputs: [Output] = []
            for output in raw["outputs"] as? [[String: Any]] ?? [] {
                let type = output["output_type"] as? String ?? ""
                var item = Output()
                switch type {
                case "stream":
                    item.text = Self.joined(output["text"])
                    item.isError = (output["name"] as? String) == "stderr"
                case "error":
                    item.text = Self.stripANSI((output["traceback"] as? [String] ?? []).joined(separator: "\n"))
                    if item.text.isEmpty { item.text = "\(output["ename"] ?? ""): \(output["evalue"] ?? "")" }
                    item.isError = true
                default:
                    let bundle = output["data"] as? [String: Any] ?? [:]
                    if let png = bundle["image/png"] {
                        item.image = Data(base64Encoded: Self.joined(png).replacingOccurrences(of: "\n", with: ""))
                    } else if let jpeg = bundle["image/jpeg"] {
                        item.image = Data(base64Encoded: Self.joined(jpeg).replacingOccurrences(of: "\n", with: ""))
                    }
                    item.text = Self.joined(bundle["text/plain"])
                    if item.image != nil && item.text.hasPrefix("<Figure") { item.text = "" }
                }
                outputs.append(item)
            }
            return Cell(kind: raw["cell_type"] as? String ?? "code", source: Self.joined(raw["source"]), outputs: outputs)
        }
    }

    /// Python cells ("percent" format, like Jupytext/VS Code): markdown as # comments.
    var percentScript: String {
        var text = "# Notebook converted by Nyxian: every cell starts with a %% line (⌘↩ runs it, ⌥⌘O shows the outputs).\n"
        text += "# Save it back as .ipynb with ⋯ › Save as Notebook.\n\n"
        for cell in cells {
            if cell.kind == "markdown" {
                text += "# %% [markdown]\n"
                text += cell.source.components(separatedBy: "\n").map { $0.isEmpty ? "#" : "# " + $0 }.joined(separator: "\n") + "\n\n"
            } else if cell.kind == "code" {
                text += "# %%\n" + cell.source.trimmingCharacters(in: .newlines) + "\n\n"
            }
        }
        return text
    }

    /// The cells of a "# %%" script.
    static func fromPercentScript(_ script: String) -> ForkNotebook {
        var cells: [Cell] = []
        var kind = "code"
        var lines: [String] = []
        var seenMarker = false
        func flush() {
            var source = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if kind == "markdown" {
                source = source.components(separatedBy: "\n").map { line in
                    if line == "#" { return "" }
                    return line.hasPrefix("# ") ? String(line.dropFirst(2)) : (line.hasPrefix("#") ? String(line.dropFirst()) : line)
                }.joined(separator: "\n")
            }
            if !source.isEmpty { cells.append(Cell(kind: kind, source: source, outputs: [])) }
            lines = []
        }
        for line in script.components(separatedBy: "\n") {
            if line.hasPrefix("# %%") {
                if seenMarker || !lines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { flush() } else { lines = [] }
                seenMarker = true
                kind = line.contains("[markdown]") ? "markdown" : "code"
            } else {
                lines.append(line)
            }
        }
        flush()
        /* the converter's own header is not a cell */
        if let first = cells.first, first.kind == "code", first.source.hasPrefix("# Notebook converted by Nyxian") { cells.removeFirst() }
        return ForkNotebook(cells: cells)
    }

    /// nbformat 4 JSON; outputs of cells run in Nyxian's cell console are added when the code matches.
    func jsonData(outputs recorded: [[String: Any]] = []) -> Data? {
        var byCode: [String: [String: Any]] = [:]
        for cell in recorded {
            if let source = cell["source"] as? String { byCode[source.trimmingCharacters(in: .whitespacesAndNewlines)] = cell }
        }
        func lines(_ text: String) -> [String] {
            let parts = text.components(separatedBy: "\n")
            var result = parts.dropLast().map { $0 + "\n" }
            if let last = parts.last, !last.isEmpty { result.append(last) }
            return result
        }
        var count = 0
        let rawCells: [[String: Any]] = cells.map { cell in
            if cell.kind != "code" {
                return ["cell_type": cell.kind, "metadata": [String: Any](), "source": lines(cell.source)]
            }
            var outputs: [[String: Any]] = []
            var execution: Any = NSNull()
            if let run = byCode[cell.source.trimmingCharacters(in: .whitespacesAndNewlines)] {
                count += 1
                execution = count
                let text = run["output"] as? String ?? ""
                let failed = run["failed"] as? Bool ?? false
                if !text.isEmpty {
                    if failed {
                        outputs.append(["output_type": "error", "ename": "Error", "evalue": "", "traceback": text.components(separatedBy: "\n")])
                    } else {
                        outputs.append(["output_type": "stream", "name": "stdout", "text": lines(text)])
                    }
                }
                for path in run["figures"] as? [String] ?? [] {
                    if let data = FileManager.default.contents(atPath: path), path.lowercased().hasSuffix(".png") {
                        outputs.append(["output_type": "display_data", "metadata": [String: Any](),
                                        "data": ["image/png": data.base64EncodedString(), "text/plain": ["<Figure>"]]])
                    }
                }
            } else if !cell.outputs.isEmpty {
                for output in cell.outputs {
                    if let image = output.image {
                        outputs.append(["output_type": "display_data", "metadata": [String: Any](), "data": ["image/png": image.base64EncodedString()]])
                    } else if output.isError {
                        outputs.append(["output_type": "error", "ename": "Error", "evalue": "", "traceback": output.text.components(separatedBy: "\n")])
                    } else {
                        outputs.append(["output_type": "stream", "name": "stdout", "text": lines(output.text)])
                    }
                }
            }
            return ["cell_type": "code", "execution_count": execution, "metadata": [String: Any](), "outputs": outputs, "source": lines(cell.source)]
        }
        let notebook: [String: Any] = [
            "cells": rawCells,
            "metadata": ["kernelspec": ["display_name": "Python 3", "language": "python", "name": "python3"],
                         "language_info": ["name": "python"]],
            "nbformat": 4, "nbformat_minor": 5,
        ]
        return try? JSONSerialization.data(withJSONObject: notebook, options: [.prettyPrinted, .sortedKeys])
    }
}
// END ForkNotebook

/// Shows a notebook as saved (cells, outputs, plots); "Run as Cells" turns it into a .py of cells.
final class ForkNotebookViewController: UIViewController {
    private let url: URL
    private let project: NXProject?
    private var notebook: ForkNotebook
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    static func open(_ url: URL, project: NXProject?, from presenter: UIViewController) {
        guard let data = try? Data(contentsOf: url), let notebook = ForkNotebook(data: data) else {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "\(url.lastPathComponent) is not a Jupyter notebook", withDelay: 0.0)
            return
        }
        let viewer = ForkNotebookViewController(url: url, project: project, notebook: notebook)
        let navigation = UINavigationController(rootViewController: viewer)
        navigation.modalPresentationStyle = .fullScreen
        presenter.present(navigation, animated: true)
    }

    init(url: URL, project: NXProject?, notebook: ForkNotebook) {
        self.url = url
        self.project = project
        self.notebook = notebook
        super.init(nibName: nil, bundle: nil)
        title = url.deletingPathExtension().lastPathComponent
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Run as Cells", image: UIImage(systemName: "play.rectangle"), primaryAction: UIAction { [weak self] _ in self?.runAsCells() })
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -14),
        ])
        render()
    }

    private func label(_ text: String, font: UIFont, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = font
        label.textColor = color
        label.text = text
        return label
    }

    private func render() {
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12
        let mono = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        var count = 0
        for cell in notebook.cells {
            if cell.kind == "markdown" {
                let text = UITextView()
                text.isEditable = false
                text.isScrollEnabled = false
                text.backgroundColor = .clear
                text.attributedText = ForkTextViewController.render(cell.source)
                stack.addArrangedSubview(text)
                continue
            }
            count += 1
            let box = UIStackView()
            box.axis = .vertical
            box.spacing = 8
            box.isLayoutMarginsRelativeArrangement = true
            box.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12)
            box.backgroundColor = .secondarySystemGroupedBackground
            box.layer.cornerRadius = 12
            box.addArrangedSubview(label("In [\(count)]", font: .monospacedSystemFont(ofSize: 12, weight: .semibold), color: .secondaryLabel))
            let code = label(cell.source, font: mono)
            code.backgroundColor = .tertiarySystemFill
            box.addArrangedSubview(code)
            for output in cell.outputs {
                if let data = output.image, let image = UIImage(data: data) {
                    let picture = UIImageView(image: image)
                    picture.contentMode = .scaleAspectFit
                    picture.backgroundColor = .white
                    picture.heightAnchor.constraint(equalTo: picture.widthAnchor, multiplier: min(2, max(0.2, image.size.height / max(1, image.size.width)))).isActive = true
                    box.addArrangedSubview(picture)
                }
                let text = output.text.trimmingCharacters(in: .newlines)
                if !text.isEmpty {
                    box.addArrangedSubview(label(text.count > 20000 ? String(text.prefix(20000)) + "\n…" : text, font: mono, color: output.isError ? .systemRed : .label))
                }
            }
            stack.addArrangedSubview(box)
        }
        if notebook.cells.isEmpty {
            stack.addArrangedSubview(label("This notebook has no cells.", font: .preferredFont(forTextStyle: .body), color: .secondaryLabel))
        }
    }

    /// A .py of "# %%" cells next to the notebook (in a project; else in a new Python project).
    private func runAsCells() {
        let script = url.deletingPathExtension().appendingPathExtension("py")
        let inProject = project != nil && url.path.hasPrefix((project!.url as URL).path)
        let target: URL
        if inProject {
            target = script
        } else {
            /* opened from Files: into the "Notebooks" folder of Nyxian's Python home */
            let folder = ForkPython.rootfs.appendingPathComponent("var/mobile/Notebooks")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(url.lastPathComponent))
            try? FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(url.lastPathComponent))
            target = folder.appendingPathComponent(script.lastPathComponent)
        }
        if FileManager.default.fileExists(atPath: target.path) {
            let alert = UIAlertController(title: target.lastPathComponent + " exists", message: "Replace it with the cells of the notebook?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open It", style: .cancel) { [weak self] _ in self?.openEditor(target) })
            alert.addAction(UIAlertAction(title: "Replace", style: .destructive) { [weak self] _ in self?.write(target) })
            present(alert, animated: true)
        } else {
            write(target)
        }
    }

    private func write(_ target: URL) {
        do {
            try notebook.percentScript.write(to: target, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: Notification.Name("FileListRefresh"), object: nil)
            openEditor(target)
        } catch {
            NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Could not write \(target.lastPathComponent): \(error.localizedDescription)", withDelay: 0.0)
        }
    }

    private func openEditor(_ target: URL) {
        guard let editor = CodeEditorViewController(project: project, url: target, isReadOnly: false) else { return }
        let navigation = UINavigationController(rootViewController: editor)
        navigation.modalPresentationStyle = .overFullScreen
        present(navigation, animated: true)
    }
}
