# Manual checks

Checks to run by hand after granting permissions (see docs/SETUP.md).

## Task 7

- [ ] `scripts/build-app.sh && open build/hyprmac.app` shows a grid icon in the menu bar.
- [ ] `~/.config/hyprmac/hyprmac.conf` is created on first launch.
- [ ] Break the config (`gaps_in = x`): the menu shows "Config Error: line N - message" within a second.
- [ ] Fix the config: the error disappears from the menu.
- [ ] With OmniWM (or Rectangle) running at launch, an alert names it.
- [ ] Without Accessibility permission, an alert explains it and nothing tiles; after granting, tiling starts within about 2 seconds.
- [ ] Without Screen Recording permission, the menu shows "Animations off (no Screen Recording)".
- [ ] Launch at Login toggles the checkmark; Pause Tiling / Resume Tiling toggles the label.

## Task 8

- [ ] Open 3 Ghostty windows: they tile in the dwindle layout matching the mockup, 10 px gaps between windows, 12 px from the screen edges, with the bar area at the top left free.
- [ ] Close one Ghostty window: the remaining windows re-tile.
- [ ] Open System Settings: it floats (not tiled).
- [ ] Plug and unplug the external monitor: no window is lost (every window is still reachable on a visible screen).
- [ ] `kill -9` the app with nothing parked, relaunch: the layout is rebuilt.
- [ ] Put a tiled Ghostty window into native fullscreen: the other windows re-tile to fill its space. Leave fullscreen: it tiles again.
- [ ] Launch hyprmac while a window is in native fullscreen; leave fullscreen: the window joins the layout.
- [ ] Minimize a tiled window: the rest re-tile. Restore it from the Dock: it tiles again.

## Task 9

- [ ] ctrl-alt + arrows and ctrl-alt + h/j/k/l move focus left/down/up/right between tiled windows (and across monitors at the edge).
- [ ] ctrl-alt-shift + arrows and ctrl-alt-shift + h/j/k/l move the focused window in that direction (and across monitors at the edge).
- [ ] ctrl-alt + 1…9, 0 switch to workspaces 1–10; ctrl-alt-shift + 1…9, 0 send the focused window to workspaces 1–10.
- [ ] With two monitors, ctrl-alt-shift-tab moves the current workspace to the other monitor.
- [ ] ctrl-alt + minus / equal shrink / grow the focused window; holding the key keeps resizing.
- [ ] ctrl-alt + T toggles the split direction, F fills the tiling area (and back), V toggles floating, Q closes the focused window.
- [ ] ctrl-alt-Return opens a new Ghostty window.
- [ ] Add `bind = $mod, b, focusorlaunch, Safari`: with Safari not running the bind launches it; switch to another workspace, press it again: it jumps to Safari's workspace and focuses Safari.
- [ ] Bind a non-existent key (`bind = $mod, foo, togglesplit`): the menu shows "Config Error: unknown key 'foo'"; remove it and the message disappears.
- [ ] Modifiers are exact: ctrl-alt-shift-T does not toggle the split; keys without the mod reach the app normally.
- [ ] ctrl-alt + left-drag on a floating window moves it live; on a tiled window it follows the cursor and, released over another tiled window, swaps with it (released over empty space it snaps back).
- [ ] ctrl-alt + right-drag resizes a floating window live, and resizes a tiled window's split live.
- [ ] Plain clicks and drags (without the mod) reach apps normally.
- [ ] Switching to a workspace shown on the other monitor warps the cursor to that monitor's center.
- [ ] With `follow_mouse = 1`, moving the cursor over another window focuses it; save `follow_mouse = 0` and it stops (no relaunch needed), save 1 again and it resumes.
- [ ] Pause Tiling: the hotkeys and mod+drag pass through to apps; Resume: they work again.
- [ ] Keys feel instant, including during animations.
