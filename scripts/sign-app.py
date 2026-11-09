#!/usr/bin/env python3
"""Sign the host app; certificate builds also sign embedded Sparkle code from the inside out."""

import argparse
import subprocess
from pathlib import Path


def sign(path, identity, entitlements=False):
    """Sign path using identity and preserve helper entitlements when requested; returns nothing."""
    arguments = ["codesign", "--force", "--sign", identity]
    if identity == "-":
        arguments.append("--timestamp=none")
    else:
        arguments.extend(["--options", "runtime", "--timestamp"])
    if entitlements:
        arguments.append("--preserve-metadata=entitlements")
    subprocess.run(arguments + [str(path)], check=True)


def main():
    """Sign app with identity, retaining vendor helper signatures for ad-hoc builds; returns no value."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--identity", default="-")
    args = parser.parse_args()
    if args.identity != "-":
        framework = args.app / "Contents/Frameworks/Sparkle.framework"
        version = framework / "Versions/B"
        helpers = list(version.rglob("*.xpc")) + list(version.rglob("*.app"))
        for helper in sorted(helpers, key=lambda path: len(path.parts), reverse=True):
            sign(helper, args.identity, entitlements=True)
        sign(version / "Autoupdate", args.identity)
        sign(framework, args.identity)
    sign(args.app, args.identity)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(args.app)], check=True)


if __name__ == "__main__":
    main()
