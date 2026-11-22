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
  - 1.0.0 (2026-11-22): Settings › App Store Connect. Your App Store Connect
    API key (Issuer ID, Key ID, .p8) signs the requests (ES256 JWT, CryptoKit);
    "Test Connection" lists your apps. Your Apple Distribution certificate
    (.p12 + password) and App Store provisioning profiles sign an .ipa for the
    App Store (zsign, apps without extensions for now), and the .ipa goes up
    with Apple's Build Uploads API (buildUploads / buildUploadFiles, the parts
    to Apple's presigned URLs, commit), then its processing state is followed.
    Secrets stay in this device's Keychain.
*/

import UIKit
import Foundation
import CryptoKit
import Security
import UniformTypeIdentifiers

// MARK: - Keychain

enum ForkASCKeychain {
    static let service = "doctoralvarez.nyxian.appstoreconnect"

    static func set(_ data: Data, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Account

enum ForkASCAccount {
    static let issuerKey = "fork.asc.issuerID"
    static let keyIDKey = "fork.asc.keyID"

    static var issuerID: String {
        get { UserDefaults.standard.string(forKey: issuerKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: issuerKey) }
    }

    static var keyID: String {
        get { UserDefaults.standard.string(forKey: keyIDKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: keyIDKey) }
    }

    static var privateKeyPEM: String? {
        guard let d = ForkASCKeychain.get("p8") else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static var p12: Data? { ForkASCKeychain.get("p12") }
    static var p12Password: String {
        get { ForkASCKeychain.get("p12pass").flatMap { String(data: $0, encoding: .utf8) } ?? "" }
        set { ForkASCKeychain.set(Data(newValue.utf8), for: "p12pass") }
    }

    static var isConfigured: Bool { !issuerID.isEmpty && !keyID.isEmpty && privateKeyPEM != nil }

    /// Key ID from a file named AuthKey_<KEYID>.p8
    static func keyID(fromFileName name: String) -> String? {
        let base = (name as NSString).deletingPathExtension
        guard base.hasPrefix("AuthKey_") else { return nil }
        let id = String(base.dropFirst("AuthKey_".count))
        return id.isEmpty ? nil : id
    }
}

// MARK: - JWT (ES256)

enum ForkASCError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}

enum ForkASCAuth {
    private static var cached: (token: String, expires: Date)?

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// A token for api.appstoreconnect.apple.com (valid 19 minutes, reused for 15)
    static func token() throws -> String {
        if let c = cached, c.expires > Date() { return c.token }
        guard ForkASCAccount.isConfigured, let pem = ForkASCAccount.privateKeyPEM else {
            throw ForkASCError.message("Add your Issuer ID, Key ID and .p8 key first (Settings › App Store Connect).")
        }
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(pemRepresentation: pem)
        } catch {
            throw ForkASCError.message("The .p8 key could not be read: \(error.localizedDescription)")
        }
        let now = Int(Date().timeIntervalSince1970)
        let header: [String: Any] = ["alg": "ES256", "kid": ForkASCAccount.keyID, "typ": "JWT"]
        let payload: [String: Any] = ["iss": ForkASCAccount.issuerID, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"]
        let h = base64URL(try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]))
        let p = base64URL(try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
        let input = "\(h).\(p)"
        let signature = try key.signature(for: Data(input.utf8)).rawRepresentation
        let token = "\(input).\(base64URL(signature))"
        cached = (token, Date().addingTimeInterval(15 * 60))
        return token
    }

    static func reset() { cached = nil }
}

// MARK: - API

enum ForkASCAPI {
    static let base = URL(string: "https://api.appstoreconnect.apple.com")!

    /// JSON request to App Store Connect; errors come back as Apple's own text
    static func request(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: path, relativeTo: base) else { throw ForkASCError.message("Bad path \(path)") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 60
        req.setValue("Bearer \(try ForkASCAuth.token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
        if status >= 400 || status == 0 {
            if status == 401 { ForkASCAuth.reset() }
            throw ForkASCError.message("App Store Connect (\(status)): \(describeErrors(json) ?? HTTPURLResponse.localizedString(forStatusCode: status))")
        }
        return json
    }

    static func describeErrors(_ json: [String: Any]) -> String? {
        guard let errors = json["errors"] as? [[String: Any]], !errors.isEmpty else { return nil }
        return errors.map { e in
            let title = e["title"] as? String ?? ""
            let detail = e["detail"] as? String ?? ""
            let code = e["code"] as? String ?? ""
            return [title, detail, code.isEmpty ? "" : "(\(code))"].filter { !$0.isEmpty }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    struct App { let id: String; let name: String; let bundleID: String }

    static func apps() async throws -> [App] {
        let json = try await request("GET", "/v1/apps?limit=200&fields[apps]=name,bundleId")
        let data = json["data"] as? [[String: Any]] ?? []
        return data.compactMap { item in
            guard let id = item["id"] as? String, let a = item["attributes"] as? [String: Any] else { return nil }
            return App(id: id, name: a["name"] as? String ?? "", bundleID: a["bundleId"] as? String ?? "")
        }
    }

    static func app(bundleID: String) async throws -> App? {
        let q = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleID
        let json = try await request("GET", "/v1/apps?filter[bundleId]=\(q)&fields[apps]=name,bundleId")
        let data = json["data"] as? [[String: Any]] ?? []
        for item in data {
            guard let id = item["id"] as? String, let a = item["attributes"] as? [String: Any] else { continue }
            if (a["bundleId"] as? String) == bundleID {
                return App(id: id, name: a["name"] as? String ?? "", bundleID: bundleID)
            }
        }
        return nil
    }
}

// MARK: - Provisioning profiles

struct ForkASCProfile {
    let url: URL
    let name: String
    let teamID: String
    let appIDPattern: String       // e.g. com.example.app or com.example.*
    let expires: Date?
    let isAppStore: Bool
    let data: Data

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AppStoreConnect/Profiles", isDirectory: true)
    }

    /// The plist inside the CMS envelope of a .mobileprovision
    static func plist(from data: Data) -> [String: Any]? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return nil }
        let slice = data[start.lowerBound..<end.upperBound]
        return (try? PropertyListSerialization.propertyList(from: Data(slice), format: nil)) as? [String: Any]
    }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url), let p = ForkASCProfile.plist(from: data) else { return nil }
        self.url = url
        self.data = data
        self.name = p["Name"] as? String ?? url.deletingPathExtension().lastPathComponent
        self.teamID = (p["TeamIdentifier"] as? [String])?.first ?? ""
        let ent = p["Entitlements"] as? [String: Any] ?? [:]
        let appID = ent["application-identifier"] as? String ?? ""
        let prefix = teamID.isEmpty ? "" : teamID + "."
        self.appIDPattern = appID.hasPrefix(prefix) ? String(appID.dropFirst(prefix.count)) : appID
        self.expires = p["ExpirationDate"] as? Date
        let devices = p["ProvisionedDevices"] as? [Any]
        let allDevices = p["ProvisionsAllDevices"] as? Bool ?? false
        let debug = ent["get-task-allow"] as? Bool ?? false
        self.isAppStore = devices == nil && !allDevices && !debug
    }

    func matches(_ bundleID: String) -> Bool {
        if appIDPattern == "*" { return true }
        if appIDPattern.hasSuffix(".*") { return bundleID.hasPrefix(String(appIDPattern.dropLast(1))) }
        return appIDPattern == bundleID
    }

    var expired: Bool { (expires ?? .distantFuture) < Date() }

    static func all() -> [ForkASCProfile] {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "mobileprovision" }.compactMap { ForkASCProfile(url: $0) }
            .sorted { $0.name < $1.name }
    }

    /// The App Store profile for this bundle ID (an exact one before a wildcard)
    static func best(for bundleID: String) -> ForkASCProfile? {
        let candidates = all().filter { $0.isAppStore && !$0.expired && $0.matches(bundleID) }
        return candidates.first(where: { $0.appIDPattern == bundleID }) ?? candidates.first
    }
}

// MARK: - .ipa: read, sign, upload

struct ForkASCIPAInfo {
    let ipa: URL
    let workFolder: URL
    let appFolder: URL
    let bundleID: String
    let version: String
    let build: String
    let name: String
    let extensions: [String]
}

enum ForkASCPipeline {
    static func workRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AppStoreConnect", isDirectory: true)
    }

    static func inspect(_ ipa: URL) throws -> ForkASCIPAInfo {
        let fm = FileManager.default
        let work = workRoot().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        guard unzipArchiveAtPath(ipa.path, work.path) else { throw ForkASCError.message("The .ipa could not be opened (is it a zip with Payload/?).") }
        let payload = work.appendingPathComponent("Payload")
        guard let app = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension == "app" }) else {
            throw ForkASCError.message("The .ipa has no Payload/<Name>.app.")
        }
        guard let data = try? Data(contentsOf: app.appendingPathComponent("Info.plist")),
              let info = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else {
            throw ForkASCError.message("The app has no readable Info.plist.")
        }
        let plugIns = app.appendingPathComponent("PlugIns")
        let exts = ((try? fm.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "appex" }
            .compactMap { url -> String? in
                guard let d = try? Data(contentsOf: url.appendingPathComponent("Info.plist")),
                      let p = (try? PropertyListSerialization.propertyList(from: d, format: nil)) as? [String: Any] else { return nil }
                return p["CFBundleIdentifier"] as? String
            }
        return ForkASCIPAInfo(ipa: ipa, workFolder: work, appFolder: app,
                              bundleID: info["CFBundleIdentifier"] as? String ?? "",
                              version: info["CFBundleShortVersionString"] as? String ?? "",
                              build: info["CFBundleVersion"] as? String ?? "",
                              name: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? app.deletingPathExtension().lastPathComponent,
                              extensions: exts)
    }

    /// What is missing to sign this app for the App Store, or nil when it can be signed
    static func signingProblem(_ info: ForkASCIPAInfo) -> String? {
        if ForkASCAccount.p12 == nil { return "Import your Apple Distribution certificate (.p12) first." }
        if !info.extensions.isEmpty {
            return "This app has extensions (\(info.extensions.joined(separator: ", "))). Signing apps with widgets for the App Store needs a profile for each one and is not ready yet; upload an .ipa already signed for the App Store, or one without them."
        }
        if ForkASCProfile.best(for: info.bundleID) == nil {
            return "No App Store provisioning profile for \(info.bundleID). Create one at developer.apple.com (Profiles › App Store Connect) and import it."
        }
        return nil
    }

    /// Signs Payload/<App>.app with the distribution certificate and its App Store profile; returns the new .ipa
    static func signForAppStore(_ info: ForkASCIPAInfo) async throws -> URL {
        if let problem = signingProblem(info) { throw ForkASCError.message(problem) }
        guard let profile = ForkASCProfile.best(for: info.bundleID), let p12 = ForkASCAccount.p12 else {
            throw ForkASCError.message("Missing certificate or profile.")
        }
        let fm = FileManager.default
        /* the old signature and profile go; zsign writes the App Store ones (entitlements from the profile) */
        try? fm.removeItem(at: info.appFolder.appendingPathComponent("_CodeSignature"))
        try? fm.removeItem(at: info.appFolder.appendingPathComponent("embedded.mobileprovision"))
        let password = ForkASCAccount.p12Password
        let ok: Bool = try await withCheckedThrowingContinuation { cont in
            _ = ZSigner.sign(withAppPath: info.appFolder.path, prov: profile.data, key: p12, pass: password) { success, error in
                if let error, !success { cont.resume(throwing: error) } else { cont.resume(returning: success) }
            }
        }
        guard ok else { throw ForkASCError.message("Signing failed: check the .p12 password and that the profile was made for this certificate.") }
        let out = workRoot().appendingPathComponent("\(info.name)-AppStore-\(info.build).ipa")
        try? fm.removeItem(at: out)
        zipDirectoryAtPath(info.workFolder.appendingPathComponent("Payload").path, out.path, true)
        guard fm.fileExists(atPath: out.path) else { throw ForkASCError.message("The signed .ipa could not be written.") }
        return out
    }

    /// Uploads the .ipa (Build Uploads API); returns the build upload ID
    static func upload(_ ipa: URL, info: ForkASCIPAInfo, progress: @escaping (Double, String) -> Void) async throws -> String {
        progress(0, "Looking for \(info.bundleID) in App Store Connect…")
        guard let app = try await ForkASCAPI.app(bundleID: info.bundleID) else {
            throw ForkASCError.message("App Store Connect has no app with the bundle ID \(info.bundleID). Create it first (App Store Connect › Apps › +).")
        }
        let size = (try FileManager.default.attributesOfItem(atPath: ipa.path)[.size] as? NSNumber)?.int64Value ?? 0
        progress(0, "Creating the build upload \(info.version) (\(info.build)) for \(app.name)…")
        let upload = try await ForkASCAPI.request("POST", "/v1/buildUploads", body: [
            "data": [
                "type": "buildUploads",
                "attributes": [
                    "cfBundleShortVersionString": info.version,
                    "cfBundleVersion": info.build,
                    "platform": "IOS"
                ],
                "relationships": ["app": ["data": ["type": "apps", "id": app.id]]]
            ]
        ])
        guard let uploadID = (upload["data"] as? [String: Any])?["id"] as? String else {
            throw ForkASCError.message("App Store Connect did not return a build upload.")
        }
        let reservation = try await ForkASCAPI.request("POST", "/v1/buildUploadFiles", body: [
            "data": [
                "type": "buildUploadFiles",
                "attributes": [
                    "assetType": "ASSET",
                    "fileName": ipa.lastPathComponent,
                    "fileSize": size,
                    "uti": "com.apple.ipa"
                ],
                "relationships": ["buildUpload": ["data": ["type": "buildUploads", "id": uploadID]]]
            ]
        ])
        guard let file = reservation["data"] as? [String: Any], let fileID = file["id"] as? String,
              let attrs = file["attributes"] as? [String: Any],
              let operations = attrs["uploadOperations"] as? [[String: Any]], !operations.isEmpty else {
            throw ForkASCError.message("App Store Connect did not return where to upload the file.")
        }

        /* the parts, to Apple's presigned URLs (no Authorization header) */
        let handle = try FileHandle(forReadingFrom: ipa)
        defer { try? handle.close() }
        var sent: Int64 = 0
        for (index, op) in operations.enumerated() {
            guard let urlText = op["url"] as? String, let url = URL(string: urlText) else { continue }
            let offset = (op["offset"] as? NSNumber)?.int64Value ?? 0
            let length = (op["length"] as? NSNumber)?.intValue ?? 0
            try handle.seek(toOffset: UInt64(offset))
            let chunk = handle.readData(ofLength: length)
            var req = URLRequest(url: url)
            req.httpMethod = op["method"] as? String ?? "PUT"
            req.timeoutInterval = 300
            for h in op["requestHeaders"] as? [[String: Any]] ?? [] {
                if let n = h["name"] as? String, let v = h["value"] as? String { req.setValue(v, forHTTPHeaderField: n) }
            }
            var attempt = 0
            while true {
                do {
                    let (_, response) = try await URLSession.shared.upload(for: req, from: chunk)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status >= 200 && status < 300 { break }
                    throw ForkASCError.message("Part \(index + 1) of \(operations.count) was refused (\(status)).")
                } catch {
                    attempt += 1
                    if attempt >= 3 { throw error }
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            sent += Int64(chunk.count)
            let fraction = size > 0 ? Double(sent) / Double(size) : 1
            progress(fraction, "Uploading part \(index + 1) of \(operations.count)…")
        }

        progress(1, "Committing the upload…")
        _ = try await ForkASCAPI.request("PATCH", "/v1/buildUploadFiles/\(fileID)", body: [
            "data": ["type": "buildUploadFiles", "id": fileID, "attributes": ["uploaded": true]]
        ])
        return uploadID
    }

    struct State {
        let state: String
        let messages: [String]
        var finished: Bool { state == "COMPLETE" || state == "FAILED" }
    }

    static func state(of uploadID: String) async throws -> State {
        let json = try await ForkASCAPI.request("GET", "/v1/buildUploads/\(uploadID)")
        let attrs = (json["data"] as? [String: Any])?["attributes"] as? [String: Any] ?? [:]
        let st = attrs["state"] as? [String: Any] ?? [:]
        var messages: [String] = []
        for (kind, label) in [("errors", "Error"), ("warnings", "Warning"), ("infos", "Note")] {
            for d in st[kind] as? [[String: Any]] ?? [] {
                let code = d["code"] as? String ?? ""
                let text = d["message"] as? String ?? d["description"] as? String ?? ""
                messages.append("\(label)\(code.isEmpty ? "" : " \(code)"): \(text)")
            }
        }
        return State(state: st["state"] as? String ?? "UNKNOWN", messages: messages)
    }
}

// MARK: - Settings › App Store Connect

@objc(ForkAppStoreConnectViewController)
class ForkAppStoreConnectViewController: UITableViewController, UIDocumentPickerDelegate, UITextFieldDelegate {

    private enum Pick { case p8, p12, profile, ipa }
    private var picking: Pick = .ipa

    private var status: String = ""
    private var statusMessages: [String] = []
    private var lastUploadID: String? = UserDefaults.standard.string(forKey: "fork.asc.lastUpload")
    private var busy = false
    private var pollTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Store Connect"
        tableView.keyboardDismissMode = .onDrag
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { pollTask?.cancel() }
    }

    // MARK: table

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 4
        case 1: return 3 + ForkASCProfile.all().count
        case 2: return 1
        default: return 2 + statusMessages.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["API Key", "Distribution Signing", "Upload", "Last Upload"][section]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Make the key in App Store Connect › Users and Access › Integrations › App Store Connect API (role App Manager or Admin). The .p8 can be downloaded once; its file name AuthKey_<Key ID>.p8 fills the Key ID. The key stays in this device's Keychain."
        case 1:
            return "Your Apple Distribution certificate as .p12 (export it with its private key from a Mac's Keychain Access, or from a signing tool) and an App Store provisioning profile for each bundle ID (developer.apple.com › Profiles › App Store Connect). Apps with widgets need one per extension and are not signed here yet."
        case 2:
            return "Pick an .ipa (an Export from Nyxian, saved to Files). Nyxian signs it for the App Store when you have the certificate and profile, then uploads it with Apple's Build Uploads API. The build shows in App Store Connect and TestFlight after Apple processes it (minutes)."
        default:
            return nil
        }
    }

    private func valueCell(_ title: String, _ value: String, symbol: String, accessory: Bool = true) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = value
        cell.imageView?.image = UIImage(systemName: symbol)
        cell.accessoryType = accessory ? .disclosureIndicator : .none
        return cell
    }

    private func fieldCell(_ placeholder: String, text: String, tag: Int, secure: Bool = false) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let field = UITextField()
        field.placeholder = placeholder
        field.text = text
        field.tag = tag
        field.isSecureTextEntry = secure
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        field.delegate = self
        field.addTarget(self, action: #selector(fieldChanged(_:)), for: .editingChanged)
        field.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            field.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
            field.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
        ])
        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (indexPath.section, indexPath.row) {
        case (0, 0): return fieldCell("Issuer ID", text: ForkASCAccount.issuerID, tag: 1)
        case (0, 1): return fieldCell("Key ID", text: ForkASCAccount.keyID, tag: 2)
        case (0, 2): return valueCell("Private Key (.p8)", ForkASCAccount.privateKeyPEM == nil ? "Import" : "In Keychain", symbol: "key.fill")
        case (0, 3):
            let c = valueCell("Test Connection", "", symbol: "checkmark.icloud", accessory: false)
            c.textLabel?.textColor = .systemBlue
            return c
        case (1, 0): return valueCell("Certificate (.p12)", ForkASCAccount.p12 == nil ? "Import" : "In Keychain", symbol: "person.badge.key.fill")
        case (1, 1): return fieldCell("Certificate password", text: ForkASCAccount.p12Password, tag: 3, secure: true)
        case (1, 2):
            let c = valueCell("Import Provisioning Profile", "", symbol: "doc.badge.plus", accessory: false)
            c.textLabel?.textColor = .systemBlue
            return c
        case (1, let row):
            let p = ForkASCProfile.all()[row - 3]
            let kind = p.isAppStore ? "App Store" : "not App Store"
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = p.name
            cell.detailTextLabel?.text = "\(p.appIDPattern) · \(kind)\(p.expired ? " · expired" : "")"
            cell.detailTextLabel?.textColor = (p.isAppStore && !p.expired) ? .secondaryLabel : .systemOrange
            cell.imageView?.image = UIImage(systemName: "doc.text.fill")
            return cell
        case (2, _):
            let c = valueCell(busy ? "Working…" : "Upload .ipa to App Store Connect", "", symbol: "icloud.and.arrow.up.fill", accessory: false)
            c.textLabel?.textColor = busy ? .secondaryLabel : .systemBlue
            return c
        case (3, 0):
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = status.isEmpty ? (lastUploadID == nil ? "No upload yet" : "Upload \(lastUploadID ?? "")") : status
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return cell
        case (3, 1):
            let c = valueCell("Refresh State", "", symbol: "arrow.clockwise", accessory: false)
            c.textLabel?.textColor = lastUploadID == nil ? .secondaryLabel : .systemBlue
            return c
        default:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = statusMessages[indexPath.row - 2]
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.selectionStyle = .none
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1 && indexPath.row >= 3
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.section == 1, indexPath.row >= 3 else { return }
        try? FileManager.default.removeItem(at: ForkASCProfile.all()[indexPath.row - 3].url)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch (indexPath.section, indexPath.row) {
        case (0, 2): pick(.p8)
        case (0, 3): testConnection()
        case (1, 0): pick(.p12)
        case (1, 2): pick(.profile)
        case (2, _): if !busy { pick(.ipa) }
        case (3, 1): if let id = lastUploadID { follow(id, once: true) }
        default: break
        }
    }

    @objc private func fieldChanged(_ field: UITextField) {
        let text = field.text ?? ""
        switch field.tag {
        case 1: ForkASCAccount.issuerID = text; ForkASCAuth.reset()
        case 2: ForkASCAccount.keyID = text; ForkASCAuth.reset()
        case 3: ForkASCAccount.p12Password = text
        default: break
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: status

    private func setStatus(_ text: String, messages: [String]? = nil) {
        status = text
        if let messages { statusMessages = messages }
        tableView.reloadSections(IndexSet(integersIn: 2...3), with: .none)
    }

    private func alert(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: picking files

    private func pick(_ kind: Pick) {
        picking = kind
        var types: [UTType] = []
        switch kind {
        case .p8: types = [UTType(filenameExtension: "p8")].compactMap { $0 }
        case .p12: types = [UTType.pkcs12, UTType(filenameExtension: "p12")].compactMap { $0 }
        case .profile: types = [UTType(filenameExtension: "mobileprovision")].compactMap { $0 }
        case .ipa: types = [UTType(filenameExtension: "ipa")].compactMap { $0 }
        }
        /* generic types last so the file is never greyed out; the extension is checked after */
        types += [UTType.data, UTType.item]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()
        let data = try? Data(contentsOf: url)
        switch picking {
        case .p8:
            guard ext == "p8", let data, let pem = String(data: data, encoding: .utf8), pem.contains("PRIVATE KEY") else {
                alert("Not a .p8 key", "Pick the AuthKey_<Key ID>.p8 file from App Store Connect.")
                return
            }
            ForkASCKeychain.set(Data(pem.utf8), for: "p8")
            if ForkASCAccount.keyID.isEmpty, let id = ForkASCAccount.keyID(fromFileName: url.lastPathComponent) {
                ForkASCAccount.keyID = id
            }
            ForkASCAuth.reset()
            tableView.reloadData()
        case .p12:
            guard ext == "p12" || ext == "pfx", let data else {
                alert("Not a .p12", "Pick your Apple Distribution certificate exported as .p12.")
                return
            }
            ForkASCKeychain.set(data, for: "p12")
            tableView.reloadData()
        case .profile:
            guard ext == "mobileprovision", let data, ForkASCProfile.plist(from: data) != nil else {
                alert("Not a provisioning profile", "Pick a .mobileprovision file.")
                return
            }
            let dest = ForkASCProfile.folder.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.createDirectory(at: ForkASCProfile.folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: dest)
            try? data.write(to: dest)
            tableView.reloadData()
            if let p = ForkASCProfile(url: dest), !p.isAppStore {
                alert("Not an App Store profile", "\(p.name) is a development or ad hoc profile; App Store uploads need an App Store Connect distribution profile.")
            }
        case .ipa:
            guard ext == "ipa" else {
                alert("Not an .ipa", "Pick an .ipa file.")
                return
            }
            /* keep our own copy: the picker's goes away */
            let copy = ForkASCPipeline.workRoot().appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.createDirectory(at: ForkASCPipeline.workRoot(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: copy)
            try? FileManager.default.copyItem(at: url, to: copy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.prepareUpload(copy) }
        }
    }

    // MARK: actions

    private func testConnection() {
        setStatus("Testing the connection…", messages: [])
        Task { @MainActor in
            do {
                let apps = try await ForkASCAPI.apps()
                let list = apps.prefix(30).map { "\($0.name) — \($0.bundleID)" }
                setStatus("Connected: \(apps.count) app\(apps.count == 1 ? "" : "s") in App Store Connect.", messages: Array(list))
            } catch {
                setStatus("Could not connect: \(error.localizedDescription)", messages: [])
            }
        }
    }

    private func prepareUpload(_ ipa: URL) {
        guard ForkASCAccount.isConfigured else {
            alert("API key needed", "Add your Issuer ID, Key ID and .p8 key first.")
            return
        }
        let info: ForkASCIPAInfo
        do { info = try ForkASCPipeline.inspect(ipa) } catch {
            alert("Cannot read the .ipa", error.localizedDescription)
            return
        }
        let problem = ForkASCPipeline.signingProblem(info)
        let sheet = UIAlertController(title: "\(info.name) \(info.version) (\(info.build))",
                                      message: info.bundleID + (problem.map { "\n\n" + $0 } ?? ""),
                                      preferredStyle: .actionSheet)
        if problem == nil {
            sheet.addAction(UIAlertAction(title: "Sign for App Store and Upload", style: .default) { _ in self.run(info, sign: true) })
        }
        sheet.addAction(UIAlertAction(title: "Upload As Is (already signed)", style: .default) { _ in self.run(info, sign: false) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = tableView
            pop.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: 2))
        }
        present(sheet, animated: true)
    }

    private func run(_ info: ForkASCIPAInfo, sign: Bool) {
        busy = true
        pollTask?.cancel()
        setStatus(sign ? "Signing for the App Store…" : "Starting…", messages: [])
        Task { @MainActor in
            do {
                let ipa = sign ? try await ForkASCPipeline.signForAppStore(info) : info.ipa
                let id = try await ForkASCPipeline.upload(ipa, info: info) { fraction, text in
                    Task { @MainActor in self.setStatus("\(text) \(Int(fraction * 100))%") }
                }
                lastUploadID = id
                UserDefaults.standard.set(id, forKey: "fork.asc.lastUpload")
                busy = false
                setStatus("Uploaded. Apple is processing the build…")
                follow(id, once: false)
            } catch {
                busy = false
                setStatus("Upload failed: \(error.localizedDescription)", messages: [])
            }
            try? FileManager.default.removeItem(at: info.workFolder)
        }
    }

    /// Reads the upload's state (every 20 s until COMPLETE or FAILED, for up to 30 min)
    private func follow(_ id: String, once: Bool) {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            let deadline = Date().addingTimeInterval(30 * 60)
            repeat {
                do {
                    let s = try await ForkASCPipeline.state(of: id)
                    let text: String
                    switch s.state {
                    case "COMPLETE": text = "Done: the build is in App Store Connect (TestFlight shows it once processed)."
                    case "FAILED": text = "Apple did not accept the build:"
                    default: text = "Apple's state: \(s.state)"
                    }
                    setStatus(text, messages: s.messages)
                    if s.finished || once { return }
                } catch {
                    setStatus("Could not read the state: \(error.localizedDescription)")
                    if once { return }
                }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            } while !Task.isCancelled && Date() < deadline
        }
    }
}
