#!/usr/bin/env python3
# fork doctoralvarez/Nyxian — version 1.3.0
# Changelog:
#  - 1.3.0 (2026-11-26): UIRequiresFullScreen = NO is left out (it is the
#    default, and iOS 26 deprecates the key: Xcode warned about it in every
#    target); a YES stays.
#  - 1.2.0 (2026-11-26): a folder inside Resources stays a folder in the app
#    (Resources/Sub/data.json is Sub/data.json, as Nyxian copies it; before it
#    was flattened to data.json), and Info-extra.plist is no longer copied
#    into the app as a file (its keys already go to Info.plist).
#  - 1.1.0 (2026-11-23): the archive had no executable ("The archive contains
#    nothing that can be signed"): the source paths started with "../" and the
#    exclusion of hidden files ("**/.*") also matched "..", so no Swift file was
#    compiled. The Xcode project is now written next to the projects (paths
#    without ".."), and only named hidden files are left out.
#  - 1.0.0 (2026-11-22): turns the Nyxian projects that Settings › App Store
#    Connect › Xcode on Mac sends (an app and the extensions its Export embeds,
#    plus manifest.json) into an XcodeGen spec, so Apple's Xcode builds, signs
#    and uploads the app itself: the build carries Xcode's own DTXcode /
#    DTSDKBuild, Assets.car, Metadata.appintents and privacy report, nothing
#    written in their place.
#
# usage: make_project.py <request folder (manifest.json + project folders)> <output folder>
#        prints the scheme name; writes <output>/project.yml and its Info /
#        entitlements files, and <output>/ExportOptions-<mode>.plist.

import json
import os
import plistlib
import re
import shutil
import subprocess
import sys

SOURCE_EXT = {".swift", ".m", ".mm", ".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".metal"}
# keys Xcode writes itself from the build settings (or that belong to Nyxian only)
IDENTITY_KEYS = {
    "CFBundleExecutable", "CFBundleIdentifier", "CFBundleName", "CFBundleVersion",
    "CFBundleShortVersionString", "CFBundlePackageType", "CFBundleDevelopmentRegion",
    "CFBundleInfoDictionaryVersion", "CFBundleSupportedPlatforms", "MinimumOSVersion",
    "UIDeviceFamily", "UIRequiredDeviceCapabilities", "CFBundleIconName", "CFBundleIcons",
    "CFBundleIcons~ipad", "LSRequiresIPhoneOS", "BuildMachineOSBuild",
}
# entitlements an App Store build may carry; the rest are Nyxian's or development-only
ENTITLEMENT_PREFIXES = (
    "com.apple.security.application-groups", "aps-environment", "com.apple.developer.",
    "keychain-access-groups", "com.apple.external-accessory", "inter-app-audio",
)


def safe_name(text, fallback):
    name = re.sub(r"[^A-Za-z0-9_]", "", text or "")
    if not name or name[0].isdigit():
        name = fallback
    return name


# Nyxian's own variables, as Xcode's build settings
VARIABLES = {
    "$(NXExecutable)": "$(PRODUCT_MODULE_NAME)", "$(NXDisplayName)": "$(PRODUCT_NAME)",
    "$(NXBundleIdentifier)": "$(PRODUCT_BUNDLE_IDENTIFIER)", "$(NXBundleVersion)": "$(CURRENT_PROJECT_VERSION)",
    "$(NXBundleShortVersion)": "$(MARKETING_VERSION)", "$(NXDeploymentTarget)": "$(IPHONEOS_DEPLOYMENT_TARGET)",
}


def translate(value):
    """Nyxian's $(NX…) as Xcode's settings; a string with another unknown $(NX…) goes (None)"""
    if isinstance(value, str):
        for a, b in VARIABLES.items():
            value = value.replace(a, b)
        return None if "$(NX" in value or "$(LDE" in value else value
    if isinstance(value, list):
        return [v for v in (translate(x) for x in value) if v is not None]
    if isinstance(value, dict):
        return {k: v for k, v in ((k, translate(x)) for k, x in value.items()) if v is not None}
    return value


def clean_info(info):
    out = {}
    for key, value in (info or {}).items():
        if key in IDENTITY_KEYS or key.startswith("NX") or key.startswith("DT") or key.startswith("LDE"):
            continue
        if key == "UIRequiresFullScreen" and value is False:
            continue  # the default; iOS 26 deprecates the key
        value = translate(value)
        if value is not None:
            out[key] = value
    return out


def clean_entitlements(ent):
    out = {}
    for key, value in (ent or {}).items():
        if key == "get-task-allow" or key.startswith("com.apple.private"):
            continue
        if any(key.startswith(p) for p in ENTITLEMENT_PREFIXES):
            out[key] = value
    return out


def swift_settings(flags):
    """-D NAME conditions and the language version; Nyxian's own paths and targets stay out"""
    conditions, version, other = [], None, []
    i = 0
    flags = flags or []
    while i < len(flags):
        f = flags[i]
        if f == "-D" and i + 1 < len(flags):
            conditions.append(flags[i + 1]); i += 2; continue
        if f.startswith("-D") and len(f) > 2:
            conditions.append(f[2:]); i += 1; continue
        if f in ("-swift-version", "-language-mode") and i + 1 < len(flags):
            version = flags[i + 1]; i += 2; continue
        if f in ("-enable-upcoming-feature", "-enable-experimental-feature") and i + 1 < len(flags):
            other += [f, flags[i + 1]]; i += 2; continue
        i += 1
    return conditions, version, other


def linker_settings(flags):
    """-l and -framework only (Xcode adds -e _NSExtensionMain to extensions itself)"""
    out, i = [], 0
    flags = flags or []
    while i < len(flags):
        f = flags[i]
        if f in ("-framework", "-weak_framework") and i + 1 < len(flags):
            out += [f, flags[i + 1]]; i += 2; continue
        if f.startswith("-l") and len(f) > 2:
            out.append(f)
        i += 1
    return out


def flatten_icon(png, dest):
    """the App Store icon may not have an alpha channel (ITMS-90717): sips through JPEG drops it"""
    tmp = dest + ".jpg"
    subprocess.run(["sips", "-s", "format", "jpeg", png, "--out", tmp], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(["sips", "-s", "format", "png", tmp, "--out", dest], check=True, stdout=subprocess.DEVNULL)
    os.remove(tmp)


def target_sources(folder, rel):
    """the sources of a Nyxian project, and its Resources copied into the bundle like Nyxian does"""
    sources = [{
        "path": rel,
        "excludes": ["Config/**", "Resources/**", ".nyxian/**", "**/.DS_Store", "**/.git/**", "**/*.xcodeproj/**",
                     "**/Info.plist", "**/*.entitlements", "Info-extra.plist"],
    }]
    res = os.path.join(folder, "Resources")
    if os.path.isdir(res):
        # 1.2.0: files go to the bundle's root; a folder stays a folder (Resources/Sub/x.json -> Sub/x.json), as Nyxian copies them
        for name in sorted(os.listdir(res)):
            if name.startswith(".") or name in ("Info.plist",) or name.endswith(".car"):
                continue
            path = os.path.join(rel, "Resources", name)
            if os.path.isdir(os.path.join(res, name)) and not name.endswith((".xcassets", ".lproj", ".bundle", ".storyboard", ".xib")):
                sources.append({"path": path, "type": "folder", "buildPhase": "resources"})
            else:
                sources.append({"path": path, "buildPhase": "resources"})
    return sources


def write_plist(path, value):
    with open(path, "wb") as f:
        plistlib.dump(value, f)


def main():
    request, out = sys.argv[1], sys.argv[2]
    # 1.1.0: no "../" in the source paths (see the changelog)
    if os.path.relpath(request, out).startswith(".."):
        sys.exit("make_project.py: the output folder has to be the request folder or inside it")
    with open(os.path.join(request, "manifest.json")) as f:
        m = json.load(f)
    os.makedirs(out, exist_ok=True)
    app = m["app"]
    team = m.get("teamID") or os.environ.get("TEAM_ID", "")
    deployment = app.get("deploymentTarget") or "17.0"
    app_name = safe_name(app.get("executable") or app.get("name"), "App")
    families = app.get("deviceFamily") or [1, 2]
    family = ",".join(str(x) for x in families if x in (1, 2)) or "1,2"

    def base_settings(p, bundle_id):
        conditions, version, other = swift_settings(p.get("swiftFlags"))
        s = {
            "PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
            "MARKETING_VERSION": str(app["version"]),
            "CURRENT_PROJECT_VERSION": str(app["build"]),
            "TARGETED_DEVICE_FAMILY": family,
            "IPHONEOS_DEPLOYMENT_TARGET": deployment,
            "SWIFT_VERSION": version or "5.0",
            "CODE_SIGN_STYLE": "Automatic",
            "GENERATE_INFOPLIST_FILE": "NO",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
        }
        if team:
            s["DEVELOPMENT_TEAM"] = team
        if conditions:
            s["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = " ".join(["$(inherited)"] + conditions)
        if other:
            s["OTHER_SWIFT_FLAGS"] = " ".join(["$(inherited)"] + other)
        link = linker_settings(p.get("linkerFlags"))
        if link:
            s["OTHER_LDFLAGS"] = " ".join(["$(inherited)"] + link)
        return s

    targets = {}
    deps = []
    for ext in m.get("extensions", []):
        name = safe_name(ext.get("executable") or ext.get("folder"), "Extension")
        if name == app_name:
            name += "Extension"
        folder = os.path.join(request, ext["folder"])
        info = clean_info(ext.get("info"))
        info.update({
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "CFBundleExecutable": "$(EXECUTABLE_NAME)",
            "CFBundleName": "$(PRODUCT_NAME)",
            "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
            "CFBundleShortVersionString": "$(MARKETING_VERSION)",
            "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
            "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
            "CFBundleInfoDictionaryVersion": "6.0",
        })
        info.setdefault("CFBundleDisplayName", ext.get("name") or name)
        info["NSExtension"] = {"NSExtensionPointIdentifier": ext.get("point") or "com.apple.widgetkit-extension"}
        info_path = f"{name}-Info.plist"
        write_plist(os.path.join(out, info_path), info)
        settings = base_settings(ext, ext["bundleID"])
        settings["INFOPLIST_FILE"] = info_path
        ent = clean_entitlements(ext.get("entitlements"))
        target = {
            "type": "app-extension",
            "platform": "iOS",
            "sources": target_sources(folder, os.path.relpath(folder, out)),
            "settings": {"base": settings},
        }
        if ent:
            ent_path = f"{name}.entitlements"
            write_plist(os.path.join(out, ent_path), ent)
            settings["CODE_SIGN_ENTITLEMENTS"] = ent_path
        targets[name] = target
        deps.append({"target": name, "embed": True})

    folder = os.path.join(request, app["folder"])
    info = clean_info(app.get("info"))
    info.update({
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "LSRequiresIPhoneOS": True,
    })
    info.setdefault("CFBundleDisplayName", app.get("name") or app_name)
    if "UILaunchScreen" not in info and "UILaunchStoryboardName" not in info:
        info["UILaunchScreen"] = {}
    write_plist(os.path.join(out, f"{app_name}-Info.plist"), info)
    settings = base_settings(app, app["bundleID"])
    settings["INFOPLIST_FILE"] = f"{app_name}-Info.plist"
    sources = target_sources(folder, os.path.relpath(folder, out))

    icon = os.path.join(folder, "Config", "AppIcon.png")
    if os.path.isfile(icon):
        catalog = os.path.join(out, "AppStoreAssets.xcassets")
        iconset = os.path.join(catalog, "AppIcon.appiconset")
        os.makedirs(iconset, exist_ok=True)
        with open(os.path.join(catalog, "Contents.json"), "w") as f:
            json.dump({"info": {"author": "xcode", "version": 1}}, f)
        flatten_icon(icon, os.path.join(iconset, "AppIcon.png"))
        with open(os.path.join(iconset, "Contents.json"), "w") as f:
            json.dump({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                       "info": {"author": "xcode", "version": 1}}, f)
        sources.append({"path": "AppStoreAssets.xcassets"})
        settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"

    ent = clean_entitlements(app.get("entitlements"))
    if ent:
        write_plist(os.path.join(out, f"{app_name}.entitlements"), ent)
        settings["CODE_SIGN_ENTITLEMENTS"] = f"{app_name}.entitlements"
    targets[app_name] = {
        "type": "application",
        "platform": "iOS",
        "sources": sources,
        "settings": {"base": settings},
        "dependencies": deps,
    }

    spec = {
        "name": app_name,
        "options": {"deploymentTarget": {"iOS": deployment}, "createIntermediateGroups": True},
        "targets": targets,
        "schemes": {app_name: {"build": {"targets": {app_name: "all"}}, "archive": {"config": "Release"}}},
    }
    with open(os.path.join(out, "project.yml"), "w") as f:
        json.dump(spec, f, indent=2)  # JSON is valid YAML for XcodeGen

    for mode, destination in (("upload", "upload"), ("export", "export")):
        opts = {
            "method": "app-store-connect",
            "destination": destination,
            "signingStyle": "automatic",
            "uploadSymbols": True,
            "manageAppVersionAndBuildNumber": False,
        }
        if team:
            opts["teamID"] = team
        write_plist(os.path.join(out, f"ExportOptions-{mode}.plist"), opts)
    print(app_name)


if __name__ == "__main__":
    main()
