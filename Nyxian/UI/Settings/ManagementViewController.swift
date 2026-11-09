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
  - 1.2.0 (2026-11-09): Processes keeps a minute of CPU and memory of every
    process: "Activity…" shows it as the profiler's graphs, live; each row
    has a small CPU line.
  - 1.1.0 (2026-11-09): Permissions: per program (app, python3, any
    executable) file access — Nyxian default, only what it declares, or all
    of Nyxian — extra read-only / read-write folders, and network on or off;
    also from a process in Processes ("Permissions…").
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
                return 5
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
                } else if indexPath.row == 4 {
                    tableViewCell.textLabel?.text = "Permissions"
                    tableViewCell.imageView?.image = UIImage(systemName: "lock.shield")
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
            } else if indexPath.row == 3 {
                navigationController?.pushViewController(ForkKernelLogViewController(), animated: true)
            } else {
                navigationController?.pushViewController(ForkPermissionsListViewController(style: .insetGrouped), animated: true)
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
    /* fork: the last minute of each process, for Activity… and the row's small graph */
    private var history: [Int: [ForkProfilerView.Sample]] = [:]
    private weak var activity: ForkProfilerGraphsViewController?
    private var activityPid = -1
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
                self.record(list)
                self.applyFilter()
            }
        }
    }
    
    private func record(_ list: [[String: Any]]) {
        var alive = Set<Int>()
        for entry in list {
            guard let pid = entry["pid"] as? Int, let cpu = entry["cpu"] as? Double, let memory = entry["memory"] as? Double else { continue }
            alive.insert(pid)
            var samples = history[pid] ?? []
            samples.append(ForkProfilerView.Sample(cpu: cpu, memory: memory, threads: entry["threads"] as? Int ?? 0))
            if samples.count > 60 { samples.removeFirst(samples.count - 60) }
            history[pid] = samples
        }
        history = history.filter { alive.contains($0.key) }
        if let activity = activity, let samples = history[activityPid] {
            activity.update(samples)
        }
    }
    
    private func showActivity(pid: Int, name: String) {
        let graphs = ForkProfilerGraphsViewController()
        graphs.title = name
        graphs.update(history[pid] ?? [])
        activity = graphs
        activityPid = pid
        let navigation = UINavigationController(rootViewController: graphs)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        present(navigation, animated: true)
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
        /* fork: the last minute of CPU, small */
        if let samples = history[pid], samples.count > 1 {
            let spark = cell.accessoryView as? ForkSparklineView ?? ForkSparklineView(color: .systemTeal)
            spark.frame = CGRect(x: 0, y: 0, width: 64, height: 28)
            spark.values = samples.map { $0.cpu }
            cell.accessoryView = spark
        } else {
            cell.accessoryView = nil
        }
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
        if entry["cpu"] != nil {
            sheet.addAction(UIAlertAction(title: "Activity (CPU and Memory)…", style: .default) { [weak self] _ in self?.showActivity(pid: pid, name: name) })
        }
        if pid != Int(ownPid), pid > 1, let program = ForkPermissionProgram(processEntry: entry) {
            sheet.addAction(UIAlertAction(title: "Permissions…", style: .default) { [weak self] _ in
                self?.navigationController?.pushViewController(ForkPermissionEditorViewController(program: program), animated: true)
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

// MARK: - fork: per-program permissions

/// A program permissions can be set for: an app (by bundle identifier) or an executable (by its real path).
/// Stored in UserDefaults under fork.permissions.v1, read by the kernel (trust.m) when the program starts.
struct ForkPermissionProgram {
    static let defaultsKey = "fork.permissions.v1"
    let key: String
    let name: String
    let detail: String
    
    init(key: String, name: String, detail: String) {
        self.key = key
        self.name = name
        self.detail = detail
    }
    
    init(application: LDEApplicationObject) {
        key = "bundle:" + (application.bundleIdentifier ?? "")
        name = application.localizedName ?? application.bundleIdentifier ?? "App"
        detail = application.bundleIdentifier ?? ""
    }
    
    init?(executablePath: String, name: String? = nil) {
        guard !executablePath.isEmpty else { return nil }
        key = "path:" + Self.realPath(executablePath)
        self.name = name ?? (executablePath as NSString).lastPathComponent
        detail = executablePath
    }
    
    init?(processEntry entry: [String: Any]) {
        let display = (entry["displayName"] as? String) ?? (entry["name"] as? String)
        if let bundle = entry["bundleIdentifier"] as? String, !bundle.isEmpty {
            key = "bundle:" + bundle
            name = display ?? bundle
            detail = bundle
        } else if let path = entry["executablePath"] as? String, !path.isEmpty {
            key = "path:" + Self.realPath(path)
            name = display ?? (path as NSString).lastPathComponent
            detail = path
        } else {
            return nil
        }
    }
    
    /// the same canonical path as the kernel's realpath()
    static func realPath(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
    
    static func allPolicies() -> [String: [String: Any]] {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Any]]) ?? [:]
    }
    
    var policy: [String: Any] {
        get { Self.allPolicies()[key] ?? ["name": name, "files": "default", "network": true] }
        nonmutating set {
            var all = Self.allPolicies()
            var value = newValue
            value["name"] = name
            value["detail"] = detail
            all[key] = value
            UserDefaults.standard.set(all, forKey: Self.defaultsKey)
        }
    }
    
    func remove() {
        var all = Self.allPolicies()
        all.removeValue(forKey: key)
        UserDefaults.standard.set(all, forKey: Self.defaultsKey)
    }
    
    /// one line for lists: what differs from Nyxian's default
    static func summary(_ policy: [String: Any]) -> String {
        var parts: [String] = []
        switch policy["files"] as? String ?? "default" {
        case "declared": parts.append("files: only what it declares")
        case "full": parts.append("files: all of Nyxian")
        default: parts.append("files: Nyxian default")
        }
        let read = (policy["read"] as? [String])?.count ?? 0
        let readWrite = (policy["readWrite"] as? [String])?.count ?? 0
        if read + readWrite > 0 { parts.append("+\(read + readWrite) folders") }
        parts.append((policy["network"] as? Bool ?? true) ? "network on" : "network blocked")
        return parts.joined(separator: " · ")
    }
}

final class ForkPermissionsListViewController: UITableViewController {
    private var keys: [String] = []
    private var policies: [String: [String: Any]] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Permissions"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: nil, menu: addMenu())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }
    
    private func reload() {
        policies = ForkPermissionProgram.allPolicies()
        keys = policies.keys.sorted { (policies[$0]?["name"] as? String ?? $0).localizedCaseInsensitiveCompare(policies[$1]?["name"] as? String ?? $1) == .orderedAscending }
        tableView.reloadData()
    }
    
    private func addMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Installed App…", image: UIImage(systemName: "app")) { [weak self] _ in self?.pickApplication() },
            UIAction(title: "Running Process…", image: UIImage(systemName: "cpu")) { [weak self] _ in self?.pickProcess() },
            UIAction(title: "Python (python3)", image: UIImage(systemName: "chevron.left.forwardslash.chevron.right")) { [weak self] _ in self?.addPython() },
            UIAction(title: "Executable by Path…", image: UIImage(systemName: "terminal")) { [weak self] _ in self?.addByPath() },
        ])
    }
    
    private func open(_ program: ForkPermissionProgram) {
        navigationController?.pushViewController(ForkPermissionEditorViewController(program: program), animated: true)
    }
    
    private func choose(_ title: String, _ programs: [ForkPermissionProgram]) {
        guard !programs.isEmpty else {
            let alert = UIAlertController(title: title, message: "There is nothing to choose from right now.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
            return
        }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for program in programs.prefix(30) {
            sheet.addAction(UIAlertAction(title: program.name, style: .default) { [weak self] _ in self?.open(program) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }
    
    private func pickApplication() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = LDEApplicationWorkspace.shared().allApplicationObjects() ?? []
            let programs = apps.map { ForkPermissionProgram(application: $0) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { self?.choose("Installed App", programs) }
        }
    }
    
    private func pickProcess() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let own = Int(getpid())
            let entries = (PEProcessManager.shared().forkProcessSnapshot() ?? []).filter { ($0["pid"] as? Int ?? 0) > 1 && ($0["pid"] as? Int) != own }
            var seen = Set<String>()
            let programs = entries.compactMap { ForkPermissionProgram(processEntry: $0) }.filter { seen.insert($0.key).inserted }
            DispatchQueue.main.async { self?.choose("Running Process", programs) }
        }
    }
    
    private func addPython() {
        if let launcher = UserDefaults.standard.string(forKey: "fork.python.launcher"), let program = ForkPermissionProgram(executablePath: launcher, name: "Python (python3)") {
            open(program)
        } else {
            let alert = UIAlertController(title: "Python is not installed yet", message: "Run a .py file or open the Python console once, then come back.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    private func addByPath() {
        let alert = UIAlertController(title: "Executable by Path", message: "The full path of the program, e.g. one of your command line tools.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "/…/MyTool"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            let path = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespaces)
            if let program = ForkPermissionProgram(executablePath: path) { self?.open(program) }
        })
        present(alert, animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(keys.count, 1) }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let sandbox = UserDefaults.standard.bool(forKey: "nyxian.boot.sandbox.filesystems")
        return "Add a program with +. Its permissions apply the next time it starts, and to the programs it starts. "
            + "Nyxian's default now: " + (sandbox ? "each program only gets what it declares (file system sandbox on)." : "every program can read and write all of Nyxian (file system sandbox off).")
            + " Blocking the network makes its IPv4/IPv6 sockets fail (\"Operation not permitted\"); it is a guard in the program's own libc calls, not a firewall."
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        guard !keys.isEmpty else {
            cell.textLabel?.text = "No program has its own permissions"
            cell.textLabel?.textColor = .secondaryLabel
            cell.selectionStyle = .none
            return cell
        }
        let key = keys[indexPath.row]
        let policy = policies[key] ?? [:]
        cell.textLabel?.text = policy["name"] as? String ?? key
        cell.detailTextLabel?.text = ForkPermissionProgram.summary(policy)
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 0
        cell.imageView?.image = UIImage(systemName: key.hasPrefix("bundle:") ? "app.fill" : "terminal.fill")
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    private func program(at row: Int) -> ForkPermissionProgram {
        let key = keys[row]
        let policy = policies[key] ?? [:]
        return ForkPermissionProgram(key: key, name: policy["name"] as? String ?? key, detail: policy["detail"] as? String ?? String(key.drop(while: { $0 != ":" }).dropFirst()))
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !keys.isEmpty else { return }
        open(program(at: indexPath.row))
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !keys.isEmpty else { return nil }
        let program = program(at: indexPath.row)
        let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            program.remove()
            self?.reload()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }
}

final class ForkPermissionEditorViewController: UITableViewController {
    private let program: ForkPermissionProgram
    private static let suggestions = ["/var/mobile", "/var/mobile/Documents", "/tmp", "/opt/python"]
    private let modes: [(id: String, title: String, detail: String)] = [
        ("default", "Nyxian Default", "As Settings decide for every program (file system sandbox)."),
        ("declared", "Only What It Declares", "Its own container and the folders its entitlements ask for, even with the sandbox off."),
        ("full", "All of Nyxian", "Read and write everything in Nyxian's root, even with the sandbox on."),
    ]
    
    init(program: ForkPermissionProgram) {
        self.program = program
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = program.name
    }
    
    private var policy: [String: Any] {
        get { program.policy }
        set { program.policy = newValue; tableView.reloadData() }
    }
    
    private func folders(_ key: String) -> [String] { policy[key] as? [String] ?? [] }
    
    override func numberOfSections(in tableView: UITableView) -> Int { 5 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return modes.count
        case 1: return folders("read").count + 1
        case 2: return folders("readWrite").count + 1
        case 3: return 1
        default: return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Files"
        case 1: return "Extra Folders — Read Only"
        case 2: return "Extra Folders — Read and Write"
        case 3: return "Network"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return program.detail
        case 2: return "Folders are inside Nyxian's root (\"/var/mobile\" is $(NXROOT)/var/mobile) and include what is in them. They add to the file mode above."
        case 3: return "Off: its connections to the internet and the local network fail with \"Operation not permitted\". Local sockets keep working."
        default: return section == 4 ? "Changes apply the next time it starts." : nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        switch indexPath.section {
        case 0:
            let mode = modes[indexPath.row]
            cell.textLabel?.text = mode.title
            cell.detailTextLabel?.text = mode.detail
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.accessoryType = (policy["files"] as? String ?? "default") == mode.id ? .checkmark : .none
        case 1, 2:
            let list = folders(indexPath.section == 1 ? "read" : "readWrite")
            if indexPath.row < list.count {
                cell.textLabel?.text = list[indexPath.row]
                cell.textLabel?.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
                cell.imageView?.image = UIImage(systemName: indexPath.section == 1 ? "eye" : "pencil")
            } else {
                cell.textLabel?.text = "Add Folder…"
                cell.textLabel?.textColor = .systemBlue
                cell.imageView?.image = UIImage(systemName: "plus.circle")
            }
        case 3:
            cell.textLabel?.text = "Network Access"
            let toggle = UISwitch()
            toggle.isOn = policy["network"] as? Bool ?? true
            toggle.addAction(UIAction { [weak self] action in
                guard let self = self, let toggle = action.sender as? UISwitch else { return }
                var value = self.policy
                value["network"] = toggle.isOn
                self.policy = value
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        default:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Restart It Now"
                cell.textLabel?.textColor = .systemBlue
                cell.detailTextLabel?.text = "Ends it if it runs, so the next start uses these permissions."
                cell.detailTextLabel?.textColor = .secondaryLabel
            } else {
                cell.textLabel?.text = "Back to Nyxian's Default"
                cell.textLabel?.textColor = .systemRed
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            var value = policy
            value["files"] = modes[indexPath.row].id
            policy = value
        case 1, 2:
            let key = indexPath.section == 1 ? "read" : "readWrite"
            if indexPath.row >= folders(key).count { addFolder(to: key) }
        case 4:
            if indexPath.row == 0 {
                endRunning()
            } else {
                program.remove()
                navigationController?.popViewController(animated: true)
            }
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 || indexPath.section == 2 else { return nil }
        let key = indexPath.section == 1 ? "read" : "readWrite"
        guard indexPath.row < folders(key).count else { return nil }
        let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            guard let self = self else { return }
            var value = self.policy
            var list = self.folders(key)
            list.remove(at: indexPath.row)
            value[key] = list
            self.policy = value
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }
    
    private func addFolder(to key: String) {
        let alert = UIAlertController(title: key == "read" ? "Read-Only Folder" : "Read and Write Folder",
                                      message: "A folder inside Nyxian's root, e.g. " + Self.suggestions.joined(separator: ", "), preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "/var/mobile/Documents"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        let save: (String) -> Void = { [weak self] raw in
            guard let self = self else { return }
            var path = raw.trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty, !path.contains("..") else { return }
            if !path.hasPrefix("/") && !path.hasPrefix("$(") { path = "/" + path }
            while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
            var value = self.policy
            var list = self.folders(key)
            if !list.contains(path) { list.append(path) }
            value[key] = list
            self.policy = value
        }
        for suggestion in Self.suggestions where !folders(key).contains(suggestion) {
            alert.addAction(UIAlertAction(title: suggestion, style: .default) { _ in save(suggestion) })
        }
        alert.addAction(UIAlertAction(title: "Add Typed Folder", style: .default) { _ in save(alert.textFields?.first?.text ?? "") })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func endRunning() {
        let entries = PEProcessManager.shared().forkProcessSnapshot() ?? []
        var ended = 0
        for entry in entries {
            guard let pid = entry["pid"] as? Int, pid > 1, pid != Int(getpid()),
                  ForkPermissionProgram(processEntry: entry)?.key == program.key else { continue }
            if PEProcessManager.shared().forkSendSignal(SIGKILL, toProcessIdentifier: pid_t(pid)) { ended += 1 }
        }
        let alert = UIAlertController(title: ended > 0 ? "\(program.name) ended" : "\(program.name) is not running",
                                      message: "Start it again and it uses these permissions.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}
