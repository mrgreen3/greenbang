# add nano as default editor
export EDITOR=vim
export TERMINAL=alacritty
export BROWSER=firefox

# Add scripts path safely
if [[ ":$PATH:" != *":$HOME/GB_Scripts:"* ]]; then
    export PATH="$PATH:$HOME/GB_Scripts"
fi

# Greenfile function to upload files to transfer.sh
# Usage: greenfile <filename>
# ideal for use in a VM to get output out of image
# without needing ssh, or other fancy tools
# Modified by MrGreen [mrgreen@archbang.org]
#
greenfile() {
  [[ -f $1 ]] || { notify-send "greenfile" "❌ File not found: $1"; return 1; }
  url=$(curl --silent --upload-file "$1" https://transfer.sh/"$(basename "$1")")
  notify-send "greenfile" "✅ Uploaded: $url"
  echo "$url"
}

alias ls='ls --color=auto'

# Package sizes
alias pkg_size="expac -H M '%m\t%n' | sort -h"


