#!/bin/sh
# Build an ad and tracker blocking hosts file from the blocklists in `sources`, minus the hosts in
# `whitelist`, after your own entries in `myhosts`, and install it as /etc/hosts.
#
#   sudo ./update-hosts.sh            build and install, then flush the DNS cache
#   ./update-hosts.sh -o FILE         build into FILE only (a dry run; no sudo needed)
#   sudo ./update-hosts.sh --restore  put back the hosts file from before the first install
#
# sources, whitelist and myhosts live next to this script; see the .example files.
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
HOSTS=/etc/hosts
BACKUP=/etc/hosts.before-GTShostsUpdate
MIN_ENTRIES=1000   # fewer blocked hosts than this means a download went wrong: stop

out=$HOSTS
case "${1:-}" in
  -o) out=${2:?usage: $0 -o FILE} ;;
  --restore)
    [ -f "$BACKUP" ] || { echo "No backup at $BACKUP" >&2; exit 1; }
    cp "$BACKUP" "$HOSTS"
    echo "Restored $HOSTS from $BACKUP"
    restored=1 ;;
  "") ;;
  *) sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 2 ;;
esac

flush_dns() {
  case $(uname) in
    Darwin) dscacheutil -flushcache; killall -HUP mDNSResponder ;;
    Linux) command -v resolvectl >/dev/null && resolvectl flush-caches || true ;;
  esac
}

if [ -n "${restored:-}" ]; then flush_dns; exit 0; fi
if [ "$out" = "$HOSTS" ] && [ "$(id -u)" -ne 0 ]; then
  echo "Installing to $HOSTS needs sudo (or use -o FILE for a dry run)" >&2; exit 1
fi

# Files may hold comments (#) and blank lines
list() { [ -f "$1" ] && sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1" || true; }

sources=$DIR/sources
[ -f "$sources" ] || sources=$DIR/sources.example
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

n=0
for url in $(list "$sources"); do
  n=$((n + 1))
  echo "Downloading $url" >&2
  curl -fsSL --max-time 60 "$url" -o "$work/list.$n" || { echo "Download failed: $url (nothing changed)" >&2; exit 1; }
done
[ "$n" -gt 0 ] || { echo "No sources in $sources" >&2; exit 1; }

# Keep only "0.0.0.0 host" / "127.0.0.1 host" lines, take the host, drop local names, lowercase, de-duplicate,
# then remove the whitelisted hosts (exact matches)
list "$DIR/whitelist" | tr 'A-Z' 'a-z' > "$work/whitelist"
cat "$work"/list.* | tr -d '\r' \
  | awk '($1 == "0.0.0.0" || $1 == "127.0.0.1") && NF >= 2 { print tolower($2) }' \
  | grep -E '^[a-z0-9_.-]+\.[a-z0-9_-]+$' \
  | grep -vxE 'localhost|localhost\.localdomain|local|broadcasthost|0\.0\.0\.0' \
  | sort -u \
  | grep -vxF -f "$work/whitelist" > "$work/blocked" || true

count=$(wc -l < "$work/blocked" | tr -d ' ')
[ "$count" -ge "$MIN_ENTRIES" ] || { echo "Only $count hosts to block: something went wrong (nothing changed)" >&2; exit 1; }

{
  if [ -f "$DIR/myhosts" ]; then
    cat "$DIR/myhosts"
  else
    printf '127.0.0.1\tlocalhost\n255.255.255.255\tbroadcasthost\n::1\tlocalhost\n'
  fi
  printf '\n# Blocklist from GTShostsUpdate, %s: %s hosts\n' "$(date '+%Y-%m-%d')" "$count"
  sed 's/^/0.0.0.0 /' "$work/blocked"
} > "$work/hosts"

if [ "$out" = "$HOSTS" ]; then
  [ -f "$BACKUP" ] || cp "$HOSTS" "$BACKUP"
  cp "$work/hosts" "$HOSTS"
  flush_dns
else
  cp "$work/hosts" "$out"
fi
echo "Wrote $out: $count blocked hosts" >&2
