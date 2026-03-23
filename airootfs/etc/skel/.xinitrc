#!/bin/sh
# X startup script

# Set up X resources
xrdb ~/.Xresources 2>/dev/null

# Start Openbox
exec openbox
