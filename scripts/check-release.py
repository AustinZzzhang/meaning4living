#!/usr/bin/env python3
"""Check release trust boundaries and website assembly without network access, credentials or publishing."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("github-release.py")
SPEC = importlib.util.spec_from_file_location("github_release", MODULE_PATH)
RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RELEASE)


class ReleaseChecks(unittest.TestCase):
    """Verify release URL/hash validation and exact-byte deployment using disposable synthetic artifacts."""

    def setUp(self):
        """Create isolated repository metadata and synthetic signed-format fixtures; no inputs or return value."""
        self.temporary = tempfile.TemporaryDirectory(prefix="living-release-check-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name) / "artifacts"
        self.directory.mkdir()
        self.repository = "fixture-owner/living-meaning"
        self.manifest = {
            "repository": self.repository, "version": "1.2.1", "build": "6", "tag": "v1.2.1",
            "site_url": RELEASE.pages_url(self.repository),
            "feed_url": RELEASE.pages_url(self.repository) + "appcast.xml",
            "minimum_macos": "13.0", "architectures": ["arm64", "x86_64"], "notarized": False,
            "source_sha256": "f" * 64,
        }
        for kind, name in [("dmg", "活着的意义-1.2.1.dmg"), ("zip", "LivingMeaning-1.2.1.zip")]:
            path = self.directory / name
            path.write_bytes(b"synthetic-format-only-fixture")
            self.manifest[kind] = {
                "name": name, "url": RELEASE.asset_url(self.repository, "v1.2.1", name),
                "sha256": RELEASE.sha256(path), "bytes": path.stat().st_size,
            }
        self.write_feed()
        self.write_manifest()

    def write_feed(self, build="6", url=None, signature=True):
        """Write a synthetic feed with build/url/signature-shape options; update its hash and return nothing."""
        enclosure = url or self.manifest["zip"]["url"]
        text = (
            f'<rss xmlns:sparkle="{RELEASE.NAMESPACE}"><channel><item>'
            f"<sparkle:version>{build}</sparkle:version>"
            f'<enclosure url="{enclosure}" length="{self.manifest["zip"]["bytes"]}" '
            'sparkle:edSignature="TEST-ONLY"/>' + "</item></channel></rss>"
        )
        if signature:
            text += "<!-- sparkle-signatures:\nedSignature: QUFBQQ==\nlength: 42\n-->"
        path = self.directory / "appcast.xml"
        path.write_text(text)
        self.manifest["appcast_sha256"] = RELEASE.sha256(path)

    def write_manifest(self):
        """Save current fixture metadata; takes no parameters and returns nothing."""
        (self.directory / "release.json").write_text(json.dumps(self.manifest))

    def test_valid_artifacts(self):
        """Accept a consistent artifact layout; no inputs, returns nothing and asserts verified metadata."""
        self.assertEqual(RELEASE.validate_artifacts(self.directory, self.repository), self.manifest)

    def test_repository_names_reject_paths_and_urls(self):
        """Reject unsafe owner/repository inputs; no inputs or return, asserts all invalid names fail."""
        for name in ["https://github.com/a/b", "../project", "a/b/c", "a/../../b", "a/../", None, "a b/c"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                RELEASE.repository_name(name)

    def test_project_and_account_pages_urls(self):
        """Check project and account website roots; no inputs or return, asserts correct canonical addresses."""
        self.assertEqual(RELEASE.pages_url("Owner/living-meaning"), "https://owner.github.io/living-meaning/")
        self.assertEqual(RELEASE.pages_url("Owner/Owner.github.io"), "https://owner.github.io/")

    def test_malicious_download_url(self):
        """Reject an unrelated download host despite valid metadata; no inputs or return value."""
        self.manifest["dmg"]["url"] = "https://attacker.invalid/package.dmg"
        with self.assertRaises(ValueError):
            RELEASE.validate_manifest(self.manifest, self.repository)

    def test_wrong_repository(self):
        """Reject manifests from another repository; no inputs or return value."""
        with self.assertRaises(ValueError):
            RELEASE.validate_manifest(self.manifest, "other-owner/living-meaning")

    def test_asset_path_traversal(self):
        """Reject a manifest filename that escapes its artifact directory; no inputs or return value."""
        self.manifest["zip"]["name"] = "../LivingMeaning-1.2.1.zip"
        with self.assertRaises(ValueError):
            RELEASE.validate_manifest(self.manifest, self.repository)

    def test_modified_download(self):
        """Catch a modified archive before deployment; no inputs or return, asserts validation fails."""
        (self.directory / self.manifest["zip"]["name"]).write_bytes(b"changed")
        with self.assertRaises(ValueError):
            RELEASE.validate_artifacts(self.directory, self.repository)

    def test_modified_feed(self):
        """Catch any alteration to signed-feed bytes; no inputs or return value."""
        with (self.directory / "appcast.xml").open("ab") as handle:
            handle.write(b"\n")
        with self.assertRaises(ValueError):
            RELEASE.validate_artifacts(self.directory, self.repository)

    def test_missing_feed_signature_marker(self):
        """Refuse unsigned-format appcasts even with matching hashes; no inputs or return value."""
        self.write_feed(signature=False)
        self.write_manifest()
        with self.assertRaises(ValueError):
            RELEASE.validate_artifacts(self.directory, self.repository)

    def test_wrong_feed_build(self):
        """Refuse a feed whose build differs from its release; no inputs or return value."""
        self.write_feed(build="5")
        self.write_manifest()
        with self.assertRaises(ValueError):
            RELEASE.validate_artifacts(self.directory, self.repository)

    def test_wrong_feed_enclosure(self):
        """Refuse a signed-format feed pointing to another download; no inputs or return value."""
        self.write_feed(url="https://attacker.invalid/app.zip")
        self.write_manifest()
        with self.assertRaises(ValueError):
            RELEASE.validate_artifacts(self.directory, self.repository)

    def test_notarization_cannot_be_claimed(self):
        """Reject unverified claims of Apple notarization; no inputs or return value."""
        self.manifest["notarized"] = True
        with self.assertRaises(ValueError):
            RELEASE.validate_manifest(self.manifest, self.repository)

    def test_deployment_preserves_signed_bytes_and_excludes_installers(self):
        """Build a site and verify unchanged appcast, injected config and no binaries; no inputs or return value."""
        output = Path(self.temporary.name) / "site"
        RELEASE.assemble_site(self.directory, output, self.repository)
        self.assertEqual((output / "appcast.xml").read_bytes(), (self.directory / "appcast.xml").read_bytes())
        self.assertIn(self.repository, (output / "release-config.js").read_text())
        self.assertTrue((output / "index.html").exists())
        self.assertFalse(list(output.rglob("*.zip")) + list(output.rglob("*.dmg")))

    def test_failed_validation_keeps_previous_site(self):
        """Reject tampered inputs before touching an existing site; no inputs or return value."""
        output = Path(self.temporary.name) / "site"
        output.mkdir()
        (output / "index.html").write_text("previous-deployment")
        self.manifest["zip"]["bytes"] += 1
        self.write_manifest()
        with self.assertRaises(ValueError):
            RELEASE.assemble_site(self.directory, output, self.repository)
        self.assertEqual((output / "index.html").read_text(), "previous-deployment")

    def test_unconfigured_preview_has_no_fake_download(self):
        """Verify source preview carries no invented release URL; no inputs or return value."""
        config = (RELEASE.ROOT / "site/release-config.js").read_text()
        self.assertIn("window.LIVING_MEANING_RELEASE = null;", config)
        self.assertNotIn("example.com", config)


if __name__ == "__main__":
    unittest.main(verbosity=2)
