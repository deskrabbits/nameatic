# Nameatic

A dead simple macOS app aimed at solving exactly one problem: "I have all these video files and I want to rename each of them with ease"

The app is keyboard-first:
- `⏎` renames the current file on disk and then shows you the next file in the batch
- `↑/↓` navigate without saving
- `⌘⌫` moves the current file to the Trash

[deskrabbits.github.io/nameatic](https://deskrabbits.github.io/nameatic/)


Bonus: works great even if you are using it with AirPods. You don't run into that issue where the first five seconds of watching the video are janky while the video gets in sync with the audio like what happens when you use Quick Look in the Finder.

## Building

Requires macOS 26 with Command Line Tools (full Xcode not needed).

```sh
script/build-app.sh          # swift build + assembles build/Nameatic.app
script/make-icon.sh          # regenerates Icon/AppIcon.icns from Icon/icon.svg
open build/Nameatic.app
```

Launch with files: `open -a build/Nameatic.app *.mov`

## Releasing

```sh
script/release.sh            # prompts for the version and release notes
script/release.sh minor      # or: 1.2, major, patch; --dry-run to skip publishing
```

Bumps `Info.plist`, builds a notarized app, tags and pushes `main`, publishes the
GitHub release, and adds the update to `appcast.xml` on `gh-pages`. Needs the
`.env` / notarytool setup described in `script/build-app.sh`, a logged-in `gh`,
and the Sparkle EdDSA key in the login keychain.

## Layout

- `Sources/Nameatic/Models` — `BatchFile`, `BatchStore` (state + on-disk rename)
- `Sources/Nameatic/Views` — builder screen, rename screen, NSTextField-backed
  rename field, chromeless AVPlayerLayer preview
- `Sources/Nameatic/Media` — async duration/thumbnail loading

The GitHub Pages site and the Sparkle `appcast.xml` feed live on the
`gh-pages` branch, not `main`.
