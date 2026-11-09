#!/usr/bin/env python3
"""Build a versioned release directory, sign update feeds using Keychain, and optionally create a DMG."""

import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path


def run(arguments):
    """Execute the supplied argument list without a shell; returns nothing and raises on nonzero exit."""
    subprocess.run([str(argument) for argument in arguments], check=True)


def validate_base_url(value):
    """Validate value as an HTTPS download directory without credentials/query; returns its normalized URL."""
    url = urllib.parse.urlsplit(value)
    if url.scheme != "https" or not url.hostname or url.username or url.password or url.fragment or url.query:
        raise ValueError("The download base URL must use HTTPS and cannot contain credentials, query or fragment")
    return value.rstrip("/") + "/"


def main():
    """Parse release options and generate local archives/appcast without uploading; returns no value."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", help="Public HTTPS folder containing the ZIP and appcast.xml")
    parser.add_argument("--output", type=Path, help="Persistent release directory; existing versions are retained")
    parser.add_argument("--dmg", action="store_true", help="Also create a drag-to-Applications installer")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    app = root / "dist/活着的意义.app"
    run([sys.executable, root / "scripts/build-info.py", "verify", app])
    with (app / "Contents/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    version = info["CFBundleShortVersionString"]
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", version):
        raise ValueError("Invalid release version")
    run(["codesign", "--verify", "--deep", "--strict", app])
    output = (args.output or root / "dist/releases").resolve()
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"LivingMeaning-{version}.zip"
    if archive.exists():
        raise FileExistsError(f"Version archive exists; increment the version or use a fresh output folder: {archive}")
    base_url = validate_base_url(args.base_url) if args.base_url else None
    sparkle = root / ".build/vendor/Sparkle-2.10.1/bin"
    if base_url:
        public_key = subprocess.check_output(
            [str(sparkle / "generate_keys"), "--account", "local.livingmeaning.updates", "-p"],
            text=True,
        ).strip()
        if public_key != info["SUPublicEDKey"]:
            raise ValueError("Signing key differs from the key pinned in the application")
    with tempfile.TemporaryDirectory(prefix=".release-staging-", dir=output) as temporary:
        staging = Path(temporary)
        for previous in output.iterdir():
            if previous.is_file() and previous.suffix in {".xml", ".zip", ".html"}:
                shutil.copy2(previous, staging / previous.name)
        staged_archive = staging / archive.name
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, staged_archive])
        notes = root / f"Resources/release-notes-{version}.html"
        if notes.exists():
            shutil.copy2(notes, staged_archive.with_suffix(".html"))
        if base_url:
            run([
                sparkle / "generate_appcast", "--account", "local.livingmeaning.updates",
                "--download-url-prefix", base_url, "--embed-release-notes", "--maximum-deltas", "0",
                "-o", staging / "appcast.xml", staging,
            ])
        if args.dmg:
            image = staging / f"活着的意义-{version}.dmg"
            if (output / image.name).exists():
                raise FileExistsError(output / image.name)
            contents = staging / "disk-contents"
            contents.mkdir()
            run(["ditto", app, contents / app.name])
            (contents / "Applications").symlink_to("/Applications")
            shutil.copy2(root / "Resources/分享安装说明.txt", contents / "安装与使用说明.txt")
            run([
                "hdiutil", "create", "-volname", "活着的意义", "-srcfolder", contents,
                "-format", "UDZO", "-fs", "HFS+", image,
            ])
            run(["hdiutil", "verify", image])
            shutil.copy2(image, staging / "活着的意义-最新版.dmg")
            manifest = {
                "version": version,
                "build": info["CFBundleVersion"],
                "dmg": image.name,
                "zip": archive.name,
                "dmgSHA256": hashlib.sha256(image.read_bytes()).hexdigest(),
                "zipSHA256": hashlib.sha256(staged_archive.read_bytes()).hexdigest(),
                "sourceSHA256": json.loads(
                    (app / "Contents/Resources/BuildInfo.json").read_text()
                )["sourceSHA256"],
            }
            (staging / "latest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        for generated in sorted(staging.iterdir(), key=lambda path: path.name == "appcast.xml"):
            if generated.is_file():
                os.replace(generated, output / generated.name)
    if base_url:
        print(f"Upload {output} to {base_url}; publish the ZIP before replacing appcast.xml.")
    else:
        print("Created offline installer. A public base URL is required to generate a publishable update feed.")
    print(f"Release files: {output}")


if __name__ == "__main__":
    main()
