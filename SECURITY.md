# Security

## Scope

Security-sensitive areas include the settings lock, local data handling, update verification,
release artifacts, and the publishing workflow.

Sensitive mode hides amounts in the interface, and the password restricts access to settings.
The local records file is not encrypted by either feature.
The password verification credential is stored in macOS Keychain.

## Reporting

Use the repository's **Security → Report a vulnerability** option if private reporting is enabled.
If that option is unavailable and no private maintainer contact is listed, open a minimal issue
asking for a private reporting channel. Do not include exploit details, credentials, or personal records there.

A private report should include the affected version, platform, reproduction steps using test data,
impact, and any suggested mitigation. Never send a real password, salary file, or signing private key.

## Updates

Use the latest official release for fixes. Older preview versions do not have a separate maintenance branch.
The app verifies updates using its pinned Sparkle public key; private release keys are not kept in GitHub Actions.
The project does not promise a response time or a security support period.

Current builds are not Apple Developer ID signed or notarized.
Sparkle update verification and Apple notarization serve different purposes;
the presence of an update signature is not a claim of Apple approval.
