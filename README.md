# Whippet

A macOS menu bar app that frees up disk space taken by iOS, Android, React Native and web development build artifacts and caches.

## Requirements

- macOS 26 or later
- Xcode 26 or later
- Apple Intelligence enabled, for the on-device explanations (optional — Whippet falls back to built-in descriptions)

## Build

```sh
git clone https://github.com/exploIF/whippet.git
cd whippet
```

Then build and install it into `/Applications`:

```sh
scripts/install.sh
```

The script builds a Release copy, quits Whippet if it's running, replaces
`/Applications/Whippet.app` and launches it. Pass `--no-open` to skip launching.
Run it again after pulling changes to update.

To work on the code instead, open the project in Xcode and press Run:

```sh
open Whippet.xcodeproj
```

`scripts/install.sh` also sets this project's Xcode build location to
`build/DerivedData.noindex` (a per-user setting, only if you haven't chosen one).
Spotlight skips `.noindex` folders, so only the copy in `/Applications` shows up in
Spotlight and Launchpad.

Whippet has no Dock icon — look for the whippet in the menu bar.

The app is ad-hoc signed when built locally, so Gatekeeper won't block it on the machine that built it.

## Tests

```sh
xcodebuild -scheme Whippet -derivedDataPath build/DerivedData.noindex/Whippet test
```
