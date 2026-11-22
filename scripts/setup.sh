#!/usr/bin/env bash
# Creates a local Luanti user directory in .dev/ with the game, every
# source listed in sources.toml, the catalogue mod and a world.
# Safe to run again.
#
# To leave a source out, name it in WL_CATALOG_SKIP, separated by spaces:
#   WL_CATALOG_SKIP="paleotest mob_core" scripts/setup.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dev="$repo/.dev"
world="$dev/worlds/catalog"
skip=" ${WL_CATALOG_SKIP:-} "

mkdir -p "$dev/games" "$dev/mods" "$dev/sources" "$world"

# Prints one line per source: name|role|mod|prefix|repo|commit|title|license
read_sources() {
	awk '
		function flush() {
			if (name != "") print name "|" v["role"] "|" v["mod"] "|" v["prefix"] "|" v["repo"] "|" v["commit"] "|" v["title"] "|" v["license"]
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

# The catalogue mod reads titles, licences and number prefixes from this
# file in the world folder.
mods=()
order=0
{
	echo "-- Written by scripts/setup.sh from sources.toml. Do not edit."
	echo "return {"
	while IFS='|' read -r name role mod prefix url commit title license; do
		case "$skip" in *" $name "*) continue ;; esac
		if [ "$role" = "game" ]; then
			fetch_pinned "$dev/games/$name" "$url" "$commit" >&2
			continue
		fi
		fetch_pinned "$dev/sources/$name" "$url" "$commit" >&2
		overlay "$dev/sources/$name" "$dev/mods/$mod"
		mods+=("$mod")
		order=$((order + 1))
		printf '\t[%s] = {order = %d, title = %s, role = %s, prefix = %s, license = %s, url = %s},\n' \
			"$(lua_string "$mod")" "$order" "$(lua_string "$title")" "$(lua_string "$role")" \
			"$(lua_string "$prefix")" "$(lua_string "$license")" "$(lua_string "$url")"
	done < <(read_sources)
	echo "}"
} > "$world/catalog_sources.lua.new"
mv "$world/catalog_sources.lua.new" "$world/catalog_sources.lua"

# The catalogue mod is linked, so changes apply without copying.
rm -rf "$dev/mods/wl_catalog"
ln -sfn "$repo/mods/wl_catalog" "$dev/mods/wl_catalog"

{
	echo "gameid = minetest"
	echo "backend = sqlite3"
	echo "player_backend = sqlite3"
	echo "auth_backend = sqlite3"
	echo "mod_storage_backend = sqlite3"
	echo "load_mod_wl_catalog = true"
	for mod in "${mods[@]}"; do
		echo "load_mod_$mod = true"
	done
} > "$world/world.mt"

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

echo "Ready. Start the catalogue with scripts/run.sh"
