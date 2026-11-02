# hyprmac — a Hyprland-style tiling window manager for macOS

Date: 2026-11-02
Status: approved 2026-11-02

## Intent

A personal tiling window manager for macOS that looks and feels like Hyprland. The user already tried OmniWM (currently running) and AeroSpace (installed, stock config) and didn't like how either looks or how they are configured. They want Hyprland's look, workspaces, a simple keymap, smooth animations, app shortcuts, and one config file that controls both behavior and looks.

Real Hyprland cannot run on macOS (it is a Linux Wayland compositor), so this is a from-scratch macOS app that imitates it within what macOS allows.

Single user, single machine: MacBook on Apple Silicon, macOS 26.5, sometimes with one external monitor. Not intended for distribution.

## Goals (v1)

1. Automatic tiling with the Hyprland **dwindle** layout, with rounded gradient borders and gaps.
2. **10 workspaces**, shared across 1–2 monitors, switched and targeted by keyboard.
3. **Smooth animations** for layout changes and workspace switches.
4. A **workspace bar**: a single floating island showing workspaces, in the "floating islands" style.
5. **One config file** in Hyprland-like syntax covering keybinds, app shortcuts, looks, animations, and window rules, applied live on save.
6. **App shortcuts**: a key focuses an app if it is running and launches it if not.

## Non-goals (v1)

- **Blur or transparency on other apps' windows.** Needs SIP partly disabled plus code injection into the Dock. The user agreed to leave it out of v1; the design must not make it impossible later.
- Disabling SIP for anything.
- An app launcher (Spotlight/Raycast covers it).
- Master layout (Hyprland's other layout). Dwindle only in v1; the layout engine should allow adding more later.
- Controlling macOS Spaces or native fullscreen. Windows in native macOS fullscreen are left alone.
- Distribution, auto-update, notarization.

## Anti-goals (builder's call: the user declined to name any, these are inferred)

- Hotkeys that feel laggy. Key press to focus/workspace change must feel instant; animations may trail behind, but input must never wait for them.
- Re-granting Accessibility/Screen Recording permission after every rebuild.
- Losing windows: a crash or quit must never leave windows parked off-screen.

## Decided with the user

### Look — "floating islands" (option B from the mockups)

- **Bar**: **one** floating pill-shaped island, centered at the top of each screen, showing **only workspaces**. Rounded, translucent with real macOS blur (the bar is our own window, so this works without SIP). The user explicitly dropped the clock and the status island (battery, volume, wifi): the macOS menu bar above already shows those. The mockup's left/right islands are not built.
- The bar sits **below the macOS menu bar**; the macOS menu bar stays visible as normal.
- **Windows**: roomy gaps between windows and around screen edges (defaults about 10px inner, 12px outer — builder may tune).
- **Focused window**: pastel gradient border, pink → purple → blue (Catppuccin Mocha `#f5c2e7` → `#cba6f7` → `#89b4fa`, 135°). **Other windows**: dim grey border.
- Everything above is configurable: colors, gradient angle, border width, corner radius, gaps, bar position, size and fonts.

### Workspaces

- Workspaces 1–10. `mod+1…0` switches, `mod+shift+1…0` sends the focused window there.
- One global pool of 10, with **no fixed home monitor** (the user chose this explicitly). Each monitor shows one workspace at a time.
- Switching to a **hidden** workspace opens it on the monitor that currently has focus.
- Switching to a workspace that is **visible on the other monitor** moves focus to that monitor; it does not pull the workspace over.
- At startup the built-in screen shows workspace 1 and the external screen shows workspace 6 (configurable). The old "1–5 / 6–10" split is gone: it was only a default.
- Unplugging the external monitor: its visible workspace becomes hidden on the remaining screen, windows intact. Replugging: the external screen shows the workspace it showed before, unless that one is visible on the built-in screen; then it shows the lowest-numbered hidden workspace (builder's call).
- `mod + shift + Tab` moves the current workspace to the other monitor (builder's call; the user had a similar binding in AeroSpace).
- Each monitor has its own bar, and its workspace island lists all 10. The workspace on this monitor is highlighted. The one shown on the other monitor is marked more subtly. Empty workspaces are dimmed. Workspaces with windows are shown normally.
- **macOS Spaces**: the user uses exactly one macOS Desktop per display. v1 assumes this and documents it as a requirement; extra Desktops are unsupported.
- Switching workspaces slides sideways by default.

### Layout — dwindle

Each new window splits the focused window in half, alternating side-by-side/stacked based on the shape of the space being split (Hyprland's dwindle behavior). `mod+T` flips the split direction of the focused window's split.

### Keymap (mod = ctrl-alt; user accepted this proposal)

| Keys | Action |
|---|---|
| mod + arrows / h j k l | focus in direction |
| mod + shift + arrows / h j k l | move window in direction |
| mod + 1…0 | go to workspace 1–10 |
| mod + shift + 1…0 | send window to workspace 1–10 |
| mod + shift + Tab | move current workspace to the other monitor |
| mod + minus / equal | shrink / grow focused window |
| mod + T | toggle split direction |
| mod + F | fill the tiling area (not macOS native fullscreen) |
| mod + V | toggle floating |
| mod + Q | close window |
| mod + left-drag / right-drag | move / resize with the mouse |
| mod + Return | open Ghostty |

All bindings live in the config; the table is the default config.

### App shortcuts

Config line: `bind = CTRL ALT, B, focusorlaunch, Safari`. If the app is running, focus its most recent window (switching workspace/monitor if needed); otherwise launch it. Plain `exec` also exists and always runs the command. The default config ships a couple of commented examples; the user will add their own.

### Config

- Hyprland-like syntax, e.g. `bind = CTRL ALT, Return, exec, open -na Ghostty`, `general { gaps_in = 10 }`, `animation = workspaces, 1, 4, default, slide`, `bezier = ...`, `windowrule = float, app:System Settings`.
- Reloads automatically on save.

## Builder's calls already made (change only with good reason)

- **Name**: `hyprmac` (working name). Config at `~/.config/hyprmac/hyprmac.conf`; if missing, write the default config there on first launch.
- **Platform**: Swift 6, AppKit, macOS 26+ only, Apple Silicon. Built with **Swift Package Manager** from the command line — the machine has the Command Line Tools (Swift 6.2.3) but **no Xcode**. The build script assembles the `.app` bundle (Info.plist, `LSUIElement = YES`) itself.
- **Code signing**: sign every build with the same self-signed code-signing certificate from the login keychain, not ad-hoc, so macOS keeps the Accessibility and Screen Recording grants across rebuilds. Document the one-time certificate setup.
- **App shape**: menu-bar-only app (no Dock icon). The menu has: reload config, open config, show config errors, pause/resume tiling, quit. Launch at login via `SMAppService`, toggle in the menu.
- **Permissions**: Accessibility (required; moving windows, event tap for hotkeys and mod+drag). Screen Recording (optional; only for animations). Without Screen Recording, everything works with instant (non-animated) changes. Explain permissions on first launch.
- **Window control**: public Accessibility API (`AXUIElement`, `AXObserver`) plus `NSWorkspace` app notifications. The private `_AXUIElementGetWindow` (to get a window ID) is allowed — it needs no SIP and every macOS WM uses it.
- **Hiding workspaces**: windows on hidden workspaces are parked just off-screen (AeroSpace's approach). On quit, pause, or crash recovery at next launch, all windows are brought back on-screen.
- **Animations — the snapshot trick**: when a layout change or workspace switch happens, put a borderless overlay window over the affected screen showing snapshots of the windows at their old positions, animate those snapshots to their new positions with Core Animation at the display's refresh rate, move the real windows to their final frames underneath at once, then remove the overlay. Snapshots come from ScreenCaptureKit. Cache a snapshot of each window when its workspace is hidden, so the workspace you switch to can slide in without capturing off-screen windows. Input is never blocked by an animation; a new action mid-animation jumps the current one to its end.
- **Animation config**: support Hyprland's `bezier` and `animation = <name>, <on/off>, <speed>, <curve>[, <style>]` for at least `windows` (move/resize from layout changes, plus a short pop-in for new windows), `workspaces` (`slide`, `fade`), and `border` (color fade on focus change).
- **Window corners**: macOS does not let us change other apps' window corner radius without SIP. The border is drawn *outside* the window, in the gap, as a per-window click-through overlay; its inner radius should match the system window corner radius on macOS 26 by default. "rounding" in the config controls the border's shape.
- **Default window rules**: dialogs, sheets, panels, and non-resizable windows float. Ship default rules for System Settings, Finder's info windows, Calculator, and similar.
- **Config errors**: on a bad config, keep running with the last good config and show the error (line number + message) in the menu and as a small notice on the bar.
- **Mouse focus**: the cursor jumps to the center of the other monitor when keyboard focus moves there (on by default, like the user's existing AeroSpace config). Focus-follows-mouse is a config option, off by default; not a v1 testing priority.
- **Conflicts**: OmniWM and Rectangle must not run at the same time (Rectangle uses ctrl-alt+arrows too). On launch, detect them and say so.

## Left to the builder

- Internal architecture, module boundaries, threading model.
- The exact config grammar beyond the examples above (stay close to Hyprland's wording where it maps cleanly).
- Whether hotkeys use a `CGEventTap` or Carbon `RegisterEventHotKey` (the tap is needed anyway for mod+drag).
- How the bar's blur is drawn (Liquid Glass vs `NSVisualEffectView`) — whatever looks closest to the islands mockup.
- Whether macOS's "Displays have separate Spaces" should be on or off — test both and document the recommendation.
- Test strategy. The dwindle layout engine and config parser should be pure Swift and unit-testable without a GUI. Verify whether XCTest / Swift Testing works with Command Line Tools only on this machine before relying on it.

## Success (builder's call)

The user can quit OmniWM, run hyprmac all day for a week, and:
- every window gets tiled with dwindle, with gradient border and gaps, on one or two monitors;
- all keymap actions and `focusorlaunch` work instantly;
- layout changes and workspace switches animate smoothly;
- the workspace island shows the correct workspaces on each monitor;
- editing the config changes looks/binds within a second, without restarting;
- quitting returns every window to the visible screen.
