#!/usr/bin/env bash
# Serves ManLoram to everyone on this network, against the local Supabase
# stack. Friends open the printed link; the game finds Supabase on this
# machine by itself, through the address they opened.
#
# Usage, from anywhere:  packages/manloram/tool/serve_lan.sh [port]
set -euo pipefail

port="${1:-8799}"
package_dir="$(cd "$(dirname "$0")/.." && pwd)"

# Prefer the usual home-network IPv4 address. On an IPv6-only network (some
# hotspots and offices) fall back to the stable global IPv6 address; 192.0.0.x
# is only a translation address there and unreachable for friends.
interface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
interface="${interface:-en0}"
ip="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
case "$ip" in 192.0.0.*) ip="" ;; esac
if [ -n "$ip" ]; then
  host="$ip"
else
  ip="$(ifconfig "$interface" | awk '/inet6/ && $NF == "secured" {print $2}' | head -1)"
  host="[$ip]"
fi
if [ -z "$ip" ]; then
  echo "No network address found. Connect to Wi-Fi or a LAN first." >&2
  exit 1
fi

if ! curl -sf -o /dev/null "http://127.0.0.1:54621/rest/v1/"; then
  echo "Local Supabase is not running. Start it with: supabase start" >&2
  exit 1
fi

echo "Building ManLoram for the web..."
(cd "$package_dir" && flutter build web >/dev/null)

echo
echo "  Share this link with friends on the same network:"
echo
echo "      http://$host:$port"
echo
echo "  Open it yourself too, in as many tabs as you like: every tab is a"
echo "  player. Stop with Ctrl+C."
echo

cd "$package_dir/build/web"
# "::" listens on IPv6 and IPv4 alike.
exec python3 -m http.server "$port" --bind ::
