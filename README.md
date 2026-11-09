<p align="center">
  <img src="site/assets/app-icon.png" width="112" height="112" alt="Living Meaning's Bernese mountain dog icon" />
</p>

# Living Meaning · 活着的意义

**Make every second count. Leave time for living.**

A small, native macOS companion that turns your salary into live earnings, counts down to the end of your shift,
and helps you clock out. Built with SwiftUI and AppKit, with a Bernese mountain dog to keep you company.

**English** · [简体中文](README.zh-CN.md)

[Website][website] · [Releases][releases] · [Issues][issues]

**macOS 13+** · **Apple Silicon & Intel** · **Local data** · **Simplified Chinese app interface**

![Living Meaning dashboard with fictional demonstration data](site/assets/dashboard.png)

## Features

- **Live menu bar:** per-second earnings and time until clock-out, with green working and red overtime states.
  Compact layout accommodates Macs with a notch; no Touch Bar is required.
- **Work calendar:** mainland China public holidays and makeup workdays for 2025–2027,
  plus weekly schedules and individual day overrides.
- **Clock-in and clock-out:** clocking in changes the status without resetting earnings.
  Early clock-out settles the remaining scheduled pay; clocking out stops further overtime loss.
- **Daily records:** total earnings, paid time outside attendance, and simulated overtime loss are shown separately.
- **Sensitive mode:** replace monetary amounts with clothing and jewelry, electronics, or food items.
  Customize the thresholds and items; losses use the same thresholds.
- **Settings lock:** protect settings with a password whose verification credential lives in macOS Keychain.
- **Presentation privacy:** hide details during system display mirroring, optionally on an external display,
  or manually with **Control–Option–Command–P**.
- **In-app updates:** check, download, and approve updates verified with the app's pinned Sparkle signing key.
- **Touch Bar:** show the current state on supported hardware while the app is in the foreground.

## Download and installation

[Official website][website] · [Download the latest release][latest]

Download the versioned **.dmg** installer from the release assets, or use the website download button.
The release workflow uses **GitHub Releases** for DMG/ZIP downloads
and **GitHub Pages** for the website and update feed.

1. Download the DMG from the official website or this repository's **Releases** page.
2. Open it and drag **活着的意义.app** into **Applications**.
3. Launch the app, set your monthly salary and working hours, then save.
4. Clock in from the dashboard or menu bar, and clock out when your day ends.

Current builds are ad-hoc signed and **not Apple Developer ID signed or notarized**.
If macOS blocks the first launch, verify the download source, attempt to open the app,
then check **System Settings → Privacy & Security → Open Anyway**.
The application does not require disabling Gatekeeper.

Official builds include the update feed. Use the app's **更新** (Updates) page to check for a newer version.
Automatic checks are off by default, and installation requires confirmation.
Older preview builds can be upgraded manually once; subsequent updates preserve local settings and records.

## How the numbers work

This is a personal time-and-pay visualization. Overtime “loss” is a motivational estimate,
not a deduction from your salary or a connection to an employer's payroll system.

```text
Per-second rate = monthly salary / total scheduled working seconds in that month
Earnings = elapsed scheduled working seconds × the shift's saved rate
Paid time outside attendance = scheduled time before clock-in + scheduled time after early clock-out
Overtime loss = counted overtime while running and not clocked out × the shift's saved rate
```

The app calls paid time outside attendance **白嫖**.
It is a **subset of earnings**, never an extra amount to add to the total.
Clocking out settles earnings to the full scheduled shift.

For example, with a 09:00–18:00 shift and a rate of ¥100 per hour:
clock in at 09:30 and out at 17:00 → **¥900 earned**, **¥150 of that outside attendance**, **¥0 lost**.

| Situation | Behavior |
| --- | --- |
| Work has started, but you have not clocked in | Earnings accrue and are classified as 白嫖. |
| You clock in | The status changes; the same day's earnings continue without resetting. |
| You clock out early | Remaining scheduled pay is settled immediately and classified as 白嫖. |
| Your shift ends without clock-out | Overtime loss accumulates while the app remains running. |
| You clock out after the shift | Further loss stops; the amount already recorded remains in the daily record. |
| You close the window | The app keeps running in the menu bar. |
| You quit the app | No loss is charged while it is closed; quitting does not clock you out. |

Existing shifts retain their schedule, rate, and time zone so changing settings does not rewrite history.
Overnight shifts are supported. Personal day overrides take priority over the built-in holiday calendar,
which takes priority over the weekly schedule.

## Privacy and limitations

- No account is required. Salary, schedules, and attendance records stay on your Mac.
- Data is stored at `~/Library/Application Support/LivingMeaning/state.json`.
  Password verification data is stored separately in macOS Keychain.
- Sensitive mode conceals amounts in the interface; the settings password protects access to settings.
  Neither feature encrypts the local records file.
- Updates request the configured feed and release files. Salary, attendance, and password data are not sent;
  Sparkle system-profile reporting is disabled.
- Automatic presentation privacy detects system mirroring and the optional external-display condition.
  It cannot reliably detect every meeting app or screen recorder. Use the manual shortcut before sharing.
- The menu bar works on supported Macs with or without a notch or Touch Bar.
  Touch Bar content follows the foreground app and is not a system-wide persistent widget.
- Sleep counts toward overtime if the app has not quit. Ordinary daytime shifts stop counting overtime at midnight.
- Clock-in, clock-out, and corrections save immediately. Other timer updates save every five seconds;
  an abnormal termination may lose the most recent unsaved interval.
- The built-in holiday calendar covers 2025–2027 and indicates when a year needs updated data.
- Version 1.2 introduced data schema 2. Back up your data before downgrading;
  an older app may need its corresponding pre-upgrade data backup.

## Build and run

Requirements: macOS, Apple Command Line Tools with a Swift compiler, and Python 3.
The first build downloads the pinned Sparkle 2.10.1 release and verifies its SHA-256.

```bash
xcode-select --install
# From the root of this checkout:
bash scripts/check.sh
python3 scripts/check-release.py
bash scripts/build.sh --universal
open "dist/活着的意义.app"
```

Omit `--universal` for a build targeting only the current Mac's architecture.
The build script assembles the `.app`, resources, embedded framework, and signatures.
No release signing private key is needed for development builds.

Preview the static website without Node.js or a frontend build step:

```bash
python3 -m http.server 8876 --bind 127.0.0.1 --directory site
# Open http://127.0.0.1:8876 in your browser.
```

Before release metadata is supplied, the preview deliberately disables downloads.

### Additional verification

These commands use isolated test data. The updater check uses temporary app copies and a loopback server.

```bash
python3 scripts/check-updates.py
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" --render-previews "$PWD/dist/previews"
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" --smoke-test "$PWD/dist/verification/live"
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" \
  --check-menu-bar "$PWD/dist/verification/menu" --without-touch-bar
```

## Releases and updates

This standalone repository contains the application, website, and publishing tools.
It has no dependency on a parent workspace.

1. Source and website code are versioned here; generated builds and personal data are excluded from Git.
2. A maintainer builds and signs a release locally using the existing Sparkle key in macOS Keychain.
3. The publishing script uploads a draft Release and downloads its assets again to verify their bytes.
4. The verified Release is published; GitHub Actions deploys the website and the unchanged signed update feed.
5. Public downloads, checksums, and the feed signature are verified after deployment.

The official update feed is `https://austinzzzhang.github.io/meaning4living/appcast.xml`.

GitHub Actions does not hold the Sparkle private key. Published versions are not overwritten.
Both the display version and the internal build number must increase for a new release.

See [initial GitHub setup](GITHUB-SETUP.md) and [update and release procedures](UPDATES.md)
for maintainer instructions, currently in Chinese.

## Project layout

```text
Sources/LivingCore/          Calendar, earnings, attendance, validation, persistence
Sources/LivingMeaning/       SwiftUI/AppKit interface, menu bar, Touch Bar, updater
Sources/LivingMeaningChecks/ Business-rule checks
Resources/                  App icon, bundle metadata, release notes
site/                       Static website and demonstrations using fictional data
scripts/                    Build, test, package, signing, and publishing tools
.github/workflows/          macOS checks and GitHub Pages deployment
docs/                       Holiday sources and platform behavior notes
```

[SPEC.md](SPEC.md) records the app's behavioral rules.
Historical `VERIFICATION*.md` files describe local acceptance checks;
their generated evidence files are not committed.

## Feedback and contributing

Bug reports and feature suggestions are welcome through [GitHub Issues][issues].
Include the app version, macOS version, Mac architecture, reproduction steps, and expected behavior.
Use fictional numbers and remove personal information from screenshots and logs.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes.
Licensing terms for source contributions must be agreed with the maintainer before submitting code.
For security-sensitive reports, follow [SECURITY.md](SECURITY.md).
Avoid disclosing secrets or personal data publicly.

## License and acknowledgments

**Licensing status: all rights reserved; no open-source license has been granted for this project's own material.**
See [LICENSE](LICENSE). Public visibility does not grant a general right to reuse, modify,
commercialize, or redistribute the project's code, documentation, or artwork.
GitHub's applicable viewing and forking rights and third-party licenses remain unaffected.

The **活着的意义 / Living Meaning** name, Bernese mountain dog icon, and other brand assets
are not offered under a separate open artwork or trademark license.

The application uses **Sparkle 2.10.1** for updates. Sparkle's license and the notices for its bundled components
are preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
and [licenses/Sparkle-LICENSE.txt](licenses/Sparkle-LICENSE.txt).
The build also includes those upstream notices inside the application.

Holiday data sources are recorded in [docs/holiday-sources](docs/holiday-sources).
Apple, macOS, Swift, GitHub, and Sparkle are names of their respective owners;
this project does not claim endorsement by them.

[website]: https://austinzzzhang.github.io/meaning4living/
[releases]: https://github.com/AustinZzzhang/meaning4living/releases
[latest]: https://github.com/AustinZzzhang/meaning4living/releases/latest
[issues]: https://github.com/AustinZzzhang/meaning4living/issues
