# Bento

![Bento](docs/banner.png)

A set of macOS tools in a single menu bar app. The first module is a Hyprland-style tiling window manager: dwindle layout, 10 workspaces, gradient borders, a workspace island under the menu bar, animations, and configuration in Hyprland syntax that reloads on save.

## Requirements

- macOS 26 on Apple Silicon
- Command Line Tools with Swift 6.2 (`xcode-select --install`); Xcode is not needed
- one macOS desktop (Space) per display

## First run

1. **Signing certificate (once).** Keychain Access → Certificate Assistant → Create a Certificate…
   Name `bento-dev`, identity type *Self Signed Root*, certificate type *Code Signing*.
   Without it macOS asks for permissions again after every rebuild.
2. **Turn off other window managers:** quit OmniWM and Rectangle (Rectangle also uses ctrl-alt + arrows).
3. **Build the app:**

   ```bash
   scripts/build-app.sh
   ```

4. **Run it:**

   ```bash
   open build/bento.app
   ```

5. **Grant permissions** in System Settings → Privacy & Security:
   - **Accessibility** — needed for tiling, shortcuts, the window overview, the command palette and pasting from clipboard history. Without it Bento still runs: clipboard history (open it from the menu; picking an entry copies it), Keep Awake and Settings work. Tiling starts a few seconds after it is granted.
   - **Screen Recording** (optional) — everything works without it, just without animations and overview thumbnails. After granting it, quit Bento from its menu and start it again.

   Settings → Permissions shows what is granted, what each permission is for, and opens the right System Settings pane.

A grid icon appears in the menu bar. Its menu has: settings, config errors, pause, and quit; Launch at Login is in Settings → Behavior.

## Shortcuts (mod = ctrl-alt)

| Shortcut | Action |
|---|---|
| mod + ←/→ / h l | focus the neighbouring window; past the last window — previous/next workspace with windows on this display (never the other display) |
| mod + ↑/↓ / k j | focus the window above/below; at the edge — previous/next display (left to right, wrapping) |
| mod + shift + ←/→ / h l | swap the window with its neighbour; past the last window — move it to the previous/next workspace of this display (empty ones too, no wrapping) and follow it there |
| mod + shift + ↑/↓ / k j | swap the window with the one above/below; at the edge — move it to the previous/next display (left to right, wrapping) |
| mod + 1…9 | workspace 1–9 |
| mod + 0 | workspace 0 — the MacBook display (only with an external monitor connected) |
| mod + shift + 1…9 / 0 | send the window to workspace 1–9 / 0 |
| mod + shift + Tab | move the workspace to the other display (only without the built-in display, e.g. two external monitors) |
| mod + minus / equal | shrink / grow the window |
| mod + T | toggle split (side by side / stacked) |
| mod + F | fill the screen |
| mod + V | floating / tiled window |
| mod + Q | close the window |
| mod + drag / right button | move / resize with the mouse |
| mod + Return | new terminal window — Terminal by default, pick another app in Settings → Behavior → Terminal (`general:terminal`) |
| F3 (Mission Control) / ctrl + ↑ | overview of the windows of all workspaces on every display; arrows — select a window (also on the other display), Return / space / click — go to the window, Esc / F3 / click on the background — close. In an older `bento.conf` add `bind = , mission_control, overview` and `bind = CTRL, up, overview` |
| shift + cmd + C | clipboard history (last 200 entries + pinned): styled text, images, Finder files; each row shows the app icon and "5m ago", the preview on the right shows the app, first and last copy, and copy count. Typing filters (app name too), ↑/↓ selects, Return / click pastes into the app you were in, shift+Return pastes as plain text, ⌘1–⌘9 pastes the n-th entry, ⌥P pins, ⌥⌫ deletes, Esc closes. Passwords from password managers and tokens (`sk-…`, `ghp_…`, JWT, private keys) are shown as `••••••••` and never written to disk. "Clear Clipboard History" in the menu clears everything except pinned entries. Works while tiling is not paused. In an older `bento.conf` add `bind = SUPER SHIFT, c, clipboard` |

## Keep Awake

The "Keep Awake" item in the Bento menu keeps the display and the system from sleeping (like `caffeinate -d`) until you turn it off or quit Bento (or from launch: `clipboard:keep_awake_on_launch = true`). While it is on, the menu bar icon changes to a coffee cup.

## Two displays

When an external monitor is connected to the MacBook, the MacBook display permanently holds workspace 0 (ctrl-alt-0) and the external monitor holds workspaces 1–9 (ctrl-alt-1…9) — regardless of which display has focus. The MacBook island shows only 0, the monitor island 1–9. Without a monitor the MacBook has workspaces 1–9 and ctrl-alt-0 does nothing. After the monitor is disconnected, windows from workspace 0 go to the lowest empty workspace 1–9, and the MacBook shows the workspace that was on the monitor.

## Dialog windows

An app's auxiliary windows — settings, "About", modal windows, fixed-size windows and windows without a full-screen button — are not tiled: they float and appear centred over the app's most recently active window, on its workspace. A regular additional app window is still tiled. A window that should float but isn't detected can be added with a `windowrule = float, app:…` rule in the config.

## Configuration

The file `~/.config/bento/bento.conf` is created on first launch. Changes take effect a second after saving; a syntax error with its line number shows up in the menu and as "!" on the island.

Bento menu → **Settings…** (⌘,) opens the settings window with the tabs Appearance (gaps, borders, island, island transparency), Behavior (focus follows mouse, cursor, animations, launch at login), Shortcuts (shortcut recording, actions, `$mod`) and Clipboard (history size, Keep Awake on launch). The window writes changes straight to `bento.conf` — it changes only the affected line, comments and manual edits are kept. Window rules (`windowrule`), mouse bindings (`bindm`) and detailed animations are still set in the file.

```
clipboard {
    history_size = 200            # 10–2000 entries, pinned ones don't count
    keep_awake_on_launch = false  # Keep Awake on from Bento launch
}
```

App shortcut (switches to it, or launches it if it isn't running):

```
bind = $mod, b, focusorlaunch, Safari
```

### Appearance

```
general {
    gaps_in = 10                  # gap between windows
    gaps_out = 20 12 12 12        # margins from the screen edge: 1–4 numbers like CSS (top right bottom left)
    border_size = 2
    border_size_inactive = 1      # border of unfocused windows; unset = border_size, 0 = no border
    col.active_border = rgba(f5c2e7ff) rgba(89b4faff) 135deg
    col.inactive_border = rgba(585b70aa)   # the last pair of digits is the alpha
}

bar {
    icons = true                  # app icons next to the workspace number; false = numbers only
    height = 30
    font_size = 13
    margin_top = 4                # island gap from the menu bar
    margin_bottom = 4             # island gap from the windows
    padding = 15                  # gap between the numbers and the island edge; defaults to half of height
    rounding = 15                 # island corner radius; defaults to half of height
    col.background = rgba(1e1e2e80)        # glass tint; rgba(00000000) = none
    col.active = rgba(f5c2e7ff)            # current workspace
    col.other_monitor = rgba(cba6f7ff)     # outline of the workspace visible on the other display
    col.text = rgba(cdd6f4ff)
    col.text_active = rgba(1e1e2eff)
    col.text_empty = rgba(6c7086ff)
    col.error = rgba(f38ba8ff)
}
```

Colours are written only as `rgba(RRGGBBAA)` or `rgb(RRGGBB)` — `#` starts a comment.

## Quitting and window safety

Windows on hidden workspaces are "parked" off-screen. On quit, pause and `kill -TERM` they come back on screen; after a crash (`kill -9`) they come back on the next launch.

## Tests

```bash
scripts/test.sh
```

(`swift test` alone won't find the Testing framework without Xcode.)

## More

- [docs/SETUP.md](docs/SETUP.md) — system setup details
- [docs/MANUAL-CHECKS.md](docs/MANUAL-CHECKS.md) — list of manual tests; start with the "Anti-goal checks" section
- [docs/superpowers/specs/2026-11-02-bento-design.md](docs/superpowers/specs/2026-11-02-bento-design.md) — design
