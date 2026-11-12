# Bento setup

## 1. Create the signing certificate (once)

A stable signing identity keeps macOS from forgetting the granted permissions after every rebuild.

1. Open Keychain Access.
2. Menu: Keychain Access -> Certificate Assistant -> Create a Certificate...
3. Name: `bento-dev`
4. Identity Type: Self Signed Root
5. Certificate Type: Code Signing
6. Create.

Without this certificate `scripts/build-app.sh` signs ad-hoc and macOS asks for permissions again after each build.

## 2. Build

```
scripts/build-app.sh
open build/bento.app
```

## 3. Grant permissions

On launch Bento asks for both permissions; enable Bento under System Settings -> Privacy & Security:

- Accessibility (needed for tiling, shortcuts, overview, palette and pasting; without it Bento opens Settings → Permissions and keeps clipboard history, Keep Awake and Settings working). Tiling starts within a couple of seconds of granting it.
- Screen Recording (optional; without it animations are off). Bento requests it at launch, which adds it to the Screen Recording list. macOS applies the grant only after a relaunch: quit Bento from its menu and open it again.

## 4. Desktops

Keep exactly one macOS Desktop (Space) per display. Bento manages its own workspaces 0–9 (0 = MacBook screen when an external monitor is connected, 1–9 otherwise) and cannot see macOS Spaces.

## 5. Other window managers

Quit OmniWM and Rectangle before using Bento; two window managers fight over window positions.

## 6. Config

`~/.config/bento/bento.conf` is created from the default on first launch. Saved changes apply within a second; syntax errors show up in the menu bar menu with the line number.

## 7. Tests

```
scripts/test.sh
```

`swift test` alone won't find the Testing framework without Xcode.

## 8. Release

`scripts/release.sh` builds the app and packs it as `build/Bento.zip` (with `Bento.app` inside) for a GitHub release. It refuses to run without the `bento-dev` certificate: every release must be signed with the same certificate, or users have to grant permissions again after updating.
