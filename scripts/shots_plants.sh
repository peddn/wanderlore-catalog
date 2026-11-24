#!/usr/bin/env bash
# Takes the pictures of the plants world: the pages of blocks as they are,
# and one picture per tree, which scripts/sheets_plants.py puts on
# overview sheets. Everything ends up in .dev/sheets-plants/.
# Called by scripts/shots.sh plants [prefixes] [kinds]; the kinds are
# pages, trees, selection and beds.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dev="$repo/.dev"
shots="$dev/shots-plants"
sheets="$dev/sheets-plants"
display=":${WL_CATALOG_DISPLAY:-97}"
only="${1:-}"
what="${2:-}"
beds="$dev/shots-beds"
selection="$dev/shots-selection"

if [ ! -f "$dev/worlds/plants/world.mt" ]; then
	echo "No plants world yet. Run scripts/setup.sh first." >&2
	exit 1
fi

rm -rf "$shots" "$beds" "$selection"
mkdir -p "$shots" "$beds" "$selection" "$sheets" "$dev/home"
ln -sfn "$dev" "$dev/home/.minetest"

config="$dev/shots-plants.conf"
cp "$dev/plants.conf" "$config"
cat >> "$config" <<CONF
wl_catalog_shots = true
wl_catalog_shots_only = $only
wl_catalog_shots_what = $what
enable_sound = false
screen_w = 1280
screen_h = 760
fps_max = 20
viewing_range = 260
enable_fog = false
enable_waving_leaves = false
enable_waving_plants = false
ipv6_server = false
bind_address = 127.0.0.1
CONF
rm -f "$dev/debug.txt"

Xvfb "$display" -screen 0 1280x760x24 >/dev/null 2>&1 &
xvfb=$!
sleep 2
HOME="$dev/home" DISPLAY="$display" LIBGL_ALWAYS_SOFTWARE=1 "${LUANTI:-luanti}" \
	--config "$config" --world "$dev/worlds/plants" --go >/dev/null 2>&1 &
luanti=$!
trap 'kill $luanti $xvfb 2>/dev/null || true' EXIT

# The mod writes one line to the log per picture:
#   SHOT <number> page <prefix> <page>
#   SHOT <number> tree <id> <name> <width>x<height>
#   SHOT <number> bed <id> <name> <kind>
#   SHOT <number> sel <id> <label> <width>x<height>
#   SHOT <number> row <name> ...   all chosen forms side by side
last=0
while kill -0 "$luanti" 2>/dev/null; do
	line="$(grep -o 'SHOT [0-9]* [a-z]* .*' "$dev/debug.txt" 2>/dev/null | tail -1 || true)"
	number="$(echo "$line" | awk '{print $2}')"
	if [ -n "$number" ] && [ "$number" != "$last" ]; then
		kind="$(echo "$line" | awk '{print $3}')"
		if [ "$kind" = "page" ]; then
			file="$sheets/blocks_$(echo "$line" | awk '{printf "%s_%02d", $4, $5}').png"
		elif [ "$kind" = "row" ]; then
			file="$sheets/selection_$(echo "$line" | awk '{print $4}')_row.png"
		elif [ "$kind" = "sel" ]; then
			file="$selection/$(echo "$line" | awk '{printf "%04d %s %s %s", $2, $4, $5, $6}').png"
		elif [ "$kind" = "bed" ]; then
			file="$beds/$(echo "$line" | awk '{printf "%04d %s %s %s", $2, $4, $5, $6}').png"
		else
			file="$shots/$(echo "$line" | awk '{printf "%04d %s %s %s", $2, $4, $5, $6}').png"
		fi
		sleep 0.3
		if [ "$kind" = "page" ]; then
			# Only the page itself, without the screen around it.
			DISPLAY="$display" import -window root -crop 1150x670+65+45 +repage "$file"
		else
			DISPLAY="$display" import -window root "$file"
		fi
		last="$number"
	fi
	if grep -q 'SHOTS DONE' "$dev/debug.txt" 2>/dev/null; then
		break
	fi
	sleep 0.2
done

python3 "$repo/scripts/sheets_plants.py" "$shots" "$sheets" trees
python3 "$repo/scripts/sheets_plants.py" "$shots" "$sheets" kinds "$dev/worlds/plants/catalog_kinds.tsv"
python3 "$repo/scripts/sheets_plants.py" "$beds" "$sheets" beds
python3 "$repo/scripts/sheets_plants.py" "$selection" "$sheets" selection
echo "Sheets are in $sheets"
