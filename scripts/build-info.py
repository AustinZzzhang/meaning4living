#!/usr/bin/env python3
"""Record build inputs in the application and refuse packaging if those inputs have changed."""

import argparse
import datetime
import hashlib
import json
import plistlib
from pathlib import Path


def fingerprint(root):
    """Hash root's application source, resources and build scripts; returns the digest and relative input names."""
    inputs = sorted(
        list((root / "Sources").rglob("*.swift"))
        + [path for path in (root / "Resources").rglob("*") if path.is_file()]
        + [root / "scripts" / name for name in [
            "build.sh", "build-info.py", "sign-app.py", "fetch-sparkle.py",
            "prepare-toolchain.py", "GenerateIcon.swift", "github-release.py",
        ]]
        + [root / "release-config.json"]
    )
    digest = hashlib.sha256()
    names = []
    for path in inputs:
        name = path.relative_to(root).as_posix()
        names.append(name)
        data = path.read_bytes()
        digest.update(name.encode() + b"\0" + str(len(data)).encode() + b"\0" + data)
    return digest.hexdigest(), names


def main():
    """Write or verify app build provenance against the checkout; returns nothing, exits nonzero for stale builds."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["write", "verify"])
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    signature, inputs = fingerprint(root)
    bundle = plistlib.loads((args.app / "Contents/Info.plist").read_bytes())
    source = plistlib.loads((root / "Resources/Info.plist").read_bytes())
    for key in ["CFBundleShortVersionString", "CFBundleVersion"]:
        if bundle[key] != source[key]:
            raise SystemExit("Application version differs from source. Run bash scripts/build.sh --universal first.")
    path = args.app / "Contents/Resources/BuildInfo.json"
    if args.action == "write":
        info = {
            "version": bundle["CFBundleShortVersionString"],
            "build": bundle["CFBundleVersion"],
            "builtAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "sourceSHA256": signature,
            "inputs": inputs,
        }
        path.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")
    else:
        if not path.exists() or json.loads(path.read_text()).get("sourceSHA256") != signature:
            raise SystemExit(
                "Built app is stale or lacks build provenance. Run bash scripts/build.sh --universal first."
            )
        print(f"Verified build {bundle['CFBundleShortVersionString']} ({bundle['CFBundleVersion']}): {signature}")


if __name__ == "__main__":
    main()
