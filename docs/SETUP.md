# hyprmac setup

## 1. Create the signing certificate (once)

A stable signing identity keeps macOS from forgetting the granted permissions after every rebuild.

1. Open Keychain Access.
2. Menu: Keychain Access -> Certificate Assistant -> Create a Certificate...
3. Name: `hyprmac-dev`
4. Identity Type: Self Signed Root
5. Certificate Type: Code Signing
6. Create.

Without this certificate `scripts/build-app.sh` signs ad-hoc and macOS asks for permissions again after each build.

## 2. Build

```
scripts/build-app.sh
open build/hyprmac.app
```

## 3. Grant permissions

On launch hyprmac asks for both permissions; enable hyprmac under System Settings -> Privacy & Security:

- Accessibility (required; hyprmac does not tile until it is granted). Tiling starts within a couple of seconds of granting it.
- Screen Recording (optional; without it animations are off). hyprmac requests it at launch, which adds it to the Screen Recording list. macOS applies the grant only after a relaunch: quit hyprmac from its menu and open it again.

## 4. Desktops

Keep exactly one macOS Desktop (Space) per display. hyprmac manages its own workspaces 1-10 and cannot see macOS Spaces.

## 5. Other window managers

Quit OmniWM and Rectangle before using hyprmac; two window managers fight over window positions.

## 6. Config

`~/.config/hyprmac/hyprmac.conf` is created from the default on first launch. Saved changes apply within a second; syntax errors show up in the menu bar menu with the line number.
