# Third-party notices

Third-party components keep their original licenses. The project's [LICENSE](LICENSE)
does not replace or restrict those grants.

## Sparkle 2.10.1

The application embeds the Sparkle update framework.

- Upstream: <https://github.com/sparkle-project/Sparkle>
- Pinned version: **2.10.1**
- Complete upstream notice: [licenses/Sparkle-LICENSE.txt](licenses/Sparkle-LICENSE.txt)
- Application copy: `Contents/Resources/Sparkle-LICENSE.txt`

Sparkle's upstream license file includes its MIT-style license and additional component notices:

| Component | Upstream notice |
| --- | --- |
| Sparkle | MIT-style permission and warranty disclaimer |
| bsdiff / bspatch | Colin Percival's two-clause BSD terms |
| sais-lite | Yuta Mori's MIT terms |
| Portable Ed25519 implementation | Orson Peters' zlib-style terms |
| SUSignatureVerifier.m | Mark Hamlin's two-clause BSD terms |

The table is an index. The complete, unmodified upstream text is authoritative.
`scripts/fetch-sparkle.py` verifies the pinned archive's SHA-256;
`scripts/build.sh` includes the upstream notices in every application build.

## Platform and build tools

The app uses Apple's system frameworks and the Swift toolchain.
Those are supplied under their respective terms and are not relicensed by this repository.
Python and GitHub Actions support development and publication; they are not bundled into the application.

The website uses local assets and system fonts, with no third-party frontend framework or external font service.

## Project artwork and holiday sources

The Bernese mountain dog icon is project artwork, not part of Sparkle.
See [LICENSE](LICENSE) for its current licensing status.
Demonstration screenshots contain fictional figures.

Holiday source references are kept in [docs/holiday-sources](docs/holiday-sources).
Those government publications are factual source references, not an endorsement of this application.
