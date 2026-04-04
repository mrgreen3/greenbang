# GreenBang live user profile
export XDG_RUNTIME_DIR=/run/user/1000
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=labwc

# Make a nicer prompt (sh-compatible, no bash-specific escapes)
PS1='\u@\h:\w\$ '

# Add ~/Scripts to $PATH
export PATH="$HOME/Scripts:$PATH"

# Start labwc on login from tty1
if [ "$(tty)" = "/dev/tty1" ] && command -v labwc >/dev/null 2>&1; then
    exec dbus-launch labwc
fi
