# Bento guide

- [Shortcuts](#shortcuts)
- [Window overview](#window-overview)
- [Clipboard history](#clipboard-history)
- [Keep Awake](#keep-awake)
- [The menu bar menu](#the-menu-bar-menu)
- [Two displays](#two-displays)
- [Dialog windows](#dialog-windows)
- [Quitting and window safety](#quitting-and-window-safety)
- [Configuration](#configuration)

## Shortcuts

**mod** = <kbd>⌃ Control</kbd> + <kbd>⌥ Option</kbd>

### Focus and move

| Shortcut | Action |
|---|---|
| <kbd>mod</kbd> <kbd>←</kbd> <kbd>→</kbd> / <kbd>h</kbd> <kbd>l</kbd> | focus the neighbouring window; past the last window — previous/next workspace with windows on this display (never the other display) |
| <kbd>mod</kbd> <kbd>↑</kbd> <kbd>↓</kbd> / <kbd>k</kbd> <kbd>j</kbd> | focus the window above/below; at the edge — previous/next display (left to right, wrapping) |
| <kbd>mod</kbd> <kbd>⇧</kbd> <kbd>←</kbd> <kbd>→</kbd> / <kbd>h</kbd> <kbd>l</kbd> | swap the window with its neighbour; past the last window — move it to the previous/next workspace of this display (empty ones too, no wrapping) and follow it there |
| <kbd>mod</kbd> <kbd>⇧</kbd> <kbd>↑</kbd> <kbd>↓</kbd> / <kbd>k</kbd> <kbd>j</kbd> | swap the window with the one above/below; at the edge — move it to the previous/next display (left to right, wrapping) |
| <kbd>mod</kbd> + drag | move the window (left button) / resize it (right button) |

### Workspaces

| Shortcut | Action |
|---|---|
| <kbd>mod</kbd> <kbd>1</kbd>…<kbd>9</kbd> | go to workspace 1–9 |
| <kbd>mod</kbd> <kbd>0</kbd> | workspace 0 — the MacBook display (only with an external monitor connected) |
| <kbd>mod</kbd> <kbd>⇧</kbd> <kbd>1</kbd>…<kbd>9</kbd> / <kbd>0</kbd> | send the window to workspace 1–9 / 0 |
| <kbd>mod</kbd> <kbd>⇧</kbd> <kbd>Tab</kbd> | move the workspace to the other display (only without the built-in display, e.g. two external monitors) |

### Window

| Shortcut | Action |
|---|---|
| <kbd>mod</kbd> <kbd>-</kbd> / <kbd>=</kbd> | shrink / grow the window |
| <kbd>mod</kbd> <kbd>T</kbd> | toggle split (side by side / stacked) |
| <kbd>mod</kbd> <kbd>F</kbd> | fill the screen |
| <kbd>mod</kbd> <kbd>V</kbd> | floating / tiled window |
| <kbd>mod</kbd> <kbd>Q</kbd> | close the window |

### Tools

| Shortcut | Action |
|---|---|
| <kbd>mod</kbd> <kbd>Return</kbd> | new terminal window — Terminal by default, pick another app in Settings → Behavior → Terminal (`general:terminal`) |
| <kbd>mod</kbd> <kbd>Space</kbd> | command palette with Bento's commands |
| <kbd>F3</kbd> (Mission Control key) / <kbd>⌃</kbd> <kbd>↑</kbd> | [window overview](#window-overview) |
| <kbd>⇧</kbd> <kbd>⌘</kbd> <kbd>C</kbd> | [clipboard history](#clipboard-history) |

The command palette and clipboard history don't work while tiling is paused.

> [!TIP]
> Upgraded from an older version and a shortcut does nothing? New default bindings are not added to an existing `bento.conf`. Add the missing ones:
>
> ```ini
> bind = , mission_control, overview
> bind = CTRL, up, overview
> bind = SUPER SHIFT, c, clipboard
> bind = $mod, space, palette
> ```

## Window overview

<kbd>F3</kbd> or <kbd>⌃</kbd> <kbd>↑</kbd> shows the windows of all workspaces on every display.

- arrows — select a window (also on the other display)
- <kbd>Return</kbd> / <kbd>Space</kbd> / click — go to the window
- <kbd>Esc</kbd> / <kbd>F3</kbd> / click on the background — close

Thumbnails need the Screen Recording permission. Trackpad gestures still open the system Mission Control.

## Clipboard history

<kbd>⇧</kbd> <kbd>⌘</kbd> <kbd>C</kbd> opens the last 200 entries plus pinned ones: styled text, images and Finder files. Each row shows the source app's icon and how long ago it was copied; the preview on the right shows the app, the first and last copy and the copy count.

| Key | Action |
|---|---|
| typing | filter (app names too) |
| <kbd>↑</kbd> <kbd>↓</kbd> | select |
| <kbd>Return</kbd> / click | paste into the app you were in |
| <kbd>⇧</kbd> <kbd>Return</kbd> | paste as plain text |
| <kbd>⌘</kbd> <kbd>1</kbd>…<kbd>9</kbd> | paste the n-th entry |
| <kbd>⌥</kbd> <kbd>P</kbd> | pin / unpin |
| <kbd>⌥</kbd> <kbd>⌫</kbd> | delete |
| <kbd>Esc</kbd> | close |

Passwords from password managers and tokens (`sk-…`, `ghp_…`, JWT, private keys) are shown as `••••••••` and never written to disk. **Clear Clipboard History** in the menu removes everything except pinned entries.

Without the Accessibility permission the history opens from the menu and picking an entry only copies it.

## Keep Awake

**Keep Awake** in the Bento menu keeps the display and the system from sleeping (like `caffeinate -d`) until you turn it off or quit Bento. While it is on, the menu bar icon becomes a coffee cup. To turn it on at every launch set `clipboard:keep_awake_on_launch = true`.

## The menu bar menu

Settings, config errors and missing permissions, Pause, Keep Awake, Clipboard History, Clear Clipboard History and Quit. Launch at Login is in Settings → Behavior.

## Two displays

When an external monitor is connected to the MacBook, the MacBook display permanently holds workspace 0 (<kbd>mod</kbd> <kbd>0</kbd>) and the external monitor holds workspaces 1–9 — regardless of which display has focus. The MacBook island shows only 0, the monitor island 1–9.

Without a monitor the MacBook has workspaces 1–9 and <kbd>mod</kbd> <kbd>0</kbd> does nothing. After the monitor is disconnected, windows from workspace 0 go to the lowest empty workspace 1–9, and the MacBook shows the workspace that was on the monitor.

## Dialog windows

An app's auxiliary windows — settings, "About", modal windows, fixed-size windows and windows without a full-screen button — are not tiled: they float, centred over the app's most recently active window, on its workspace. A regular additional app window is still tiled. A window that should float but isn't detected can be added with a `windowrule = float, app:…` rule.

## Quitting and window safety

Windows on hidden workspaces are "parked" off-screen. On quit, pause and `kill -TERM` they come back on screen; after a crash (`kill -9`) they come back on the next launch.

## Configuration

`~/.config/bento/bento.conf` is created on first launch. Changes take effect a second after saving; a syntax error with its line number shows up in the menu and as "!" on the island.

**Settings…** in the Bento menu (<kbd>⌘</kbd> <kbd>,</kbd>) has the tabs Appearance (gaps, borders, island, island transparency), Behavior (focus follows mouse, cursor, animations, launch at login, terminal app), Shortcuts (shortcut recording, actions, `$mod`), Clipboard (history size, Keep Awake on launch), Permissions and About. It writes straight to `bento.conf` and changes only the affected line — comments and manual edits are kept. Window rules (`windowrule`), mouse bindings (`bindm`) and detailed animations are set in the file only.

Colours are written only as `rgba(RRGGBBAA)` or `rgb(RRGGBB)` — `#` starts a comment.

### Windows and borders

```ini
general {
    gaps_in = 10                  # gap between windows
    gaps_out = 20 12 12 12        # margins from the screen edge: 1–4 numbers like CSS (top right bottom left)
    border_size = 2
    border_size_inactive = 1      # border of unfocused windows; unset = border_size, 0 = no border
    col.active_border = rgba(f5c2e7ff) rgba(89b4faff) 135deg
    col.inactive_border = rgba(585b70aa)   # the last pair of digits is the alpha
    terminal = Terminal           # app opened by mod+Return, e.g. Ghostty or iTerm
}
```

### Workspace island

```ini
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

### Clipboard and Keep Awake

```ini
clipboard {
    history_size = 200            # 10–2000 entries, pinned ones don't count
    keep_awake_on_launch = false  # Keep Awake on from Bento launch
}
```

### App shortcuts

Switch to an app, or launch it if it isn't running:

```ini
bind = $mod, b, focusorlaunch, Safari
```

### Window rules

```ini
windowrule = float, app:^(System Settings|Calculator|Archive Utility)$
windowrule = float, app:^Finder$, title:Info$
```
