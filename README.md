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

Then either open it in Xcode and press Run:

```sh
open Whippet.xcodeproj
```

or build from the command line and install it:

```sh
xcodebuild -scheme Whippet -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Whippet.app /Applications/
open /Applications/Whippet.app
```

Whippet has no Dock icon — look for the whippet in the menu bar.

The app is ad-hoc signed when built locally, so Gatekeeper won't block it on the machine that built it.

## Tests

```sh
xcodebuild -scheme Whippet test
```
