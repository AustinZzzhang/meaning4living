#!/usr/bin/env python3
"""Prepare a project-local VFS overlay for stale duplicate Command Line Tools files."""

import json
import subprocess
import sys
from pathlib import Path


def main():
    """Inspect the selected toolchain and write overlays to argv[1]; return no value."""
    destination = Path(sys.argv[1]).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    compiler = Path(subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip())
    toolchain = compiler.parent.parent
    empty = destination / "empty.modulemap"
    empty.write_text("// Duplicate legacy module map hidden only for this build.\n")
    roots = []
    headers = toolchain / "include" / "swift"
    legacy = headers / "module.modulemap"
    current = headers / "bridging.modulemap"
    if legacy.exists() and current.exists():
        if "module SwiftBridging" in legacy.read_text() and "module SwiftBridging" in current.read_text():
            roots.append({"type": "file", "name": str(legacy), "external-contents": str(empty)})
    manifest = toolchain / "lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule"
    for private in manifest.glob("*.private.swiftinterface"):
        public = private.with_name(private.name.replace(".private.swiftinterface", ".swiftinterface"))
        if public.exists():
            private_version = private.read_text().splitlines()[1]
            public_version = public.read_text().splitlines()[1]
            if private_version != public_version:
                roots.append({"type": "file", "name": str(private), "external-contents": str(public)})
    overlay = destination / "overlay.json"
    overlay.write_text(json.dumps({"version": 0, "roots": roots}, indent=2) + "\n")
    print(overlay)


if __name__ == "__main__":
    main()
