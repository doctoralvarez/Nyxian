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
 Fork doctoralvarez/Nyxian — version 1.3.0
 Changelog:
  - 1.3.0 (2026-11-19): the section is "iOS Builds": besides the token,
    Build Python Wheel, Build C/C++ Library and Build Fortran Library send a
    build to your Mac (or GitHub's); "Build Again" replaces an existing one.
  - 1.2.0 (2026-11-18): "iOS Wheels" section: the GitHub token Nyxian uses
    to start a build of an iOS wheel pip could not find (kept in the
    Keychain; set, replace or remove it here).
  - 1.1.0 (2026-11-16): the footer explains that with Incremental Build on
    only the Swift files that changed are compiled, and that Automatic One
    Pass is then off.
  - 1.0.1 (2026-11-15): choosing a Swift in One Pass option tries it again
    after it failed on this device; the footer says when it is off for that.
  - 1.0.0 (2026-11-15): "Speed" section: the memory iOS gives Nyxian, Swift
    "One Pass" (Automatic / On / Off) and "All Cores with More Memory"; the
    Threads stepper goes up to every core.
*/

import UIKit
import CoreCompiler

class ToolChainViewController: NXUITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ToggleTableCell.self, forCellReuseIdentifier: ToggleTableCell.reuseIdentifier)
        
        self.title = "Toolchain"
        
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.rowHeight = UITableView.automaticDimension
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 4 { return 3 }
        if section == 5 { return 1 + ForkWheelBuilder.Kind.allCases.count }
        return (section == 3) ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "An incremental build compiles only the parts of the code that have changed, reducing build times by avoiding a full rebuild of the entire project."
        case 1:
            return "Using a remote daemon process means that Nyxian does not compile the code directly, it hands it over to a remote daemon process that still runs on your device, which means that if LLVM crashes it will not take Nyxian with it and also it would gurantee that the memory is destroyed after compilation and no broken LLVM state is still present."
        case 2:
            return "Threading in compilation refers to the compiler's ability to perform tasks in parallel like parsing, code generation, and optimization across multiple CPU threads to speed up the build process."
        case 3:
            return "This clears caches that were created for performance."
        case 4:
            return ForkBuildSpeedFooter.text
        case 5:
            return "Builds for iOS run in the \"iOS wheels\" workflow of doctoralvarez/Nyxian: on your Mac if it is on, else on GitHub's. Python wheels go where Nyxian's pip looks (pip also offers one when it finds no iOS wheel); C/C++ and Fortran libraries (static, arm64) go on the ios-native release; Fortran is experimental (LLVM Flang). From the shell: iosbuild python|c|fortran NAME… [--rebuild]. It needs a fine-grained GitHub token for that repository with \"Actions: Read and write\" (you can add that permission to the token you already use for your Mac). It stays in this device's Keychain and is never given to Python or to the packages you install."
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Features"
        case 3:
            return "Actions"
        case 4:
            return "Speed"
        case 5:
            return "iOS Builds"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch indexPath.section {
        case 0:
            cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
            (cell as! ToggleTableCell).configure(title: "Incremental Build", key: "LDEIncrementalBuild", defaultValue: true)
            break
        case 1:
            cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
            (cell as! ToggleTableCell).configure(title: "Remote Compilation Daemon", key: "LDERemoteCompileService", defaultValue: true)
            break
        case 2:
            let optimCpuCount: Int = (Int)(CCGetMaximumPerformanceCores())
            /* fork: up to every core (efficiency cores too) */
            cell = StepperTableCell(title: "Threads", key: "cputhreads", defaultValue: optimCpuCount, minValue: 1, maxValue: max(optimCpuCount, ForkBuildSpeed.allCores))
            break
        case 4:
            switch indexPath.row {
            case 0:
                let info = UITableViewCell(style: .value1, reuseIdentifier: nil)
                info.textLabel?.text = "Memory Limit"
                let limit = ForkMemoryInfo.format(ForkBuildSpeed.memoryLimit)
                info.detailTextLabel?.text = ForkBuildSpeed.hasMoreMemory ? "\(limit) · more memory" : limit
                info.selectionStyle = .none
                cell = info
            case 1:
                let picker = PickerTableCell(options: ForkBuildSpeed.onePassOptions, title: "Swift in One Pass", key: ForkBuildSpeed.onePassKey, defaultValue: 0)
                /* choosing again tries One Pass again after it failed here */
                picker.callback = { _ in UserDefaults.standard.removeObject(forKey: ForkBuildSpeed.onePassFailedKey) }
                cell = picker
            default:
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "All Cores with More Memory", key: ForkBuildSpeed.allCoresKey, defaultValue: true)
            }
        case 5 where indexPath.row > 0:
            let build = UITableViewCell(style: .default, reuseIdentifier: nil)
            build.textLabel?.text = "Build \(ForkWheelBuilder.Kind.allCases[indexPath.row - 1].title)…"
            build.textLabel?.textColor = .tintColor
            cell = build
        case 5:
            let token = UITableViewCell(style: .value1, reuseIdentifier: nil)
            token.textLabel?.text = "GitHub Token"
            token.detailTextLabel?.text = ForkWheelBuilder.token == nil ? "Not set" : "Set ✓"
            token.accessoryType = .disclosureIndicator
            cell = token
        default:
            switch(indexPath.row) {
            case 0:
                cell = UITableViewCell()
                cell.textLabel?.text = "Clear Module Cache"
                break
            default:
                cell = UITableViewCell()
                cell.textLabel?.text = "Clear Project Cache"
                break
            }
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        /* fork: the token for iOS wheel builds */
        if indexPath.section == 5 {
            tableView.deselectRow(at: indexPath, animated: true)
            if indexPath.row > 0 {
                ForkWheelBuilder.ask(kind: ForkWheelBuilder.Kind.allCases[indexPath.row - 1], from: self)
            } else {
                forkEditWheelToken(tableView)
            }
            return
        }
        if(indexPath.section == 3) {
            // TODO: use the indication popup for cache clearing
            switch(indexPath.row) {
            case 0:
                NXBootstrap.shared().clear(NXBootstrap.shared().swiftModuleCacheURL)
                break
            default:
                NXBootstrap.shared().clear(NXBootstrap.shared().cacheURL)
                break
            }
            try? FileManager.default.removeItem(at: NXBootstrap.shared().swiftModuleCacheURL)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

/// fork: what the Speed options do
enum ForkBuildSpeedFooter {
    static var text: String {
        let cores = "\(ForkBuildSpeed.performanceCores) performance of \(ForkBuildSpeed.allCores) cores"
        let now = ForkBuildSpeed.hasMoreMemory
            ? "Now: more memory, builds use \(ForkBuildSpeed.threads) threads."
            : "Now: normal memory, builds use \(ForkBuildSpeed.threads) threads (\(cores))."
        let failed = UserDefaults.standard.bool(forKey: ForkBuildSpeed.onePassFailedKey)
            ? " One Pass failed here once, so Automatic leaves it off; choose an option to try it again." : ""
        return "Swift in One Pass compiles all Swift files of a project in a single run (whole module): SwiftUI and the other frameworks are loaded, and the code is checked, once instead of once per file. With Incremental Build on, only the Swift files that changed are compiled again when the change is inside bodies (a view's body, a function), which is faster for edit and run, so Automatic leaves One Pass off then; with Incremental Build off it turns One Pass on with Increased Memory Limit (or 4 GB or more) and two or more Swift files. Run with nothing changed opens the installed app at once. If a one-pass build fails without an error in the code, it is compiled file by file at once. All Cores uses the efficiency cores too when there is more memory. Changing these compiles the project again once. " + now + failed
    }
}

// MARK: - fork: iOS wheels token

extension ToolChainViewController {
    func forkEditWheelToken(_ tableView: UITableView) {
        let hasToken = ForkWheelBuilder.token != nil
        let alert = UIAlertController(
            title: "GitHub Token",
            message: "Paste a fine-grained token for doctoralvarez/Nyxian with \"Actions: Read and write\". It is saved in the Keychain of this device.",
            preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = hasToken ? "Paste to replace the saved token" : "github_pat_…"
            field.isSecureTextEntry = true
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if hasToken {
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
                ForkWheelBuilder.saveToken(nil)
                tableView.reloadSections(IndexSet(integer: 5), with: .automatic)
            })
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let saved = ForkWheelBuilder.saveToken(text)
            NXAlertDiagnosticPresenter.notifyUser(with: saved ? .note : .warning, withMessage: saved ? "Token saved" : "Could not save the token", withDelay: 0.0)
            tableView.reloadSections(IndexSet(integer: 5), with: .automatic)
        })
        present(alert, animated: true)
    }
}

