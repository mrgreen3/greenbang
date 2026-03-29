#!/bin/bash
# GreenBang repository setup

echo "Checking network connection..."
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "No network connection detected."
    echo "Please connect to a network and try again."
    exit 1
fi

echo ""
echo "Select region:"
echo "1) Europe"
echo "2) North America"
echo "3) Asia Pacific"
echo "4) Default CDN (geo-aware, recommended)"
echo ""
read -p "Choice [4]: " choice

case "$choice" in
    1) MIRROR="https://mirrors.ircam.fr/pub/alpine" ;;
    2) MIRROR="https://mirrors.edge.kernel.org/alpine" ;;
    3) MIRROR="https://mirror.aarnet.edu.au/pub/alpine" ;;
    *) MIRROR="https://dl-cdn.alpinelinux.org/alpine" ;;
esac

doas tee /etc/apk/repositories <<EOF
$MIRROR/v3.23/main
$MIRROR/v3.23/community
EOF

doas apk update && echo "Done. Repositories configured." || echo "Update failed — check mirror availability."
