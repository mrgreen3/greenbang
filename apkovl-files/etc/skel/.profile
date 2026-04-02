# GreenBang live user profile
export XDG_RUNTIME_DIR=/run/user/1000
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=labwc

# Start labwc on login from tty1
if [ "$(tty)" = "/dev/tty1" ] && command -v labwc >/dev/null 2>&1; then
    exec dbus-launch labwc
fi
