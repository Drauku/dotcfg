#!/bin/bash
# ~/.local/bin/remote-qbit
# Universal script to send magnet links to a remote qBittorrent WebUI using the API
# Optimized for Reverse Proxies (Caddy/OPNsense) and Split-Horizon DNS

# --- CONFIGURATION ---
# The raw hostname for the connectivity check (Ping/NC)
WEB_URL="qbit.drauku.net"
USERNAME="admin"
PASSWORD="1qaz2wsx3edc"
# ---------------------

QBIT_URL="https://$WEB_URL"
QBIT_PORT=9090
MAGNET_LINK="$1"

# DEBUG: Check DNS resolution before doing anything else
# getent hosts looks at /etc/hosts AND your DNS server
RESOLVED_IP=$(getent hosts "$WEB_URL" | awk '{print $1}')

if [ -z "$RESOLVED_IP" ]; then
    notify-send "qBit DNS Error" "Could not resolve $WEB_URL at all." --urgency=critical
    exit 1
fi

# If it shows a Cloudflare IP (e.g., 172.67.x.x or 104.21.x.x),
# the script will fail because of NAT Loopback.
notify-send "DNS Debug" "$WEB_URL resolved to: $RESOLVED_IP"

# 1. Pre-flight Check: Is the server reachable?
# We use the absolute path to ping to ensure it works when called by Firefox
# if ! /usr/bin/ping -c 1 -W 1 "$WEB_URL" &>/dev/null; then
#     notify-send "qBit Error" "Server $WEB_URL is unreachable on LAN." --urgency=critical
#     # Debug: Show what IP the script resolved
#     notify-send "DNS Debug" "$WEB_URL resolved to $(/usr/bin/dig +short $WEB_URL)"
#     exit 1
# fi
# if ! nc -z -w 1 "$SERVER_IP" $QBIT_PORT; then
#     notify-send "qBit Error" "Port $QBIT_PORT on $SERVER_IP is closed." --urgency=critical
#     exit 1
# fi

# 2. Login and get Authentication Cookie
# We use an internal variable to store headers for SID extraction
login_response=$(curl -s -i --header "Referer: $QBIT_URL" \
    --data "username=$USERNAME&password=$PASSWORD" \
    "$QBIT_URL/api/v2/auth/login")

# Extract SID (Session ID) using a robust regex for the Cookie header
SID=$(echo "$login_response" | grep -o 'SID=[^;]*' | head -1)

if [ -z "$SID" ]; then
    notify-send "qBit Error" "Login failed. Check credentials or Caddy config." --urgency=critical
    exit 1
fi

# 3. Add the Torrent
# --data-urlencode handles the special characters in magnet links correctly
add_request=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST --header "Referer: $QBIT_URL" \
    --cookie "$SID" \
    --data-urlencode "urls=$MAGNET_LINK" \
    "$QBIT_URL/api/v2/torrents/add")

# 4. Feedback Loop
if [ "$add_request" == "200" ]; then
    notify-send "Torrent Added" "Successfully sent to $WEB_URL" --icon=emblem-downloads
else
    notify-send "qBit Error" "API returned error code: $add_request" --urgency=critical
fi
