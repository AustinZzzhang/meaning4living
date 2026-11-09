#!/usr/bin/env python3
"""Fetch the pinned official Sparkle binary release and verify its SHA-256 before extraction."""

import hashlib
import subprocess
import tempfile
import urllib.request
from pathlib import Path

VERSION = "2.10.1"
SHA256 = "1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27"


def main():
    """Fetch the pinned release into this project's build cache; no arguments, prints the verified directory."""
    root = Path(__file__).resolve().parent.parent
    vendor = root / ".build" / "vendor"
    vendor.mkdir(parents=True, exist_ok=True)
    archive = vendor / f"Sparkle-{VERSION}.tar.xz"
    destination = vendor / f"Sparkle-{VERSION}"
    if not archive.exists():
        url = f"https://github.com/sparkle-project/Sparkle/releases/download/{VERSION}/{archive.name}"
        with tempfile.NamedTemporaryFile(dir=vendor, delete=False) as temporary:
            temporary_path = Path(temporary.name)
        try:
            urllib.request.urlretrieve(url, temporary_path)
            actual = hashlib.sha256(temporary_path.read_bytes()).hexdigest()
            if actual != SHA256:
                raise RuntimeError("Sparkle download checksum mismatch")
            temporary_path.rename(archive)
        finally:
            temporary_path.unlink(missing_ok=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise RuntimeError("Cached Sparkle checksum mismatch; refusing to use it")
    destination.mkdir(exist_ok=True)
    subprocess.run(["tar", "-xf", str(archive), "-C", str(destination)], check=True)
    print(destination)


if __name__ == "__main__":
    main()
