#!/usr/bin/env bash
# Takes a picture of every creature and puts them on overview sheets in
# .dev/sheets/. With "plants" as the first argument it does the same for
# the blocks and trees of the plants world, into .dev/sheets-plants/; a
# second argument limits that to the sources with these number prefixes,
# for example: scripts/shots.sh plants "MT EB". A third argument limits it
# to some kinds of pictures: pages, trees, beds.
# Runs Luanti on a virtual screen, so nothing appears on yours. Needs
# Xvfb, ImageMagick (import) and Python 3 with Pillow.
# Run scripts/setup.sh first.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dev="$repo/.dev"
shots="$dev/shots"
display=":${WL_CATALOG_DISPLAY:-97}"

if [ "${1:-}" = "plants" ]; then
	exec "$repo/scripts/shots_plants.sh" "${2:-}" "${3:-}"
fi

rm -rf "$shots" && mkdir -p "$shots" "$dev/home" "$dev/sheets"
ln -sfn "$dev" "$dev/home/.minetest"

# A copy of the settings with what the virtual screen needs.
config="$dev/shots.conf"
cp "$dev/minetest.conf" "$config"
cat >> "$config" <<'CONF'
wl_catalog_shots = true
enable_sound = false
screen_w = 1280
screen_h = 760
fps_max = 20
ipv6_server = false
bind_address = 127.0.0.1
CONF
rm -f "$dev/debug.txt"

Xvfb "$display" -screen 0 1280x760x24 >/dev/null 2>&1 &
xvfb=$!
sleep 2
HOME="$dev/home" DISPLAY="$display" LIBGL_ALWAYS_SOFTWARE=1 "${LUANTI:-luanti}" \
	--config "$config" --world "$dev/worlds/catalog" --go >/dev/null 2>&1 &
luanti=$!
trap 'kill $luanti $xvfb 2>/dev/null || true' EXIT

# The mod writes one line to the log per creature. Each new line is the
# moment for a screenshot.
last=0
while kill -0 "$luanti" 2>/dev/null; do
	line="$(grep -o 'SHOT [0-9]* [A-Z][0-9]* [a-z_0-9:]*' "$dev/debug.txt" 2>/dev/null | tail -1 || true)"
	number="$(echo "$line" | awk '{print $2}')"
	if [ -n "$number" ] && [ "$number" != "$last" ]; then
		id="$(echo "$line" | awk '{print $3}')"
		name="$(echo "$line" | awk '{print $4}' | sed 's/.*://')"
		sleep 0.35
		DISPLAY="$display" import -window root "$shots/$(printf '%03d' "$number")_${id}_${name}.png"
		last="$number"
	fi
	if grep -q 'SHOTS DONE' "$dev/debug.txt" 2>/dev/null; then
		break
	fi
	sleep 0.2
done

python3 "$repo/scripts/sheets.py" "$shots" "$dev/sheets"
echo "Sheets are in $dev/sheets"
