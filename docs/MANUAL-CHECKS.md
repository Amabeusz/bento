# Manual checks

Checks to run by hand after granting permissions (see docs/SETUP.md).

## Anti-goal checks (run first)

Put windows on workspaces 2 and 3 (ctrl-alt-shift-2 / -3), stay on workspace 1, then:

- [ ] Quit hyprmac from its menu: every window comes back on screen.
- [ ] Relaunch, park windows again, Pause Tiling: every window comes back on screen.
- [ ] Relaunch, park windows again, `kill -TERM <pid>`: every window comes back on screen.
- [ ] Relaunch, park windows again, `kill -9 <pid>`: the parked windows stay off-screen; launch hyprmac again: every window comes back on screen.
- [ ] Repeat all four with the external monitor connected (windows parked from both monitors).
- [ ] With a busy or frozen app (e.g. IntelliJ indexing, or an app beachballing): hyprmac hotkeys still react at once, and typing and clicking in other apps stays responsive.

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
- [ ] ctrl-alt + 1…9 switch to workspaces 1–9, ctrl-alt-0 to workspace 0 (MacBook screen, only with an external monitor); ctrl-alt-shift + the same keys send the focused window there.
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

- [ ] One centered translucent island per monitor sits right under the macOS menu bar, showing 1–9 (one screen) or "0" on the MacBook and 1–9 on the external monitor.
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

## Final review fixes

- [ ] Close a Ghostty window while another Ghostty window is on a different workspace: hyprmac stays on the current workspace (no jump), and the current workspace's next window gets focus and the active border.
- [ ] Same with Cmd-Q of an app that has a window on another workspace, and with Cmd-H: no jump to another workspace.
- [ ] Cmd-Tab (slowly, not right after closing a window) to an app whose window is on a hidden workspace: hyprmac switches to that workspace.
- [ ] Switch to an empty workspace and type: nothing reaches the previously focused (now parked) window; Finder (or, if Finder has windows, hyprmac) is active.
- [ ] Send the last window of a workspace to another workspace with ctrl-alt-shift-N and type: nothing reaches the sent window.
- [ ] Close the focused tiled window: the next window on that workspace gets keyboard focus and the active border together.
- [ ] Drag a tiled window by its title bar (no mod) and release: it snaps back into its tile. Resize a tiled window from its edge: it snaps back.
- [ ] An app that resizes its own tiled window (e.g. a terminal changing its size) snaps back once; a window with a minimum size bigger than its tile is left alone after one try (no flicker loop).
- [ ] Move or resize a floating window by its title bar or edge: it stays where you put it, also after the next layout change.
- [ ] ctrl-alt + right-drag a floating window very small: it stops at 100×60.
- [ ] Cmd-H an app with tiled windows: the rest re-tile with no hole; unhide it (Cmd-Tab or Dock): its windows tile again.
- [ ] An app that starts slowly (its windows don't tile at launch) tiles once you activate it.
- [ ] Break the config (`gaps_in = x`): each island grows a red "!" at its right end; hovering it shows "line N — message"; fixing the config removes it.
- [ ] With hyprmac running, turn hyprmac off under Accessibility, then toggle `follow_mouse` in the config and save (this recreates the event tap, which now fails): the menu shows "Hotkeys unavailable — check Accessibility permission". Turn it back on and toggle `follow_mouse` again: the item disappears.
- [ ] On first launch without Screen Recording, macOS prompts for it and hyprmac appears in System Settings -> Privacy & Security -> Screen Recording; after granting and relaunching, animations run.
- [ ] mod+drag and mod+right-drag still move/resize windows; a mod+click on the empty desktop does nothing; plain clicks and drags still reach apps.
- [ ] With `follow_mouse = 1`, focus still follows the mouse; toggling it in the config still takes effect without a relaunch.

## Pinned built-in workspace (two screens)

- [ ] With the external monitor connected: the built-in island shows only "0" and is narrow; the external island shows 1–9 with no empty space at its end.
- [ ] Focus on the built-in screen, press ctrl-alt-3: workspace 3 opens on the external monitor, focus and cursor move there, the built-in screen still shows workspace 0.
- [ ] Focus on the external monitor, press ctrl-alt-0: focus and cursor move to the built-in screen.
- [ ] On the laptop alone switch to workspace 3 with a window on it, then plug the monitor in: the built-in shows 0, the external shows workspace 3 with its window.
- [ ] ctrl-alt-shift-Tab with two screens does nothing.
- [ ] Unplug the monitor: workspaces 1–9 are reachable on the built-in screen and no window is lost.
- [ ] Lid closed / mirrored displays: note what happens (rule is off when there is no built-in screen in the list).

## Arrow past the last window switches workspace

- [ ] One screen, windows on workspaces 1 and 3: on 1, ctrl-alt-→ past the rightmost window slides to workspace 3; ctrl-alt-← past the leftmost window slides back to 1 (empty 2 skipped).
- [ ] On the highest non-empty workspace ctrl-alt-→ does nothing; ctrl-alt-↑/↓ never switch workspaces.
- [ ] Two screens: on the external monitor ctrl-alt-→ past the last window goes to its next non-empty workspace (1–9); the built-in screen stays on 0.

## Workspace 0 on the MacBook

- [ ] With the external monitor: MacBook shows workspace 0 (island "0"), monitor starts on 1 (island 1–9); ctrl-alt-0 focuses the MacBook.
- [ ] Laptop alone: island 1–9, ctrl-alt-0 and ctrl-alt-shift-0 do nothing.
- [ ] Put a window on 0, unplug the monitor: the window lands on the lowest empty workspace 1–9 (its badge is no longer dimmed), the MacBook shows the workspace the monitor was showing; nothing is lost.
- [ ] Plug the monitor back in: MacBook returns to 0, the monitor shows the workspace the MacBook was on.
- [ ] Focus a window on workspace 0, unplug the monitor: typing goes to a window visible on the MacBook (or nowhere if its workspace is empty), never to the hidden window from 0.

## App popups float over their app

- [ ] Safari ⌘, (Settings), Finder ⌘I (Get Info), an IntelliJ dialog (e.g. Settings): each opens floating, centered over that app's window, and the tiles don't move.
- [ ] A second normal window of the same app (e.g. ⌘N in Ghostty) still joins the tiles.
- [ ] A dialog bigger than the screen stays fully on screen.
- [ ] Java Swing menus (e.g. a menu-bar menu and a right-click menu) open where they were clicked, not centered over the window, and get no border.
- [ ] IntelliJ popups (the run-configuration picker, a right-click menu in the editor) open where they were invoked, every time including the first, not centered.
- [ ] A new normal window (Ghostty ⌘N) still joins the tiles right away (about 0.1 s later, no visible delay).

## App icons on the island

- [ ] Each non-empty workspace shows the icons of its apps next to its number, one per app (3 Ghostty windows = 1 icon), tiles first in layout order, then floating windows; empty workspaces show only the number.
- [ ] The active workspace's pill covers the number and its icons; clicking anywhere on a workspace (number or icon) switches to it; the island stays centered as it grows and shrinks.
- [ ] Opening / closing / moving a window (mod+shift+N) updates the icons at once; the red "!" still sits at the right end.
- [ ] Save `bar { icons = false }`: the island goes back to numbers only, without a relaunch.

## Native tabs share one tile

- [ ] Ghostty ⌘T: the new tab takes the same tile, no empty tile appears next to it; switching tabs doesn't change the layout.
- [ ] ⌘W on a tab leaves the tile to the remaining tab; closing the last tab removes the tile.
- [ ] Same with Safari tabs.
