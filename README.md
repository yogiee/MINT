# MINT — Media INformaTion

A lightning-fast, native macOS viewer for full media file info, powered by [MediaInfo](https://mediaarea.net/MediaInfo).

Right-click any video/audio/image → **Open With → MINT** and the file's full technical details are on screen instantly — no drag-and-drop dance, no empty window. Built because MediaInfo-GUI and BetterMediaInfo both open empty on "Open With."

## Features

- **Open With actually works** — the file is parsed and shown the moment the window appears (cold or warm launch).
- **Independent windows** — every file opens in its own window; arrange them side by side to compare.
- **Clean inspector** — a summary card (with thumbnail) plus a curated, humanized field list; floating track switcher (General / Video / Audio / …).
- **Pretty / Raw** — curated view or the verbatim `mediainfo` output.
- **Filter** (⌘F), **click-to-copy** any value, **Copy** / **Export** the whole report.
- **Recent files** sidebar, **Light / Dark / System** appearance, adjustable font size & row spacing.
- **Self-contained** — the `mediainfo` CLI is bundled; you don't need to install anything.

## Install

1. Download `MINT.dmg` from the [latest release](https://github.com/yogiee/MINT/releases/latest).
2. Open the DMG and drag **MINT** to **Applications**.

### First launch (Gatekeeper)

MINT is **not notarized** (no paid Apple Developer account), so macOS will warn on first launch. One-time bypass:

- **Right-click** MINT.app → **Open** → **Open**, *or*
- run once in Terminal:
  ```sh
  xattr -dr com.apple.quarantine /Applications/MINT.app
  ```

It's a normal, ad-hoc-signed app — this is only needed once.

## Requirements

- macOS 15 (Sequoia) or later, Apple Silicon or Intel.

## Build from source

```sh
git clone https://github.com/yogiee/MINT.git
cd MINT
./scripts/build-app.sh      # → build/MINT.app and build/MINT.dmg
```
Or open `MINT.xcodeproj` in Xcode and Run (uses your Homebrew `mediainfo` in dev; the release script bundles it).

Requires Xcode 26+ and (for the bundled CLI) `brew install media-info`.

## Credits

- [MediaInfo](https://mediaarea.net/MediaInfo) © MediaArea.net SARL — BSD-2-Clause. The `mediainfo` CLI, `libmediainfo`, and `libzen` are bundled. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
- Thumbnails via macOS QuickLook.
