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
        return 5
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 4 { return 3 }
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
                cell = PickerTableCell(options: ForkBuildSpeed.onePassOptions, title: "Swift in One Pass", key: ForkBuildSpeed.onePassKey, defaultValue: 0)
            default:
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "All Cores with More Memory", key: ForkBuildSpeed.allCoresKey, defaultValue: true)
            }
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
        return "Swift in One Pass compiles all Swift files of a project in a single run (whole module): SwiftUI and the other frameworks are loaded, and the code is checked, once instead of once per file, and the machine code of each file is made in parallel. It needs more memory, so Automatic turns it on with Increased Memory Limit (or 4 GB or more) and two or more Swift files; a project of one Swift file builds the same either way. All Cores uses the efficiency cores too when there is more memory. Changing these compiles the project again once. " + now
    }
}

