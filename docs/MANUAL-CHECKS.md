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

## Task 10

- [ ] The focused window has the pink→purple→blue ring at 135° (pink at the top-left, blue at the bottom-right); other windows have the grey ring.
- [ ] Rings sit in the gaps between windows and line up with the macOS 26 window corners at `rounding = 16`. If they don't, measure the real corner radius and change the default in `DefaultConfig.swift` and `Config.swift` (update the Task 3 test).
- [ ] Changing focus cross-fades the ring colors over about 0.5 s; with `animations = 0` or `animation = border, 0` the switch is instant.
- [ ] Changing `col.active_border` in the config and saving updates the rings without a relaunch.
- [ ] A ctrl-alt left-drag of a tiled or floating window moves its ring with it live; resizing with ctrl-alt right-drag resizes the ring live.
- [ ] Floating windows' rings do not show above other windows that cover them.
- [ ] Workspace-parked (off-screen) windows have no ring; Pause Tiling removes all rings, Resume brings them back.

## Task 11

- [ ] One centered translucent island per monitor sits right under the macOS menu bar, showing 1–10 (the last label is "10").
- [ ] The workspace shown on a monitor is a filled pink pill with dark text on that monitor's bar; the workspace shown on the other monitor has a purple outline; empty workspaces are dimmed, others are normal light text.
- [ ] Switching workspaces with the hotkeys moves the highlights on both monitors' bars.
- [ ] Clicking a number switches to that workspace without activating hyprmac or stealing focus from the current app.
- [ ] Tiled windows never overlap the island; the island stays above other windows and appears on every Space, but not in Mission Control.
- [ ] Save `bar { height = 40 }`: the island resizes without a relaunch and the tiling area adjusts; save `enabled = false`: the island disappears and tiling grows into the space; `enabled = true` brings it back.
- [ ] Unplugging / replugging the external monitor removes / recreates its island; Pause Tiling hides the islands, Resume brings them back.

## Task 12

- [ ] Opening and closing windows animates the re-tiling smoothly at 120 Hz on the built-in display; a new window pops in (slightly scaled up and faded in), or, if it is too new to capture, fades in at the end. During the animation the final layout never shows through behind the moving snapshots (no full-size windows behind growing snapshots, no flickering slivers in the gaps).
- [ ] Switching from an empty workspace to a populated one never shows the new windows at once: windows with a cached snapshot slide in, others fade in at the end; switching to a workspace for the first time after launch fades its windows in at the end.
- [ ] The desktop (wallpaper, icons) and unmoved windows look unchanged during an animation; no hyprmac border or bar is doubled in it.
- [ ] ctrl-alt-1 → ctrl-alt-2 slides left, back slides right; clicking a number on the bar slides the same way.
- [ ] Mashing ctrl-alt-1/2 quickly never lags the keys or leaves an overlay behind; every window ends up at its final frame.
- [ ] Borders disappear during a transition and come back (at the right frames and colors) when it ends; Pause Tiling in the middle of an animation, then Resume: borders are back.
- [ ] With Screen Recording revoked, everything still works instantly (no animation).
- [ ] `animation = workspaces, 1, 3, smooth, fade` cross-fades after saving.
- [ ] `animations { enabled = false }` turns it all off.
- [ ] ctrl-alt mouse drags, config reloads and plugging/unplugging a monitor apply instantly without an overlay.
