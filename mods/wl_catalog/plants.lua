-- The catalogue of trees and plants. init.lua loads this file instead of
-- the catalogue of creatures when the world is the plants world.
--
-- It shows two things. The blocks: every trunk, leaf, sapling, flower,
-- grass, mushroom and ground block the sources registered, as pages of
-- inventory pictures with numbers. And the trees: every tree the sources
-- bring, standing in rows on a flat and bare world, one row per source.
--
-- Nothing here uses the generators of the sources. The world is
-- "singlenode", the ground is a block of the catalogue that no plant
-- spreads on, and the trees are placed one by one.

local plants = {
	nodes = {},     -- sorted list of blocks
	node_by_id = {},
	trees = {},     -- sorted list of trees
	tree_by_id = {},
	beds = {},      -- the blocks that stand as a bed in the world
	signs = {},     -- names at the start of each row and aisle
	sources = {},   -- list of sources that show something, in order
}

local storage = core.get_mod_storage()
local SHOTS = core.settings:get_bool("wl_catalog_shots", false)

local source_info = {}
do
	local path = core.get_worldpath() .. "/catalog_sources.lua"
	local file = io.open(path, "r")
	if file then
		file:close()
		source_info = dofile(path)
	end
	-- The mods of a modpack share one source.
	local by_prefix = {}
	for mod, source in pairs(source_info) do
		if source.role == "content" then
			by_prefix[source.prefix] = by_prefix[source.prefix] or source
			source_info[mod] = by_prefix[source.prefix]
		end
	end
end

--
-- The ground
--

-- Lines every block and a stronger one every eight, to judge sizes.
core.register_node("wl_catalog:ground", {
	description = "Boden des Katalogs",
	tiles = {"[fill:16x16:#566349^[fill:15x15:0,0:#5f6d50"},
	groups = {cracky = 3},
	is_ground_content = false,
})

core.register_node("wl_catalog:path", {
	description = "Weg des Katalogs",
	tiles = {"[fill:16x16:#b9ab86^[fill:15x15:0,0:#c9bb95"},
	groups = {cracky = 3},
	is_ground_content = false,
})

local GROUND_TOP, GROUND_BOTTOM = 0, -6

core.register_on_generated(function(minp, maxp)
	if minp.y > GROUND_TOP or maxp.y < GROUND_BOTTOM then
		return
	end
	local vmanip, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea(emin, emax)
	local data = vmanip:get_data()
	local ground = core.get_content_id("wl_catalog:ground")
	for z = minp.z, maxp.z do
		for y = math.max(minp.y, GROUND_BOTTOM), math.min(maxp.y, GROUND_TOP) do
			local vi = area:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				data[vi] = ground
				vi = vi + 1
			end
		end
	end
	vmanip:set_data(data)
	vmanip:calc_lighting()
	vmanip:write_to_map()
end)

--
-- Blocks
--

local CATEGORIES = {"trunk", "planks", "leaves", "sapling", "flower", "mushroom", "plant", "water", "ground"}
local CATEGORY_LABEL = {
	trunk = "Stamm", planks = "Bretter", leaves = "Laub", sapling = "Setzling",
	flower = "Blume", mushroom = "Pilz", plant = "Pflanze", water = "Wasserpflanze",
	ground = "Boden",
}
local CATEGORY_COLOR = {
	trunk = "#6b4a2e", planks = "#8a6a3c", leaves = "#2f6b33", sapling = "#4f8a3a",
	flower = "#8a3f6f", mushroom = "#7a4a4a", plant = "#3f7a5a", water = "#2f5f8a",
	ground = "#5a5a4a",
}
local CATEGORY_ORDER = {}
for index, name in ipairs(CATEGORIES) do
	CATEGORY_ORDER[name] = index
end

-- Shapes built from a block, which would only repeat its texture.
local DERIVED = {"stair", "slab", "fence", "gate", "door", "wall", "_post", "panel", "micro_",
	"slope", "ladder", "sign", "chest", "bookshelf", "table", "chair", "bench", "pane"}

local function category(name, def)
	local groups = def.groups or {}
	if groups.not_in_creative_inventory and groups.not_in_creative_inventory > 0 then
		return nil
	end
	local short = name:match(":(.*)$") or name
	for _, part in ipairs(DERIVED) do
		if short:find(part, 1, true) then
			return nil
		end
	end
	local drawtype = def.drawtype or "normal"
	if groups.sapling then
		return "sapling"
	elseif groups.tree then
		return "trunk"
	elseif groups.wood then
		return "planks"
	elseif groups.leaves or groups.leafdecay then
		return "leaves"
	elseif groups.mushroom then
		return "mushroom"
	elseif groups.flower then
		return "flower"
	elseif drawtype == "plantlike_rooted" or short:find("lily", 1, true)
			or short:find("coral", 1, true) or short:find("seaweed", 1, true)
			or short:find("kelp", 1, true) then
		return "water"
	elseif drawtype == "plantlike" or groups.flora or groups.grass or groups.plant
			or groups.vines or groups.attached_node and (drawtype == "mesh" or drawtype == "nodebox") then
		return "plant"
	elseif groups.soil or groups.spreading_dirt_type then
		return "ground"
	end
	return nil
end

local function plain(text)
	text = core.get_translated_string("de", tostring(text or ""))
	text = core.strip_colors(text)
	return (text:gsub("\n.*", ""))
end

local function collect_nodes()
	local list = {}
	for name, def in pairs(core.registered_nodes) do
		local mod = name:match("^([^:]+):")
		local source = mod and source_info[mod]
		if source and source.role == "content" then
			local kind = category(name, def)
			if kind then
				list[#list + 1] = {
					name = name,
					short = name:match(":(.*)$"),
					description = plain(def.description),
					category = kind,
					source = source,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		if a.source.order ~= b.source.order then
			return a.source.order < b.source.order
		elseif a.category ~= b.category then
			return CATEGORY_ORDER[a.category] < CATEGORY_ORDER[b.category]
		end
		return a.name < b.name
	end)
	local count = {}
	for _, entry in ipairs(list) do
		local prefix = entry.source.prefix
		count[prefix] = (count[prefix] or 0) + 1
		entry.id = prefix .. count[prefix]
		plants.node_by_id[entry.id] = entry
	end
	plants.nodes = list
end

--
-- Trees
--

local plant_category = {}

local function resolve(name)
	return core.registered_aliases[name] or name
end

-- Looks into a schematic. Returns its size, whether it holds blocks of
-- the catalogue other than ground, and the mod most of them come from.
local function inspect(schematic)
	local ok, read = true, schematic
	if type(schematic) ~= "table" then
		ok, read = pcall(core.read_schematic, schematic, {write_yslice_prob = "none"})
	end
	if not ok or type(read) ~= "table" or type(read.size) ~= "table" or type(read.data) ~= "table" then
		return nil
	end
	local mods, found, trunks = {}, 0, 0
	-- What it is made of: how many blocks of each kind, and which trunk
	-- block most often.
	local made = {total = 0, trunk = 0, leaves = 0, plant = 0, other = 0}
	local trunk_count = {}
	for _, node in ipairs(read.data) do
		local name = resolve(node.name)
		local kind = plant_category[name]
		local present = name ~= "air" and name ~= "ignore" and (node.prob or 255) > 0
		if present then
			made.total = made.total + 1
			if kind == "trunk" then
				made.trunk = made.trunk + 1
				trunk_count[name] = (trunk_count[name] or 0) + 1
				if not made.trunk_node or trunk_count[name] > trunk_count[made.trunk_node] then
					made.trunk_node = name
				end
			elseif kind == "leaves" then
				made.leaves = made.leaves + 1
				trunk_count[name] = (trunk_count[name] or 0) + 1
				if not made.leaves_node or trunk_count[name] > trunk_count[made.leaves_node] then
					made.leaves_node = name
				end
			elseif kind and kind ~= "ground" and kind ~= "planks" then
				made.plant = made.plant + 1
			else
				made.other = made.other + 1
			end
		end
		if kind and kind ~= "ground" and present then
			found = found + 1
			if kind == "trunk" then
				trunks = trunks + 1
			end
			local mod = name:match("^([^:]+):")
			mods[mod] = (mods[mod] or 0) + 1
		end
	end
	local best, most = nil, 0
	for mod, number in pairs(mods) do
		if number > most then
			best, most = mod, number
		end
	end
	return read.size, found, best, trunks, made
end

local function mod_of_path(path)
	local found, length = nil, 0
	for _, mod in ipairs(core.get_modnames()) do
		local modpath = core.get_modpath(mod)
		if modpath and #modpath > length and path:sub(1, #modpath + 1) == modpath .. "/" then
			found, length = mod, #modpath
		end
	end
	return found
end

local function clean_path(path)
	return (path:gsub("\\", "/"):gsub("/+", "/"))
end

local function collect_trees()
	local list, seen = {}, {}

	local function add(schematic, name, mod, offset)
		local size, found, guess, trunks, made = inspect(schematic)
		if not size or found == 0 then
			return
		end
		mod = mod or guess
		local source = mod and source_info[mod] or guess and source_info[guess]
		if not source or source.role ~= "content" then
			return
		end
		-- The same tree registered again, for another biome.
		local key = source.prefix .. "|" .. name .. "|" .. size.x .. "x" .. size.y .. "x" .. size.z
		if seen[key] then
			return
		end
		seen[key] = true
		list[#list + 1] = {
			name = name,
			source = source,
			w = size.x, h = size.y, d = size.z,
			offset = offset or 0,
			trunks = trunks,
			made = made,
			schematic = schematic,
		}
	end

	-- What the sources registered for their own generators.
	local numbered = {}
	for _, def in pairs(core.registered_decorations) do
		if def.deco_type == "schematic" and def.schematic then
			if type(def.schematic) == "string" then
				local path = clean_path(def.schematic)
				if not seen[path] then
					seen[path] = true
					add(path, path:match("([^/]+)%.mts$") or path, mod_of_path(path), def.place_offset_y)
				end
			elseif type(def.schematic) == "table" and not seen[def.schematic] then
				seen[def.schematic] = true
				local name = def.name and def.name:match("([^:]+)$")
				if not name then
					-- Named after its most frequent block.
					local counts, best, most = {}, "tree", 0
					for _, node in ipairs(def.schematic.data or {}) do
						local node_name = resolve(node.name)
						if plant_category[node_name] and plant_category[node_name] ~= "ground" then
							counts[node_name] = (counts[node_name] or 0) + 1
							if counts[node_name] > most then
								best, most = node_name:match(":(.*)$"), counts[node_name]
							end
						end
					end
					name = best
				end
				add(def.schematic, name, nil, def.place_offset_y)
			end
		end
	end

	-- Schematic files the sources carry without registering them, such as
	-- the trees that only grow from saplings.
	local function scan(mod, folder, depth)
		for _, file in ipairs(core.get_dir_list(folder, false) or {}) do
			if file:match("%.mts$") then
				local path = clean_path(folder .. "/" .. file)
				if not seen[path] then
					seen[path] = true
					add(path, file:match("^(.*)%.mts$"), mod, 0)
				end
			end
		end
		if depth > 0 then
			for _, sub in ipairs(core.get_dir_list(folder, true) or {}) do
				if sub ~= "textures" and sub ~= "models" and sub ~= "sounds" and sub ~= "locale" then
					scan(mod, folder .. "/" .. sub, depth - 1)
				end
			end
		end
	end
	for mod, source in pairs(source_info) do
		local modpath = core.get_modpath(mod)
		if modpath and source.role == "content" then
			scan(mod, modpath, 2)
		end
	end

	-- Trees that More Trees grows from rules instead of files.
	local moretrees = rawget(_G, "moretrees")
	local source = source_info.moretrees
	if moretrees and source and type(moretrees.treelist) == "table" then
		for _, def in ipairs(moretrees.treelist) do
			local tree = def[1]
			local grow = moretrees["grow_" .. tree]
			local model = moretrees[tree .. "_model"]
			if type(grow) == "function" or type(model) == "table" then
				list[#list + 1] = {
					name = tree,
					source = source,
					w = 40, h = 60, d = 40,
					offset = 0,
					grown = true,
					made = {total = 2, trunk = 1, leaves = 1, plant = 0, other = 0,
						trunk_node = "moretrees:" .. tree .. "_trunk",
						leaves_node = "moretrees:" .. tree .. "_leaves"},
					grow = function(pos)
						if type(grow) == "function" then
							grow(pos)
						else
							core.spawn_tree(pos, model)
						end
					end,
				}
			end
		end
	end

	table.sort(list, function(a, b)
		if a.source.order ~= b.source.order then
			return a.source.order < b.source.order
		elseif a.name ~= b.name then
			return a.name < b.name
		end
		return a.h < b.h
	end)
	local count = {}
	for _, entry in ipairs(list) do
		local prefix = entry.source.prefix
		count[prefix] = (count[prefix] or 0) + 1
		entry.id = prefix .. "-T" .. count[prefix]
		plants.tree_by_id[entry.id] = entry
	end
	plants.trees = list
end

--
-- Kinds of trees
--
-- Besides its source every entry has a group: a tree, a bush, a log, a
-- group of plants or a structure. Trees also have a family, guessed from
-- their name, such as all birches of all sources, and within it a species:
-- the trees built from the same trunk block.

-- Families in the order they are shown. A word in braces has to be a whole
-- word of the name, the others may be part of one.
local FAMILIES = {
	{"Birke", {"birch"}},
	{"Buche", {"beech"}},
	{"Eiche", {"{oak}", "oak_"}},
	{"Ahorn", {"maple"}},
	{"Pappel und Espe", {"poplar", "aspen"}},
	{"Weide", {"willow"}},
	{"Erle", {"alder"}},
	{"Esche", {"{ash}", "ash_"}},
	{"Apfel", {"apple"}},
	{"Kirsche", {"cherry", "sakura"}},
	{"Zitrus", {"lemon", "orange", "citrus"}},
	{"Obstbaum", {"pear", "plum", "peach", "apricot", "olive", "banana", "mango", "fig"}},
	{"Kiefer", {"pine"}},
	{"Tanne und Fichte", {"{fir}", "fir_", "spruce"}},
	{"Zeder, Lärche, Zypresse", {"cedar", "larch", "cypress"}},
	{"Mammutbaum", {"redwood", "sequoia"}},
	{"Akazie", {"acacia"}},
	{"Palme", {"palm", "coconut"}},
	{"Dschungelbaum", {"jungle", "samauma"}},
	{"Mangrove", {"mangrove"}},
	{"Bambus", {"bamboo"}},
	{"Kaktus", {"cactus", "cacti"}},
	{"Riesenpilz", {"mushroom", "shroom"}},
	{"Baobab", {"baobab"}},
}

local function family_of(text)
	text = text:lower()
	local words = {}
	for word in text:gmatch("%a+") do
		words[word] = true
	end
	for _, family in ipairs(FAMILIES) do
		for _, key in ipairs(family[2]) do
			local whole = key:match("^{(.*)}$")
			if whole and words[whole] or not whole and text:find(key, 1, true) then
				return family[1]
			end
		end
	end
	return nil
end

local GROUPS = {"Bäume", "Büsche", "Stämme und Stümpfe", "Pflanzengruppen", "Strukturen und Gebäude"}

local function classify(tree)
	local made = tree.made
	local group
	if made.other > made.total / 2 then
		group = 5
	elseif made.trunk > 0 and made.leaves > 0 then
		group = tree.h > 4 and 1 or 2
	elseif made.trunk > 0 then
		group = 3
	elseif made.leaves > 0 then
		group = tree.h > 6 and 1 or 2
	else
		group = 4
	end
	tree.group = GROUPS[group]
	tree.species = made.trunk_node and made.trunk_node:match(":(.*)$") or ""
	if group == 1 then
		tree.family = family_of(tree.name .. " " .. tree.species)
		-- A tree without a known name stays with its source.
		tree.row = tree.family or ("Sonstige Bäume – " .. tree.source.title)
		tree.row_order = tree.family and 1 or 2
	else
		tree.row = tree.group
		tree.row_order = 1 + group
	end
end

--
-- Where the trees stand
--

-- Rows run along x, one per source, far enough apart that the next row
-- lies beyond the viewing range.
local ROW_Z, ROW_GAP = 200, 320
local BASE_Y = GROUND_TOP + 1
-- Half the height of the picture at distance 1, for the field of view
-- used in the pictures.
local FOV = 60
local HALF = math.tan(math.rad(FOV / 2))

-- The width a tree needs in its row and in its picture.
local function view_of(tree)
	return math.max(tree.w, tree.d, tree.h + tree.offset) * 1.15 + 4
end

local function lay_out()
	local row, x, last = 0, 0, nil
	for _, tree in ipairs(plants.trees) do
		if tree.source ~= last then
			row, x, last = row + 1, 0, tree.source
			tree.source.row_z = ROW_Z + (row - 1) * ROW_GAP
			plants.signs[#plants.signs + 1] = {
				pos = {x = -10, y = BASE_Y + 6, z = tree.source.row_z},
				text = tree.source.prefix .. " " .. tree.source.title,
			}
		end
		local slot = math.ceil(view_of(tree))
		tree.x = x + math.floor(slot / 2)
		tree.z = tree.source.row_z
		x = x + slot
	end
end

-- Every tree stands a second time, in rows by kind: a row per family,
-- then the trees without one by source, then bushes, logs, groups of
-- plants and structures. Within a row the trees of one species stand
-- together. These rows lie beyond the beds.
local KIND_Z = -4000
plants.kinds = {}       -- the rows by kind, in order
plants.copies = {}      -- the second standing of each tree

local function lay_out_kinds()
	local family_order = {}
	for index, family in ipairs(FAMILIES) do
		family_order[family[1]] = index
	end
	local list = {}
	for _, tree in ipairs(plants.trees) do
		classify(tree)
		list[#list + 1] = tree
	end
	table.sort(list, function(a, b)
		if a.row_order ~= b.row_order then
			return a.row_order < b.row_order
		elseif a.row ~= b.row then
			if a.family and b.family then
				return family_order[a.family] < family_order[b.family]
			end
			return a.source.order < b.source.order
		elseif a.species ~= b.species then
			return a.species < b.species
		elseif a.h ~= b.h then
			return a.h < b.h
		end
		return a.id < b.id
	end)
	local x, row
	for _, tree in ipairs(list) do
		if not row or row.title ~= tree.row then
			row = {title = tree.row, z = KIND_Z - #plants.kinds * ROW_GAP, trees = {}}
			plants.kinds[#plants.kinds + 1] = row
			x = 0
			plants.signs[#plants.signs + 1] = {
				pos = {x = -10, y = BASE_Y + 6, z = row.z},
				text = row.title,
			}
		end
		local slot = math.ceil(view_of(tree))
		local copy = setmetatable({x = x + math.floor(slot / 2), z = row.z, copy_of = tree,
			suffix = " copy"}, {__index = tree})
		x = x + slot
		row.trees[#row.trees + 1] = copy
		plants.copies[#plants.copies + 1] = copy
	end
end

-- Where to stand to see the whole tree, looking along +z.
local function viewpoint(tree)
	-- Measured on pictures: the client shows more than the field of view
	-- says, so the camera stands closer than the calculation gives.
	local distance = 0.66 * view_of(tree) / (2 * HALF)
	local height = math.max(tree.h + tree.offset, 2)
	return {
		x = tree.x + (tree.shift_x or 0),
		y = BASE_Y + height / 2,
		z = tree.z + (tree.shift_z or 0) - tree.d / 2 - distance,
	}
end

--
-- Planks to walk along
--
-- Every kind of planks of the sources as a small wall, side by side, to
-- choose the planks of a wood category. The row lies near the selection.

local PLANK_Z, PLANK_SLOT = -3120, 5
plants.planks = {}

local function lay_out_planks()
	for _, entry in ipairs(plants.nodes) do
		if entry.category == "planks" then
			entry.plank_x = #plants.planks * PLANK_SLOT
			plants.planks[#plants.planks + 1] = entry
		end
	end
	plants.signs[#plants.signs + 1] = {
		pos = {x = -8, y = BASE_Y + 5, z = PLANK_Z},
		text = "Bretter aller Quellen",
	}
	for _, sample in ipairs(plants.plank_samples) do
		plants.planks[#plants.planks + 1] = sample
	end
end

local function place_planks(entry)
	local z = entry.plank_z or PLANK_Z
	local p1 = {x = entry.plank_x - 1, y = BASE_Y, z = z}
	local p2 = {x = entry.plank_x + 1, y = BASE_Y + 2, z = z + 1}
	local vmanip = VoxelManip()
	local emin, emax = vmanip:read_from_map(p1, p2)
	local area = VoxelArea(emin, emax)
	local data = vmanip:get_data()
	local content = core.get_content_id(entry.name)
	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			for x = p1.x, p2.x do
				data[area:index(x, y, z)] = content
			end
		end
	end
	vmanip:set_data(data)
	vmanip:write_to_map(true)
end

--
-- The selection
--
-- selection.lua lists what the author chose for Wanderlore. Each chosen
-- form stands once more, between the beds and the rows by kind, with its
-- trunk and leaves replaced by the chosen blocks.

local SELECTION_Z = -3000
plants.selected = {}
plants.plank_samples = {}

-- Blocks have to be registered while the mods load, so the blocks of
-- hanging leaves are made here, before anything else of the selection is
-- known. The strands are cut out of the texture of the leaves.
do
	local ok, list = pcall(dofile, core.get_modpath("wl_catalog") .. "/selection.lua")
	local mask = "[fill:16x16:#00000000"
	for _, strand in ipairs({{0, 2, 16}, {3, 1, 11}, {5, 2, 16}, {8, 1, 13}, {10, 2, 16}, {13, 1, 9}, {15, 1, 14}}) do
		mask = mask .. "^[fill:" .. strand[2] .. "x" .. strand[3] .. ":" .. strand[1] .. ",0:#ffffffff"
	end
	mask = mask:gsub("%^", "\\^"):gsub(":", "\\:")
	for _, species in ipairs(ok and type(list) == "table" and list or {}) do
		if species.hanging_texture then
			core.register_node("wl_catalog:hanging_" .. species.name, {
				description = "Hängendes Laub: " .. species.title,
				drawtype = "allfaces_optional",
				tiles = {species.hanging_texture .. "^[mask:" .. mask},
				paramtype = "light",
				waving = 1,
				walkable = false,
				groups = {snappy = 3},
			})
		end
	end
end

-- Returns a schematic enlarged by a factor, each block of the result
-- taken from the nearest one of the original.
local function enlarge(schematic, factor)
	if type(schematic) == "string" then
		schematic = core.read_schematic(schematic, {write_yslice_prob = "none"})
	end
	local from = schematic.size
	local size = {x = math.ceil(from.x * factor), y = math.ceil(from.y * factor), z = math.ceil(from.z * factor)}
	local data = {}
	for z = 0, size.z - 1 do
		local sz = math.min(from.z - 1, math.floor(z / factor))
		for y = 0, size.y - 1 do
			local sy = math.min(from.y - 1, math.floor(y / factor))
			for x = 0, size.x - 1 do
				local sx = math.min(from.x - 1, math.floor(x / factor))
				local node = schematic.data[(sz * from.y + sy) * from.x + sx + 1]
				data[#data + 1] = {name = node.name, prob = node.prob, param2 = node.param2}
			end
		end
	end
	return {size = size, data = data}
end

local function block_of(spec, kind)
	local tree = plants.tree_by_id[spec]
	if tree then
		return kind == "trunk" and tree.made.trunk_node or tree.made.leaves_node
	end
	local entry = plants.node_by_id[spec]
	if entry then
		return entry.name
	end
	return core.registered_nodes[spec] and spec or nil
end

local function lay_out_selection()
	local path = core.get_modpath("wl_catalog") .. "/selection.lua"
	local ok, list = pcall(dofile, path)
	if not ok or type(list) ~= "table" then
		core.log("warning", "[wl_catalog] selection.lua could not be read: " .. tostring(list))
		return
	end
	local row = 0
	for _, species in ipairs(list) do
		local trunk, leaves = block_of(species.trunk, "trunk"), block_of(species.leaves, "leaves")
		if not trunk or not leaves then
			core.log("warning", "[wl_catalog] selection " .. species.name .. ": trunk or leaves not found")
		else
			local z = SELECTION_Z - row * ROW_GAP
			row = row + 1
			plants.signs[#plants.signs + 1] = {
				pos = {x = -10, y = BASE_Y + 6, z = z},
				text = "Auswahl: " .. species.title .. (species.category and " (" .. species.category .. ")" or ""),
			}
			-- The planks of its category stand as a small wall at the start.
			local planks = species.planks and block_of(species.planks, "planks")
			if planks then
				plants.plank_samples[#plants.plank_samples + 1] = {
					name = planks, id = species.category or "Bretter",
					short = species.planks, plank_x = -8, plank_z = z,
				}
			end
			local x = 0
			for index, form in ipairs(species.forms) do
				local tree = plants.tree_by_id[form.tree]
				if form.build then
					-- A form built in selection.lua itself.
					local ok, schematic = pcall(form.build, trunk, leaves, "wl_catalog:hanging_" .. species.name)
					if ok and type(schematic) == "table" then
						local id = species.name:upper() .. "-" .. index
						local copy = {z = z, id = id, shot_id = id, suffix = "", offset = 0,
							source = {title = "Auswahl", prefix = "SEL", order = 0},
							chosen = {trunk = trunk, leaves = leaves},
							label = form.label or "gebaut",
							name = species.title .. " " .. (form.label or "gebaut"),
							schematic = schematic,
							w = schematic.size.x, h = schematic.size.y, d = schematic.size.z,
							made = {trunk_node = trunk, leaves_node = leaves}}
						local slot = math.ceil(view_of(copy))
						copy.x = x + math.floor(slot / 2)
						x = x + slot
						plants.selected[#plants.selected + 1] = copy
					else
						core.log("warning", "[wl_catalog] selection " .. species.name .. ": form " ..
							index .. " could not be built: " .. tostring(schematic))
					end
				elseif not tree then
					core.log("warning", "[wl_catalog] selection " .. species.name .. ": no tree " .. form.tree)
				else
					local copy = setmetatable({z = z, copy_of = tree, suffix = " sel " .. species.name .. index,
						chosen = {trunk = trunk, leaves = leaves,
							hanging = form.hang and "wl_catalog:hanging_" .. species.name or nil},
						label = form.label or form.tree,
						shot_id = species.name:upper() .. "-" .. index,
						name = species.title .. " " .. (form.label or form.tree)}, {__index = tree})
					if form.scale and tree.schematic then
						copy.schematic = enlarge(tree.schematic, form.scale)
						copy.w, copy.h, copy.d = copy.schematic.size.x, copy.schematic.size.y, copy.schematic.size.z
						copy.offset = math.floor(tree.offset * form.scale)
					end
					local slot = math.ceil(view_of(copy))
					copy.x = x + math.floor(slot / 2)
					x = x + slot
					plants.selected[#plants.selected + 1] = copy
				end
			end
		end
	end
end

-- Replaces every trunk and all leaves at the place of a chosen form by
-- the chosen blocks. Whatever else the form brought, such as fruit, goes.
local function rewrite(tree)
	-- Only the place of this form: its neighbours stand close. A tree that
	-- grew by rules has no known size and gets the whole of its slot.
	local reach = math.ceil(math.max(tree.w, tree.d) / 2) + (tree.grown and 8 or 1)
	local p1 = {x = tree.x - reach, y = BASE_Y, z = tree.z - reach}
	local p2 = {x = tree.x + reach, y = BASE_Y + math.max(tree.h, tree.grown and 60 or 0) + 30, z = tree.z + reach}
	local vmanip = VoxelManip()
	local emin, emax = vmanip:read_from_map(p1, p2)
	local area = VoxelArea(emin, emax)
	local data = vmanip:get_data()
	local air, ignore = core.CONTENT_AIR, core.CONTENT_IGNORE
	local trunk, leaves = core.get_content_id(tree.chosen.trunk), core.get_content_id(tree.chosen.leaves)
	local kinds, dropped = {}, 0
	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			local vi = area:index(p1.x, y, z)
			for _ = p1.x, p2.x do
				local content = data[vi]
				if content ~= air and content ~= ignore then
					local kind = kinds[content]
					if kind == nil then
						local name = core.get_name_from_content_id(content)
						kind = plant_category[name] or name:find("^wl_catalog:hanging_") and "keep" or false
						kinds[content] = kind
					end
					if kind == "keep" then
						-- Hanging leaves of the selection itself.
					elseif kind == "trunk" then
						data[vi] = trunk
					elseif kind == "leaves" then
						data[vi] = leaves
					else
						data[vi] = air
						dropped = dropped + 1
					end
				end
				vi = vi + 1
			end
		end
	end
	-- Hanging leaves: in every column the lowest run of leaves, if it hangs
	-- free at the rim of the crown, keeps its top leaf and turns the rest
	-- into hanging leaves.
	if tree.chosen.hanging and core.registered_nodes[tree.chosen.hanging] then
		local hanging = core.get_content_id(tree.chosen.hanging)
		local ystride, zstride = area.ystride, area.zstride
		for z = p1.z, p2.z do
			for x = p1.x, p2.x do
				local vi = area:index(x, p1.y, z)
				for y = p1.y, p2.y do
					if data[vi] == leaves then
						local run = 1
						while data[vi + run * ystride] == leaves do
							run = run + 1
						end
						local free = data[vi - ystride] == air and (data[vi - 1] == air or data[vi + 1] == air
							or data[vi - zstride] == air or data[vi + zstride] == air)
						if free and run >= 2 then
							for step = 0, math.min(run - 2, 4) do
								data[vi + step * ystride] = hanging
							end
						end
						break
					elseif data[vi] ~= air and data[vi] ~= ignore then
						break
					end
					vi = vi + ystride
				end
			end
		end
	end
	vmanip:set_data(data)
	vmanip:write_to_map(true)
	if dropped > 0 then
		core.log("action", "[wl_catalog] selection " .. tree.name .. ": " .. dropped .. " other blocks removed")
	end
end

-- Measures what grew at the place of a tree, for the trees whose size is
-- not known beforehand.
local function measure(tree)
	local reach = 24
	local p1 = {x = tree.x - reach, y = BASE_Y, z = tree.z - reach}
	local p2 = {x = tree.x + reach, y = BASE_Y + 90, z = tree.z + reach}
	local vmanip = VoxelManip()
	local emin, emax = vmanip:read_from_map(p1, p2)
	local area = VoxelArea(emin, emax)
	local data = vmanip:get_data()
	local air, ignore = core.CONTENT_AIR, core.CONTENT_IGNORE
	local minx, maxx, minz, maxz, maxy
	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			local vi = area:index(p1.x, y, z)
			for x = p1.x, p2.x do
				local content = data[vi]
				if content ~= air and content ~= ignore then
					minx, maxx = math.min(minx or x, x), math.max(maxx or x, x)
					minz, maxz = math.min(minz or z, z), math.max(maxz or z, z)
					maxy = math.max(maxy or y, y)
				end
				vi = vi + 1
			end
		end
	end
	if not minx then
		return nil
	end
	return {
		w = maxx - minx + 1, h = maxy - BASE_Y + 1, d = maxz - minz + 1,
		shift_x = (minx + maxx) / 2 - tree.x, shift_z = (minz + maxz) / 2 - tree.z,
	}
end

local function apply_measure(tree, size)
	tree.w, tree.h, tree.d = size.w, size.h, size.d
	tree.shift_x, tree.shift_z = size.shift_x, size.shift_z
end

--
-- Beds of ground plants
--
-- Every flower, mushroom, plant and water plant stands as a small field
-- of its own, to show how it looks when it covers the ground. The beds
-- lie apart from the trees. Every source has an aisle of its own: a path
-- along x with its beds on both sides.

local BED_KINDS = {flower = true, mushroom = true, plant = true, water = true}
local BED, BED_SLOT = 5, 12
local AISLE_Z, AISLE_GAP = -400, 48
-- How far the middle of a bed lies from the middle of the path.
local BED_SIDE = 7

local function lay_out_beds()
	local aisle, count, last = 0, 0, nil
	for _, entry in ipairs(plants.nodes) do
		if BED_KINDS[entry.category] then
			if entry.source ~= last then
				aisle, count, last = aisle + 1, 0, entry.source
				entry.source.aisle_z = AISLE_Z - (aisle - 1) * AISLE_GAP
				plants.signs[#plants.signs + 1] = {
					pos = {x = -6, y = BASE_Y + 3, z = entry.source.aisle_z},
					text = entry.source.prefix .. " " .. entry.source.title,
				}
			end
			-- Left and right in turn, so that the numbers run along the path.
			entry.bed_side = count % 2 == 0 and 1 or -1
			entry.bed_x = math.floor(count / 2) * BED_SLOT
			entry.bed_z = entry.source.aisle_z + entry.bed_side * BED_SIDE
			count = count + 1
			plants.beds[#plants.beds + 1] = entry
		end
	end
end

-- Where to stand to see a bed: on the far edge of the path, looking
-- across it and down at the bed.
local BED_PITCH = math.rad(36)
local function bed_viewpoint(entry)
	return {x = entry.bed_x, y = BASE_Y + 3.6, z = entry.bed_z - entry.bed_side * 5.2}
end
local function bed_yaw(entry)
	return entry.bed_side == 1 and 0 or math.pi
end

-- Written straight into the map, so that no block starts to grow.
local function place_bed(entry)
	local def = core.registered_nodes[entry.name]
	local half = math.floor(BED / 2)
	-- A plant that is rooted in its block takes the place of the ground.
	local y = def.drawtype == "plantlike_rooted" and GROUND_TOP or BASE_Y
	local param2 = def.place_param2 or 0
	if def.paramtype2 == "wallmounted" or def.paramtype2 == "colorwallmounted" then
		param2 = 1
	end
	local p1 = {x = entry.bed_x - half, y = y, z = entry.bed_z - half}
	local p2 = {x = entry.bed_x + half, y = y, z = entry.bed_z + half}
	local vmanip = VoxelManip()
	local emin, emax = vmanip:read_from_map(p1, p2)
	local area = VoxelArea(emin, emax)
	local data, params = vmanip:get_data(), vmanip:get_param2_data()
	local content = core.get_content_id(entry.name)
	for z = p1.z, p2.z do
		for x = p1.x, p2.x do
			local vi = area:index(x, y, z)
			data[vi] = content
			params[vi] = param2
		end
	end
	vmanip:set_data(data)
	vmanip:set_param2_data(params)
	vmanip:write_to_map(true)

	-- The piece of the path in front of the bed.
	local aisle_z = entry.source.aisle_z
	p1 = {x = entry.bed_x - BED_SLOT / 2, y = GROUND_TOP, z = aisle_z - 1}
	p2 = {x = entry.bed_x + BED_SLOT / 2 - 1, y = GROUND_TOP, z = aisle_z + 1}
	vmanip = VoxelManip()
	emin, emax = vmanip:read_from_map(p1, p2)
	area = VoxelArea(emin, emax)
	data = vmanip:get_data()
	local path = core.get_content_id("wl_catalog:path")
	for z = p1.z, p2.z do
		for x = p1.x, p2.x do
			data[area:index(x, GROUND_TOP, z)] = path
		end
	end
	vmanip:set_data(data)
	vmanip:write_to_map(true)
end

local built = storage:get_int("built") == 1
local measured = core.deserialize(storage:get_string("measured")) or {}

local function place(tree)
	local pos = {x = tree.x, y = BASE_Y + tree.offset, z = tree.z}
	if tree.grow then
		-- Something for the tree to start from, as a sapling would have.
		local ok, err = pcall(tree.grow, {x = tree.x, y = BASE_Y, z = tree.z})
		if not ok then
			core.log("warning", "[wl_catalog] " .. tree.id .. " did not grow: " .. tostring(err))
		end
		local size = measure(tree)
		local key = tree.id .. (tree.suffix or "")
		if size then
			measured[key] = size
			apply_measure(tree, size)
		else
			tree.failed = true
			measured[key] = {failed = true}
		end
	else
		local ok, result = pcall(core.place_schematic, pos, tree.schematic, "0", nil, false,
			"place_center_x, place_center_z")
		if not ok or not result then
			core.log("warning", "[wl_catalog] " .. tree.id .. " could not be placed: " .. tostring(result))
			tree.failed = true
			measured[tree.id .. (tree.suffix or "")] = {failed = true}
		end
	end
	if tree.chosen and not tree.failed then
		rewrite(tree)
	end
end

-- Places the trees one after the other. Each waits until the generator
-- has laid the ground below it.
local function build(index)
	local tree = plants.trees[index] or plants.copies[index - #plants.trees]
		or plants.selected[index - #plants.trees - #plants.copies]
	if not tree then
		local past = index - #plants.trees - #plants.copies - #plants.selected
		local plank = plants.planks[past]
		if plank then
			local z = plank.plank_z or PLANK_Z
			local p1 = {x = plank.plank_x - 2, y = GROUND_BOTTOM, z = z - 2}
			local p2 = {x = plank.plank_x + 2, y = BASE_Y + 3, z = z + 3}
			core.emerge_area(p1, p2, function(_, _, remaining)
				if remaining == 0 then
					core.after(0, function()
						pcall(place_planks, plank)
						build(index + 1)
					end)
				end
			end)
			return
		end
		local entry = plants.beds[past - #plants.planks]
		if not entry then
			storage:set_int("built", 1)
			storage:set_string("measured", core.serialize(measured))
			built = true
			core.log("action", "[wl_catalog] BUILT " .. #plants.trees .. " trees twice, " ..
				#plants.beds .. " beds")
			return
		end
		local p1 = {x = entry.bed_x - BED_SLOT / 2, y = GROUND_BOTTOM, z = entry.source.aisle_z - BED_SIDE - 3}
		local p2 = {x = entry.bed_x + BED_SLOT / 2, y = BASE_Y + 2, z = entry.source.aisle_z + BED_SIDE + 3}
		core.emerge_area(p1, p2, function(_, _, remaining)
			if remaining == 0 then
				core.after(0, function()
					local ok, err = pcall(place_bed, entry)
					if not ok then
						core.log("warning", "[wl_catalog] bed " .. entry.id .. " failed: " .. tostring(err))
					end
					build(index + 1)
				end)
			end
		end)
		return
	end
	local reach = math.ceil(math.max(tree.w, tree.d) / 2) + 2
	local p1 = {x = tree.x - reach, y = GROUND_BOTTOM, z = tree.z - reach}
	local p2 = {x = tree.x + reach, y = BASE_Y + math.max(tree.h, 16) + 4, z = tree.z + reach}
	core.emerge_area(p1, p2, function(_, _, remaining)
		if remaining == 0 then
			-- Not from inside the callback: the next request has to wait
			-- until this one has returned.
			core.after(0, function()
				place(tree)
				build(index + 1)
			end)
		end
	end)
end

--
-- Pages of blocks
--

local COLUMNS, ROWS = 12, 6
local PER_PAGE = COLUMNS * ROWS
local PAGE_W, PAGE_H = 24.4, 14.2

-- The pages: each holds blocks of one source only.
local pages = {}

local function paginate()
	local page
	for _, entry in ipairs(plants.nodes) do
		if not page or page.source ~= entry.source or #page.entries == PER_PAGE then
			page = {source = entry.source, entries = {}}
			pages[#pages + 1] = page
		end
		page.entries[#page.entries + 1] = entry
	end
	-- Trunks, planks and leaves once more, those of all sources side by
	-- side, to compare them.
	for _, kind in ipairs({"trunk", "planks", "leaves", "sapling"}) do
		local group = {prefix = kind:upper(), title = CATEGORY_LABEL[kind] .. " aller Quellen",
			license = "je Quelle, siehe deren Tafel", order = 1000 + CATEGORY_ORDER[kind]}
		page = nil
		for _, entry in ipairs(plants.nodes) do
			if entry.category == kind then
				if not page or #page.entries == PER_PAGE then
					page = {source = group, entries = {}, across = true}
					pages[#pages + 1] = page
				end
				page.entries[#page.entries + 1] = entry
			end
		end
	end
	local number = {}
	for _, one in ipairs(pages) do
		number[one.source] = (number[one.source] or 0) + 1
		one.number = number[one.source]
	end
	for _, one in ipairs(pages) do
		one.of = number[one.source]
	end
end

local function page_formspec(index, buttons)
	local page = pages[index]
	local esc = core.formspec_escape
	local fs = {
		"formspec_version[7]size[", PAGE_W, ",", PAGE_H, "]",
		"bgcolor[#22262cff;true]box[0,0;", PAGE_W, ",", PAGE_H, ";#22262c]",
		"style_type[label;font_size=*1.25;font=bold]",
		"label[0.3,0.45;", esc(page.across and (page.source.title ..
			"  (Seite " .. page.number .. " von " .. page.of .. ")") or
			(page.source.prefix .. "  " .. page.source.title .. "  –  " ..
			page.entries[1].id .. " bis " .. page.entries[#page.entries].id ..
			"  (Seite " .. page.number .. " von " .. page.of .. ")")), "]",
		"style_type[label;font_size=*0.8;font=normal]",
		"label[", PAGE_W - 9.2, ",0.45;", esc("Lizenz: " .. page.source.license:sub(1, 70)), "]",
	}
	for slot, entry in ipairs(page.entries) do
		local x = 0.2 + ((slot - 1) % COLUMNS) * 2.0
		local y = 0.9 + math.floor((slot - 1) / COLUMNS) * 2.2
		fs[#fs + 1] = "box[" .. x .. "," .. y .. ";1.9,2.1;" .. CATEGORY_COLOR[entry.category] .. "]"
		if buttons then
			fs[#fs + 1] = "item_image_button[" .. (x + 0.3) .. "," .. (y + 0.08) .. ";1.3,1.3;" ..
				esc(entry.name) .. ";pick_" .. entry.id .. ";]"
		else
			fs[#fs + 1] = "item_image[" .. (x + 0.3) .. "," .. (y + 0.08) .. ";1.3,1.3;" .. esc(entry.name) .. "]"
		end
		fs[#fs + 1] = "style_type[label;font_size=*1.0;font=bold]"
		fs[#fs + 1] = "label[" .. (x + 0.08) .. "," .. (y + 1.6) .. ";" .. esc(entry.id) .. "]"
		fs[#fs + 1] = "style_type[label;font_size=*0.62;font=normal]"
		fs[#fs + 1] = "label[" .. (x + 0.08) .. "," .. (y + 1.93) .. ";" .. esc(entry.short:sub(1, 18)) .. "]"
	end
	return table.concat(fs)
end

--
-- Using the catalogue in the game
--

local FORMNAME = "wl_catalog:plants"
local states = {}

local function show(name)
	local state = states[name]
	if not state then
		state = {page = 1}
		states[name] = state
	end
	if #pages == 0 then
		core.chat_send_player(name, "Die Quellen haben keine Pflanzen angemeldet.")
		return
	end
	state.page = math.max(1, math.min(#pages, state.page))
	local esc = core.formspec_escape
	local titles, selected = {}, 1
	for index, source in ipairs(plants.page_groups) do
		titles[index] = esc(source.across and source.title or source.prefix .. " " .. source.title)
		if source == pages[state.page].source then
			selected = index
		end
	end
	local fs = page_formspec(state.page, true) ..
		"style_type[label;font_size=*1.0;font=normal]" ..
		"button[0.2," .. (PAGE_H - 0.0) .. ";2,0.8;prev;<]" ..
		"button[2.3," .. (PAGE_H - 0.0) .. ";2,0.8;next;>]" ..
		"dropdown[4.6," .. (PAGE_H - 0.0) .. ";7,0.8;source;" .. table.concat(titles, ",") .. ";" .. selected .. ";true]" ..
		"label[12," .. (PAGE_H + 0.4) .. ";" .. esc(state.info or "Ein Klick legt den Block ins Inventar.") .. "]"
	fs = fs:gsub("size%[[^%]]*%]", "size[" .. PAGE_W .. "," .. (PAGE_H + 1.0) .. "]", 1)
	core.show_formspec(name, FORMNAME, fs)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return false
	end
	local name = player:get_player_name()
	local state = states[name]
	if not state or fields.quit then
		return true
	end
	if fields.prev then
		state.page = (state.page - 2) % #pages + 1
	elseif fields.next then
		state.page = state.page % #pages + 1
	elseif fields.source and plants.page_groups[tonumber(fields.source)]
			and plants.page_groups[tonumber(fields.source)] ~= pages[state.page].source then
		local source = plants.page_groups[tonumber(fields.source)]
		for index, page in ipairs(pages) do
			if page.source == source then
				state.page = index
				break
			end
		end
	else
		for field in pairs(fields) do
			local id = field:match("^pick_(.+)$")
			local entry = id and plants.node_by_id[id]
			if entry then
				player:get_inventory():add_item("main", entry.name)
				state.info = entry.id .. "  " .. entry.name .. "  (" .. CATEGORY_LABEL[entry.category] ..
					")  " .. entry.description
			end
		end
	end
	show(name)
	return true
end)

core.register_chatcommand("pflanzen", {
	description = "Öffnet die Tafeln der Blöcke",
	func = function(name)
		show(name)
		return true
	end,
})

local function go_to(player, tree)
	local pos = viewpoint(tree)
	pos.y = BASE_Y
	player:set_pos(pos)
	player:set_look_horizontal(0)
	player:set_look_vertical(0)
end

core.register_chatcommand("baum", {
	params = "[<Nummer>]",
	description = "Springt vor einen Baum, etwa /baum MT-T3. Ohne Nummer: die Reihen.",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end
		param = param:trim():upper()
		if param == "" then
			local lines = {}
			for _, source in ipairs(plants.sources) do
				if source.first_tree then
					lines[#lines + 1] = source.first_tree.id .. " bis " .. source.last_tree.id ..
						"  " .. source.title
				end
			end
			return true, "Reihen der Bäume:\n" .. table.concat(lines, "\n")
		end
		local tree = plants.tree_by_id[param] or plants.tree_by_id[param .. "-T1"]
		if not tree then
			return false, "Diese Nummer gibt es nicht."
		end
		go_to(player, tree)
		return true, tree.id .. "  " .. tree.name .. "  " .. tree.w .. " breit, " .. tree.h .. " hoch"
	end,
})

core.register_chatcommand("beet", {
	params = "<Nummer oder Quelle>",
	description = "Springt vor das Beet einer Bodenpflanze, etwa /beet EB12, oder an den Anfang eines Gangs, etwa /beet EB",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		param = param:trim():upper()
		local entry = plants.node_by_id[param]
		if not player then
			return false
		end
		for _, source in ipairs(plants.sources) do
			if source.prefix == param and source.aisle_z then
				player:set_pos({x = -4, y = BASE_Y, z = source.aisle_z})
				player:set_look_horizontal(-math.pi / 2)
				player:set_look_vertical(0)
				return true, "Gang von " .. source.title
			end
		end
		if not entry or not entry.bed_x then
			return false, "Zu dieser Nummer gibt es kein Beet."
		end
		local pos = bed_viewpoint(entry)
		pos.y = BASE_Y
		player:set_pos(pos)
		player:set_look_horizontal(bed_yaw(entry))
		player:set_look_vertical(0)
		return true, entry.id .. "  " .. entry.name
	end,
})

--
-- The list of sources: jump to the trees or the beds of one
--

local JUMPNAME = "wl_catalog:plants_jump"

local function go_to_aisle(player, source)
	player:set_pos({x = -4, y = BASE_Y, z = source.aisle_z})
	player:set_look_horizontal(-math.pi / 2)
	player:set_look_vertical(0)
end

local function show_jump(name)
	local esc = core.formspec_escape
	local rows = math.ceil(#plants.sources / 2)
	local height = 1.3 + rows * 0.9 + 0.3
	local fs = {
		"formspec_version[7]size[21.4,", height, "]",
		"style_type[label;font=bold]",
		"label[0.4,0.6;Quellen – springe zu den Bäumen oder zum Gang der Beete]",
		"style_type[label;font=normal]",
		"style[selection;bgcolor=#3a7a3a]",
		"button[14.4,0.15;6.6,0.8;selection;", esc("Auswahl für Wanderlore  (" .. #plants.selected .. ")"), "]",
	}
	for index, source in ipairs(plants.sources) do
		local x = 0.4 + (index > rows and 10.5 or 0)
		local y = 1.2 + ((index - 1) % rows) * 0.9
		local trees, beds = 0, 0
		for _, tree in ipairs(plants.trees) do
			trees = trees + (tree.source == source and 1 or 0)
		end
		for _, entry in ipairs(plants.beds) do
			beds = beds + (entry.source == source and 1 or 0)
		end
		fs[#fs + 1] = "label[" .. x .. "," .. (y + 0.4) .. ";" ..
			esc(source.prefix .. "  " .. source.title:sub(1, 30)) .. "]"
		if source.first_tree then
			fs[#fs + 1] = "button[" .. (x + 5.3) .. "," .. y .. ";2.4,0.8;tree_" .. index ..
				";" .. esc(trees .. " Bäume") .. "]"
		end
		if source.aisle_z then
			fs[#fs + 1] = "button[" .. (x + 7.8) .. "," .. y .. ";2.4,0.8;aisle_" .. index ..
				";" .. esc(beds .. " Beete") .. "]"
		end
	end
	core.show_formspec(name, JUMPNAME, table.concat(fs))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= JUMPNAME then
		return false
	end
	local name = player:get_player_name()
	if fields.selection and plants.selected[1] then
		go_to(player, plants.selected[1])
		core.close_formspec(name, JUMPNAME)
		core.chat_send_player(name, "Auswahl für Wanderlore: " .. #plants.selected ..
			" Formen. Die Reihe läuft nach rechts.")
		return true
	end
	for field in pairs(fields) do
		local kind, index = field:match("^(%a+)_(%d+)$")
		local source = index and plants.sources[tonumber(index)]
		if source and kind == "tree" and source.first_tree then
			go_to(player, source.first_tree)
			core.close_formspec(name, JUMPNAME)
			core.chat_send_player(name, source.title .. ": " .. source.first_tree.id .. " bis " ..
				source.last_tree.id .. ". Die Reihe läuft nach rechts.")
		elseif source and kind == "aisle" and source.aisle_z then
			go_to_aisle(player, source)
			core.close_formspec(name, JUMPNAME)
			core.chat_send_player(name, "Gang von " .. source.title .. ". Er läuft geradeaus.")
		end
	end
	return true
end)

local KINDNAME = "wl_catalog:plants_kinds"

local function show_kinds(name)
	local esc = core.formspec_escape
	local columns = 3
	local rows = math.ceil(#plants.kinds / columns)
	local fs = {
		"formspec_version[7]size[21.4,", 1.3 + rows * 0.9 + 0.3, "]",
		"style_type[label;font=bold]",
		"label[0.4,0.6;Bäume nach Art – jede Reihe zeigt die Bäume aller Quellen]",
		"style[selection;bgcolor=#3a7a3a]",
		"button[14.4,0.15;6.6,0.8;selection;", esc("Auswahl für Wanderlore  (" .. #plants.selected .. ")"), "]",
	}
	for index, row in ipairs(plants.kinds) do
		local x = 0.4 + math.floor((index - 1) / rows) * 7
		local y = 1.2 + ((index - 1) % rows) * 0.9
		fs[#fs + 1] = "button[" .. x .. "," .. y .. ";6.8,0.8;kind_" .. index .. ";" ..
			esc(row.title:sub(1, 40) .. "  (" .. #row.trees .. ")") .. "]"
	end
	core.show_formspec(name, KINDNAME, table.concat(fs))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= KINDNAME then
		return false
	end
	local name = player:get_player_name()
	if fields.selection and plants.selected[1] then
		go_to(player, plants.selected[1])
		core.close_formspec(name, KINDNAME)
		core.chat_send_player(name, "Auswahl für Wanderlore: " .. #plants.selected ..
			" Formen. Die Reihe läuft nach rechts.")
		return true
	end
	for field in pairs(fields) do
		local row = plants.kinds[tonumber(field:match("^kind_(%d+)$") or "")]
		if row then
			go_to(player, row.trees[1])
			core.close_formspec(name, KINDNAME)
			core.chat_send_player(name, row.title .. ": " .. #row.trees .. " Einträge. Die Reihe läuft nach rechts.")
		end
	end
	return true
end)

core.register_chatcommand("bretter", {
	description = "Springt zu den Brettern aller Quellen, als kleine Wände nebeneinander",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player or not plants.planks[1] then
			return false
		end
		player:set_pos({x = 0, y = BASE_Y, z = PLANK_Z - 6})
		player:set_look_horizontal(0)
		player:set_look_vertical(0)
		return true, #plants.planks .. " Bretter. Die Reihe läuft nach rechts."
	end,
})

core.register_chatcommand("auswahl", {
	description = "Springt zur Auswahl für Wanderlore: die gewählten Formen mit den gewählten Blöcken",
	func = function(name)
		local player = core.get_player_by_name(name)
		local first = plants.selected[1]
		if not player or not first then
			return false, "Es ist nichts ausgewählt."
		end
		go_to(player, first)
		return true, "Auswahl: " .. #plants.selected .. " Formen. Die Reihe läuft nach rechts."
	end,
})

core.register_chatcommand("arten", {
	description = "Öffnet die Liste der Baumarten, um zu ihren Reihen zu springen",
	func = function(name)
		show_kinds(name)
		return true
	end,
})

core.register_craftitem("wl_catalog:plant_kinds", {
	description = "Bäume nach Art: zu einer Reihe springen",
	inventory_image = "default_diamond.png",
	on_use = function(_, user)
		show_kinds(user:get_player_name())
	end,
})

core.register_chatcommand("quellen", {
	description = "Öffnet die Liste der Quellen, um zu ihren Bäumen oder Beeten zu springen",
	func = function(name)
		show_jump(name)
		return true
	end,
})

core.register_craftitem("wl_catalog:plant_compass", {
	description = "Quellen: zu Bäumen und Beeten springen",
	inventory_image = "default_mese_crystal.png",
	on_use = function(_, user)
		show_jump(user:get_player_name())
	end,
})

core.register_craftitem("wl_catalog:plant_book", {
	description = "Tafeln der Pflanzen",
	inventory_image = "default_book.png",
	on_use = function(_, user)
		show(user:get_player_name())
	end,
})

-- Numbers above the trees near the player.
local huds = {}

local function update_huds()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local shown = huds[name] or {}
		huds[name] = shown
		local pos = player:get_pos()
		for _, tree in ipairs(plants.trees) do
			local near = math.abs(tree.z - pos.z) < 160 and math.abs(tree.x - pos.x) < 140
			if near and not shown[tree.id] then
				shown[tree.id] = player:hud_add({
					type = "waypoint",
					name = tree.id .. " " .. tree.name,
					text = "",
					precision = 0,
					number = 0xFFFFFF,
					world_pos = {x = tree.x, y = BASE_Y + tree.h + tree.offset + 2, z = tree.z},
				})
			elseif not near and shown[tree.id] then
				player:hud_remove(shown[tree.id])
				shown[tree.id] = nil
			end
		end
		for _, tree in ipairs(plants.standing) do
			local key = tree.id .. tree.suffix
			local near = math.abs(tree.z - pos.z) < 160 and math.abs(tree.x - pos.x) < 140
			if near and not shown[key] then
				shown[key] = player:hud_add({
					type = "waypoint",
					name = tree.id .. " " .. tree.name,
					text = "",
					precision = 0,
					number = 0xFFFFFF,
					world_pos = {x = tree.x, y = BASE_Y + tree.h + tree.offset + 2, z = tree.z},
				})
			elseif not near and shown[key] then
				player:hud_remove(shown[key])
				shown[key] = nil
			end
		end
		for _, entry in ipairs(plants.planks) do
			local key = entry.id .. " planks" .. (entry.plank_z or "")
			local plank_z = entry.plank_z or PLANK_Z
			local near = math.abs(plank_z - pos.z) < 60 and math.abs(entry.plank_x - pos.x) < 60
			if near and not shown[key] then
				shown[key] = player:hud_add({
					type = "waypoint",
					name = entry.id .. " " .. entry.short,
					text = "",
					precision = 0,
					number = 0xFFFFFF,
					world_pos = {x = entry.plank_x, y = BASE_Y + 3.6, z = plank_z},
				})
			elseif not near and shown[key] then
				player:hud_remove(shown[key])
				shown[key] = nil
			end
		end
		for index, sign in ipairs(plants.signs) do
			local key = "sign" .. index
			local near = math.abs(sign.pos.z - pos.z) < 400 and math.abs(sign.pos.x - pos.x) < 400
			if near and not shown[key] then
				shown[key] = player:hud_add({
					type = "waypoint",
					name = sign.text,
					text = "",
					precision = 0,
					number = 0xFFE08A,
					world_pos = sign.pos,
				})
			elseif not near and shown[key] then
				player:hud_remove(shown[key])
				shown[key] = nil
			end
		end
		for _, entry in ipairs(plants.beds) do
			local near = math.abs(entry.bed_z - pos.z) < 40 and math.abs(entry.bed_x - pos.x) < 50
			if near and not shown[entry.id] then
				shown[entry.id] = player:hud_add({
					type = "waypoint",
					name = entry.id .. " " .. entry.short,
					text = "",
					precision = 0,
					number = 0xFFFFFF,
					world_pos = {x = entry.bed_x, y = BASE_Y + 2.5, z = entry.bed_z},
				})
			elseif not near and shown[entry.id] then
				player:hud_remove(shown[entry.id])
				shown[entry.id] = nil
			end
		end
	end
	core.after(2, update_huds)
end

--
-- Pictures
--
-- With the setting wl_catalog_shots the catalogue shows every page of
-- blocks and then every tree for a moment and writes a line to the log
-- for each. A script outside the game takes a screenshot at each line.

local SHOTNAME = "wl_catalog:plants_shot"
local shot_number = 0

-- wl_catalog_shots_only limits the pictures to some sources, named by
-- their prefixes.
local only
do
	local setting = core.settings:get("wl_catalog_shots_only") or ""
	for prefix in setting:gmatch("%S+") do
		only = only or {}
		only[prefix:upper()] = true
	end
end
local function wanted(source)
	return not only or only[source.prefix]
end

-- wl_catalog_shots_what limits them to some kinds: pages, trees, beds.
local what
do
	local setting = core.settings:get("wl_catalog_shots_what") or ""
	for kind in setting:gmatch("%S+") do
		what = what or {}
		what[kind] = true
	end
end

-- A plain sky, nothing on the screen, and a player who stays where put.
local function prepare_view(player)
	player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false, wielditem = false,
		breathbar = false, minimap = false, minimap_radar = false, basic_debug = false, chat = false})
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	player:set_fov(FOV, false, 0)
	local inventory = player:get_inventory()
	inventory:set_size("hand", 1)
	inventory:set_stack("hand", 1, "wl_catalog:no_hand")
	inventory:set_list("main", {})
	player:set_sky({type = "plain", base_color = "#a9c8e6", clouds = false})
	player:set_clouds({density = 0})
	player:set_sun({visible = false, sunrise_visible = false})
	player:set_moon({visible = false})
	player:set_stars({visible = false})
	player:override_day_night_ratio(1)
end

local function shot(label)
	shot_number = shot_number + 1
	core.log("action", "[wl_catalog] SHOT " .. shot_number .. " " .. label)
end

local function shoot_beds(name, index)
	local player = core.get_player_by_name(name)
	local entry = plants.beds[index]
	if not player or not entry or what and not what.beds then
		core.log("action", "[wl_catalog] SHOTS DONE")
		return
	end
	if not wanted(entry.source) then
		return shoot_beds(name, index + 1)
	end
	local pos = bed_viewpoint(entry)
	pos.y = pos.y - 1.625
	player:set_pos(pos)
	player:set_look_horizontal(bed_yaw(entry))
	player:set_look_vertical(BED_PITCH)
	-- The first beds of an aisle need longer, their surroundings are new.
	core.after(entry.bed_x == 0 and 3.0 or 1.4, function()
		shot("bed " .. entry.id .. " " .. entry.short:gsub("[^%w_]", "_") .. " " .. entry.category)
		core.after(0.9, shoot_beds, name, index + 1)
	end)
end

local function shoot_selection(name, index)
	local player = core.get_player_by_name(name)
	local tree = plants.selected[index]
	if player and not tree and plants.selected[index - 1] and not (what and not what.selection) then
		-- At the end one picture of all forms side by side, to compare
		-- their sizes. The forms of the first species only.
		local first, last, height = plants.selected[1], nil, 0
		for _, one in ipairs(plants.selected) do
			if one.z == first.z then
				last = one
				height = math.max(height, one.h)
			end
		end
		local left, right = first.x - view_of(first) / 2, last.x + view_of(last) / 2
		local distance = 0.66 * math.max((right - left) / 1.15, height * 1.2) / (2 * HALF)
		player:set_pos({x = (left + right) / 2, y = BASE_Y + height / 2 - 1.625, z = first.z - distance})
		player:set_look_horizontal(0)
		player:set_look_vertical(0)
		core.after(8, function()
			shot("row " .. first.shot_id:match("^(%u+)") .. " Reihe 0x0")
			core.after(1.0, shoot_beds, name, 1)
		end)
		return
	end
	if not player or not tree or what and not what.selection then
		return shoot_beds(name, 1)
	end
	if tree.failed then
		return shoot_selection(name, index + 1)
	end
	local pos = viewpoint(tree)
	pos.y = pos.y - 1.625
	player:set_pos(pos)
	player:set_look_horizontal(0)
	player:set_look_vertical(0)
	core.after(2.5 + view_of(tree) / 40, function()
		shot("sel " .. tree.shot_id .. " " .. tree.label:gsub("[^%w_.-]", "_") .. " " .. tree.w .. "x" .. tree.h)
		core.after(1.0, shoot_selection, name, index + 1)
	end)
end

local function shoot_trees(name, index)
	local player = core.get_player_by_name(name)
	local tree = plants.trees[index]
	if not player or not tree or what and not what.trees then
		return shoot_selection(name, 1)
	end
	if tree.failed or not wanted(tree.source) then
		return shoot_trees(name, index + 1)
	end
	local pos = viewpoint(tree)
	-- The position of a player is that of the feet.
	pos.y = pos.y - 1.625
	player:set_pos(pos)
	player:set_look_horizontal(0)
	player:set_look_vertical(0)
	-- Far trees need longer until the client has their blocks.
	local wait = 2.0 + view_of(tree) / 40
	core.after(wait, function()
		shot("tree " .. tree.id .. " " .. tree.name:gsub("[^%w_]", "_") .. " " .. tree.w .. "x" .. tree.h)
		core.after(1.0, shoot_trees, name, index + 1)
	end)
end

local function shoot_pages(name, index)
	if not core.get_player_by_name(name) then
		return
	end
	local page = pages[index]
	if not page or what and not what.pages then
		core.close_formspec(name, SHOTNAME)
		core.after(1.0, shoot_trees, name, 1)
		return
	end
	if not page.across and not wanted(page.source) then
		return shoot_pages(name, index + 1)
	end
	core.show_formspec(name, SHOTNAME, page_formspec(index, false))
	core.after(1.6, function()
		shot("page " .. page.source.prefix .. " " .. page.number)
		core.after(1.0, shoot_pages, name, index + 1)
	end)
end

local function start_shots(name)
	if not built then
		core.after(1, start_shots, name)
		return
	end
	-- Once more: some sources set a sky of their own after a player joined.
	local player = core.get_player_by_name(name)
	if player then
		prepare_view(player)
	end
	shoot_pages(name, 1)
end

--
-- Start
--

-- A hand that reaches nothing, so that no block is outlined in a picture.
core.register_item("wl_catalog:no_hand", {
	type = "none",
	wield_image = "blank.png",
	range = 0,
})

core.register_on_mods_loaded(function()
	-- Nothing may grow, spread or wither while one looks at it. The game
	-- lets mushrooms die in daylight, for one.
	for _, list in ipairs({core.registered_abms, core.registered_lbms}) do
		for index = #list, 1, -1 do
			list[index] = nil
		end
	end
	collect_nodes()
	for _, entry in ipairs(plants.nodes) do
		plant_category[entry.name] = entry.category
	end
	collect_trees()
	lay_out()
	lay_out_kinds()
	lay_out_selection()
	lay_out_planks()
	lay_out_beds()
	paginate()
	plants.page_groups = {}
	for _, page in ipairs(pages) do
		if plants.page_groups[#plants.page_groups] ~= page.source then
			page.source.across = page.across
			plants.page_groups[#plants.page_groups + 1] = page.source
		end
	end
	plants.standing = {}
	for _, list in ipairs({plants.copies, plants.selected}) do
		for _, copy in ipairs(list) do
			plants.standing[#plants.standing + 1] = copy
		end
	end
	for _, copy in ipairs(plants.standing) do
		local size = measured[copy.id .. copy.suffix]
		if size and size.failed then
			copy.failed = true
		elseif size then
			apply_measure(copy, size)
		end
	end
	-- For the sheets by kind: which tree stands in which row.
	local lines = {}
	for index, row in ipairs(plants.kinds) do
		for _, copy in ipairs(row.trees) do
			lines[#lines + 1] = table.concat({index, row.title, copy.id, copy.species}, "\t")
		end
	end
	core.safe_file_write(core.get_worldpath() .. "/catalog_kinds.tsv", table.concat(lines, "\n") .. "\n")

	local seen = {}
	local function note(source)
		if not seen[source] then
			seen[source] = true
			plants.sources[#plants.sources + 1] = source
		end
	end
	for _, entry in ipairs(plants.nodes) do
		note(entry.source)
	end
	for _, tree in ipairs(plants.trees) do
		note(tree.source)
		tree.source.first_tree = tree.source.first_tree or tree
		tree.source.last_tree = tree
		local size = measured[tree.id]
		if size and size.failed then
			tree.failed = true
		elseif size then
			apply_measure(tree, size)
		end
	end
	table.sort(plants.sources, function(a, b)
		return a.order < b.order
	end)

	-- What stands where depends on the sources and on this file. A map
	-- built for another arrangement cannot be repaired from here.
	local arrangement = #plants.trees .. " " .. #plants.copies .. " " .. #plants.beds .. " " ..
		#plants.kinds .. " " .. #plants.selected .. " " .. #plants.planks
	if built and storage:get_string("arrangement") ~= arrangement then
		plants.outdated = true
		core.log("warning", "[wl_catalog] the map was built for another arrangement; run scripts/setup.sh")
	end
	storage:set_string("arrangement", arrangement)

	core.log("action", "[wl_catalog] plants: " .. #plants.nodes .. " blocks on " .. #pages ..
		" pages, " .. #plants.trees .. " trees, " .. #plants.beds .. " beds from " .. #plants.sources .. " sources")
	for _, source in ipairs(plants.sources) do
		local blocks, trees = 0, 0
		for _, entry in ipairs(plants.nodes) do
			blocks = blocks + (entry.source == source and 1 or 0)
		end
		for _, tree in ipairs(plants.trees) do
			trees = trees + (tree.source == source and 1 or 0)
		end
		core.log("action", "[wl_catalog] source " .. source.prefix .. " | " .. source.title ..
			" | " .. blocks .. " | " .. trees)
	end
	if not built then
		core.after(0, build, 1)
	end
	if not SHOTS then
		core.after(2, update_huds)
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)
	for _, priv in ipairs({"fly", "fast", "noclip", "teleport", "give"}) do
		privs[priv] = true
	end
	core.set_player_privs(name, privs)
	player:override_day_night_ratio(1)
	player:set_clouds({density = 0})

	if SHOTS then
		prepare_view(player)
		player:set_pos({x = 0, y = BASE_Y, z = 0})
		core.after(4, start_shots, name)
		return
	end

	local inventory = player:get_inventory()
	for _, item in ipairs({"wl_catalog:plant_book", "wl_catalog:plant_compass", "wl_catalog:plant_kinds"}) do
		if not inventory:contains_item("main", item) then
			inventory:add_item("main", item)
		end
	end
	if player:get_pos().y < GROUND_BOTTOM or player:get_meta():get_int("wl_catalog_placed") == 0 then
		player:get_meta():set_int("wl_catalog_placed", 1)
		local first = plants.trees[1]
		if first then
			go_to(player, first)
		else
			player:set_pos({x = 0, y = BASE_Y, z = 0})
		end
	end
	if plants.outdated then
		core.chat_send_player(name, core.colorize("#ff6040", "Die Karte dieser Welt ist veraltet: Bäume und " ..
			"Beete stehen nicht dort, wo die Listen hinspringen. Luanti beenden, scripts/setup.sh " ..
			"ausführen, neu starten."))
	end
	core.chat_send_player(name, "Katalog der Pflanzen: " .. #plants.nodes .. " Blöcke, " ..
		#plants.trees .. " Bäume. /quellen oder der Kristall im Inventar springt zu den Bäumen oder Beeten einer Quelle, " ..
		"/arten oder der Diamant zu den Bäumen nach Art, /auswahl zur Auswahl für Wanderlore, " ..
		"/bretter zu den Brettern aller Quellen. " ..
		"/pflanzen zeigt die Tafeln der Blöcke, /baum die Reihen der Bäume, " ..
		"/baum <Nummer> springt vor einen Baum, /beet <Nummer> vor das Beet einer Bodenpflanze. " ..
		"Fliegen mit K.")
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	states[name] = nil
	huds[name] = nil
end)

core.log("action", "[wl_catalog] loaded")
