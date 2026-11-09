#!/usr/bin/env python3
"""Verify the installed version and process through native AppKit, preserving Unicode bundle paths."""

import argparse
import json
import plistlib
import subprocess
from pathlib import Path


def running_applications():
    """Return native process IDs, Unicode bundle paths and launch dates for LivingMeaning; takes no parameters."""
    script = """
    ObjC.import("AppKit");
    var apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("local.livingmeaning.mac");
    var rows = [];
    for (var i = 0; i < apps.count; i++) {
        var app = apps.objectAtIndex(i);
        rows.push({
            pid: Number(app.processIdentifier),
            bundle: ObjC.unwrap(app.bundleURL.path),
            launchedAt: Number(app.launchDate.timeIntervalSince1970)
        });
    }
    JSON.stringify(rows);
    """
    output = subprocess.check_output(["osascript", "-l", "JavaScript", "-e", script], text=True, timeout=10)
    return json.loads(output)


def main():
    """Read CLI options and verify version, unique process and data migration; returns nothing, fails on mismatch."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=Path("/Applications/活着的意义.app"))
    parser.add_argument("--expected-version", default="1.2.0")
    args = parser.parse_args()
    info = plistlib.loads((args.app / "Contents/Info.plist").read_bytes())
    executable = args.app / "Contents/MacOS/LivingMeaning"
    processes = running_applications()
    state_path = Path.home() / "Library/Application Support/LivingMeaning/state.json"
    state = json.loads(state_path.read_text())
    checks = {
        "versionMatches": info["CFBundleShortVersionString"] == args.expected_version,
        "exactlyOneInstance": len(processes) == 1,
        "correctUnicodePath": len(processes) == 1 and processes[0]["bundle"] == str(args.app),
        "launchedAfterBuild": len(processes) == 1 and processes[0]["launchedAt"] >= executable.stat().st_mtime,
        "schema2": state.get("version") == 2,
        "hasConfirmedSchedule": state.get("hasConfirmedSchedule") is True,
    }
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(args.app)], check=True, timeout=15)
    report = {
        "version": info["CFBundleShortVersionString"],
        "build": info["CFBundleVersion"],
        "checks": checks,
        "passed": all(checks.values()),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not report["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
