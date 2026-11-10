#!/usr/bin/env python3
"""Exercise Sparkle against signed, disposable loopback fixtures; never update an installed application."""

import functools
import http.server
import json
import plistlib
import shutil
import subprocess
import tempfile
import threading
import time
import uuid
from pathlib import Path


def run(arguments, **options):
    """Run arguments without shell interpolation, forwarding options; returns the completed process."""
    return subprocess.run([str(value) for value in arguments], check=True, **options)


def modify_bundle(app, identifier, version, display_version):
    """Set app's disposable identifier, build version and display_version, then sign it; returns nothing."""
    path = app / "Contents/Info.plist"
    info = plistlib.loads(path.read_bytes())
    info["CFBundleIdentifier"] = identifier
    info["CFBundleVersion"] = str(version)
    info["CFBundleShortVersionString"] = display_version
    info["SUEnableAutomaticChecks"] = False
    info["SURequireSignedFeed"] = True
    info["SUSignedFeedFailureExpirationInterval"] = 0
    info["SUVerifyUpdateBeforeExtraction"] = True
    info["NSAppTransportSecurity"] = {"NSAllowsLocalNetworking": True}
    path.write_bytes(plistlib.dumps(info))
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", app], capture_output=True)


def check_case(root, sandbox, harness, mode):
    """Run one signed update or tamper-rejection mode in sandbox; returns test results, preserving logs."""
    case = sandbox / mode
    case.mkdir()
    target = case / "target/活着的意义.app"
    target.parent.mkdir()
    source = root / "dist/活着的意义.app"
    source_info = plistlib.loads((source / "Contents/Info.plist").read_bytes())
    previous_build = 7
    next_build = int(source_info["CFBundleVersion"])
    next_version = source_info["CFBundleShortVersionString"]
    if next_build <= previous_build:
        raise ValueError("The current build must be newer than the published 1.2.2 build 7.")
    run(["ditto", source, target])
    target_executable = target / "Contents/MacOS/LivingMeaning"
    shutil.copy2(harness, target_executable)
    identifier = "local.livingmeaning.update-fixture." + uuid.uuid4().hex
    modify_bundle(target, identifier, previous_build, "1.2.2")
    server_root = case / "server"
    server_root.mkdir()
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(server_root))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    prefix = f"http://127.0.0.1:{server.server_port}/"
    tools = root / ".build/vendor/Sparkle-2.10.1/bin"
    try:
        next_app = case / "next/活着的意义.app"
        next_app.parent.mkdir()
        run(["ditto", target, next_app])
        modify_bundle(next_app, identifier, next_build, next_version)
        archive = server_root / f"fixture-{next_build}.zip"
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", next_app, archive])
        run([
            tools / "generate_appcast", "--account", "local.livingmeaning.updates",
            "--download-url-prefix", prefix, "--maximum-deltas", "0", server_root,
        ], capture_output=True)
        feed = server_root / "appcast.xml"
        run([
            tools / "sign_update", "--account", "local.livingmeaning.updates", "--verify", feed,
        ], capture_output=True)
        if mode == "bad-archive":
            with archive.open("ab") as handle:
                handle.write(b"tamper-test")
        if mode == "bad-feed":
            data = feed.read_bytes()
            assert b"<channel>" in data
            feed.write_bytes(data.replace(b"<channel>", b"<channel><!--tamper-test-->", 1))
        expected = "install" if mode == "install" else "reject"
        process = subprocess.run(
            [str(target_executable), str(target), prefix + "appcast.xml", expected, str(sandbox)],
            capture_output=True, text=True, timeout=60,
        )
        (case / "harness.log").write_text(process.stdout + "\n" + process.stderr)
        print(process.stdout, flush=True)
        if process.returncode != 0:
            raise RuntimeError(f"{mode} failed; see {case / 'harness.log'}")
        deadline = time.monotonic() + 25
        while mode == "install" and time.monotonic() < deadline:
            try:
                installed = plistlib.loads((target / "Contents/Info.plist").read_bytes())
                if installed["CFBundleVersion"] == str(next_build):
                    break
            except FileNotFoundError:
                pass
            time.sleep(0.2)
        info = plistlib.loads((target / "Contents/Info.plist").read_bytes())
        version = info["CFBundleVersion"]
        assert version == str(next_build if mode == "install" else previous_build), version
        expected_display = next_version if mode == "install" else "1.2.2"
        assert info["CFBundleShortVersionString"] == expected_display
        run(["codesign", "--verify", "--deep", "--strict", target], capture_output=True)
        return {
            "passed": True, "oldVersion": "1.2.2", "oldBuild": str(previous_build),
            "installedVersion": info["CFBundleShortVersionString"],
            "installedBuild": version, "signatureVerified": True,
        }
    finally:
        server.shutdown()
        server.server_close()


def main():
    """Run signed self-install/tamper tests in system temp and persist all outcomes; exits nonzero on failure."""
    root = Path(__file__).resolve().parent.parent
    sandbox = Path(tempfile.mkdtemp(prefix="living-update-integration-"))
    harness_app = sandbox / "Harness.app"
    executable = harness_app / "Contents/MacOS/UpdateHarness"
    executable.parent.mkdir(parents=True)
    framework_dir = harness_app / "Contents/Frameworks"
    framework_dir.mkdir()
    vendor = root / ".build/vendor/Sparkle-2.10.1"
    run(["ditto", vendor / "Sparkle.framework", framework_dir / "Sparkle.framework"])
    (harness_app / "Contents/Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": "local.livingmeaning.update-harness." + uuid.uuid4().hex,
        "CFBundleExecutable": "UpdateHarness", "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1", "CFBundleName": "Update Fixture",
        "NSAppTransportSecurity": {"NSAllowsLocalNetworking": True},
    }))
    overlay = root / ".build/direct/toolchain/overlay.json"
    run([
        "xcrun", "swiftc", "-swift-version", "5", "-F", vendor, "-framework", "Sparkle",
        "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
        "-vfsoverlay", overlay, "-Xcc", "-ivfsoverlay", "-Xcc", overlay,
        root / "scripts/UpdateHarness.swift", "-o", executable,
    ])
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", harness_app], capture_output=True)
    report = {}
    info = plistlib.loads((root / "dist/活着的意义.app/Contents/Info.plist").read_bytes())
    report_dir = root / "dist" / f"verification-{info['CFBundleShortVersionString']}"
    report_dir.mkdir(exist_ok=True)
    for mode in ["install", "bad-archive", "bad-feed"]:
        try:
            report[mode] = check_case(root, sandbox, executable, mode)
        except (AssertionError, RuntimeError, subprocess.SubprocessError) as error:
            report[mode] = {"passed": False, "error": str(error), "fixture": str(sandbox / mode)}
        log = sandbox / mode / "harness.log"
        if log.exists():
            saved_log = report_dir / f"update-{mode}.log"
            shutil.copy2(log, saved_log)
            report[mode]["log"] = str(saved_log)
    report_file = report_dir / "update-integration.json"
    report_file.write_text(json.dumps(report, indent=2) + "\n")
    if not all(result["passed"] for result in report.values()):
        raise SystemExit(f"FAIL update checks; see {report_file}")
    print(f"PASS actual Sparkle install and tamper rejection: {report_file}")


if __name__ == "__main__":
    main()
