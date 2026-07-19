# Renamatic

A dead simple macOS app aimed at solving exactly one problem: "I have all these video files and I want to rename each of them with ease"

The app is keyboard-first:
- `⏎` renames the current file on disk and then shows you the next file in the batch
- `↑/↓` navigate without saving
- `⌘⌫` moves the current file to the Trash

[deskrabbits.github.io/renamatic](https://deskrabbits.github.io/renamatic/)


Bonus: works great even if you are using it with AirPods. You don't run into that issue where the first five seconds of watching the video are janky while the video gets in sync with the audio like what happens when you use Quick Look in the Finder.

## Building

Requires macOS 26 with Command Line Tools (full Xcode not needed).

```sh
script/build-app.sh          # swift build + assembles build/Renamatic.app
script/make-icon.sh          # regenerates Icon/AppIcon.icns from Icon/icon.svg
open build/Renamatic.app
```

Launch with files: `open -a build/Renamatic.app *.mov`

## Layout

- `Sources/Renamatic/Models` — `BatchFile`, `BatchStore` (state + on-disk rename)
- `Sources/Renamatic/Views` — builder screen, rename screen, NSTextField-backed
  rename field, chromeless AVPlayerLayer preview
- `Sources/Renamatic/Media` — async duration/thumbnail loading

The GitHub Pages site (Jekyll) and the Sparkle `appcast.xml` feed live on the
`gh-pages` branch, not `main`.
