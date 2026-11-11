# Manual checks

Checks to run by hand after granting permissions (see docs/SETUP.md).

## Anti-goal checks (run first)

Put windows on workspaces 2 and 3 (ctrl-alt-shift-2 / -3), stay on workspace 1, then:

- [ ] Quit bento from its menu: every window comes back on screen.
- [ ] Relaunch, park windows again, Pause Tiling: every window comes back on screen.
- [ ] Relaunch, park windows again, `kill -TERM <pid>`: every window comes back on screen.
- [ ] Relaunch, park windows again, `kill -9 <pid>`: the parked windows stay off-screen; launch bento again: every window comes back on screen.
- [ ] Repeat all four with the external monitor connected (windows parked from both monitors).
- [ ] With a busy or frozen app (e.g. IntelliJ indexing, or an app beachballing): bento hotkeys still react at once, and typing and clicking in other apps stays responsive.

## Task 7

- [ ] `scripts/build-app.sh && open build/bento.app` shows a grid icon in the menu bar.
- [ ] `~/.config/bento/bento.conf` is created on first launch.
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
- [ ] Launch bento while a window is in native fullscreen; leave fullscreen: the window joins the layout.
- [ ] Minimize a tiled window: the rest re-tile. Restore it from the Dock: it tiles again.

## Task 9

- [ ] ctrl-alt + ←/→ and ctrl-alt + h/l move focus left/right between tiled windows (and to the previous/next workspace at the edge); ctrl-alt + ↑/↓ and ctrl-alt + k/j move focus to the window above/below, and to the other monitor at the edge.
- [ ] ctrl-alt-shift + arrows and ctrl-alt-shift + h/j/k/l move the focused window in that direction (at the edge: ←/→ to the previous/next workspace of the same monitor, ↑/↓ to the other monitor).
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
- [ ] Clicking a number switches to that workspace without activating bento or stealing focus from the current app.
- [ ] Tiled windows never overlap the island; the island stays above other windows and appears on every Space, but not in Mission Control.
- [ ] Save `bar { height = 40 }`: the island resizes without a relaunch and the tiling area adjusts; save `enabled = false`: the island disappears and tiling grows into the space; `enabled = true` brings it back.
- [ ] Unplugging / replugging the external monitor removes / recreates its island; Pause Tiling hides the islands, Resume brings them back.

## Task 12

- [ ] Opening and closing windows animates the re-tiling smoothly at 120 Hz on the built-in display; a new window pops in (slightly scaled up and faded in), or, if it is too new to capture, fades in at the end. During the animation the final layout never shows through behind the moving snapshots (no full-size windows behind growing snapshots, no flickering slivers in the gaps).
- [ ] Switching from an empty workspace to a populated one never shows the new windows at once: windows with a cached snapshot slide in, others fade in at the end; switching to a workspace for the first time after launch fades its windows in at the end.
- [ ] The desktop (wallpaper, icons) and unmoved windows look unchanged during an animation; no bento border or bar is doubled in it.
- [ ] ctrl-alt-1 → ctrl-alt-2 slides left, back slides right; clicking a number on the bar slides the same way.
- [ ] Mashing ctrl-alt-1/2 quickly never lags the keys or leaves an overlay behind; every window ends up at its final frame.
- [ ] Borders disappear during a transition and come back (at the right frames and colors) when it ends; Pause Tiling in the middle of an animation, then Resume: borders are back.
- [ ] With Screen Recording revoked, everything still works instantly (no animation).
- [ ] `animation = workspaces, 1, 3, smooth, fade` cross-fades after saving.
- [ ] `animations { enabled = false }` turns it all off.
- [ ] ctrl-alt mouse drags, config reloads and plugging/unplugging a monitor apply instantly without an overlay.

## Final review fixes

- [ ] Close a Ghostty window while another Ghostty window is on a different workspace: bento stays on the current workspace (no jump), and the current workspace's next window gets focus and the active border.
- [ ] Same with Cmd-Q of an app that has a window on another workspace, and with Cmd-H: no jump to another workspace.
- [ ] Cmd-Tab (slowly, not right after closing a window) to an app whose window is on a hidden workspace: bento switches to that workspace.
- [ ] Switch to an empty workspace and type: nothing reaches the previously focused (now parked) window; Finder (or, if Finder has windows, bento) is active.
- [ ] Send the last window of a workspace to another workspace with ctrl-alt-shift-N and type: nothing reaches the sent window.
- [ ] Close the focused tiled window: the next window on that workspace gets keyboard focus and the active border together.
- [ ] Drag a tiled window by its title bar (no mod) and release: it snaps back into its tile. Resize a tiled window from its edge: it snaps back.
- [ ] An app that resizes its own tiled window (e.g. a terminal changing its size) snaps back once; a window with a minimum size bigger than its tile is left alone after one try (no flicker loop).
- [ ] Move or resize a floating window by its title bar or edge: it stays where you put it, also after the next layout change.
- [ ] ctrl-alt + right-drag a floating window very small: it stops at 100×60.
- [ ] Cmd-H an app with tiled windows: the rest re-tile with no hole; unhide it (Cmd-Tab or Dock): its windows tile again.
- [ ] An app that starts slowly (its windows don't tile at launch) tiles once you activate it.
- [ ] Break the config (`gaps_in = x`): each island grows a red "!" at its right end; hovering it shows "line N — message"; fixing the config removes it.
- [ ] With bento running, turn bento off under Accessibility, then toggle `follow_mouse` in the config and save (this recreates the event tap, which now fails): the menu shows "Hotkeys unavailable — check Accessibility permission". Turn it back on and toggle `follow_mouse` again: the item disappears.
- [ ] On first launch without Screen Recording, macOS prompts for it and bento appears in System Settings -> Privacy & Security -> Screen Recording; after granting and relaunching, animations run.
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
- [ ] Two screens: on the external monitor ctrl-alt-→ past the last window goes to its next non-empty workspace (1–9), never to the MacBook; the built-in screen stays on 0.

## Up/down arrows switch monitors at the edge

- [ ] External monitor left of the MacBook: on the MacBook ctrl-alt-↑ moves focus and cursor to the external monitor (its last focused window); ctrl-alt-↓ goes back; ↑ on the external and ↓ on the MacBook also switch (wrap-around).
- [ ] Three windows (one left, two stacked on the right): from the top-right window ctrl-alt-↓ focuses the one below it; ctrl-alt-↓ again switches to the other monitor.
- [ ] After ctrl-alt-↑ to the external monitor, ctrl-alt-→ past its last window switches the external monitor's workspace; the MacBook stays on 0.
- [ ] Laptop alone: ctrl-alt-↑/↓ do nothing.

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
- [ ] Safari tab hover previews (hover a tab, then move to the next one) stay under the hovered tab, are never centered over the window, and get no border.

## App icons on the island

- [ ] Each non-empty workspace shows the icons of its apps next to its number, one per app (3 Ghostty windows = 1 icon), tiles first in layout order, then floating windows; empty workspaces show only the number.
- [ ] The active workspace's pill covers the number and its icons; clicking anywhere on a workspace (number or icon) switches to it; the island stays centered as it grows and shrinks.
- [ ] Opening / closing / moving a window (mod+shift+N) updates the icons at once; the red "!" still sits at the right end.
- [ ] Save `bar { icons = false }`: the island goes back to numbers only, without a relaunch.

## Native tabs share one tile

- [ ] Ghostty ⌘T: the new tab takes the same tile, no empty tile appears next to it; switching tabs doesn't change the layout.
- [ ] ⌘W on a tab leaves the tile to the remaining tab; closing the last tab removes the tile.
- [ ] Same with Safari tabs.

## Windows keep their workspaces across a restart

- [ ] Spread windows over three workspaces (mod+shift+N), quit bento from the menu, start it again: every window is back on its workspace and the islands show the same icons as before.
- [ ] Same after `kill <pid>` of bento, and after Pause / Resume in the menu.
- [ ] Quit an app and reopen it while bento runs: its new window lands on the visible workspace (memory follows the window, not the app).
- [ ] `~/Library/Application Support/bento/workspaces.json` exists; `~/.config/bento/` gets no new files and the config is not reloaded on window moves.

## Windows return to their workspace after an app reloads them

- [ ] Claude windows on workspaces 2 and 6, you are on 1: cmd+R in a Claude window (reload) — afterwards the windows are back on 2 and 6, workspace 1 shows what it showed before, focus stays on 1.
- [ ] Close a window on the visible workspace and wait more than 5 s before opening a new window of the same app: the new window opens on the visible workspace.
- [ ] Minimize a window and restore it from the Dock, or hide its app with cmd+H: no other window of that app opened right after jumps to the minimized window's workspace.

## Window overview on F3

- [ ] F3 opens the overview on every screen and Mission Control does not open; each screen shows the windows of all its non-empty workspaces (MacBook: workspace 0; external: 1–9) as screenshots in a grid, each with its workspace number.
- [ ] Windows of hidden workspaces show their content, not a blank image; thumbnails are much larger than in Mission Control.
- [ ] Clicking a thumbnail closes the overview, switches to that window's workspace and focuses it; Esc, F3 again or a click on the background just close it.
- [ ] Without Screen Recording each thumbnail shows the app icon and window title instead of a screenshot.
- [ ] ctrl+↑ opens and closes the same overview and Mission Control does not open.
- [ ] The focused window's thumbnail has an accent ring when the overview opens; arrows move the ring to the nearest thumbnail in that direction, also onto the other screen; Return or space goes to the ringed window.
- [ ] Text in the thumbnails is sharp on both the Retina and the external screen.
- [ ] Above each thumbnail: the app icon and the window title (the active tab in Safari, Chrome, Ghostty), cut with "…" at the thumbnail's width; a window without a title shows the app name; titles never overlap the thumbnail above.

## Moving windows with mod+shift+arrows follows the focus axes

- [ ] One window on workspace 1 of the external screen: mod+shift+→ takes it to workspace 2 and shows workspace 2 with the window focused; mod+shift+← brings it back; at workspace 9 (→) or 1 (←) nothing happens.
- [ ] mod+shift+→/← never sends a window to the other screen; on the MacBook (workspace 0) they do nothing past the last window.
- [ ] mod+shift+↓/↑ past the last window moves it to the other screen's visible workspace, focus and cursor follow; with windows stacked (1 | 2/3) the first press swaps with the window below.

## Clipboard history

- [ ] Copy three different texts in any apps, press shift+cmd+C: a panel opens in the middle of the screen with the mouse, newest text on top, the app you were in stays focused (its menu bar stays).
- [ ] Copying a text that is already in the history moves it to the top instead of adding a second copy.
- [ ] Typing filters the list (case does not matter); ↑/↓ move the highlight and stop at the first/last row; with more than 14 entries the list scrolls with the highlight.
- [ ] Return closes the panel and pastes the highlighted text into the app you were in; the text is also on the clipboard (cmd+V pastes it again) and is now at the top of the history; its copy count in the preview did not grow.
- [ ] Clicking a row pastes it the same way; Esc, shift+cmd+C again, or a click in another window close the panel without pasting.
- [ ] A password copied from a password manager (1Password, Keychain Access "Copy Password") shows up as `••••••••` in the list and the preview, does not match a search for its text, pastes the real password, and is gone from the history after restarting bento (not in `clipboard.json`).
- [ ] A token copied from a terminal (`ghp_…`, `sk-…`, a JWT) is masked the same way; an ordinary sentence is not.
- [ ] Quit bento and start it again: the history is still there (`~/Library/Application Support/bento/clipboard.json`).
- [ ] After Pause Tiling, shift+cmd+C does nothing (decision D2 A); after Resume it works again.
- [ ] First start after the update: the history from the old version (plain texts) is still there, in the same order.
- [ ] Each row shows the source app's icon, the text, how long ago it was copied ("now", "5m", "3h", "2d") and ⌘1–⌘9 on the first nine rows; the preview on the right shows the full text and App / First copied / Last copied / Copies; copying the same text again raises Copies and keeps First copied.
- [ ] Copy an image (cmd+ctrl+shift+4 screenshot, "Copy Image" in Preview): the row shows a thumbnail and "Image W×H", the preview shows it large, Return pastes the image (e.g. into Notes).
- [ ] Copy two files in Finder: the row shows the file icon and "name + 1 more", the preview lists the paths, Return in a Finder window pastes copies of the files; typing part of a file name finds it.
- [ ] Copy styled text (Safari, Notes): Return pastes it with styles into Notes / TextEdit, shift+Return pastes plain text.
- [ ] Preview of text: a short text (e.g. `git push origin main`) is large and centered; a longer one is smaller from the top; a link (`https://jira.example.com/jira/browse/ABC-123`) shows a "Link" chip, the domain large and the path below; `#378ADD` or `rgb(55, 138, 221)` shows a big color swatch with the value and R G B A; `{"a":1,"b":[1,2]}` shows indented JSON; a masked secret stays `••••••••`.
- [ ] Under the details of every preview: ⏎ Paste, ⇧⏎ Paste as plain text, ⌥P Pin (Unpin on a pinned row), ⌥⌫ Delete.
- [ ] In the panel: ⌘3 pastes the third row; ⌥P pins the highlighted row (pin icon, row jumps to the top, no "π" in the search field), ⌥P again unpins it; ⌥⌫ removes the highlighted row.
- [ ] Pinned rows stay on top after new copies; menu → Clear Clipboard History removes everything except pinned rows (also from `clipboard.json` and `~/Library/Application Support/bento/clipboard/`).

## Keep Awake

- [ ] Menu → Keep Awake: the item gets a ✓, the menu bar icon becomes a cup, `pmset -g assertions` lists `PreventUserIdleDisplaySleep` named "bento Keep Awake".
- [ ] Menu → Keep Awake again: no ✓, grid icon back, the assertion is gone from `pmset -g assertions`.
- [ ] With Keep Awake on, Quit bento and separately `kill <pid>` of bento: in both cases the assertion is gone afterwards.
- [ ] With Keep Awake on, the screen does not dim or sleep after the display-sleep time from System Settings.
