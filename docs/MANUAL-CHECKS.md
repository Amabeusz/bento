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
