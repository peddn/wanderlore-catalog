#!/usr/bin/env bash
# Creates a local Luanti user directory in .dev/ with the game, every
# source listed in sources.toml, the catalogue mod and a world.
# Safe to run again.
#
# There are two worlds: "catalog" with the creatures and "plants" with
# trees and plants. A source belongs to the creatures unless sources.toml
# says set = "plants"; a library may say set = "both".
#
# To leave a source out, name it in WL_CATALOG_SKIP, separated by spaces:
#   WL_CATALOG_SKIP="paleotest mob_core" scripts/setup.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dev="$repo/.dev"
world="$dev/worlds/catalog"
plants="$dev/worlds/plants"
skip=" ${WL_CATALOG_SKIP:-} "

mkdir -p "$dev/games" "$dev/mods" "$dev/sources" "$world" "$plants"

# Prints one line per source:
# name|role|mod|prefix|repo|commit|title|license|set|plant_mods
read_sources() {
	awk '
		function flush() {
			if (name != "") print name "|" v["role"] "|" v["mod"] "|" v["prefix"] "|" v["repo"] "|" v["commit"] "|" v["title"] "|" v["license"] "|" v["set"] "|" v["plant_mods"]
			delete v
		}
		/^\[/ { flush(); name = substr($0, 2, length($0) - 2); next }
		/^[a-z_]+ *= *"/ {
			key = $1; val = $0
			sub(/^[a-z_]+ *= *"/, "", val); sub(/"[ \t]*$/, "", val)
			v[key] = val
		}
		END { flush() }
	' "$repo/sources.toml"
}

# Fetches exactly one commit of a repository into a folder.
fetch_pinned() {
	local folder="$1" url="$2" commit="$3"
	if [ "$(git -C "$folder" rev-parse HEAD 2>/dev/null || true)" = "$commit" ]; then
		return
	fi
	rm -rf "$folder"
	git init -q "$folder"
	git -C "$folder" remote add origin "$url"
	git -C "$folder" fetch -q --depth 1 origin "$commit"
	git -C "$folder" checkout -q FETCH_HEAD
}

# Builds the folder Luanti loads for a source: a copy of the source with an
# init.lua of our own that runs compat.lua first. The copy is needed
# because Luanti's mod security does not follow links out of a mod folder.
# The fetched source itself stays untouched.
overlay() {
	local source="$1" target="$2"
	rm -rf "$target"
	mkdir -p "$target"
	(cd "$source" && tar cf - --exclude=.git .) | (cd "$target" && tar xf -)
	mv "$target/init.lua" "$target/init_original.lua"
	cp "$repo/mods/wl_catalog/compat.lua" "$target/wl_compat.lua"
	cat > "$target/init.lua" <<'LUA'
-- Written by scripts/setup.sh. Runs the fixes for old mods, then the mod.
local path = core.get_modpath(core.get_current_modname())
dofile(path .. "/wl_compat.lua")
dofile(path .. "/init_original.lua")
LUA
}

# Prints a text as a Lua string.
lua_string() {
	local text="${1//\\/\\\\}"
	text="${text//\"/\\\"}"
	printf '"%s"' "$text"
}

# The catalogue mod reads titles, licences and number prefixes from a
# file in the world folder. A source that is a modpack gets one line per
# mod in it.
mods=()
plant_mods=()
order=0
lines_creatures="$dev/sources.creatures.tmp"
lines_plants="$dev/sources.plants.tmp"
: > "$lines_creatures"
: > "$lines_plants"

# Notes one mod of a source for the worlds it belongs to.
note() {
	local mod="$1" set="$2" line
	line="$(printf '\t[%s] = {order = %d, title = %s, role = %s, prefix = %s, license = %s, url = %s},' \
		"$(lua_string "$mod")" "$order" "$(lua_string "$title")" "$(lua_string "$role")" \
		"$(lua_string "$prefix")" "$(lua_string "$license")" "$(lua_string "$url")")"
	if [ "$set" != "plants" ]; then
		echo "$line" >> "$lines_creatures"
		mods+=("$mod")
	fi
	if [ "$set" != "creatures" ]; then
		echo "$line" >> "$lines_plants"
		plant_mods+=("$mod")
	fi
}

while IFS='|' read -r name role mod prefix url commit title license set game_mods; do
	case "$skip" in *" $name "*) continue ;; esac
	set="${set:-creatures}"
	order=$((order + 1))
	if [ "$role" = "game" ]; then
		fetch_pinned "$dev/games/$name" "$url" "$commit"
		# The mods of the game that bring plants are a source of the
		# plants world. They are loaded anyway.
		for game_mod in $game_mods; do
			printf '\t[%s] = {order = %d, title = %s, role = "content", prefix = %s, license = %s, url = %s},\n' \
				"$(lua_string "$game_mod")" "$order" "$(lua_string "$title")" \
				"$(lua_string "$prefix")" "$(lua_string "$license")" "$(lua_string "$url")" >> "$lines_plants"
		done
		continue
	fi
	fetch_pinned "$dev/sources/$name" "$url" "$commit"
	if [ -f "$dev/sources/$name/modpack.conf" ] || [ -f "$dev/sources/$name/modpack.txt" ]; then
		for folder in "$dev/sources/$name"/*/; do
			[ -f "$folder/init.lua" ] || continue
			sub="$(basename "$folder")"
			case "$skip" in *" $sub "*) continue ;; esac
			overlay "$folder" "$dev/mods/$sub"
			note "$sub" "$set"
		done
	else
		overlay "$dev/sources/$name" "$dev/mods/${mod:-$name}"
		note "${mod:-$name}" "$set"
	fi
done < <(read_sources)

for which in creatures plants; do
	[ "$which" = "creatures" ] && target="$world" || target="$plants"
	{
		echo "-- Written by scripts/setup.sh from sources.toml. Do not edit."
		echo "return {"
		cat "$dev/sources.$which.tmp"
		echo "}"
	} > "$target/catalog_sources.lua.new"
	mv "$target/catalog_sources.lua.new" "$target/catalog_sources.lua"
	rm -f "$dev/sources.$which.tmp"
done
echo "plants" > "$plants/catalog_set.txt"

# The catalogue places trees and beds once, when the world is new. After a
# change of the sources or of the mod they would stand in the wrong places
# or be missing, so the map of the plants world is made anew each time.
rm -f "$plants/map.sqlite" "$plants/mod_storage.sqlite"

# The catalogue mod is linked, so changes apply without copying.
rm -rf "$dev/mods/wl_catalog"
ln -sfn "$repo/mods/wl_catalog" "$dev/mods/wl_catalog"

write_world() {
	local target="$1"
	shift
	{
		echo "gameid = minetest"
		echo "backend = sqlite3"
		echo "player_backend = sqlite3"
		echo "auth_backend = sqlite3"
		echo "mod_storage_backend = sqlite3"
		echo "load_mod_wl_catalog = true"
		for mod in "$@"; do
			echo "load_mod_$mod = true"
		done
	} > "$target/world.mt"
}
write_world "$world" "${mods[@]}"
write_world "$plants" "${plant_mods[@]}"

if [ ! -f "$dev/minetest.conf" ]; then
	cat > "$dev/minetest.conf" <<'CONF'
# Local settings for the catalogue world. Not checked in.
name = catalog
mg_name = flat
mgflat_spflags = nolakes,nohills,nocaverns
creative_mode = true
enable_damage = false
mobs_spawn = false
time_speed = 0
enable_sound = true
CONF
fi

# The plants stand in a world that is flat and bare. The generator makes
# nothing; the catalogue mod lays the ground.
if [ ! -f "$dev/plants.conf" ]; then
	cat > "$dev/plants.conf" <<'CONF'
# Local settings for the plants world. Not checked in.
name = catalog
mg_name = singlenode
creative_mode = true
enable_damage = false
mobs_spawn = false
time_speed = 0
enable_sound = true
viewing_range = 240
CONF
fi

echo "Ready. Start the creatures with scripts/run.sh, the plants with scripts/run.sh plants"
