public let defaultConfigText = """
# hyprmac config — saved changes apply immediately
$mod = CTRL ALT

general {
    gaps_in = 10
    gaps_out = 12
    border_size = 2
    col.active_border = rgba(f5c2e7ff) rgba(cba6f7ff) rgba(89b4faff) 135deg
    col.inactive_border = rgba(585b70aa)
}

decoration {
    rounding = 16
}

bar {
    enabled = true
    height = 30
    font_size = 13
}

input {
    follow_mouse = 0
}

cursor {
    warp_to_monitor = true
}

animations {
    enabled = true
    bezier = smooth, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 3, smooth
    animation = workspaces, 1, 3, smooth, slide
    animation = border, 1, 5, default
}

workspace = 1, monitor:builtin, default:true
workspace = 6, monitor:external, default:true

bind = $mod, left, movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up, movefocus, u
bind = $mod, down, movefocus, d
bind = $mod, h, movefocus, l
bind = $mod, l, movefocus, r
bind = $mod, k, movefocus, u
bind = $mod, j, movefocus, d
bind = $mod SHIFT, left, movewindow, l
bind = $mod SHIFT, right, movewindow, r
bind = $mod SHIFT, up, movewindow, u
bind = $mod SHIFT, down, movewindow, d
bind = $mod SHIFT, h, movewindow, l
bind = $mod SHIFT, l, movewindow, r
bind = $mod SHIFT, k, movewindow, u
bind = $mod SHIFT, j, movewindow, d
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9
bind = $mod, 0, workspace, 10
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9
bind = $mod SHIFT, 0, movetoworkspace, 10
bind = $mod SHIFT, tab, movecurrentworkspacetomonitor
bind = $mod, minus, resizeactive, -50 -50
bind = $mod, equal, resizeactive, 50 50
bind = $mod, t, togglesplit
bind = $mod, f, fullscreen
bind = $mod, v, togglefloating
bind = $mod, q, killactive
bind = $mod, return, exec, open -na Ghostty

# app shortcuts: focus the app if running, launch it if not
# bind = $mod, b, focusorlaunch, Safari
# bind = $mod, i, focusorlaunch, IntelliJ IDEA

bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

windowrule = float, app:^(System Settings|Calculator|Archive Utility)$
windowrule = float, app:^Finder$, title:Info$
"""
