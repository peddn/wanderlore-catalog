#!/usr/bin/env bash
# Starts Luanti with the catalogue of creatures, or with "plants" as the
# first argument the catalogue of trees and plants. Run scripts/setup.sh
# first.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dev="$repo/.dev"

world="catalog"
config="minetest.conf"
if [ "${1:-}" = "plants" ]; then
	world="plants"
	config="plants.conf"
	shift
fi

if [ ! -f "$dev/worlds/$world/world.mt" ]; then
	echo "No catalogue world yet. Run scripts/setup.sh first." >&2
	exit 1
fi

# Luanti keeps its user directory in $HOME/.minetest. Pointing HOME at a
# folder inside .dev keeps the catalogue apart from your own worlds.
mkdir -p "$dev/home"
ln -sfn "$dev" "$dev/home/.minetest"
HOME="$dev/home" exec "${LUANTI:-luanti}" --config "$dev/$config" \
	--world "$dev/worlds/$world" --go "$@"
