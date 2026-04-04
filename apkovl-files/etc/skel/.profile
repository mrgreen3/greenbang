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

# TODO: Fix PS1 color codes for ash/sh
# Current PS1 works but has no colors. These alternatives use actual ANSI escape sequences.
# Uncomment one to test - they should work in Alpine ash without bash-specific wrappers.
#
# Option 1: Using \033 notation (green user@host, blue path)
# PS1='\033[32m\u@\h\033[0m:\033[34m\w\033[0m\$ '
#
# Option 2: Using \e notation (same as above, alternate syntax)
# PS1='\e[32m\u@\h\e[0m:\e[34m\w\e[0m\$ '
#
# Color reference:
# \e[32m = green, \e[34m = blue, \e[0m = reset all attributes
