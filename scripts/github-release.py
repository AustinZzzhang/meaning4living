#!/usr/bin/env python3
"""Prepare signed GitHub Releases and deploy their unchanged update feed alongside the Pages website."""

import argparse
import datetime
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPARKLE = ROOT / ".build/vendor/Sparkle-2.10.1/bin"
NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def run(arguments, **options):
    """Run argument values without a shell, forwarding options; return the successful process or raise."""
    return subprocess.run([str(value) for value in arguments], check=True, **options)


def github(arguments):
    """Run GitHub CLI arguments using the installed executable; return stdout without exposing credentials."""
    command = shutil.which("gh")
    if not command and Path("/opt/homebrew/bin/gh").exists():
        command = "/opt/homebrew/bin/gh"
    if not command:
        raise ValueError("Install GitHub CLI and run gh auth login first.")
    return run([command, *arguments], capture_output=True, text=True).stdout


def repository_name(value):
    """Validate a public GitHub owner/repository identifier supplied as value; return its normalized string."""
    pattern = r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}"
    if not isinstance(value, str) or not re.fullmatch(pattern, value):
        raise ValueError("Use an explicit GitHub owner/repository, for example your-account/living-meaning.")
    if value.split("/")[1] in {".", ".."}:
        raise ValueError("Invalid repository name.")
    return value


def configured_repository(required=True):
    """Load the configured repository; required controls missing configuration errors, returns a name or None."""
    value = json.loads((ROOT / "release-config.json").read_text()).get("repository")
    if value is None and not required:
        return None
    return repository_name(value)


def pages_url(repository):
    """Derive the default HTTPS Pages URL from repository; return the canonical base including its trailing slash."""
    owner, name = repository_name(repository).split("/")
    suffix = "" if name.lower() == f"{owner.lower()}.github.io" else name + "/"
    return f"https://{owner.lower()}.github.io/{suffix}"


def sha256(path):
    """Hash bytes at path and return their SHA-256 digest without modifying the file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset_url(repository, tag, filename):
    """Construct an immutable HTTPS release URL from repository/tag/filename; return the encoded address."""
    return f"https://github.com/{repository}/releases/download/{tag}/{urllib.parse.quote(filename, safe='')}"


def release_info():
    """Read source release metadata with no arguments; return a validated version/build/tag dictionary."""
    info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
    version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    if not re.fullmatch(r"\d+(?:\.\d+){1,3}", version) or not build.isdigit():
        raise ValueError("Release version and build must be numeric.")
    return {"version": version, "build": build, "tag": "v" + version}


def validate_manifest(manifest, repository):
    """Validate manifest URLs, filenames and release fields against repository; return the verified dictionary."""
    repository_name(repository)
    if manifest.get("repository") != repository:
        raise ValueError("Manifest repository mismatch.")
    version, build = manifest.get("version", ""), manifest.get("build", "")
    if not re.fullmatch(r"\d+(?:\.\d+){1,3}", version) or not str(build).isdigit():
        raise ValueError("Manifest version/build is invalid.")
    tag = "v" + version
    if manifest.get("tag") != tag or manifest.get("feed_url") != pages_url(repository) + "appcast.xml":
        raise ValueError("Manifest tag or update address is invalid.")
    if manifest.get("site_url") != pages_url(repository):
        raise ValueError("Manifest website address is invalid.")
    if manifest.get("minimum_macos") != "13.0" or manifest.get("architectures") != ["arm64", "x86_64"]:
        raise ValueError("Unsupported platform metadata.")
    if manifest.get("notarized") is not False:
        raise ValueError("Apple notarization must not be claimed by this unsigned release pipeline.")
    if not re.fullmatch(r"[a-f0-9]{64}", manifest.get("appcast_sha256", "")):
        raise ValueError("Invalid appcast checksum.")
    if not re.fullmatch(r"[a-f0-9]{64}", manifest.get("source_sha256", "")):
        raise ValueError("Invalid source fingerprint.")
    for kind in ["dmg", "zip"]:
        item = manifest.get(kind, {})
        name = item.get("name", "")
        if not name or Path(name).name != name or "/" in name or "\\" in name or not name.endswith("." + kind):
            raise ValueError("Unsafe release filename.")
        if item.get("url") != asset_url(repository, tag, name):
            raise ValueError("Release download URL mismatch.")
        if not re.fullmatch(r"[a-f0-9]{64}", item.get("sha256", "")):
            raise ValueError("Invalid asset checksum.")
        if type(item.get("bytes")) is not int or item["bytes"] <= 0:
            raise ValueError("Invalid asset size.")
    return manifest


def validate_artifacts(directory, repository):
    """Validate manifest, signed-feed structure and artifact hashes in directory for repository; return manifest."""
    manifest = validate_manifest(json.loads((directory / "release.json").read_text()), repository)
    feed = directory / "appcast.xml"
    if sha256(feed) != manifest["appcast_sha256"]:
        raise ValueError("Feed bytes changed after signing.")
    feed_bytes = feed.read_bytes()
    if not re.search(rb"<!-- sparkle-signatures:\s*edSignature: [A-Za-z0-9+/=]+\s*length: \d+\s*-->", feed_bytes):
        raise ValueError("The update feed has no Sparkle signature.")
    item = ET.fromstring(feed_bytes).find("./channel/item")
    if item is None:
        raise ValueError("The update feed contains no release.")
    enclosure = item.find("enclosure")
    if enclosure is None or enclosure.get("url") != manifest["zip"]["url"]:
        raise ValueError("Feed enclosure does not match the uploaded ZIP.")
    if item.findtext(f"{{{NAMESPACE}}}version") != str(manifest["build"]):
        raise ValueError("Feed build differs from the release.")
    if not enclosure.get(f"{{{NAMESPACE}}}edSignature"):
        raise ValueError("The update archive lacks a signature.")
    if enclosure.get("length") != str(manifest["zip"]["bytes"]):
        raise ValueError("Feed enclosure size differs from the archive.")
    for kind in ["dmg", "zip"]:
        artifact = directory / manifest[kind]["name"]
        if artifact.stat().st_size != manifest[kind]["bytes"] or sha256(artifact) != manifest[kind]["sha256"]:
            raise ValueError(f"{kind.upper()} differs from the manifest.")
    return manifest


def prepare():
    """Package the configured universal app, sign its update feed and create release.json; return the release path."""
    repository = configured_repository()
    info = release_info()
    app = ROOT / "dist/活着的意义.app"
    bundle = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected_feed = pages_url(repository) + "appcast.xml"
    if bundle.get("SUFeedURL") != expected_feed:
        raise ValueError("Rebuild with the configured official update feed before packaging.")
    run([sys.executable, ROOT / "scripts/build-info.py", "verify", app])
    architectures = run(
        ["lipo", "-archs", app / "Contents/MacOS/LivingMeaning"], capture_output=True, text=True
    ).stdout.split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise ValueError("Run bash scripts/build.sh --universal before release.")
    directory = ROOT / "dist/github" / info["tag"]
    if directory.exists():
        manifest = validate_artifacts(directory, repository)
        provenance = json.loads((app / "Contents/Resources/BuildInfo.json").read_text())
        if manifest["source_sha256"] != provenance["sourceSHA256"]:
            raise ValueError("Prepared version uses different source. Increment the version before a new release.")
        print("Reusing verified prepared release:", directory)
        return directory
    prefix = f"https://github.com/{repository}/releases/download/{info['tag']}/"
    directory.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".prepare-", dir=directory.parent) as temporary:
        staging = Path(temporary) / "release"
        run([sys.executable, ROOT / "scripts/release.py", "--base-url", prefix, "--output", staging, "--dmg"])
        run([SPARKLE / "sign_update", "--account", "local.livingmeaning.updates",
             "--verify", staging / "appcast.xml"])
        generated = json.loads((staging / "latest.json").read_text())
        manifest = {
            **info, "repository": repository, "site_url": pages_url(repository), "feed_url": expected_feed,
            "minimum_macos": "13.0", "architectures": ["arm64", "x86_64"], "notarized": False,
            "prepared_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "appcast_sha256": sha256(staging / "appcast.xml"), "source_sha256": generated["sourceSHA256"],
        }
        for kind in ["dmg", "zip"]:
            artifact = staging / generated[kind]
            manifest[kind] = {
                "name": artifact.name, "url": asset_url(repository, info["tag"], artifact.name),
                "sha256": sha256(artifact), "bytes": artifact.stat().st_size,
            }
        (staging / "release.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        validate_artifacts(staging, repository)
        shutil.move(str(staging), str(directory))
    print("Prepared signed release:", directory)
    return directory


def assemble_site(directory, output, repository):
    """Assemble website in output using verified artifacts in directory for repository; return the output path."""
    manifest = validate_artifacts(directory, repository)
    if output.exists():
        raise ValueError("Website output already exists; choose a fresh output directory.")
    shutil.copytree(ROOT / "site", output)
    for name in ["appcast.xml", "release.json"]:
        shutil.copyfile(directory / name, output / name)
    (output / "release-config.js").write_text(
        "window.LIVING_MEANING_RELEASE = " + json.dumps(manifest, ensure_ascii=False).replace("<", "\\u003c") + ";\n"
    )
    if sha256(output / "appcast.xml") != manifest["appcast_sha256"]:
        raise ValueError("Website assembly changed the signed update feed.")
    return output


def publish():
    """Publish a prepared release using authenticated GitHub CLI after remote checks; return the public release URL."""
    github(["auth", "status", "--hostname", "github.com"])
    repository = configured_repository()
    directory = prepare()
    manifest = validate_artifacts(directory, repository)
    run([SPARKLE / "sign_update", "--account", "local.livingmeaning.updates",
         "--verify", directory / "appcast.xml"])
    if run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout.strip():
        raise ValueError("Commit and push reviewed changes before publishing; this script never commits.")
    head = run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    remote = json.loads(github(["api", f"repos/{repository}/commits/main"]))
    if remote["sha"] != head:
        raise ValueError("Remote main must match the reviewed local commit before release.")
    repo = json.loads(github(["api", f"repos/{repository}"]))
    if repo["private"]:
        raise ValueError("This website pipeline requires the approved public repository.")
    tag = manifest["tag"]
    assets = [directory / manifest[kind]["name"] for kind in ["dmg", "zip"]]
    assets += [directory / "appcast.xml", directory / "release.json", directory / "latest.json"]
    existing = None
    try:
        existing = json.loads(github([
            "release", "view", tag, "--repo", repository, "--json", "isDraft,assets,targetCommitish"
        ]))
    except subprocess.CalledProcessError as error:
        if "release not found" not in (error.stderr or "").lower() and "404" not in (error.stderr or ""):
            raise
    if existing is not None and not existing["isDraft"]:
        raise ValueError("This version is already public; never replace released binaries. Increment the version.")
    if existing is not None and existing["targetCommitish"] != head:
        raise ValueError("Existing draft targets a different commit. Review it before continuing.")
    if existing is None:
        notes = directory / "release-notes.md"
        notes.write_text(
            f"活着的意义 {manifest['version']}（构建 {manifest['build']}）\n\n"
            f"- macOS 13+，Apple Silicon / Intel 通用应用。\n"
            f"- 官网：{manifest['site_url']}\n"
            "- 内置固定更新源；升级保留本机设置、打卡记录和保护密码。\n"
            "- 当前为未做 Apple 公证的试用版，安装说明见官网。\n\n"
            f"DMG SHA-256：`{manifest['dmg']['sha256']}`\n"
        )
        github(["release", "create", tag, "--repo", repository, "--target", head, "--draft",
                "--title", f"活着的意义 {manifest['version']}", "--notes-file", str(notes)])
    current = json.loads(github(["release", "view", tag, "--repo", repository, "--json", "assets"]))
    present = {item["name"] for item in current["assets"]}
    missing = [str(asset) for asset in assets if asset.name not in present]
    if missing:
        github(["release", "upload", tag, "--repo", repository, *missing])
    # Verify downloads from the draft before making the assets public.
    with tempfile.TemporaryDirectory(prefix="living-release-readback-") as temporary:
        github(["release", "download", tag, "--repo", repository, "--dir", temporary])
        downloaded = validate_artifacts(Path(temporary), repository)
        if downloaded != manifest:
            raise ValueError("The draft has different release metadata. Leave it unpublished for review.")
    try:
        pages = json.loads(github(["api", f"repos/{repository}/pages"]))
        if pages.get("build_type") != "workflow":
            raise ValueError("Existing Pages configuration differs; review it before switching publishing modes.")
    except subprocess.CalledProcessError as error:
        if "404" not in error.stderr:
            raise
        github(["api", "--method", "POST", f"repos/{repository}/pages", "-f", "build_type=workflow"])
    github(["release", "edit", tag, "--repo", repository, "--draft=false", "--latest"])
    # Explicit dispatch covers accounts where publishing a release does not trigger a workflow.
    github(["workflow", "run", "pages.yml", "--repo", repository, "--ref", "main"])
    address = f"https://github.com/{repository}/releases/tag/{tag}"
    print("Release published:", address)
    print("Pages deployment queued. Verify its success before sharing:", pages_url(repository))
    return address


def verify_online():
    """Verify public website/feed/download bytes against the local prepared release; return a verification report."""
    repository = configured_repository()
    directory = ROOT / "dist/github" / release_info()["tag"]
    manifest = validate_artifacts(directory, repository)
    with tempfile.TemporaryDirectory(prefix="living-public-readback-") as temporary:
        output = Path(temporary)
        for name in ["release.json", "appcast.xml"]:
            request = urllib.request.Request(pages_url(repository) + name, headers={"Cache-Control": "no-cache"})
            with urllib.request.urlopen(request, timeout=30) as response:
                (output / name).write_bytes(response.read())
        for kind in ["dmg", "zip"]:
            with urllib.request.urlopen(manifest[kind]["url"], timeout=45) as response:
                (output / manifest[kind]["name"]).write_bytes(response.read())
        public = validate_artifacts(output, repository)
        if public != manifest:
            raise ValueError("The deployed website does not yet match this release.")
        run([SPARKLE / "sign_update", "--account", "local.livingmeaning.updates",
             "--verify", output / "appcast.xml"])
        with urllib.request.urlopen(pages_url(repository), timeout=30) as response:
            if "活着的意义" not in response.read().decode("utf-8"):
                raise ValueError("The website did not render the expected product.")
    report = {"website": pages_url(repository), "version": manifest["version"],
              "publicDownloadsVerified": True, "signedFeedVerified": True}
    (directory / "online-verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


def main():
    """Dispatch explicit configuration/build/publish/site/verification CLI actions; return nothing."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    configure = commands.add_parser("configure")
    configure.add_argument("repository")
    commands.add_parser("feed-url")
    commands.add_parser("prepare")
    commands.add_parser("publish")
    commands.add_parser("verify-online")
    website = commands.add_parser("assemble-site")
    website.add_argument("--artifacts", type=Path, required=True)
    website.add_argument("--output", type=Path, required=True)
    website.add_argument("--repository", required=True)
    args = parser.parse_args()
    if args.action == "configure":
        name = repository_name(args.repository)
        (ROOT / "release-config.json").write_text(json.dumps({"repository": name}, indent=2) + "\n")
        print("Configured repository:", name)
        print("Website:", pages_url(name))
        print("Update feed:", pages_url(name) + "appcast.xml")
    elif args.action == "feed-url":
        name = configured_repository(required=False)
        print(pages_url(name) + "appcast.xml" if name else "")
    elif args.action == "prepare":
        prepare()
    elif args.action == "publish":
        publish()
    elif args.action == "assemble-site":
        print(assemble_site(args.artifacts, args.output, repository_name(args.repository)))
    elif args.action == "verify-online":
        verify_online()


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error
