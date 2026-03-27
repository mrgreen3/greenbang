# GreenBang login shell configuration

. $HOME/.bashrc

# Start labwc on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ] 2>/dev/null; then
    export XDG_CURRENT_DESKTOP=labwc
    export XDG_SESSION_TYPE=wayland
    exec labwc
fi
