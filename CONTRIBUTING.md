# Contributing

English and Simplified Chinese reports are welcome.

## Report a problem or suggest a feature

Use the repository's Issues tab for ordinary bugs and feature requests.
For a bug, include:

- App version and build number.
- macOS version and Apple Silicon or Intel architecture.
- A minimal set of reproduction steps.
- Expected behavior and what actually happened.
- Screenshots or logs with fictional amounts and personal information removed.

Never attach your salary records, settings password, Keychain exports, or signing keys.
For a security-sensitive issue, follow [SECURITY.md](SECURITY.md).

## Propose a source change

This project's original material is not currently offered under an open-source license.
Read [LICENSE](LICENSE) and discuss permission and contribution terms with the maintainer
before submitting code. An issue or pull request does not itself resolve those terms.

For an agreed change:

1. Keep calendar and earnings rules in `Sources/LivingCore` and platform UI in `Sources/LivingMeaning`.
2. Keep changes focused and describe the resulting user behavior.
3. Document each new or changed function's purpose, parameters, and return value.
4. Keep source lines at or below 120 characters.
5. Run checks appropriate to the change:

   ```bash
   bash scripts/check.sh
   python3 scripts/check-release.py
   bash scripts/build.sh --universal
   ```

6. For interface changes, inspect actual native preview output using isolated test data.
7. Include verification results and known limits in the change description.
8. Use an English commit subject. Do not commit generated builds, personal data, or secrets.

The existing updater key and published release assets must not be replaced.
Only the maintainer's approved publishing process may sign and publish official updates.
