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
 Fork doctoralvarez/Nyxian — version 1.5.0
 Changelog:
  - 1.5.0 (2026-11-12): App Preview — a panel at the right of the editor
    (app projects, iPad) with the running app inside, like the preview of
    Swift Playgrounds, without #Preview or PreviewProvider. It loads once
    when the project opens; editing Swift code pauses it (a still picture of
    the app stays); saving (⌘S) builds again and, without errors, the app
    comes back. Top bar: ↻ reload and hide; the editor bar has a button to
    show it again. Settings › Customization › App Preview turns it on/off.
  - 1.4.2 (2026-11-08): ▶ while a cancelled build is still stopping says so.
  - 1.4.1 (2026-11-08): ▶ / ⌘R in a Python project runs the .py on screen (no build).
  - 1.4.0 (2026-11-07): the debugger attaches to every run (Pause /
    Continue next to the profiler, ⌃⌘Y); ⌘\\ toggles a breakpoint (editor).
  - 1.3.0 (2026-11-07): the export button opens the export assistant;
    profiler pill (CPU, memory, threads) over the console while the app runs.
  - 1.2.0 (2026-11-07): ⌃⇥ switches to the previously used tab (press again
    to go back), ⌃⇧⇥ to the least recently used one; tabs remember the order
    they were used in.
  - 1.1.0 (2026-11-07): ⇧⌘F Search in Project, ⇧⌘O Open Quickly; tapping a
    "file:line" printed in the console opens that file at that line.
  - 1.0.0 (2026-11-06): ⌘B builds without running, ⇧⌘I opens the
    Issue Navigator.
*/

import UIKit

enum PosixSignal: CustomStringConvertible {
    case hangup
    case interrupt
    case quit
    case illegal
    case trap
    case abort
    case bus
    case fpe
    case kill
    case user1
    case segv
    case user2
    case pipe
    case alarm
    case terminate
    case child
    case cont
    case stop
    case tstp
    case ttin
    case ttou
    case urgent
    case xcpu
    case xfsz
    case vtalrm
    case prof
    case winch
    case sys
    
    var rawValue: Int32 {
        switch self {
            case .hangup: return SIGHUP
            case .interrupt: return SIGINT
            case .quit: return SIGQUIT
            case .illegal: return SIGILL
            case .trap: return SIGTRAP
            case .abort: return SIGABRT
            case .bus: return SIGBUS
            case .fpe: return SIGFPE
            case .kill: return SIGKILL
            case .user1: return SIGUSR1
            case .segv: return SIGSEGV
            case .user2: return SIGUSR2
            case .pipe: return SIGPIPE
            case .alarm: return SIGALRM
            case .terminate: return SIGTERM
            case .child: return SIGCHLD
            case .cont: return SIGCONT
            case .stop: return SIGSTOP
            case .tstp: return SIGTSTP
            case .ttin: return SIGTTIN
            case .ttou: return SIGTTOU
            case .urgent: return SIGURG
            case .xcpu: return SIGXCPU
            case .xfsz: return SIGXFSZ
            case .vtalrm: return SIGVTALRM
            case .prof: return SIGPROF
            case .winch: return SIGWINCH
            case .sys: return SIGSYS
        }
    }
    
    init?(rawValue: Int32) {
        switch rawValue {
            case SIGHUP: self = .hangup
            case SIGINT: self = .interrupt
            case SIGQUIT: self = .quit
            case SIGILL: self = .illegal
            case SIGTRAP: self = .trap
            case SIGABRT: self = .abort
            case SIGBUS: self = .bus
            case SIGFPE: self = .fpe
            case SIGKILL: self = .kill
            case SIGUSR1: self = .user1
            case SIGSEGV: self = .segv
            case SIGUSR2: self = .user2
            case SIGPIPE: self = .pipe
            case SIGALRM: self = .alarm
            case SIGTERM: self = .terminate
            case SIGCHLD: self = .child
            case SIGCONT: self = .cont
            case SIGSTOP: self = .stop
            case SIGTSTP: self = .tstp
            case SIGTTIN: self = .ttin
            case SIGTTOU: self = .ttou
            case SIGURG: self = .urgent
            case SIGXCPU: self = .xcpu
            case SIGXFSZ: self = .xfsz
            case SIGVTALRM: self = .vtalrm
            case SIGPROF: self = .prof
            case SIGWINCH: self = .winch
            case SIGSYS: self = .sys
            default: return nil
        }
    }

    var description: String {
        switch self {
            case .hangup: return "SIGHUP: Hangup detected on controlling terminal"
            case .interrupt: return "SIGINT: Interrupt from keyboard"
            case .quit: return "SIGQUIT: Quit from keyboard"
            case .illegal: return "SIGILL: Illegal Instruction"
            case .trap: return "SIGTRAP: Trace/breakpoint trap"
            case .abort: return "SIGABRT: Abort signal"
            case .bus: return "SIGBUS: Bus error (bad memory access)"
            case .fpe: return "SIGFPE: Floating-point exception"
            case .kill: return "SIGKILL: Kill signal (forced termination)"
            case .user1: return "SIGUSR1: User-defined signal 1"
            case .segv: return "SIGSEGV: Segmentation fault (invalid memory reference)"
            case .user2: return "SIGUSR2: User-defined signal 2"
            case .pipe: return "SIGPIPE: Broken pipe"
            case .alarm: return "SIGALRM: Timer signal from alarm()"
            case .terminate: return "SIGTERM: Termination signal"
            case .child: return "SIGCHLD: Child process stopped or terminated"
            case .cont: return "SIGCONT: Continue if stopped"
            case .stop: return "SIGSTOP: Stop process"
            case .tstp: return "SIGTSTP: Stop typed at terminal"
            case .ttin: return "SIGTTIN: Terminal input for background process"
            case .ttou: return "SIGTTOU: Terminal output for background process"
            case .urgent: return "SIGURG: Urgent condition on socket"
            case .xcpu: return "SIGXCPU: CPU time limit exceeded"
            case .xfsz: return "SIGXFSZ: File size limit exceeded"
            case .vtalrm: return "SIGVTALRM: Virtual alarm clock"
            case .prof: return "SIGPROF: Profiling timer expired"
            case .winch: return "SIGWINCH: Window resize signal"
            case .sys: return "SIGSYS: Bad system call"
        }
    }
}

class UIHitTestExtendedView: UIView {
    var hitTestInsets = UIEdgeInsets(top: -15, left: 0, bottom: -15, right: 0)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Too big fingers!!!
        let largerArea = bounds.inset(by: hitTestInsets)
        return largerArea.contains(point)
    }
}

class MainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    let project: NXProject
    var masterVC: FileListViewController?
    var detailVC: SplitScreenDetailViewController?
    var lock: os_unfair_lock = os_unfair_lock()
    /* fork: App Preview */
    var forkPreview: ForkAppPreviewContainer?
    
    init(project: NXProject) {
        self.project = project
        super.init(style: .doubleColumn)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        
        masterVC = FileListViewController(project: project)
        detailVC = SplitScreenDetailViewController(project: project)

        if let masterVC = masterVC,
           let detailVC = detailVC {
            let masterNav = UINavigationController(rootViewController: masterVC)
            let detailNav = UINavigationController(rootViewController: detailVC)
            
            /* fork: the App Preview panel at the right of the editor (app projects) */
            if ForkAppPreview.isAvailable(for: project) {
                let container = ForkAppPreviewContainer(content: detailNav, project: project, detail: detailVC)
                self.forkPreview = container
                self.viewControllers = [masterNav, container]
            } else {
                self.viewControllers = [masterNav,detailNav]
            }
        }

        self.displayModeButtonVisibility = .never
        
        if self.project.projectConfig.schemeKind == .app {
            NXWindowSessionApplication.bringSessionToFront(withBundleIdentifier: self.project.projectConfig.bundleid)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(invokeBuild), name: Notification.Name("RunAct"), object: nil)
        NXApplicationState.fileListRequiresToSendRequests = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        NXApplicationState.fileListRequiresToSendRequests = false
    }
    
    override var keyCommands: [UIKeyCommand]? {
        let closeCommand = UIKeyCommand(title: "Close", action: #selector(self.detailVC?.closeCurrentTab), input: "W", modifierFlags: [.command])
        let runCommand = UIKeyCommand(title: "Run", action: #selector(self.invokeBuild), input: "R", modifierFlags: [.command])
        
        closeCommand.wantsPriorityOverSystemBehavior = true
        
        /* fork: build-only and issue navigator shortcuts */
        let buildCommand = UIKeyCommand(title: "Build", action: #selector(self.invokeBuildOnly), input: "B", modifierFlags: [.command])
        let issuesCommand = UIKeyCommand(title: "Show Issues", action: #selector(self.showIssueNavigator), input: "I", modifierFlags: [.command, .shift])
        buildCommand.wantsPriorityOverSystemBehavior = true
        issuesCommand.wantsPriorityOverSystemBehavior = true
        
        let searchCommand = UIKeyCommand(title: "Search in Project", action: #selector(self.showProjectSearch), input: "F", modifierFlags: [.command, .shift])
        let quickOpenCommand = UIKeyCommand(title: "Open Quickly", action: #selector(self.showQuickOpen), input: "O", modifierFlags: [.command, .shift])
        searchCommand.wantsPriorityOverSystemBehavior = true
        quickOpenCommand.wantsPriorityOverSystemBehavior = true
        
        /* fork: recently used tabs */
        let previousFileCommand = UIKeyCommand(title: "Previous File", action: #selector(self.showPreviousFile), input: "\t", modifierFlags: [.control])
        let oldestFileCommand = UIKeyCommand(title: "Least Recent File", action: #selector(self.showLeastRecentFile), input: "\t", modifierFlags: [.control, .shift])
        previousFileCommand.wantsPriorityOverSystemBehavior = true
        oldestFileCommand.wantsPriorityOverSystemBehavior = true
        
        /* fork: debugger */
        let pauseCommand = UIKeyCommand(title: "Pause or Continue", action: #selector(self.debugPauseOrContinue), input: "y", modifierFlags: [.command, .control])
        pauseCommand.wantsPriorityOverSystemBehavior = true
        
        return [closeCommand, runCommand, buildCommand, issuesCommand, searchCommand, quickOpenCommand, previousFileCommand, oldestFileCommand, pauseCommand]
    }
    
    @objc func debugPauseOrContinue() {
        let debugger = NXForkDebugger.shared()
        guard debugger.attached else { return }
        if debugger.stopped {
            debugger.resume()
        } else {
            DispatchQueue.global(qos: .userInitiated).async { _ = debugger.pause() }
        }
    }
    
    @objc func showPreviousFile() {
        self.detailVC?.forkSelectRecentTab(leastRecent: false)
    }
    
    @objc func showLeastRecentFile() {
        self.detailVC?.forkSelectRecentTab(leastRecent: true)
    }
    
    /* fork: project-wide search and quick open from the keyboard */
    @objc func showProjectSearch() {
        self.detailVC?.forkPresentProjectSearch(self.project)
    }
    
    @objc func showQuickOpen() {
        self.detailVC?.forkPresentQuickOpen(self.project)
    }
    
    /* fork: compile and link without signing, installing or running */
    @objc func invokeBuildOnly() {
        guard let detailVC = self.detailVC,
              !NXBuilder.builds,
              os_unfair_lock_trylock(&self.lock) else { return }
        
        self.masterVC?.navigationItem.leftBarButtonItem?.isEnabled = false
        
        buildProjectWithArgumentUI(targetViewController: detailVC, project: detailVC.project, buildType: .build) { [weak self] _, _ in
            guard let self = self else { return }
            self.masterVC?.navigationItem.leftBarButtonItem?.isEnabled = true
            os_unfair_lock_unlock(&self.lock)
        }
    }
    
    /* fork: open the Issue Navigator from the keyboard */
    @objc func showIssueNavigator() {
        guard let detailVC = self.detailVC,
              detailVC.presentedViewController == nil else { return }
        let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
        loggerView.modalPresentationStyle = .formSheet
        detailVC.present(loggerView, animated: true)
    }
    
    @objc func invokeBuild() {
        /* fork: a cancelled build can still be finishing its current step */
        if NXBuilder.builds && NXBuilder.forkCancelRequested {
            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "The cancelled build is still stopping, try again in a moment", withDelay: 0.0)
            return
        }
        NXDocumentManager.shared().saveAll { [weak self] in
            /* fork: a Python project runs its script, there is nothing to build */
            if let self, let detailVC = self.detailVC, ForkPython.isPythonProject(detailVC.project) {
                ForkPython.runProject(detailVC.project, from: detailVC)
                return
            }
            guard let self = self,
                  let masterVC = self.masterVC,
                  let detailVC = self.detailVC,
                  os_unfair_lock_trylock(&self.lock) else {
                /* fork: busy — the App Preview should not wait forever */
                if let path = self?.project.url.path {
                    NotificationCenter.default.post(name: ForkAppPreview.runFinished, object: path, userInfo: ["result": false, "busy": true])
                }
                return
            }
            do {
                
                let project = detailVC.project
                
                masterVC.navigationItem.leftBarButtonItem?.isEnabled = false
                self.detailVC?.logView?.clearConsole()
                
                buildProjectWithArgumentUI(targetViewController: detailVC, project: project, buildType: .run) { [weak self] result, execPath in
                    if let process = detailVC.process {
                        process.remove(detailVC)
                        detailVC.process = nil
                    }
                    
                    guard let self = self else { return }
                    masterVC.navigationItem.leftBarButtonItem?.isEnabled = true
                    os_unfair_lock_unlock(&self.lock)
                    /* fork: App Preview follows every run */
                    defer { NotificationCenter.default.post(name: ForkAppPreview.runFinished, object: project.url.path, userInfo: ["result": result]) }
                    
                    if result {
                        let fileTable: PEFileTable = PEFileTable.empty()
                        
                        if let logView = detailVC.logView {
                            fileTable.appendFileDescriptor(logView.pipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDOUT_FILENO)
                            fileTable.appendFileDescriptor(logView.pipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: STDERR_FILENO)
                            fileTable.appendFileDescriptor(logView.stdinPipe.fileHandleForReading.fileDescriptor, withMappingToLoc: STDIN_FILENO)
                            
                            fileTable.appendFileDescriptor(logView.pipe.fileHandleForReading.fileDescriptor, withMappingToLoc: 100)
                            fileTable.appendFileDescriptor(logView.stdinPipe.fileHandleForWriting.fileDescriptor, withMappingToLoc: 101)
                        }
                        
                        var processIdentifier: pid_t = -1
                        
                        if project.projectConfig.schemeKind == .app {
                            processIdentifier = PEProcessManager.shared().spawnProcess(withBundleIdentifier: project.projectConfig.bundleid, withItems: ["PEFileTable":fileTable], withKernelSurfaceProcess: nil, doRestartIfRunning: true)
                        } else if project.projectConfig.schemeKind == .utility, let execPath = execPath {
                            guard let homePath: String = LDEApplicationWorkspace.shared().utilityHomePath() else {
                                return
                            }
                            
                            processIdentifier = PEProcessManager.shared().spawnProcess(withItems: [
                                "PEExecutablePath": execPath,
                                "PEArguments": [
                                    execPath
                                ],
                                "PEEnvironment": [
                                    "HOME": homePath,
                                    "CFFIXED_USER_HOME": homePath,
                                    "TMPDIR": (homePath as NSString).appendingPathComponent("/Tmp")
                                ],
                                "PEWorkingDirectory": homePath,
                                "PEFileTable": fileTable,
                            ], withKernelSurfaceProcess: nil)
                        }
                        
                        if processIdentifier > 0,
                           let process: PEProcess = PEProcessManager.shared().process(forProcessIdentifier: processIdentifier) {
                            process.add(detailVC)
                            detailVC.process = process
                            /* fork: debugger */
                            ForkDebugSession.shared.start(processIdentifier: processIdentifier, project: project)
                        } else {
                            if let logView = detailVC.logView {
                                logView.writeMessage(toConsole: "failed to spawn process")
                            }
                        }
                    }
                }
            }
        }
    }
}

class SplitScreenDetailViewController: UIViewController, PEProcessObserver {
    let project: NXProject
    
    var lock: os_unfair_lock = os_unfair_lock()
    var process: PEProcess? = nil
    
    var logView: NXConsoleView?
    var logViewHeightConstraint: NSLayoutConstraint?
    var logViewHeight: CGFloat = 300
    let resizeHandle = {
        let logTopBorder = UIHitTestExtendedView()
        logTopBorder.translatesAutoresizingMaskIntoConstraints = false
        logTopBorder.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.white.withAlphaComponent(0.2)
        return logTopBorder
    }()
    
    let emptyEditorVC: UIViewController = {
        let emptyEditorVC: UIViewController = UIViewController()
        emptyEditorVC.view.backgroundColor = LDETheme.currentTheme?.backgroundColor
        let label: UILabel = UILabel()
        label.text = "Empty Editor"
        label.translatesAutoresizingMaskIntoConstraints = false
        emptyEditorVC.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: emptyEditorVC.view.safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: emptyEditorVC.view.safeAreaLayoutGuide.centerYAnchor)
        ])
        return emptyEditorVC
    }()
    
    var childVCMasterConstraints: [NSLayoutConstraint]?
    var childVCMaster: UIViewController?
    var childVC: UIViewController? {
        get {
            childVCMaster
        }
        set {
            os_unfair_lock_lock(&self.lock)
            defer { os_unfair_lock_unlock(&self.lock) }
            
            if let oldVC = childVCMaster {
                if oldVC == newValue {
                    return
                }
                
                // Animate oldVC out
                UIView.animate(withDuration: 0.3, animations: {
                    oldVC.view.alpha = 0
                }, completion: { _ in
                    oldVC.view.removeFromSuperview()
                    oldVC.removeFromParent()
                })
            }
            
            // trying to get old constraints
            if let oldConstraints = self.childVCMasterConstraints {
                NSLayoutConstraint.deactivate(oldConstraints)
            }
            
            // setting to new view controller
            childVCMaster = newValue
            
            let vc = newValue ?? self.emptyEditorVC
            self.addChild(vc)
            vc.view.alpha = 0
            self.view.addSubview(vc.view)
            
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            
            let constraints: [NSLayoutConstraint] = {
                var isIOS26: Bool = false
                var isIOS27: Bool = false
                
                if #available(iOS 26.0, *) {
                    if #unavailable(iOS 27.0) {
                        isIOS26 = true
                    } else {
                        isIOS27 = true
                    }
                }
                
                let hconstrains: NSLayoutConstraint = logView!.heightAnchor.constraint(equalToConstant: logViewHeight)
                self.logViewHeightConstraint = hconstrains
                
                return [
                    vc.view.topAnchor.constraint(equalTo: isIOS27 ? view.topAnchor : view.safeAreaLayoutGuide.topAnchor),
                    vc.view.bottomAnchor.constraint(equalTo: logView!.topAnchor, constant: isIOS26 ? -16 : 0),
                    vc.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: isIOS26 ? 16 : 0),
                    vc.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: isIOS26 ? -16 : 0),
                    hconstrains
                ]
            }()
            
            if #available(iOS 27.0, *) {
                let leftEdge = UIView()
                leftEdge.translatesAutoresizingMaskIntoConstraints = false
                leftEdge.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.white.withAlphaComponent(0.2)
                vc.view.addSubview(leftEdge)
                
                NSLayoutConstraint.activate([
                    leftEdge.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                    leftEdge.topAnchor.constraint(equalTo: vc.view.topAnchor),
                    leftEdge.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                    leftEdge.widthAnchor.constraint(equalToConstant: 0.5),
                ])
            } else if #available(iOS 26.0, *) {
                vc.view.layer.cornerRadius = 20
                vc.view.layer.cornerCurve = .continuous
                vc.view.layer.borderWidth = 1.0
                vc.view.layer.borderColor = LDETheme.currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
                vc.view.layer.masksToBounds = true
            }
            
            self.childVCMasterConstraints = constraints
            NSLayoutConstraint.activate(constraints)
            
            UIView.animate(withDuration: 0.3) {
                vc.view.alpha = 1
            }
            
            self.view.bringSubviewToFront(self.resizeHandle)
        }
    }
    var childButton: UIButtonTab?
    
    private let scrollView = FileTabBar()
    private let tabBarView = UIView()
    private var stack: FileTabStack {
        get {
            scrollView.stackView
        }
    }
    private var tabs: [UIButtonTab] = []
    /* fork: tabs by last use, most recent first */
    private var recentTabs: [URL] = []
    
    private func forkTouchRecent(_ url: URL) {
        recentTabs.removeAll { $0 == url }
        recentTabs.insert(url, at: 0)
    }
    
    /// ⌃⇥ goes to the tab used before this one; ⌃⇧⇥ to the one unused the longest.
    func forkSelectRecentTab(leastRecent: Bool) {
        recentTabs.removeAll { url in !tabs.contains { $0.url == url } }
        guard recentTabs.count > 1 else { return }
        let target = leastRecent ? recentTabs[recentTabs.count - 1] : recentTabs[1]
        guard let button = tabs.first(where: { $0.url == target }) else { return }
        childButton = button
        childVC = button.vc
        updateTabSelection(selectedTab: button)
        forkTouchRecent(target)
    }
    
    func openPath(url: URL, line: CFIndex, column: CFIndex, isReadOnly: Bool) {
        if let existingTab = tabs.first(where: { $0.url == url }) {
            forkTouchRecent(url)
            self.childButton = existingTab
            self.childVC = existingTab.vc
            (self.childVC as! CodeEditorViewController).goto(location: MDKSourceLocationMake(line, column))
            updateTabSelection(selectedTab: existingTab)
            return
        }
        
        let open: (UIButtonTab) -> Void = { [weak self] button in
            guard let self = self else { return }
            self.childButton = button
            self.childVC = button.vc
            self.updateTabSelection(selectedTab: button)
            self.forkTouchRecent(button.url)
        }
        
        let close: (UIButtonTab) -> Void = { [weak self] button in
            guard let self = self else { return }
            
            let wasSelected = self.childButton == button
            
            if self.childVC == button.vc {
                self.childVC = nil
            }
            guard let index = self.tabs.firstIndex(of: button) else { return }
            
            button.removeTarget(nil, action: nil, for: .allEvents)
            
            self.scrollView.removeArrangedSubview(button)
            button.removeFromSuperview()
            self.tabs.remove(at: index)
            
            if wasSelected {
                var newSelectedTab: UIButtonTab? = nil
                if self.tabs.count > 0 {
                    if index < self.tabs.count {
                        newSelectedTab = self.tabs[index]
                    } else if index - 1 >= 0 {
                        newSelectedTab = self.tabs[index - 1]
                    }
                }
                
                if let tabToSelect = newSelectedTab {
                    self.childButton = tabToSelect
                    self.childVC = tabToSelect.vc
                    self.updateTabSelection(selectedTab: tabToSelect)
                } else {
                    self.childButton = nil
                    self.childVC = nil
                    self.updateTabSelection(selectedTab: nil)
                }
            } else {
                self.updateTabSelection(selectedTab: self.childButton)
            }
        }
        
        guard let button = UIButtonTab(frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                       project: self.project,
                                       url: url,
                                       line: line,
                                       column: column,
                                       openAction: open,
                                       closeAction: close,
                                       isReadOnly: isReadOnly) else {
            return
        }
        
        self.scrollView.addArrangedSubview(button)
        self.tabs.append(button)
        
        self.updateTabSelection(selectedTab: button)
    }
    
    func closeTab(url: URL) {
        guard let button = tabs.first(where: { $0.url == url }) else { return }
        guard let index = tabs.firstIndex(of: button) else { return }
        
        button.removeTarget(nil, action: nil, for: .allEvents)
        
        scrollView.removeArrangedSubview(button)
        button.removeFromSuperview()
        tabs.remove(at: index)
        
        if childButton == button {
            childVC = nil
            childButton = nil
            
            var newSelectedTab: UIButtonTab? = nil
            if tabs.count > 0 {
                if index < tabs.count {
                    newSelectedTab = tabs[index]
                } else if index - 1 >= 0 {
                    newSelectedTab = tabs[index - 1]
                }
            }
            
            if let tabToSelect = newSelectedTab {
                childButton = tabToSelect
                childVC = tabToSelect.vc
                updateTabSelection(selectedTab: tabToSelect)
            } else {
                updateTabSelection(selectedTab: nil)
            }
        } else {
            updateTabSelection(selectedTab: childButton)
        }
    }

    init(project: NXProject) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = LDETheme.currentTheme?.gutterBackgroundColor
        
        /* setting up logview */
        logView = NXConsoleView()
        logView!.isEditable = true
        logView!.isSelectable = true
        if #available(iOS 26.0, *) {
            if #unavailable(iOS 27.0) {
                logView!.layer.cornerRadius = 20
                logView!.layer.cornerCurve = .continuous
                logView!.layer.borderWidth = 1.0
                logView!.layer.borderColor = LDETheme.currentTheme?.gutterHairlineColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
                logView!.layer.masksToBounds = true
            }
        }
        logView!.translatesAutoresizingMaskIntoConstraints = false
        logView!.backgroundColor = LDETheme.currentTheme?.backgroundColor
        logView!.textColor = LDETheme.currentTheme?.textColor
        self.view.addSubview(logView!)
        
        if #available(iOS 27.0, *) {
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            let logLeftBorder = UIView()
            logLeftBorder.translatesAutoresizingMaskIntoConstraints = false
            logLeftBorder.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.white.withAlphaComponent(0.2)
            self.view.addSubview(logLeftBorder)
            
            NSLayoutConstraint.activate([
                logLeftBorder.leadingAnchor.constraint(equalTo: logView!.leadingAnchor),
                logLeftBorder.topAnchor.constraint(equalTo: logView!.topAnchor),
                logLeftBorder.bottomAnchor.constraint(equalTo: logView!.bottomAnchor),
                logLeftBorder.widthAnchor.constraint(equalToConstant: 0.5)
            ])
        } else if #available(iOS 26.0, *) {
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
            ])
            
            self.resizeHandle.backgroundColor = .clear
        } else { // iOS 18 fallback
            NSLayoutConstraint.activate([
                logView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                logView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                logView!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        self.view.addSubview(self.resizeHandle)
        
        /* fork: live CPU / memory of the running app, over the console */
        let profiler = ForkRuntimeBar { [weak self] in self?.process }
        profiler.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(profiler)
        NSLayoutConstraint.activate([
            profiler.topAnchor.constraint(equalTo: logView!.topAnchor, constant: 8),
            profiler.trailingAnchor.constraint(equalTo: logView!.trailingAnchor, constant: -10)
        ])
        
        NSLayoutConstraint.activate([
            self.resizeHandle.topAnchor.constraint(equalTo: logView!.topAnchor),
            self.resizeHandle.leadingAnchor.constraint(equalTo: logView!.leadingAnchor),
            self.resizeHandle.trailingAnchor.constraint(equalTo: logView!.trailingAnchor),
            self.resizeHandle.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        resizeHandle.addGestureRecognizer(pan)
        
        self.navigationItem.titleView = self.scrollView
        
        var barButtons: [UIBarButtonItem] = []
        if !NXApplicationState.extensionLessMode {
            barButtons.append(UIBarButtonItem(image: UIImage(systemName: "play.fill"), primaryAction: UIAction { _ in
                NotificationCenter.default.post(name: NSNotification.Name("RunAct"), object: nil)
            }))
        }
        barButtons.append(UIBarButtonItem(image: UIImage(systemName: "archivebox.fill"), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            /* fork: version and checks first */
            ForkExportAssistant.present(from: self, project: self.project)
        }))
        barButtons.append(UIBarButtonItem(image: UIImage(systemName: "exclamationmark.triangle.fill"), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
            loggerView.modalPresentationStyle = .formSheet
            self.present(loggerView, animated: true)
        }))
        self.navigationItem.rightBarButtonItems = barButtons
        
        childVC = nil
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            if let vc = self.childVCMaster {
                vc.view.layer.borderColor = LDETheme.currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
            }
            self.logView?.layer.borderColor = LDETheme.currentTheme?.backgroundColor.cgColor ?? UIColor.white.withAlphaComponent(0.2).cgColor
        }
    }
    
    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self.view)
        
        let minHeight: CGFloat = 80
        let maxHeight: CGFloat = self.view.bounds.height * 0.7
        
        let bottomEdge = self.view.bounds.height - 16
        let newHeight = bottomEdge - location.y
        
        logViewHeight = max(minHeight, min(maxHeight, newHeight))
        logViewHeightConstraint?.constant = logViewHeight
        
        UIView.animate(withDuration: 0.0) {
            self.view.layoutIfNeeded()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMyNotification(_:)), name: Notification.Name("FileListAct"), object: nil)
        /* fork: tapped "file:line" in the console */
        NotificationCenter.default.addObserver(self, selector: #selector(handleConsoleSourceLocation(_:)), name: Notification.Name("NXConsoleOpenSourceLocation"), object: nil)
    }
    
    /* fork: open the file and line a running program printed (Swift runtime traps, compiler-style paths) */
    @objc func handleConsoleSourceLocation(_ notification: Notification) {
        guard let console = notification.object as? NXConsoleView, console === self.logView,
              let info = notification.userInfo,
              let rawPath = info["path"] as? String,
              let line = (info["line"] as? NSNumber)?.intValue else { return }
        let column = (info["column"] as? NSNumber)?.intValue ?? 1
        
        guard let url = resolveConsoleSourcePath(rawPath) else {
            let alert = UIAlertController(
                title: "File Not in Project",
                message: "\(rawPath) is not part of this project. It may belong to the Swift runtime or the SDK.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        self.openPath(url: url, line: CFIndex(line), column: CFIndex(column), isReadOnly: false)
    }
    
    /// Absolute paths are used as they are; relative ones ("Module/File.swift") match the project file sharing the longest path suffix.
    private func resolveConsoleSourcePath(_ rawPath: String) -> URL? {
        if rawPath.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: rawPath) ? URL(fileURLWithPath: rawPath) : nil
        }
        
        let wanted = rawPath.split(separator: "/").map(String.init)
        guard !wanted.isEmpty else { return nil }
        
        var best: (url: URL, matched: Int)?
        for url in ProjectFileIndex.files(in: self.project.url) {
            let parts = url.standardizedFileURL.pathComponents
            var matched = 0
            while matched < wanted.count,
                  matched < parts.count,
                  parts[parts.count - 1 - matched] == wanted[wanted.count - 1 - matched] {
                matched += 1
            }
            if matched > 0, matched > (best?.matched ?? 0) {
                best = (url, matched)
            }
        }
        return best?.url
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleMyNotification(_ notification: Notification) {
        guard let args = notification.object as? [String] else { return }
        if args.count > 1 {
            switch(args[0]) {
            case "open":
                self.openPath(url: URL(fileURLWithPath: args[1]), line: CFIndex(args[2]) ?? 0, column: CFIndex(args[3]) ?? 0, isReadOnly: (args.count >= 5 && args[4] == "1"))
                break
            case "close":
                self.closeTab(url: URL(fileURLWithPath: args[1]))
                break
            default:
                break
            }
        }
    }
    
    private func updateTabSelection(selectedTab: UIButtonTab?) {
        let selectedColor: UIColor
        
        if #available(iOS 26.0, *) {
            selectedColor = LDETheme.currentTheme?.appTableCell ?? UIColor.systemGray2
        } else {
            selectedColor = LDETheme.currentTheme?.appTableCell ?? UIColor.systemGray2
        }
        
        let unselectedColor: UIColor = .clear
        
        for tab in tabs {
            let isSelected: Bool = (tab == selectedTab)
            let targetColor: UIColor = isSelected ? selectedColor : unselectedColor
            UIView.animate(withDuration: 0.25) {
                tab.backgroundColor = targetColor
                tab.setSelected(isSelected)
            }
        }
    }
    
    @objc func closeCurrentTab() {
        if let childButton = self.childButton {
            childButton.closeAction(childButton)
        }
    }
    
    func process(_ process: PEProcess!, didExitWithWait4Code code: Int32) {
        ForkDebugSession.shared.processExited(process)
        DispatchQueue.main.sync {
            if let logView = self.logView {
                let signalBits = code & 0x7F
                let isStopped = signalBits == 0x7F
                
                if signalBits == 0 {
                    let exitCode = (code >> 8) & 0xFF
                    logView.writeMessage(toConsole: "process did exit with code: \(exitCode)", with: exitCode == 0 ? .systemGreen : .systemRed)
                } else if !isStopped {
                    let signalNumber = signalBits
                    var color: UIColor = .systemYellow
                    if(signalNumber == 9) {
                        color = .systemRed
                    }
                    logView.writeMessage(toConsole: "process was killed by signal: \(signalNumber) (\(PosixSignal(rawValue: signalNumber)?.description ?? "SIGUNKNOWN"))", with: color)
                } else {
                    // IDK how this would happen
                    let stopSignal = (code >> 8) & 0xFF
                    logView.writeMessage(toConsole: "process was stopped by signal: \(stopSignal) (\(PosixSignal(rawValue: stopSignal)?.description ?? "SIGUNKNOWN"))", with: .yellow)
                }
            }
        }
    }
}

class UIButtonTab: UIButton {
    var url: URL {
        get {
            self.vc.file.fileURL
        }
    }
    let vc: CodeEditorViewController
    let closeAction: (UIButtonTab) -> Void
    
    private var closeButton: UIButton?
    private let fileIcon: FileIcon
    
    init?(frame: CGRect,
          project: NXProject,
          url: URL,
          line: CFIndex,
          column: CFIndex,
          openAction: @escaping (UIButtonTab) -> Void,
          closeAction: @escaping (UIButtonTab) -> Void,
          isReadOnly: Bool) {
        
        guard let codeEditor = CodeEditorViewController(project: project, url: url, line: line, column: column, isReadOnly: isReadOnly) else {
            return nil
        }
        
        self.vc = codeEditor
        self.closeAction = closeAction
        
        self.fileIcon = FileIcon(withFontSize: 15)
        
        super.init(frame: frame)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        self.setTitle(self.url.lastPathComponent, for: .normal)
        self.setTitleColor(LDETheme.currentTheme?.textColor, for: .normal)
        self.titleLabel?.font = .systemFont(ofSize: 13)
        self.contentHorizontalAlignment = .center
        self.contentVerticalAlignment = .center
        self.titleLabel?.textAlignment = .center
        
        if #available(iOS 26.0, *) {
            self.layer.cornerRadius = 13
            self.layer.cornerCurve = .continuous
        } else {
            self.layer.cornerRadius = 10
            self.layer.cornerCurve = .continuous
        }
        
        self.layer.masksToBounds = true
        
        fileIcon.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(fileIcon)
        NSLayoutConstraint.activate([
            fileIcon.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            fileIcon.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5),
            fileIcon.heightAnchor.constraint(equalTo: self.heightAnchor, constant: -10),
            fileIcon.widthAnchor.constraint(equalTo: fileIcon.heightAnchor)
        ])
        
        fileIcon.configure(with: FileListEntry(name: self.url.lastPathComponent, path: self.url.path, isLink: false, type: .file))
        
        self.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            openAction(s)
        }, for: .touchUpInside)
        
        openAction(self)
        
        self.contentEdgeInsets = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 28) // make room for close button
        
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)), for: .normal)
        closeButton.tintColor = LDETheme.currentTheme?.textColor.withAlphaComponent(0.6)
        closeButton.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            closeAction(s)
        }, for: .touchUpInside)
        
        self.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -6),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18)
        ])
        self.closeButton = closeButton
    }
    
    func setSelected(_ selected: Bool) {
        self.closeButton?.isHidden = !selected
    }
    
    private var storedMenu: UIMenu?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            return self?.storedMenu
        }
    }
}

extension UIColor {
    func brighter(by percentage: CGFloat = 30.0) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        
        let newBrightness = min(brightness + percentage/100, 1)
        return UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha)
    }
}

// MARK: - Fork: App Preview panel

/// The running app in a panel at the right of the editor (like the preview of
/// Swift Playgrounds). No #Preview or PreviewProvider: it is the app itself,
/// built and run once when the project opens. Editing Swift code pauses it
/// (a still picture stays); saving builds again and, when it builds without
/// errors, the app comes back.
enum ForkAppPreview {
    static let enabledKey = "fork.appPreview"
    static let visibleKey = "fork.appPreview.visible"
    static let codeChanged = Notification.Name("ForkAppPreviewCodeChanged")
    static let codeSaved = Notification.Name("ForkAppPreviewCodeSaved")
    static let runFinished = Notification.Name("ForkAppPreviewRunFinished")

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func isAvailable(for project: NXProject) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && isEnabled
            && !NXApplicationState.extensionLessMode
            && project.projectConfig.schemeKind == .app
            && ForkPython.scriptKind(of: project) == nil
    }
}

final class ForkAppPreviewContainer: UIViewController {
    private enum State {
        case idle, building, waitingWindow, running, paused, failed, stopped
    }

    private let content: UIViewController
    private let project: NXProject
    private weak var detail: SplitScreenDetailViewController?
    private let projectPath: String

    private let panel = UIView()
    private let divider = UIView()
    private let header = UIStackView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let dockArea = UIView()
    private let snapshotView = UIImageView()
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var panelWidth: NSLayoutConstraint!

    private var state: State = .idle
    private var visible: Bool = UserDefaults.standard.object(forKey: ForkAppPreview.visibleKey) as? Bool ?? true
    private var timer: Timer?
    private var loadedOnce = false
    private var waitUntil = Date.distantPast
    private var graceUntil = Date.distantPast
    private var busyRetries = 0
    private var changedDuringBuild = false
    private var saveWork: DispatchWorkItem?
    private var toggleItem: UIBarButtonItem?
    private var pauseWhenRunning = false

    /// The live app shows while it runs (and while it first builds); while
    /// paused or rebuilding after a change, the still picture shows instead
    private var liveVisible: Bool {
        switch state {
        case .running, .waitingWindow, .idle, .stopped: return true
        case .building: return snapshotView.image == nil
        case .paused, .failed: return false
        }
    }

    init(content: UIViewController, project: NXProject, detail: SplitScreenDetailViewController?) {
        self.content = content
        self.project = project
        self.detail = detail
        self.projectPath = project.url.path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var bundleIdentifier: String { project.projectConfig.bundleid ?? "" }

    /// The panel shows only when there is room (not in a narrow Split View)
    private var hasRoom: Bool {
        traitCollection.horizontalSizeClass != .compact && view.bounds.width >= 600
    }

    private var isShown: Bool { visible && hasRoom }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LDETheme.currentTheme?.gutterBackgroundColor

        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        content.didMove(toParent: self)

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = LDETheme.currentTheme?.gutterBackgroundColor ?? .secondarySystemBackground
        panel.clipsToBounds = true
        view.addSubview(panel)

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.separator
        panel.addSubview(divider)

        titleLabel.text = "App Preview"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = LDETheme.currentTheme?.textColor ?? .label
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        statusLabel.lineBreakMode = .byTruncatingTail
        let titles = UIStackView(arrangedSubviews: [titleLabel, statusLabel])
        titles.axis = .vertical
        titles.spacing = 1

        let reload = UIButton(type: .system)
        reload.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        reload.accessibilityLabel = "Reload Preview"
        reload.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        let hide = UIButton(type: .system)
        hide.setImage(UIImage(systemName: "sidebar.right"), for: .normal)
        hide.accessibilityLabel = "Hide Preview"
        hide.addTarget(self, action: #selector(hideTapped), for: .touchUpInside)
        for button in [reload, hide] {
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }

        header.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 6
        header.addArrangedSubview(titles)
        header.addArrangedSubview(UIView())
        header.addArrangedSubview(spinner)
        header.addArrangedSubview(reload)
        header.addArrangedSubview(hide)
        panel.addSubview(header)

        dockArea.translatesAutoresizingMaskIntoConstraints = false
        dockArea.backgroundColor = LDETheme.currentTheme?.backgroundColor ?? .systemBackground
        dockArea.layer.cornerRadius = 14
        dockArea.layer.cornerCurve = .continuous
        dockArea.layer.borderWidth = 0.5
        dockArea.layer.borderColor = (LDETheme.currentTheme?.gutterHairlineColor ?? UIColor.separator).cgColor
        dockArea.clipsToBounds = true
        panel.addSubview(dockArea)

        snapshotView.translatesAutoresizingMaskIntoConstraints = false
        snapshotView.contentMode = .scaleAspectFit
        snapshotView.alpha = 0.45
        dockArea.addSubview(snapshotView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textColor = .secondaryLabel
        dockArea.addSubview(messageLabel)

        panelWidth = panel.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.trailingAnchor.constraint(equalTo: panel.leadingAnchor),

            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panelWidth,

            divider.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            divider.topAnchor.constraint(equalTo: panel.topAnchor),
            divider.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),

            header.topAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.topAnchor, constant: 6),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8),
            header.heightAnchor.constraint(equalToConstant: 40),

            dockArea.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            dockArea.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
            dockArea.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -10),
            dockArea.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            snapshotView.topAnchor.constraint(equalTo: dockArea.topAnchor),
            snapshotView.bottomAnchor.constraint(equalTo: dockArea.bottomAnchor),
            snapshotView.leadingAnchor.constraint(equalTo: dockArea.leadingAnchor),
            snapshotView.trailingAnchor.constraint(equalTo: dockArea.trailingAnchor),

            messageLabel.centerYAnchor.constraint(equalTo: dockArea.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: dockArea.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: dockArea.trailingAnchor, constant: -20)
        ])

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(codeChanged(_:)), name: ForkAppPreview.codeChanged, object: nil)
        center.addObserver(self, selector: #selector(codeSaved(_:)), name: ForkAppPreview.codeSaved, object: nil)
        center.addObserver(self, selector: #selector(runFinished(_:)), name: ForkAppPreview.runFinished, object: nil)
        setState(.idle)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        /* the split view wraps this container in a navigation controller of its
           own; the editor already has its bar */
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addToggleButton()
        updateWidth()
        if isShown {
            startTimer()
            if !loadedOnce {
                loadedOnce = true
                adoptOrLoad()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        /* the project closed: the app keeps running, out of the way */
        timer?.invalidate()
        timer = nil
        NXWindowServer.shared()?.forkUndock(puttingAway: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWidth()
        dock()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.setNeedsLayout()
    }

    // MARK: layout

    private func targetWidth() -> CGFloat {
        guard isShown else { return 0 }
        return min(max(view.bounds.width * 0.38, 320), 520)
    }

    private func updateWidth() {
        let width = targetWidth()
        if panelWidth.constant != width {
            let wasShown = panelWidth.constant > 0
            panelWidth.constant = width
            if wasShown && width == 0 {
                /* no room any more (narrow Split View): put the app away */
                timer?.invalidate()
                timer = nil
                NXWindowServer.shared()?.forkUndock(puttingAway: true)
            } else if !wasShown && width > 0 && viewIfLoaded?.window != nil {
                startTimer()
            }
        }
    }

    private func dockRect() -> CGRect {
        guard isShown, panelWidth.constant > 0, let server = NXWindowServer.shared() else { return .zero }
        let rect = dockArea.convert(dockArea.bounds.insetBy(dx: 4, dy: 4), to: server)
        return rect.width > 60 && rect.height > 60 ? rect : .zero
    }

    private func dock() {
        guard let server = NXWindowServer.shared(), isShown, viewIfLoaded?.window != nil else { return }
        let rect = dockRect()
        guard rect != .zero else { return }
        server.forkDock(bundleIdentifier: bundleIdentifier, rect: rect)
        server.forkShowDockedWindow(liveVisible)
    }

    private func addToggleButton() {
        guard toggleItem == nil, let detail else { return }
        let item = UIBarButtonItem(image: UIImage(systemName: "rectangle.righthalf.inset.filled"), primaryAction: UIAction { [weak self] _ in
            self?.toggleVisible()
        })
        item.accessibilityLabel = "App Preview"
        toggleItem = item
        var items = detail.navigationItem.rightBarButtonItems ?? []
        items.append(item)
        detail.navigationItem.rightBarButtonItems = items
    }

    // MARK: state

    private func setState(_ newState: State, message: String? = nil) {
        state = newState
        let text: String
        var status: String
        switch newState {
        case .idle:
            text = "Tap ↻ to load the app"; status = "Not loaded"
        case .building:
            text = snapshotView.image == nil ? "Building the app…" : ""; status = "Building…"
        case .waitingWindow:
            text = snapshotView.image == nil ? "Starting the app…" : ""; status = "Starting…"
        case .running:
            text = ""; status = "Running"
        case .paused:
            text = "Paused — the code changed.\nSave (⌘S) to build again; the app comes back when there are no errors."
            status = "Paused"
        case .failed:
            text = "The code has errors.\nFix them and save (⌘S), or tap ↻."
            status = "Build failed"
        case .stopped:
            text = "The app is not running.\nTap ↻ to load it again."
            status = "Stopped"
        }
        if let message { status = message }
        messageLabel.text = text
        messageLabel.isHidden = text.isEmpty
        statusLabel.text = status
        if newState == .building || newState == .waitingWindow { spinner.startAnimating() } else { spinner.stopAnimating() }
        if newState == .running || newState == .idle || newState == .stopped { snapshotView.image = nil }
        NXWindowServer.shared()?.forkShowDockedWindow(liveVisible)
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func appWindowExists() -> Bool {
        guard let server = NXWindowServer.shared() else { return false }
        return server.windowIdentifier(forBundleIdentifier: bundleIdentifier) != id_t(bitPattern: -1)
    }

    private func tick() {
        guard isShown else { return }
        let exists = appWindowExists()
        switch state {
        case .waitingWindow:
            if exists && Date() >= graceUntil {
                setState(.running)
                dock()
                if pauseWhenRunning {
                    /* edited while it built */
                    pauseWhenRunning = false
                    if let picture = NXWindowServer.shared()?.forkSnapshotDockedWindow() { snapshotView.image = picture }
                    setState(.paused)
                }
            } else if Date() > waitUntil {
                setState(.stopped, message: "The app did not open a window")
            }
        case .running:
            if exists {
                dock()
            } else if Date() >= graceUntil {
                setState(.stopped)
            }
        case .idle, .stopped:
            /* started from ▶ elsewhere */
            if exists {
                setState(.running)
                dock()
            }
        case .building, .paused, .failed:
            if exists { dock() }
        }
    }

    /// First time: an app already running is shown, otherwise it is built.
    private func adoptOrLoad() {
        if appWindowExists() {
            setState(.running)
            dock()
        } else {
            load()
        }
    }

    private func load() {
        guard isShown else { return }
        if NXBuilder.builds {
            /* another build is running: try again soon */
            busyRetries += 1
            guard busyRetries < 60 else { busyRetries = 0; setState(.failed, message: "Another build kept running"); return }
            setState(.building, message: "Waiting for the current build…")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.load() }
            return
        }
        busyRetries = 0
        changedDuringBuild = false
        setState(.building)
        guard let split = splitViewController as? MainSplitViewController else {
            setState(.failed, message: "Could not start the build")
            return
        }
        split.invokeBuild()
    }

    // MARK: notifications

    @objc private func codeChanged(_ note: Notification) {
        guard (note.object as? String) == projectPath else { return }
        switch state {
        case .running, .waitingWindow:
            if let picture = NXWindowServer.shared()?.forkSnapshotDockedWindow() {
                snapshotView.image = picture
            }
            setState(.paused)
        case .building:
            changedDuringBuild = true
        default:
            break
        }
    }

    @objc private func codeSaved(_ note: Notification) {
        guard (note.object as? String) == projectPath, isShown,
              state == .paused || state == .failed else { return }
        /* several files saved at once (Save All): one build */
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.load() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    @objc private func runFinished(_ note: Notification) {
        guard (note.object as? String) == projectPath else { return }
        let result = note.userInfo?["result"] as? Bool ?? false
        if note.userInfo?["busy"] as? Bool == true {
            if state == .building {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.load() }
            }
            return
        }
        guard isShown else { return }
        if result {
            /* edited while it built: it opens, then pauses */
            pauseWhenRunning = changedDuringBuild
            changedDuringBuild = false
            /* the old window can still be closing for a moment */
            graceUntil = Date().addingTimeInterval(1.5)
            waitUntil = Date().addingTimeInterval(40)
            setState(.waitingWindow)
        } else {
            setState(.failed)
        }
    }

    // MARK: buttons

    @objc private func reloadTapped() {
        guard state != .building else { return }
        NXDocumentManager.shared().saveAll { [weak self] in
            DispatchQueue.main.async { self?.load() }
        }
    }

    @objc private func hideTapped() {
        setVisible(false)
    }

    private func toggleVisible() {
        setVisible(!visible)
    }

    private func setVisible(_ newValue: Bool) {
        visible = newValue
        UserDefaults.standard.set(newValue, forKey: ForkAppPreview.visibleKey)
        if !newValue {
            timer?.invalidate()
            timer = nil
            NXWindowServer.shared()?.forkUndock(puttingAway: true)
        }
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            self.updateWidth()
            self.view.layoutIfNeeded()
        } completion: { _ in
            guard newValue, self.isShown else { return }
            self.startTimer()
            if !self.loadedOnce || self.state == .idle || self.state == .stopped {
                self.loadedOnce = true
                self.adoptOrLoad()
            } else {
                self.dock()
            }
        }
        if newValue && !hasRoom {
            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "App Preview needs a wider window (full screen or a larger Split View)", withDelay: 0.0)
        }
    }
}
