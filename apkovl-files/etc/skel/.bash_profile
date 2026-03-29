# GreenBang login shell configuration

. $HOME/.bashrc

# Start labwc on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export XDG_CURRENT_DESKTOP=labwc
    export XDG_SESSION_TYPE=wayland
    exec dbus-run-session labwc
fi
