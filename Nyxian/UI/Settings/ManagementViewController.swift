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
  - 1.0.0 (2026-11-09): Processes (process monitor: every process of
    Nyxian's kernel with state, CPU, memory, threads and run time, updated
    every second; stop, continue, terminate or kill one) and Kernel Log
    (kmsg of this launch or the previous one, live, searchable, shareable).
*/

import UIKit

class NXManagementUISingleFlight {
    private static let slot = DispatchSemaphore(value: 1)
    private static let queue = DispatchQueue(label: "org.emexlabs.nyxian.mgmt.singleflight", qos: .userInitiated)
    
    @discardableResult static func run(_ body: @escaping () -> Void) -> Bool {
        guard slot.wait(timeout: .now()) == .success else { return false }
        queue.async {
            defer { self.slot.signal() }
            body()
        }
        return true
    }
}

class ManagementViewController: NXUITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Management"
        view.backgroundColor = .systemBackground
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(section) {
            case 0:
                return 1
            case 1:
                return 1
            case 2:
                return 4
            default:
                return 6
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableViewCell: UITableViewCell = UITableViewCell()
        
        switch(indexPath.section) {
            case 0:
                tableViewCell.textLabel?.text = "Browse Virtual File System"
                tableViewCell.accessoryType = .disclosureIndicator
            case 1:
                tableViewCell.textLabel?.text = "Installed Root Certificate Authorities"
                tableViewCell.accessoryType = .disclosureIndicator
            case 2:
                if indexPath.row == 0 {
                    tableViewCell.textLabel?.text = "Installed Applications"
                    tableViewCell.accessoryType = .disclosureIndicator
                } else if indexPath.row == 1 {
                    tableViewCell.textLabel?.text = "Installed KEXTs"
                    tableViewCell.accessoryType = .disclosureIndicator
                } else if indexPath.row == 2 {
                    tableViewCell.textLabel?.text = "Processes"
                    tableViewCell.imageView?.image = UIImage(systemName: "cpu")
                    tableViewCell.accessoryType = .disclosureIndicator
                } else if indexPath.row == 3 {
                    tableViewCell.textLabel?.text = "Kernel Log (kmsg)"
                    tableViewCell.imageView?.image = UIImage(systemName: "text.alignleft")
                    tableViewCell.accessoryType = .disclosureIndicator
                }
            default:
                if indexPath.row == 0 {
                    tableViewCell.textLabel?.text = "Clear IconCache"
                } else if indexPath.row == 1 {
                    tableViewCell.textLabel?.text = "Userspace Reboot"
                } else if indexPath.row == 2 {
                    tableViewCell.textLabel?.text = "Reload Daemons"
                } else if indexPath.row == 3 {
                    tableViewCell.textLabel?.text = "Clear Application Caches"
                    tableViewCell.textLabel?.textColor = .systemRed
                } else if indexPath.row == 4 {
                    tableViewCell.textLabel?.text = "Restore Virtual Environment"
                    tableViewCell.textLabel?.textColor = .systemRed
                } else if indexPath.row == 5 {
                    tableViewCell.textLabel?.text = "Restore Everything"
                    tableViewCell.textLabel?.textColor = .systemRed
                }
        }
        
        return tableViewCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch(indexPath.section) {
        case 0:
            navigationController?.pushViewController(FileListViewController(isSublink: true, path: NXBootstrap.shared().rootfsURL.path), animated: true)
        case 1:
            print("pressed on list RootCAs")
        case 2:
            if indexPath.row == 0 {
                navigationController?.pushViewController(ApplicationManagementViewController(style: .insetGrouped), animated: true)
            } else if indexPath.row == 1 {
                navigationController?.pushViewController(KEXTManagementViewController(style: .insetGrouped), animated: true)
            } else if indexPath.row == 2 {
                navigationController?.pushViewController(ForkProcessMonitorViewController(style: .insetGrouped), animated: true)
            } else {
                navigationController?.pushViewController(ForkKernelLogViewController(), animated: true)
            }
        default:
            if indexPath.row == 0 {
                ProjectTableCell.iconCache.removeAllObjects()
            } else if indexPath.row == 1 {
                NXManagementUISingleFlight.run {
                    PEUserspaceManager.shared().rebootUserspace()
                }
            } else if indexPath.row == 2 {
                NXManagementUISingleFlight.run {
                    PEUserspaceManager.shared().reloadDaemons()
                }
            } else if indexPath.row == 3 {
                let alert = UIAlertController(
                    title: "Clear Application Caches",
                    message: "All application caches will be wiped, this can have consequences, but it will result in less data being in use. (Some people like that for performance reasons)",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Proceed", style: .destructive) { [weak self] _ in
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: nil, message: "Clearing Application Caches", preferredStyle: .alert)
                        
                        let activityIndicator = UIActivityIndicatorView(style: .medium)
                        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                        activityIndicator.startAnimating()
                        
                        alert.view.addSubview(activityIndicator)
                        
                        NSLayoutConstraint.activate([
                            activityIndicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
                            activityIndicator.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20)
                        ])
                        
                        guard let self = self else {
                            return
                        }
                        self.present(alert, animated: true) { [weak self] in
                            guard let self = self else {
                                return
                            }
                            DispatchQueue.global().async { [weak self] in
                                guard let self = self else {
                                    return
                                }
                                let success = PEUserspaceManager.shared().clearApplicationCaches()
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else {
                                        return
                                    }
                                    alert.dismiss(animated: true)
                                    if !success {
                                        let alert = UIAlertController(
                                            title: "Error",
                                            message: "Clearing Application Caches failed",
                                            preferredStyle: .alert
                                        )
                                        
                                        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                                        
                                        self.present(alert, animated: true)
                                    }
                                }
                            }
                        }
                    }
                })
                
                alert.addAction(UIAlertAction(title: "Keep Caches", style: .cancel))
                
                self.present(alert, animated: true)
            } else if indexPath.row == 4 {
                let alert = UIAlertController(
                    title: "Restore Virtual Environment",
                    message: "All apps, kexts, binaries and data containers in the virtual environment will be wiped.",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Proceed", style: .destructive) { [weak self] _ in
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: nil, message: "Restoring", preferredStyle: .alert)
                        
                        let activityIndicator = UIActivityIndicatorView(style: .medium)
                        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                        activityIndicator.startAnimating()
                        
                        alert.view.addSubview(activityIndicator)
                        
                        NSLayoutConstraint.activate([
                            activityIndicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
                            activityIndicator.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20)
                        ])
                        
                        guard let self = self else {
                            return
                        }
                        self.present(alert, animated: true) { [weak self] in
                            guard let self = self else {
                                return
                            }
                            DispatchQueue.global().async { [weak self] in
                                guard let self = self else {
                                    return
                                }
                                let success = PEUserspaceManager.shared().restore()
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else {
                                        return
                                    }
                                    alert.dismiss(animated: true)
                                    if !success {
                                        let alert = UIAlertController(
                                            title: "Error",
                                            message: "Restore failed",
                                            preferredStyle: .alert
                                        )
                                        
                                        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                                        
                                        self.present(alert, animated: true)
                                    }
                                }
                            }
                        }
                    }
                })
                
                alert.addAction(UIAlertAction(title: "Keep Data", style: .cancel))
                
                self.present(alert, animated: true)
            } else if indexPath.row == 5 {
                let alert = UIAlertController(
                    title: "Restore Everything",
                    message: "All projects, configurations, kexts, apps, binaries and data containers in the virtual environment will be wiped.",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Proceed", style: .destructive) { [weak self] _ in
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: nil, message: "Restoring", preferredStyle: .alert)
                        
                        let activityIndicator = UIActivityIndicatorView(style: .medium)
                        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                        activityIndicator.startAnimating()
                        
                        alert.view.addSubview(activityIndicator)
                        
                        NSLayoutConstraint.activate([
                            activityIndicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
                            activityIndicator.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20)
                        ])
                        
                        guard let self = self else {
                            return
                        }
                        self.present(alert, animated: true) { [weak self] in
                            guard let self = self else {
                                return
                            }
                            DispatchQueue.global().async { [weak self] in
                                guard let self = self else {
                                    return
                                }
                                let success = PEUserspaceManager.shared().restoreEverything()
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else {
                                        return
                                    }
                                    alert.dismiss(animated: true)
                                    if !success {
                                        let alert = UIAlertController(
                                            title: "Error",
                                            message: "Restore failed",
                                            preferredStyle: .alert
                                        )
                                        
                                        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                                        
                                        self.present(alert, animated: true)
                                    }
                                }
                            }
                        }
                    }
                })
                
                alert.addAction(UIAlertAction(title: "Keep Data", style: .cancel))
                
                self.present(alert, animated: true)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - fork: process monitor

/// Every process of Nyxian's kernel, updated every second; tap one to stop, continue, terminate or kill it.
final class ForkProcessMonitorViewController: UITableViewController, UISearchResultsUpdating {
    private enum Sort: String, CaseIterable { case pid = "PID", cpu = "CPU", memory = "Memory", name = "Name" }
    private var all: [[String: Any]] = []
    private var shown: [[String: Any]] = []
    private var timer: Timer?
    private var sort: Sort = .pid
    private var paused = false
    private let search = UISearchController(searchResultsController: nil)
    private let ownPid = getpid()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Processes"
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Name, PID or bundle"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        updateButtons()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        reload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, !self.paused, !self.tableView.isDragging else { return }
            self.reload()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    private func updateButtons() {
        let sortMenu = UIMenu(title: "Sort by", children: Sort.allCases.map { option in
            UIAction(title: option.rawValue, state: option == sort ? .on : .off) { [weak self] _ in
                self?.sort = option
                self?.updateButtons()
                self?.reload()
            }
        })
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), menu: sortMenu),
            UIBarButtonItem(image: UIImage(systemName: paused ? "play.fill" : "pause.fill"), primaryAction: UIAction { [weak self] _ in
                guard let self = self else { return }
                self.paused.toggle()
                self.updateButtons()
            })
        ]
    }
    
    private func reload() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let list = PEProcessManager.shared().forkProcessSnapshot() ?? []
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.all = list
                self.applyFilter()
            }
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) { applyFilter() }
    
    private func applyFilter() {
        let query = (search.searchBar.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        var list = all
        if !query.isEmpty {
            list = list.filter { entry in
                let fields = [Self.name(entry), "\(entry["pid"] as? Int ?? -1)", entry["bundleIdentifier"] as? String ?? "", entry["executablePath"] as? String ?? ""]
                return fields.contains { $0.lowercased().contains(query) }
            }
        }
        switch sort {
        case .pid: break
        case .cpu: list.sort { ($0["cpu"] as? Double ?? -1) > ($1["cpu"] as? Double ?? -1) }
        case .memory: list.sort { ($0["memory"] as? Double ?? -1) > ($1["memory"] as? Double ?? -1) }
        case .name: list.sort { Self.name($0).localizedCaseInsensitiveCompare(Self.name($1)) == .orderedAscending }
        }
        shown = list
        tableView.reloadData()
    }
    
    private static func name(_ entry: [String: Any]) -> String {
        if let display = entry["displayName"] as? String, !display.isEmpty { return display }
        if let path = entry["executablePath"] as? String, !path.isEmpty { return (path as NSString).lastPathComponent }
        return entry["name"] as? String ?? "?"
    }
    
    static func duration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let running = all.filter { ($0["state"] as? String) == "running" }.count
        let stopped = all.filter { ($0["state"] as? String) == "stopped" }.count
        return "\(all.count) processes · \(running) running · \(stopped) stopped" + (paused ? " · paused" : "")
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "proc") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "proc")
        let entry = shown[indexPath.row]
        let pid = entry["pid"] as? Int ?? -1
        let state = entry["state"] as? String ?? "?"
        var title = Self.name(entry)
        if pid == Int(ownPid) { title += " (Nyxian)" }
        cell.textLabel?.text = title
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        var parts = ["PID \(pid)", "parent \(entry["ppid"] as? Int ?? 0)"]
        if let pgid = entry["pgid"] as? Int, pgid != pid { parts.append("group \(pgid)") }
        parts.append(state)
        if let cpu = entry["cpu"] as? Double { parts.append(String(format: "CPU %.0f%%", cpu)) }
        if let memory = entry["memory"] as? Double { parts.append(ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)) }
        if let threads = entry["threads"] as? Int { parts.append("\(threads) threads") }
        if let uptime = entry["uptime"] as? Double { parts.append(Self.duration(uptime)) }
        cell.detailTextLabel?.text = parts.joined(separator: " · ")
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.detailTextLabel?.textColor = .secondaryLabel
        let symbol: String
        let tint: UIColor
        switch state {
        case "stopped": symbol = "pause.circle.fill"; tint = .systemOrange
        case "zombie": symbol = "xmark.circle"; tint = .systemGray
        case "starting": symbol = "hourglass.circle"; tint = .systemBlue
        default: symbol = "play.circle.fill"; tint = .systemGreen
        }
        cell.imageView?.image = UIImage(systemName: symbol)
        cell.imageView?.tintColor = tint
        return cell
    }
    
    private func send(_ signal: Int32, to pid: Int, name: String) {
        if !PEProcessManager.shared().forkSendSignal(signal, toProcessIdentifier: pid_t(pid)) {
            let alert = UIAlertController(title: "Could not signal \(name)", message: "The process may have ended already.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.reload() }
    }
    
    private func confirmed(_ title: String, _ message: String, _ action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: title, style: .destructive) { _ in action() })
        present(alert, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = shown[indexPath.row]
        let pid = entry["pid"] as? Int ?? -1
        let name = Self.name(entry)
        var details = "PID \(pid) · parent \(entry["ppid"] as? Int ?? 0)"
        if let pgid = entry["pgid"] as? Int { details += " · group \(pgid)" }
        if let sid = entry["sid"] as? Int { details += " · session \(sid)" }
        details += " · uid \(entry["uid"] as? Int ?? 0)"
        if let bundle = entry["bundleIdentifier"] as? String { details += "\n\(bundle)" }
        if let path = entry["executablePath"] as? String { details += "\n\(path)" }
        let sheet = UIAlertController(title: name, message: details, preferredStyle: .actionSheet)
        if pid == Int(ownPid) || pid <= 0 {
            sheet.message = details + "\n\nThis is Nyxian itself (its kernel): it cannot be signalled from here."
        } else {
            let critical = pid == 1
            if (entry["state"] as? String) == "stopped" {
                sheet.addAction(UIAlertAction(title: "Continue (SIGCONT)", style: .default) { [weak self] _ in self?.send(SIGCONT, to: pid, name: name) })
            } else {
                sheet.addAction(UIAlertAction(title: "Stop (SIGSTOP)", style: .default) { [weak self] _ in self?.send(SIGSTOP, to: pid, name: name) })
            }
            sheet.addAction(UIAlertAction(title: "Interrupt (SIGINT)", style: .default) { [weak self] _ in self?.send(SIGINT, to: pid, name: name) })
            sheet.addAction(UIAlertAction(title: "Terminate (SIGTERM)", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                if critical { self.confirmed("Terminate", "PID 1 is launchd: ending it restarts Nyxian's userspace.") { self.send(SIGTERM, to: pid, name: name) } }
                else { self.send(SIGTERM, to: pid, name: name) }
            })
            sheet.addAction(UIAlertAction(title: "Kill (SIGKILL)", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.confirmed("Kill", critical ? "PID 1 is launchd: killing it restarts Nyxian's userspace." : "\(name) ends at once, without saving anything.") { self.send(SIGKILL, to: pid, name: name) }
            })
        }
        sheet.addAction(UIAlertAction(title: "Copy Details", style: .default) { _ in UIPasteboard.general.string = name + "\n" + details })
        sheet.addAction(UIAlertAction(title: "Close", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }
        present(sheet, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = shown[indexPath.row]
        let pid = entry["pid"] as? Int ?? -1
        guard pid > 1, pid != Int(ownPid) else { return nil }
        let name = Self.name(entry)
        let kill = UIContextualAction(style: .destructive, title: "Kill") { [weak self] _, _, done in
            self?.send(SIGKILL, to: pid, name: name)
            done(true)
        }
        let stopped = (entry["state"] as? String) == "stopped"
        let toggle = UIContextualAction(style: .normal, title: stopped ? "Continue" : "Stop") { [weak self] _, _, done in
            self?.send(stopped ? SIGCONT : SIGSTOP, to: pid, name: name)
            done(true)
        }
        toggle.backgroundColor = stopped ? .systemGreen : .systemOrange
        return UISwipeActionsConfiguration(actions: [kill, toggle])
    }
}

// MARK: - fork: kernel log

/// kmsg: what Nyxian's kernel logs, for this launch (live) or the previous one; search, copy, share.
final class ForkKernelLogViewController: UIViewController, UISearchBarDelegate {
    private let textView = UITextView()
    private let picker = UISegmentedControl(items: ["This Launch", "Previous Launch"])
    private let searchBar = UISearchBar()
    private var timer: Timer?
    private var lastText = ""
    private var live = true
    
    private static var devfs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("mntfs/devfs")
    }
    
    /// The log of this launch moves into devfs once the kernel is up; before that it is in Documents.
    static var currentURL: URL {
        let devfsLog = devfs.appendingPathComponent("kmsg")
        if FileManager.default.fileExists(atPath: devfsLog.path) { return devfsLog }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("kmsg.txt")
    }
    static var previousURL: URL { devfs.appendingPathComponent("kmsg_old") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kernel Log"
        view.backgroundColor = .systemBackground
        
        picker.selectedSegmentIndex = 0
        picker.addTarget(self, action: #selector(changedSource), for: .valueChanged)
        navigationItem.titleView = picker
        
        searchBar.placeholder = "Filter lines (e.g. tty, proc, fail)"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .secondarySystemBackground
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.dataDetectorTypes = []
        
        let stack = UIStackView(arrangedSubviews: [searchBar, textView])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateButtons()
        load(scrollToEnd: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, self.live, self.picker.selectedSegmentIndex == 0, !self.textView.isDragging else { return }
            self.load(scrollToEnd: false)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    private func updateButtons() {
        let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), primaryAction: UIAction { [weak self] _ in self?.shareLog() })
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: [
            UIAction(title: live ? "Pause Live Updates" : "Resume Live Updates", image: UIImage(systemName: live ? "pause" : "play")) { [weak self] _ in
                guard let self = self else { return }
                self.live.toggle()
                self.updateButtons()
                if self.live { self.load(scrollToEnd: true) }
            },
            UIAction(title: "Copy All", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                UIPasteboard.general.string = self?.filtered(self?.lastText ?? "")
            },
            UIAction(title: "Go to End", image: UIImage(systemName: "arrow.down.to.line")) { [weak self] _ in self?.scrollToEnd() },
        ]))
        navigationItem.rightBarButtonItems = [more, share]
    }
    
    @objc private func changedSource() {
        lastText = ""
        load(scrollToEnd: true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { render(lastText, scrollToEnd: true) }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    
    private func load(scrollToEnd: Bool) {
        let url = picker.selectedSegmentIndex == 0 ? Self.currentURL : Self.previousURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let text: String
            if let data = try? Data(contentsOf: url) {
                text = String(decoding: data, as: UTF8.self)
            } else {
                text = ""
            }
            DispatchQueue.main.async {
                guard let self = self, text != self.lastText || scrollToEnd else { return }
                self.lastText = text
                self.render(text, scrollToEnd: scrollToEnd)
            }
        }
    }
    
    private func filtered(_ text: String) -> String {
        let query = (searchBar.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return text }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.range(of: query, options: .caseInsensitive) != nil }
            .joined(separator: "\n")
    }
    
    private func render(_ text: String, scrollToEnd: Bool) {
        let atEnd = textView.contentOffset.y + textView.bounds.height >= textView.contentSize.height - 40
        let body = filtered(text)
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 13 : 11
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let result = NSMutableAttributedString()
        if body.isEmpty {
            let note = picker.selectedSegmentIndex == 0 ? "The kernel has not logged anything yet." : "There is no log of a previous launch."
            result.append(NSAttributedString(string: (searchBar.text ?? "").isEmpty ? note : "No line matches.", attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel]))
        } else {
            let alert = try? NSRegularExpression(pattern: "fail|error|panic|denied|crash|invalid", options: .caseInsensitive)
            for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
                let string = String(line)
                var color = UIColor.label
                if alert?.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil { color = .systemRed }
                let attributed = NSMutableAttributedString(string: string + "\n", attributes: [.font: font, .foregroundColor: color])
                /* [  12.345678] [system] — the time and the subsystem dimmed */
                if string.hasPrefix("["), let close = string.firstIndex(of: "]") {
                    var end = string.index(after: close)
                    if let second = string[end...].firstIndex(of: "]"), string[end...].hasPrefix(" [") { end = string.index(after: second) }
                    attributed.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(string.startIndex..<end, in: string))
                }
                result.append(attributed)
            }
        }
        textView.attributedText = result
        if scrollToEnd || atEnd { DispatchQueue.main.async { self.scrollToEnd() } }
    }
    
    private func scrollToEnd() {
        let length = textView.attributedText.length
        guard length > 0 else { return }
        textView.scrollRangeToVisible(NSRange(location: length - 1, length: 1))
    }
    
    private func shareLog() {
        let name = picker.selectedSegmentIndex == 0 ? "kmsg.txt" : "kmsg_previous.txt"
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? filtered(lastText).write(to: file, atomically: true, encoding: .utf8)
        let activity = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(activity, animated: true)
    }
}
