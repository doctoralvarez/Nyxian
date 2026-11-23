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
 Fork doctoralvarez/Nyxian — version 1.4.0
 Changelog:
  - 1.4.0 (2026-11-23): Xcode on Mac scrolls down to Last Upload and stays
    there while it works, so you see each step as it happens; at the end it
    says plainly how it went: ✅ ** ARCHIVE SUCCEEDED ** (and the upload), or
    ❌ where Xcode stopped and where its log is.
  - 1.3.2 (2026-11-22): App Icon (Assets.car) goes through the private
    repository, like Xcode on Mac: the icon is no longer on the public fork's
    release, and the token needs the same permissions for both ("Contents:
    Read and write" on the private repository, "Actions: Read and write" on
    the fork). Before it asked for Contents on the public fork (GitHub 403).
  - 1.3.1 (2026-11-22): Increased Memory Limit and Extended Virtual Addressing
    for the apps and widgets that ask for them: Xcode on Mac's automatic
    signing turns them on for the App ID (Apple's App Store Connect API refuses
    them), and the .ipa upload says when a profile lacks them.
  - 1.3.0 (2026-11-22): iCloud and Push Notifications through your Apple
    Developer account, only for the app and widgets that ask for them (Export ›
    Capabilities of each project): Nyxian turns ICLOUD / PUSH_NOTIFICATIONS on
    for their bundle IDs (and App Groups), before the App Store profiles are
    made and before Xcode on Mac signs. iCloud containers cannot be made with
    the API: Nyxian says which one to create and assign, once.
  - 1.2.0 (2026-11-22): "Xcode on Mac (recommended)": Preflight of each app
    project (ForkAppStorePreflight.swift) with fixes, then the projects go to
    Xcode on your Mac (GitHub's when it is off), which builds, signs and
    uploads the app; the build's processing is followed. The .ipa upload has
    a Preflight too (Preflight .ipa, and a report before each upload).
  - 1.1.0 (2026-11-22): automatic signing with the API key: the bundle IDs of the
    app and of each extension are registered, App Groups turned on, and one App
    Store profile made per bundle ID with the distribution certificate (imported
    .p12, or one created here from a key made on the device). zsign signs each
    bundle with its own profile, with CodeResources and embedded profiles
    (ZSigner signAppStore). App Icon: Config/AppIcon.png goes to Apple's actool
    on a Mac (iOS Asset Catalog workflow) and Assets.car comes back into
    Config/AssetCatalog, which Export puts in the app.
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

    /// Payload/<App>.app or its PlugIns/<X>.appex with this bundle ID
    static func bundleURL(_ info: ForkASCIPAInfo, identifier: String) -> URL? {
        if identifier == info.bundleID { return info.appFolder }
        let plugIns = info.appFolder.appendingPathComponent("PlugIns")
        return ((try? FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)) ?? []).first {
            ForkPreflight.readPlist($0.appendingPathComponent("Info.plist"))["CFBundleIdentifier"] as? String == identifier
        }
    }

    /// Every bundle ID to sign: the app first, then its extensions
    static func bundleIDs(_ info: ForkASCIPAInfo) -> [String] { [info.bundleID] + info.extensions }

    /// The imported App Store profiles for the app and each extension, or what is missing
    static func importedProfiles(_ info: ForkASCIPAInfo) -> (profiles: [String: Data], missing: [String]) {
        var found: [String: Data] = [:]
        var missing: [String] = []
        for id in bundleIDs(info) {
            if let p = ForkASCProfile.best(for: id) { found[id] = p.data } else { missing.append(id) }
        }
        return (found, missing)
    }

    /// Signs Payload/<App>.app and each .appex with its own App Store profile; returns the new .ipa
    static func signForAppStore(_ info: ForkASCIPAInfo, profiles: [String: Data]) async throws -> URL {
        guard let p12 = ForkASCAccount.p12 else { throw ForkASCError.message("No distribution certificate: import a .p12 or create one.") }
        let missing = bundleIDs(info).filter { profiles[$0] == nil }
        if !missing.isEmpty { throw ForkASCError.message("No App Store profile for \(missing.joined(separator: ", ")).") }
        let fm = FileManager.default
        /* the old signatures and profiles go; zsign writes the App Store ones
           (entitlements from each profile, CodeResources, embedded.mobileprovision) */
        var bundles: [URL] = [info.appFolder]
        let plugIns = info.appFolder.appendingPathComponent("PlugIns")
        bundles += ((try? fm.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "appex" }
        for bundle in bundles {
            try? fm.removeItem(at: bundle.appendingPathComponent("_CodeSignature"))
            try? fm.removeItem(at: bundle.appendingPathComponent("embedded.mobileprovision"))
        }
        let password = ForkASCAccount.p12Password
        let ok: Bool = try await withCheckedThrowingContinuation { cont in
            _ = ZSigner.signAppStore(withAppPath: info.appFolder.path, profiles: profiles, key: p12, pass: password) { success, error in
                if let error, !success { cont.resume(throwing: error) } else { cont.resume(returning: success) }
            }
        }
        guard ok else { throw ForkASCError.message("Signing failed: check the .p12 password and that the profiles were made for this certificate.") }
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


// MARK: - Automatic signing: certificate, bundle IDs and App Store profiles from the API

enum ForkASCProvisioning {
    static let certIDKey = "fork.asc.certificateID"

    static func normalizedSerial(_ s: String) -> String {
        var t = s.uppercased().filter { $0.isHexDigit }
        while t.hasPrefix("0") && t.count > 1 { t.removeFirst() }
        return t
    }

    /// The serial number of the imported .p12's certificate (hex)
    static func serialOfImportedP12() -> String? {
        guard let p12 = ForkASCAccount.p12 else { return nil }
        let options: [String: Any] = [kSecImportExportPassphrase as String: ForkASCAccount.p12Password]
        var items: CFArray?
        guard SecPKCS12Import(p12 as CFData, options as CFDictionary, &items) == errSecSuccess,
              let list = items as? [[String: Any]], let first = list.first,
              let identityRef = first[kSecImportItemIdentity as String] else { return nil }
        let identity = identityRef as! SecIdentity
        var cert: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &cert) == errSecSuccess, let cert,
              let serial = SecCertificateCopySerialNumberData(cert, nil) as Data? else { return nil }
        return normalizedSerial(serial.map { String(format: "%02X", $0) }.joined())
    }

    /// The App Store Connect ID of the distribution certificate Nyxian signs with
    static func certificateID() async throws -> String {
        guard ForkASCAccount.p12 != nil else {
            throw ForkASCError.message("No distribution certificate: import your .p12 or tap Create Distribution Certificate.")
        }
        let json = try await ForkASCAPI.request("GET", "/v1/certificates?filter[certificateType]=DISTRIBUTION,IOS_DISTRIBUTION&limit=200&fields[certificates]=serialNumber,name,certificateType")
        let data = json["data"] as? [[String: Any]] ?? []
        if let serial = serialOfImportedP12() {
            for c in data {
                let attrs = c["attributes"] as? [String: Any] ?? [:]
                if normalizedSerial(attrs["serialNumber"] as? String ?? "") == serial, let id = c["id"] as? String {
                    UserDefaults.standard.set(id, forKey: certIDKey)
                    return id
                }
            }
            throw ForkASCError.message("Your .p12 is not one of this account's distribution certificates (it may be revoked, or from another team).")
        }
        /* a .p12 Nyxian made itself (iOS cannot read its serial back): the ID kept when it was created */
        if let saved = UserDefaults.standard.string(forKey: certIDKey), data.contains(where: { ($0["id"] as? String) == saved }) {
            return saved
        }
        throw ForkASCError.message("The certificate in the Keychain could not be matched to App Store Connect; check the .p12 password.")
    }

    /// A new Apple Distribution certificate: the key is made here and never leaves the device
    static func createCertificate() async throws -> String {
        guard let csr = ZSigner.makeCSR(withCommonName: "Apple Distribution") as? [String: Any],
              let csrText = csr["csr"] as? String, let keyPEM = csr["key"] as? Data else {
            throw ForkASCError.message("Could not make the key and its signing request.")
        }
        let json = try await ForkASCAPI.request("POST", "/v1/certificates", body: [
            "data": ["type": "certificates", "attributes": ["csrContent": csrText, "certificateType": "DISTRIBUTION"]]
        ])
        guard let item = json["data"] as? [String: Any], let id = item["id"] as? String,
              let attrs = item["attributes"] as? [String: Any],
              let content = attrs["certificateContent"] as? String, let der = Data(base64Encoded: content) else {
            throw ForkASCError.message("App Store Connect did not return the certificate.")
        }
        let password = UUID().uuidString
        guard let p12 = ZSigner.makeP12(withCertificate: der, privateKey: keyPEM, password: password, name: "Apple Distribution") else {
            throw ForkASCError.message("Could not package the certificate as .p12.")
        }
        ForkASCKeychain.set(p12, for: "p12")
        ForkASCAccount.p12Password = password
        UserDefaults.standard.set(id, forKey: certIDKey)
        return id
    }

    /// The bundle ID resource (registered when it does not exist yet)
    static func bundleIDResource(_ identifier: String, name: String) async throws -> String {
        let q = identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? identifier
        let json = try await ForkASCAPI.request("GET", "/v1/bundleIds?filter[identifier]=\(q)&limit=200&fields[bundleIds]=identifier,name,platform")
        for item in json["data"] as? [[String: Any]] ?? [] {
            let attrs = item["attributes"] as? [String: Any] ?? [:]
            if (attrs["identifier"] as? String) == identifier, let id = item["id"] as? String { return id }
        }
        let safeName = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }.map(String.init).joined()
        let created = try await ForkASCAPI.request("POST", "/v1/bundleIds", body: [
            "data": ["type": "bundleIds", "attributes": ["identifier": identifier, "name": safeName.isEmpty ? "App" : safeName, "platform": "IOS"]]
        ])
        guard let id = (created["data"] as? [String: Any])?["id"] as? String else {
            throw ForkASCError.message("Could not register \(identifier).")
        }
        return id
    }

    /// Turns on App Groups for a bundle ID (already on: fine)
    static func enableAppGroups(_ bundleResourceID: String) async {
        _ = try? await ForkASCAPI.request("POST", "/v1/bundleIdCapabilities", body: [
            "data": [
                "type": "bundleIdCapabilities",
                "attributes": ["capabilityType": "APP_GROUPS"],
                "relationships": ["bundleId": ["data": ["type": "bundleIds", "id": bundleResourceID]]]
            ]
        ])
    }

    /// What a bundle asks for in its entitlements: iCloud, Push Notifications, App Groups
    struct Requested {
        var iCloud = false
        var containers: [String] = []
        var push = false
        var groups: [String] = []
        var memory = false
        var addressing = false
        var names: [String] {
            (iCloud ? ["iCloud"] : []) + (push ? ["Push Notifications"] : []) + (groups.isEmpty ? [] : ["App Groups"])
                + (memory ? ["Increased Memory Limit"] : []) + (addressing ? ["Extended Virtual Addressing"] : [])
        }
        /// the ones Apple's API turns on (the memory ones only Xcode's signing does)
        var byAPI: [String] {
            (iCloud ? ["iCloud"] : []) + (push ? ["Push Notifications"] : []) + (groups.isEmpty ? [] : ["App Groups"])
        }
    }

    static func requested(_ entitlements: [String: Any]) -> Requested {
        var r = Requested()
        r.containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
        r.iCloud = !r.containers.isEmpty || entitlements["com.apple.developer.icloud-services"] != nil || entitlements["com.apple.developer.ubiquity-kvstore-identifier"] != nil
        r.push = entitlements["aps-environment"] != nil
        r.groups = entitlements["com.apple.security.application-groups"] as? [String] ?? []
        r.memory = entitlements["com.apple.developer.kernel.increased-memory-limit"] != nil
        r.addressing = entitlements["com.apple.developer.kernel.extended-virtual-addressing"] != nil
        return r
    }

    /// Turns on, at Apple, only what this bundle asks for (already on: fine)
    static func enableRequested(_ bundleResourceID: String, _ r: Requested) async -> [String] {
        var notes: [String] = []
        func enable(_ type: String, settings: [[String: Any]]? = nil) async {
            var attributes: [String: Any] = ["capabilityType": type]
            if let settings { attributes["settings"] = settings }
            do {
                _ = try await ForkASCAPI.request("POST", "/v1/bundleIdCapabilities", body: [
                    "data": [
                        "type": "bundleIdCapabilities",
                        "attributes": attributes,
                        "relationships": ["bundleId": ["data": ["type": "bundleIds", "id": bundleResourceID]]]
                    ]
                ])
            } catch {
                let text = error.localizedDescription
                /* "already enabled" comes back as a conflict: that is what we want */
                if !text.contains("409") && !text.localizedCaseInsensitiveContains("already") {
                    notes.append("\(type): \(text)")
                }
            }
        }
        if !r.groups.isEmpty { await enable("APP_GROUPS") }
        if r.iCloud { await enable("ICLOUD", settings: [["key": "ICLOUD_VERSION", "options": [["key": "XCODE_6"]]]]) }
        if r.push { await enable("PUSH_NOTIFICATIONS") }
        return notes
    }

    /// What the profile lacks of what the bundle asks for, said the way to fix it
    static func missingInProfile(_ identifier: String, _ r: Requested, profile: Data) -> [String] {
        let ent = (ForkASCProfile.plist(from: profile)?["Entitlements"] as? [String: Any]) ?? [:]
        var notes: [String] = []
        let memoryNames = (r.memory && ent["com.apple.developer.kernel.increased-memory-limit"] == nil ? ["Increased Memory Limit"] : [])
            + (r.addressing && ent["com.apple.developer.kernel.extended-virtual-addressing"] == nil ? ["Extended Virtual Addressing"] : [])
        if !memoryNames.isEmpty {
            notes.append("\(identifier): the profile has no \(memoryNames.joined(separator: " / ")). Apple's App Store Connect API cannot turn these on (it refuses them): Xcode on Mac does it when it signs, or turn it on once for the App ID at developer.apple.com (or with GetMoreRam), then Upload again.")
        }
        if r.push && ent["aps-environment"] == nil {
            notes.append("\(identifier): the profile has no Push Notifications yet; tap Upload again in a minute (Apple turns it on for the App ID first).")
        }
        if r.iCloud {
            let have = ent["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
            let missing = r.containers.filter { !have.contains($0) }
            if !missing.isEmpty {
                notes.append("\(identifier): iCloud is on, but the container \(missing.joined(separator: ", ")) is not assigned. The API cannot make containers: at developer.apple.com › Identifiers › iCloud Containers create it (once), then \(identifier) › iCloud › Configure › tick it; Upload again.")
            }
        }
        return notes
    }

    /// Bundle IDs registered and their capabilities on, for Xcode on Mac (Xcode then makes the profiles)
    static func prepareForXcode(app: NXProject, appEntitlements: [String: Any], extensions: [(id: String, name: String, entitlements: [String: Any])],
                                progress: @escaping (String) -> Void) async -> [String] {
        var notes: [String] = []
        let appID = app.projectConfig.bundleid ?? ""
        let appName = app.projectConfig.displayName ?? appID
        var all: [(id: String, name: String, entitlements: [String: Any])] = [(appID, appName, appEntitlements)]
        all += extensions
        for b in all {
            let r = requested(b.entitlements)
            if r.names.isEmpty { continue }
            if r.memory || r.addressing {
                let kinds = (r.memory ? ["Increased Memory Limit"] : []) + (r.addressing ? ["Extended Virtual Addressing"] : [])
                notes.append("\(b.id): \(kinds.joined(separator: " and ")) — Xcode's automatic signing turns it on for the App ID (Apple's API cannot).")
            }
            if r.byAPI.isEmpty { continue }
            progress("Turning on \(r.byAPI.joined(separator: ", ")) for \(b.id)…")
            do {
                let resource = try await bundleIDResource(b.id, name: b.name)
                notes += await enableRequested(resource, r)
                notes.append("\(b.id): \(r.byAPI.joined(separator: ", ")) on at Apple.")
                if r.iCloud && !r.containers.isEmpty {
                    notes.append("\(b.id): iCloud container \(r.containers.joined(separator: ", ")) — if it does not exist yet, create it at developer.apple.com › Identifiers › iCloud Containers (the API cannot); Xcode assigns it.")
                }
            } catch {
                notes.append("\(b.id): \(error.localizedDescription)")
            }
        }
        return notes
    }

    /// A fresh App Store profile for the bundle ID with the certificate (replaces the one Nyxian made before)
    static func profile(identifier: String, bundleResourceID: String, certificateID: String) async throws -> Data {
        let name = "App Store \(identifier)"
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let existing = try await ForkASCAPI.request("GET", "/v1/profiles?filter[name]=\(q)&limit=50&fields[profiles]=name")
        for item in existing["data"] as? [[String: Any]] ?? [] {
            if let id = item["id"] as? String, ((item["attributes"] as? [String: Any])?["name"] as? String) == name {
                _ = try? await ForkASCAPI.request("DELETE", "/v1/profiles/\(id)")
            }
        }
        let json = try await ForkASCAPI.request("POST", "/v1/profiles", body: [
            "data": [
                "type": "profiles",
                "attributes": ["name": name, "profileType": "IOS_APP_STORE"],
                "relationships": [
                    "bundleId": ["data": ["type": "bundleIds", "id": bundleResourceID]],
                    "certificates": ["data": [["type": "certificates", "id": certificateID]]]
                ]
            ]
        ])
        guard let attrs = (json["data"] as? [String: Any])?["attributes"] as? [String: Any],
              let content = attrs["profileContent"] as? String, let data = Data(base64Encoded: content) else {
            throw ForkASCError.message("App Store Connect did not return the profile for \(identifier).")
        }
        try? FileManager.default.createDirectory(at: ForkASCProfile.folder, withIntermediateDirectories: true)
        try? data.write(to: ForkASCProfile.folder.appendingPathComponent("\(identifier).mobileprovision"), options: .atomic)
        return data
    }

    /// App Groups the app declares (Nyxian writes them into its Info.plist)
    static func appGroups(_ info: ForkASCIPAInfo) -> [String] {
        guard let d = try? Data(contentsOf: info.appFolder.appendingPathComponent("Info.plist")),
              let p = (try? PropertyListSerialization.propertyList(from: d, format: nil)) as? [String: Any] else { return [] }
        return p["NXApplicationGroups"] as? [String] ?? []
    }

    /// Bundle IDs, App Groups and one App Store profile per bundle (app and each extension)
    static func prepare(_ info: ForkASCIPAInfo, progress: @escaping (String) -> Void) async throws -> (profiles: [String: Data], notes: [String]) {
        progress("Checking the distribution certificate…")
        let certID = try await certificateID()
        let groups = appGroups(info)
        var profiles: [String: Data] = [:]
        var notes: [String] = []
        for identifier in ForkASCPipeline.bundleIDs(info) {
            progress("Bundle ID \(identifier)…")
            let label = identifier == info.bundleID ? info.name : "\(info.name) \(identifier.components(separatedBy: ".").last ?? "")"
            let resource = try await bundleIDResource(identifier, name: label)
            if !groups.isEmpty { await enableAppGroups(resource) }
            /* 1.3.0: iCloud and Push only for the bundles whose signature asks for them */
            var asked = Requested()
            if let bundle = ForkASCPipeline.bundleURL(info, identifier: identifier),
               let exe = ForkPreflight.readPlist(bundle.appendingPathComponent("Info.plist"))["CFBundleExecutable"] as? String,
               let mach = ForkMachO(url: bundle.appendingPathComponent(exe)) {
                asked = requested(mach.entitlements)
                asked.groups = []
                if !asked.byAPI.isEmpty {
                    progress("Turning on \(asked.byAPI.joined(separator: ", ")) for \(identifier)…")
                    notes += await enableRequested(resource, asked)
                }
            }
            progress("App Store profile for \(identifier)…")
            let data = try await profile(identifier: identifier, bundleResourceID: resource, certificateID: certID)
            profiles[identifier] = data
            notes += missingInProfile(identifier, asked, profile: data)
            let ent = (ForkASCProfile.plist(from: data)?["Entitlements"] as? [String: Any]) ?? [:]
            let inProfile = ent["com.apple.security.application-groups"] as? [String] ?? []
            let missing = groups.filter { !inProfile.contains($0) }
            if !missing.isEmpty {
                notes.append("\(identifier): the profile has no App Group \(missing.joined(separator: ", ")). At developer.apple.com › Identifiers › App Groups create it (once), then open \(identifier) › App Groups › Configure and tick it; tap Upload again so Nyxian makes the profile anew. Until then the app and its widget cannot share data.")
            }
        }
        return (profiles, notes)
    }
}

// MARK: - App icon: Assets.car from Apple's actool on a Mac (GitHub Actions)

enum ForkASCIconCompiler {
    static let releaseTag = "asset-catalog"
    /* 1.3.2: the icon and Assets.car go through the private repository; only the workflow runs in the public one */
    static var storage: String { ForkAboutViewController.backupRepository }
    static let workflow = "ios-assets.yml"
    /* the workflow file is on the fork's main branch once merged; until then on this branch */
    static let refs: [String] = [ForkWheelBuilder.branch, "app-intents-2.4.0"]

    struct ProjectIcon {
        let project: NXProject
        let name: String
        var compiled: Bool { ForkAssetCatalog.isCurrent(project.url as URL) }
    }

    static func projects() -> [ProjectIcon] {
        let fm = FileManager.default
        let root = ForkEmbeddedExtensions.projectsURL
        let items = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return items.compactMap { url -> ProjectIcon? in
            guard fm.fileExists(atPath: ForkAssetCatalog.iconURL(url).path),
                  fm.fileExists(atPath: url.appendingPathComponent("Config/Project.plist").path),
                  let project = NXProject(url: url) else { return nil }
            return ProjectIcon(project: project, name: project.projectConfig.displayName ?? url.lastPathComponent)
        }.sorted { $0.name < $1.name }
    }

    private static func github(_ urlText: String, method: String = "GET", body: Data? = nil, contentType: String = "application/json", accept: String = "application/vnd.github+json") async throws -> (Data, Int) {
        guard let token = ForkWheelBuilder.token else {
            throw ForkASCError.message("Add your GitHub token in Settings › Toolchain › iOS Builds (it needs \"Contents: Read and write\" on \(storage) and \"Actions: Read and write\" on \(ForkWheelBuilder.repository)).")
        }
        guard let url = URL(string: urlText) else { throw ForkASCError.message("Bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 120
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(accept, forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            req.httpBody = body
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private static func json(_ data: Data) -> [String: Any] {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    }

    private static func explain(_ status: Int, _ data: Data, _ what: String) -> ForkASCError {
        var text = "\(what) (GitHub \(status))"
        if status == 401 { text += ": the token is not valid (or expired)." }
        if status == 403 || status == 404 { text += ": the token needs \"Contents: Read and write\" on \(storage) and \"Actions: Read and write\" on \(ForkWheelBuilder.repository)." }
        if let m = json(data)["message"] as? String { text += "\n\(m)" }
        return ForkASCError.message(text)
    }

    private static func releaseID() async throws -> Int {
        let api = "https://api.github.com/repos/\(storage)/releases"
        let (data, status) = try await github("\(api)/tags/\(releaseTag)")
        if status == 200, let id = json(data)["id"] as? Int { return id }
        let body = try JSONSerialization.data(withJSONObject: [
            "tag_name": releaseTag, "name": "Asset catalogs", "prerelease": true,
            "target_commitish": ForkWheelBuilder.branch,
            "body": "Temporary files of Settings › App Store Connect › App Icon: an icon goes up as <request>.png, comes back compiled by actool as <request>.zip, and both are removed."
        ])
        let (created, createdStatus) = try await github(api, method: "POST", body: body)
        guard createdStatus == 201, let id = json(created)["id"] as? Int else { throw explain(createdStatus, created, "Could not create the asset-catalog release") }
        return id
    }

    /// Sends Config/AppIcon.png to the Mac, waits for Assets.car and keeps it in Config/AssetCatalog
    static func compile(_ item: ProjectIcon, progress: @escaping (String) -> Void) async throws {
        let projectURL = item.project.url as URL
        let iconURL = ForkAssetCatalog.iconURL(projectURL)
        guard let png = try? Data(contentsOf: iconURL), let hash = ForkAssetCatalog.sha256(of: iconURL) else {
            throw ForkASCError.message("\(item.name) has no Config/AppIcon.png.")
        }
        let request = UUID().uuidString
        progress("Uploading the icon…")
        let release = try await releaseID()
        let upload = "https://uploads.github.com/repos/\(storage)/releases/\(release)/assets?name=\(request).png"
        let (upData, upStatus) = try await github(upload, method: "POST", body: png, contentType: "image/png")
        guard upStatus == 201 else { throw explain(upStatus, upData, "Could not upload the icon") }

        let minimum = (item.project.projectConfig.infoDictionary?["MinimumOSVersion"] as? String) ?? "17.0"
        progress("Starting actool on the Mac…")
        var started = false
        var lastError: ForkASCError?
        for ref in refs {
            let body = try JSONSerialization.data(withJSONObject: ["ref": ref, "inputs": ["request": request, "minimum": minimum]])
            let (d, st) = try await github("https://api.github.com/repos/\(ForkWheelBuilder.repository)/actions/workflows/\(workflow)/dispatches", method: "POST", body: body)
            if st == 204 { started = true; break }
            if st == 404 || st == 422 {
                /* GitHub dispatches a workflow only when its file is on the default branch */
                lastError = ForkASCError.message("GitHub did not find the iOS Asset Catalog workflow (\(st)). It has to be on the repository's default branch (\(ForkWheelBuilder.branch)): merge the branch that adds .github/workflows/\(workflow) there, then try again. (A token without \"Actions: Read and write\" gets the same answer.)")
                continue
            }
            lastError = explain(st, d, "Could not start the iOS Asset Catalog workflow")
        }
        guard started else { throw lastError ?? ForkASCError.message("Could not start the workflow.") }

        /* the answer: <request>.zip on the same release (a Mac takes a few minutes) */
        let deadline = Date().addingTimeInterval(20 * 60)
        var download: URL?
        var assetID: Int?
        while download == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 15_000_000_000)
            progress("Waiting for actool on the Mac…")
            let (d, st) = try await github("https://api.github.com/repos/\(storage)/releases/\(release)/assets?per_page=100")
            guard st == 200, let assets = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { continue }
            if let a = assets.first(where: { ($0["name"] as? String) == "\(request).zip" }), let id = a["id"] as? Int {
                /* a private repository's asset comes through the API with the token */
                download = URL(string: "https://api.github.com/repos/\(storage)/releases/assets/\(id)")
                assetID = id
            }
        }
        guard let download else {
            throw ForkASCError.message("actool did not answer in 20 minutes: see the iOS Asset Catalog workflow on GitHub.")
        }
        progress("Downloading Assets.car…")
        let (zipData, zipStatus) = try await github(download.absoluteString, accept: "application/octet-stream")
        guard zipStatus == 200 else { throw ForkASCError.message("Could not download the compiled catalog (GitHub \(zipStatus)).") }
        let fm = FileManager.default
        let tmp = ForkASCPipeline.workRoot().appendingPathComponent("icon-\(request)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let zipURL = tmp.appendingPathComponent("catalog.zip")
        try zipData.write(to: zipURL)
        let out = tmp.appendingPathComponent("out", isDirectory: true)
        guard unzipArchiveAtPath(zipURL.path, out.path),
              fm.fileExists(atPath: out.appendingPathComponent("Assets.car").path) else {
            throw ForkASCError.message("The answer from the Mac has no Assets.car.")
        }
        let dest = ForkAssetCatalog.folder(projectURL)
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: out, to: dest)
        try Data((hash + "\n").utf8).write(to: dest.appendingPathComponent("source.sha256"))
        try? fm.removeItem(at: tmp)
        if let assetID {
            _ = try? await github("https://api.github.com/repos/\(storage)/releases/assets/\(assetID)", method: "DELETE")
        }
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
    private var icons: [ForkASCIconCompiler.ProjectIcon] = []
    private var iconBusy: String?

    /// Sections
    private let sAccount = 0, sSigning = 1, sIcon = 2, sXcode = 3, sUpload = 4, sStatus = 5
    private var xcodeApps: [NXProject] = []
    private var preflightOnly = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Store Connect"
        tableView.keyboardDismissMode = .onDrag
        icons = ForkASCIconCompiler.projects()
        xcodeApps = ForkXcodeOnMac.apps()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        icons = ForkASCIconCompiler.projects()
        xcodeApps = ForkXcodeOnMac.apps()
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { pollTask?.cancel() }
    }

    // MARK: table

    override func numberOfSections(in tableView: UITableView) -> Int { 6 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case sAccount: return 4
        case sSigning: return 4 + ForkASCProfile.all().count
        case sIcon: return max(icons.count, 1)
        case sXcode: return 1 + max(xcodeApps.count, 1)
        case sUpload: return 2
        default: return 2 + statusMessages.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["API Key", "Distribution Signing", "App Icon (Assets.car)", "Xcode on Mac (recommended)", "Upload .ipa Directly", "Last Upload"][section]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case sAccount:
            return "Make the key in App Store Connect › Users and Access › Integrations › App Store Connect API (role Admin: it also makes certificates and profiles). The .p8 can be downloaded once; its file name AuthKey_<Key ID>.p8 fills the Key ID. The key stays in this device's Keychain."
        case sSigning:
            return "Automatic: with the API key Nyxian registers the bundle IDs (the app and each widget), turns on App Groups and makes one App Store profile per bundle ID with your distribution certificate, each time you upload. Import your Apple Distribution .p12, or create a certificate here (its private key is made on this device and stays in the Keychain). App Groups themselves are created once at developer.apple.com; Nyxian says when a profile lacks one. Imported profiles are used when you choose to."
        case sIcon:
            return "The App Store wants the icon in an asset catalog, which only Apple's actool writes, on a Mac. Nyxian sends the project's Config/AppIcon.png to the iOS Asset Catalog workflow (your Mac, or GitHub's) and keeps Assets.car in Config/AssetCatalog; every Export then puts it in the app. Needs the GitHub token of Settings › Toolchain › iOS Builds with \"Contents: Read and write\" on \(ForkASCIconCompiler.storage), like Xcode on Mac. The PNG only goes through that private repository and is removed after."
        case sXcode:
            return "Tap an app: Preflight checks what would go to Apple and fixes what it can, then its project and the widgets its Export embeds go to Apple's Xcode on your Mac (GitHub's when yours is off), which builds, signs (automatic, with your API key) and uploads it. The build is Xcode's own, nothing written in its place. Once, in the repository's Settings › Secrets › Actions: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (the .p8 text) and APPLE_TEAM_ID if Team ID is empty. The GitHub token needs \"Contents: Read and write\" on \(ForkXcodeOnMac.privateRepository): the projects only go through that private repository."
        case sUpload:
            return "An .ipa built by Nyxian has no DTXcode / DTSDKBuild (ITMS-90534): Apple asks for apps built with Xcode, so this upload is for builds made elsewhere, or to try. Preflight .ipa shows what Apple will likely answer. Pick an .ipa (an Export from Nyxian, saved to Files). Nyxian signs it for the App Store, the app and each widget with its own profile, then uploads it with Apple's Build Uploads API. The build shows in App Store Connect and TestFlight after Apple processes it (minutes)."
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

    private func actionCell(_ title: String, symbol: String, enabled: Bool = true) -> UITableViewCell {
        let c = valueCell(title, "", symbol: symbol, accessory: false)
        c.textLabel?.textColor = enabled ? .systemBlue : .secondaryLabel
        return c
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
        let row = indexPath.row
        switch indexPath.section {
        case sAccount:
            switch row {
            case 0: return fieldCell("Issuer ID", text: ForkASCAccount.issuerID, tag: 1)
            case 1: return fieldCell("Key ID", text: ForkASCAccount.keyID, tag: 2)
            case 2: return valueCell("Private Key (.p8)", ForkASCAccount.privateKeyPEM == nil ? "Import" : "In Keychain", symbol: "key.fill")
            default: return actionCell("Test Connection", symbol: "checkmark.icloud")
            }
        case sSigning:
            switch row {
            case 0: return valueCell("Certificate (.p12)", ForkASCAccount.p12 == nil ? "Import" : "In Keychain", symbol: "person.badge.key.fill")
            case 1: return fieldCell("Certificate password", text: ForkASCAccount.p12Password, tag: 3, secure: true)
            case 2: return actionCell("Create Distribution Certificate", symbol: "plus.seal", enabled: !busy)
            case 3: return actionCell("Import Provisioning Profile", symbol: "doc.badge.plus")
            default:
                let p = ForkASCProfile.all()[row - 4]
                let kind = p.isAppStore ? "App Store" : "not App Store"
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.textLabel?.text = p.name
                cell.detailTextLabel?.text = "\(p.appIDPattern) · \(kind)\(p.expired ? " · expired" : "")"
                cell.detailTextLabel?.textColor = (p.isAppStore && !p.expired) ? .secondaryLabel : .systemOrange
                cell.imageView?.image = UIImage(systemName: "doc.text.fill")
                return cell
            }
        case sIcon:
            guard !icons.isEmpty else {
                let c = valueCell("No project with Config/AppIcon.png", "", symbol: "app.dashed", accessory: false)
                c.textLabel?.textColor = .secondaryLabel
                c.selectionStyle = .none
                return c
            }
            let item = icons[row]
            let state: String
            if iconBusy == item.name { state = "Compiling…" } else { state = item.compiled ? "Compiled" : "Compile" }
            let c = valueCell(item.name, state, symbol: item.compiled ? "checkmark.seal.fill" : "app.badge", accessory: false)
            c.detailTextLabel?.textColor = item.compiled ? .systemGreen : .systemBlue
            return c
        case sXcode:
            if row == 0 { return fieldCell("Team ID (10 characters)", text: ForkXcodeOnMac.teamID, tag: 4) }
            guard !xcodeApps.isEmpty else {
                let c = valueCell("No app projects", "", symbol: "app.dashed", accessory: false)
                c.textLabel?.textColor = .secondaryLabel
                c.selectionStyle = .none
                return c
            }
            let p = xcodeApps[row - 1]
            let (version, build) = ForkPreflight.versions(p)
            let widgets = ForkEmbeddedExtensions.embedded(in: p).count
            let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            c.textLabel?.text = p.projectConfig.displayName ?? (p.url as URL).lastPathComponent
            c.detailTextLabel?.text = "\(p.projectConfig.bundleid ?? "") · \(version) (\(build))\(widgets > 0 ? " · \(widgets) widget\(widgets == 1 ? "" : "s")" : "")"
            c.detailTextLabel?.textColor = .secondaryLabel
            c.imageView?.image = UIImage(systemName: "hammer.circle.fill")
            c.accessoryType = .disclosureIndicator
            return c
        case sUpload:
            if row == 1 { return actionCell("Preflight .ipa (no upload)", symbol: "checklist", enabled: !busy) }
            return actionCell(busy ? "Working…" : "Upload .ipa to App Store Connect", symbol: "icloud.and.arrow.up.fill", enabled: !busy)
        default:
            switch row {
            case 0:
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.textLabel?.text = status.isEmpty ? (lastUploadID == nil ? "No upload yet" : "Upload \(lastUploadID ?? "")") : status
                cell.textLabel?.numberOfLines = 0
                cell.selectionStyle = .none
                return cell
            case 1:
                return actionCell("Refresh State", symbol: "arrow.clockwise", enabled: lastUploadID != nil)
            default:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = statusMessages[row - 2]
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
                cell.selectionStyle = .none
                return cell
            }
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == sSigning && indexPath.row >= 4
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.section == sSigning, indexPath.row >= 4 else { return }
        try? FileManager.default.removeItem(at: ForkASCProfile.all()[indexPath.row - 4].url)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = indexPath.row
        switch indexPath.section {
        case sAccount:
            if row == 2 { pick(.p8) }
            if row == 3 { testConnection() }
        case sSigning:
            if row == 0 { pick(.p12) }
            if row == 2 && !busy { createCertificate() }
            if row == 3 { pick(.profile) }
        case sIcon:
            if !icons.isEmpty && iconBusy == nil { compileIcon(icons[row]) }
        case sXcode:
            if row > 0 && row <= xcodeApps.count && !busy { xcodeMenu(xcodeApps[row - 1], at: indexPath) }
        case sUpload:
            preflightOnly = row == 1
            if !busy { pick(.ipa) }
        default:
            if row == 1, let id = lastUploadID { follow(id, once: true) }
        }
    }

    @objc private func fieldChanged(_ field: UITextField) {
        let text = field.text ?? ""
        switch field.tag {
        case 1: ForkASCAccount.issuerID = text; ForkASCAuth.reset()
        case 2: ForkASCAccount.keyID = text; ForkASCAuth.reset()
        case 3: ForkASCAccount.p12Password = text
        case 4: ForkXcodeOnMac.teamID = text
        default: break
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: status

    private func setStatus(_ text: String, messages: [String]? = nil, follow: Bool = false) {
        status = text
        if let messages { statusMessages = messages }
        tableView.reloadData()
        if follow { scrollToStatus() }
    }

    /// Last Upload, at the bottom: what Xcode on Mac is doing right now
    private func scrollToStatus() {
        DispatchQueue.main.async {
            let rows = self.tableView.numberOfRows(inSection: self.sStatus)
            guard rows > 0 else { return }
            self.tableView.scrollToRow(at: IndexPath(row: rows - 1, section: self.sStatus), at: .bottom, animated: true)
        }
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
            UserDefaults.standard.removeObject(forKey: ForkASCProvisioning.certIDKey)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if self.preflightOnly { self.preflightIPA(copy) } else { self.prepareUpload(copy) }
            }
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

    private func createCertificate() {
        guard ForkASCAccount.isConfigured else {
            alert("API key needed", "Add your Issuer ID, Key ID and .p8 key first.")
            return
        }
        let ask = UIAlertController(title: "Create a Distribution Certificate?",
                                    message: "Apple allows a few distribution certificates per team. The new one replaces the .p12 in Nyxian's Keychain; its private key is made on this device and only exists here.",
                                    preferredStyle: .alert)
        ask.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ask.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            self.busy = true
            self.setStatus("Creating the distribution certificate…", messages: [])
            Task { @MainActor in
                do {
                    let id = try await ForkASCProvisioning.createCertificate()
                    self.busy = false
                    self.setStatus("Distribution certificate created (\(id)) and kept in the Keychain.")
                } catch {
                    self.busy = false
                    self.setStatus("Could not create the certificate: \(error.localizedDescription)")
                }
            }
        })
        present(ask, animated: true)
    }

    private func compileIcon(_ item: ForkASCIconCompiler.ProjectIcon) {
        iconBusy = item.name
        setStatus("App icon of \(item.name)…", messages: [])
        Task { @MainActor in
            do {
                try await ForkASCIconCompiler.compile(item) { text in
                    Task { @MainActor in self.setStatus("\(item.name): \(text)") }
                }
                self.iconBusy = nil
                self.icons = ForkASCIconCompiler.projects()
                self.setStatus("\(item.name): Assets.car ready in Config/AssetCatalog. Export the app again to include it.")
            } catch {
                self.iconBusy = nil
                self.setStatus("App icon of \(item.name): \(error.localizedDescription)")
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
        var lines: [String] = [info.bundleID]
        if !info.extensions.isEmpty { lines.append("Extensions: \(info.extensions.joined(separator: ", "))") }
        let hasCar = FileManager.default.fileExists(atPath: info.appFolder.appendingPathComponent("Assets.car").path)
        if !hasCar { lines.append("No Assets.car: the App Store will likely refuse the icon (App Icon section above, then Export again).") }
        if ForkASCAccount.p12 == nil { lines.append("No distribution certificate yet: import a .p12 or create one.") }
        let imported = ForkASCPipeline.importedProfiles(info)
        let findings = ForkPreflight.check(ipa: info)
        let errorCount = findings.filter { $0.level == .error }.count
        lines.insert("Preflight: \(errorCount) error\(errorCount == 1 ? "" : "s"), \(findings.filter { $0.level == .warning }.count) warning(s)\(findings.contains { $0.code == "ITMS-90534" } ? " (not built by Xcode: ITMS-90534; Xcode on Mac is the way)" : "").", at: 0)

        let sheet = UIAlertController(title: "\(info.name) \(info.version) (\(info.build))",
                                      message: lines.joined(separator: "\n\n"), preferredStyle: .actionSheet)
        if ForkASCAccount.p12 != nil {
            sheet.addAction(UIAlertAction(title: "Sign (Automatic Profiles) and Upload", style: .default) { _ in self.run(info, mode: .automatic) })
            if imported.missing.isEmpty {
                sheet.addAction(UIAlertAction(title: "Sign (Imported Profiles) and Upload", style: .default) { _ in self.run(info, mode: .imported) })
            }
        }
        sheet.addAction(UIAlertAction(title: "Upload As Is (already signed)", style: .default) { _ in self.run(info, mode: .asIs) })
        sheet.addAction(UIAlertAction(title: "Preflight Report", style: .default) { _ in
            self.showPreflight(title: "Preflight · \(info.name)", note: "What Apple will likely answer for this .ipa. Apple runs more checks when it processes the build.", findings: findings)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = tableView
            pop.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: sUpload))
        }
        present(sheet, animated: true)
    }

    private enum Mode { case automatic, imported, asIs }

    private func run(_ info: ForkASCIPAInfo, mode: Mode) {
        busy = true
        pollTask?.cancel()
        setStatus("Starting…", messages: [])
        Task { @MainActor in
            var notes: [String] = []
            do {
                let ipa: URL
                switch mode {
                case .asIs:
                    ipa = info.ipa
                case .imported:
                    setStatus("Signing for the App Store…")
                    ipa = try await ForkASCPipeline.signForAppStore(info, profiles: ForkASCPipeline.importedProfiles(info).profiles)
                case .automatic:
                    let prepared = try await ForkASCProvisioning.prepare(info) { text in
                        Task { @MainActor in self.setStatus(text) }
                    }
                    notes = prepared.notes
                    setStatus("Signing for the App Store…", messages: notes)
                    ipa = try await ForkASCPipeline.signForAppStore(info, profiles: prepared.profiles)
                }
                let id = try await ForkASCPipeline.upload(ipa, info: info) { fraction, text in
                    Task { @MainActor in self.setStatus("\(text) \(Int(fraction * 100))%") }
                }
                lastUploadID = id
                UserDefaults.standard.set(id, forKey: "fork.asc.lastUpload")
                busy = false
                setStatus("Uploaded. Apple is processing the build…", messages: notes)
                follow(id, once: false, extra: notes)
            } catch {
                busy = false
                setStatus("Upload failed: \(error.localizedDescription)", messages: notes)
            }
            try? FileManager.default.removeItem(at: info.workFolder)
        }
    }

    // MARK: Preflight and Xcode on Mac

    private func showPreflight(title: String, note: String, findings: [ForkPreflightFinding],
                               recheck: (() async -> [ForkPreflightFinding])? = nil,
                               action: (title: String, run: () -> Void)? = nil) {
        let vc = ForkPreflightViewController(title: title, note: note, findings: findings, recheck: recheck, action: action)
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func preflightIPA(_ ipa: URL) {
        let info: ForkASCIPAInfo
        do { info = try ForkASCPipeline.inspect(ipa) } catch {
            alert("Cannot read the .ipa", error.localizedDescription)
            return
        }
        showPreflight(title: "Preflight · \(info.name)", note: "\(info.bundleID) \(info.version) (\(info.build)). Nothing was uploaded.", findings: ForkPreflight.check(ipa: info))
        try? FileManager.default.removeItem(at: info.workFolder)
    }

    private func xcodeMenu(_ app: NXProject, at indexPath: IndexPath) {
        let name = app.projectConfig.displayName ?? (app.url as URL).lastPathComponent
        let sheet = UIAlertController(title: name, message: "Preflight first; Xcode on the Mac does the build.", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Preflight", style: .default) { _ in self.preflightProject(app, then: nil) })
        sheet.addAction(UIAlertAction(title: "Preflight, then Xcode → App Store Connect", style: .default) { _ in self.preflightProject(app, then: .upload) })
        sheet.addAction(UIAlertAction(title: "Preflight, then Xcode Check (no upload)", style: .default) { _ in self.preflightProject(app, then: .check) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = tableView
            pop.sourceRect = tableView.rectForRow(at: indexPath)
        }
        present(sheet, animated: true)
    }

    private func preflightProject(_ app: NXProject, then mode: ForkXcodeOnMac.Mode?) {
        let name = app.projectConfig.displayName ?? (app.url as URL).lastPathComponent
        setStatus("Preflight of \(name)…", messages: [])
        Task { @MainActor in
            let findings = await ForkPreflight.check(project: app, forXcode: true)
            self.setStatus("Preflight of \(name): \(findings.filter { $0.level == .error }.count) error(s).", messages: [])
            var action: (title: String, run: () -> Void)?
            if let mode {
                action = (mode == .upload ? "Xcode → App Store Connect" : "Xcode Check (no upload)", { self.sendToXcode(app, mode: mode) })
            }
            self.showPreflight(title: "Preflight · \(name)",
                               note: "The app and the widgets its Export embeds, as Xcode on the Mac will get them. Tap a finding with ⓘ to fix it in the project.",
                               findings: findings,
                               recheck: { await ForkPreflight.check(project: NXProject(url: app.url) ?? app, forXcode: true) },
                               action: action)
        }
    }

    private func sendToXcode(_ app: NXProject, mode: ForkXcodeOnMac.Mode) {
        let fresh = NXProject(url: app.url) ?? app
        let name = fresh.projectConfig.displayName ?? (fresh.url as URL).lastPathComponent
        let (version, build) = ForkPreflight.versions(fresh)
        busy = true
        pollTask?.cancel()
        setStatus("\(name): starting…", messages: [], follow: true)
        pollTask = Task { @MainActor in
            do {
                let result = try await ForkXcodeOnMac.send(fresh, mode: mode) { text in
                    Task { @MainActor in self.setStatus("\(name): \(text)", follow: true) }
                }
                self.busy = false
                var messages: [String] = []
                if !result.xcode.isEmpty { messages.append(result.xcode) }
                /* 1.4.0: how it went, in Xcode's own words when the log has them */
                let where_ = result.log.map { "Files › On My iPad › Nyxian › AppStoreConnect › \($0.lastPathComponent)" } ?? "the App Store (Xcode) workflow on GitHub"
                if result.ok {
                    messages += result.summary.isEmpty ? (mode == .check ? ["✅ ** ARCHIVE SUCCEEDED **"] : ["✅ ** ARCHIVE SUCCEEDED **", "✅ Upload succeeded"]) : result.summary.map { "✅ " + $0 }
                } else {
                    let failed = result.summary.filter { $0.contains("FAILED") || $0.localizedCaseInsensitiveContains("failed") }
                    let stage = ["project": "making the Xcode project", "archive": "the archive (build)", "upload": "signing and uploading", "start": "getting the projects"][result.stage] ?? result.stage
                    messages.append(failed.isEmpty ? "❌ Error in \(stage)" : failed.map { "❌ " + $0 }.joined(separator: "\n"))
                    messages.append("See the log: \(where_)")
                }
                messages += result.issues
                if result.ok && result.log != nil { messages.append("Full Xcode log: \(where_)") }
                guard result.ok else {
                    self.setStatus("\(name): ❌ Xcode stopped in \(["project": "the Xcode project", "archive": "the build", "upload": "signing / upload", "start": "the start"][result.stage] ?? result.stage).", messages: messages, follow: true)
                    return
                }
                if mode == .check {
                    self.setStatus("\(name): ✅ Xcode built the archive (not signed, not uploaded).", messages: messages, follow: true)
                    return
                }
                self.setStatus("\(name) \(version) (\(build)): ✅ uploaded by Xcode. Apple is processing it…", messages: messages, follow: true)
                let deadline = Date().addingTimeInterval(45 * 60)
                while !Task.isCancelled && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard let state = try? await ForkXcodeOnMac.processingState(bundleID: fresh.projectConfig.bundleid ?? "", version: version, build: build) else { continue }
                    switch state {
                    case "VALID":
                        self.setStatus("\(name) \(version) (\(build)): ✅ ready in App Store Connect and TestFlight.", messages: messages, follow: true)
                        return
                    case "INVALID", "FAILED":
                        self.setStatus("\(name) \(version) (\(build)): ❌ Apple marked the build \(state). Its e-mail says why.", messages: messages, follow: true)
                        return
                    default:
                        self.setStatus("\(name) \(version) (\(build)): Apple's state \(state)…", messages: messages)
                    }
                }
            } catch {
                self.busy = false
                self.setStatus("\(name): \(error.localizedDescription)", messages: [])
            }
        }
    }

    /// Reads the upload's state (every 20 s until COMPLETE or FAILED, for up to 30 min)
    private func follow(_ id: String, once: Bool, extra: [String] = []) {
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
                    setStatus(text, messages: s.messages + extra)
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
