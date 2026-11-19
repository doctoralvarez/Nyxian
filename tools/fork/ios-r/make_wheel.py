#!/usr/bin/env python3
# Fork doctoralvarez/Nyxian — version 0.1.0
# Changelog:
#  - 0.1.0 (2026-11-19): packs R for iOS (R_HOME) with the nyxian_r module
#    as a wheel, nyxian_r-<R version>-py3-none-ios_13_0_arm64_iphoneos.whl, so
#    Nyxian's pip installs it and signs its binaries like any package's.
"""make_wheel.py <R_HOME> <nyxian_r dir> <version> <out dir>"""
import base64
import hashlib
import os
import sys
import zipfile

TAG = "py3-none-ios_13_0_arm64_iphoneos"


def main(r_home, module, version, out):
    name = "nyxian_r"
    dist = "%s-%s.dist-info" % (name, version)
    wheel = os.path.join(out, "%s-%s-%s.whl" % (name, version, TAG))
    records = []

    def add(zf, arc, data):
        zf.writestr(zipfile.ZipInfo(arc, (2026, 11, 19, 0, 0, 0)), data, compress_type=zipfile.ZIP_DEFLATED)
        digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
        records.append("%s,sha256=%s,%d" % (arc, digest, len(data)))

    with zipfile.ZipFile(wheel, "w") as zf:
        for base, _, files in os.walk(module):
            for f in sorted(files):
                if f.endswith(".pyc"):
                    continue
                path = os.path.join(base, f)
                with open(path, "rb") as h:
                    add(zf, os.path.join(name, os.path.relpath(path, module)), h.read())
        for base, _, files in os.walk(r_home):
            for f in sorted(files):
                path = os.path.join(base, f)
                if os.path.islink(path):
                    continue
                arc = os.path.join(name, "R", os.path.relpath(path, r_home))
                with open(path, "rb") as h:
                    data = h.read()
                info = zipfile.ZipInfo(arc, (2026, 11, 19, 0, 0, 0))
                info.external_attr = (os.stat(path).st_mode & 0o777) << 16
                zf.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED)
                digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
                records.append("%s,sha256=%s,%d" % (arc, digest, len(data)))
        meta = ("Metadata-Version: 2.1\nName: nyxian-r\nVersion: %s\n"
                "Summary: R %s for iOS inside Nyxian (R_HOME + console through rpy2)\n"
                "License: GPL-2.0-or-later\nRequires-Python: >=3.10\n"
                "Requires-Dist: rpy2-rinterface\nRequires-Dist: cffi\n" % (version, version)).encode()
        add(zf, dist + "/METADATA", meta)
        add(zf, dist + "/WHEEL", ("Wheel-Version: 1.0\nGenerator: nyxian\nRoot-Is-Purelib: false\nTag: %s\n" % TAG).encode())
        add(zf, dist + "/top_level.txt", b"nyxian_r\n")
        records.append(dist + "/RECORD,,")
        zf.writestr(dist + "/RECORD", "\n".join(records) + "\n")
    print(wheel)


if __name__ == "__main__":
    main(*sys.argv[1:5])
