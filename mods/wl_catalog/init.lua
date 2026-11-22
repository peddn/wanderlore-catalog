-- wl_catalog: shows every creature model of the loaded mods in a window,
-- with its textures and animations, so that one can pick from them.
--
-- The catalogue does not spawn the creatures of the other mods. It reads
-- what they registered and shows the model itself, so nothing walks away
-- or attacks.

local catalog = {
	entries = {},   -- sorted list of creatures
	by_id = {},     -- "N12" -> entry
	sources = {},   -- list of sources that show at least one creature
}

local FORMNAME = "wl_catalog:main"
local SHOTNAME = "wl_catalog:shot"

-- Sources as written by scripts/setup.sh. Without the file the catalogue
-- still works, it then knows no titles, licences or number prefixes.
local source_info = {}
do
	local path = core.get_worldpath() .. "/catalog_sources.lua"
	local file = io.open(path, "r")
	if file then
		file:close()
		source_info = dofile(path)
	end
end

local KIND_LABEL = {
	monster = "Monster",
	animal = "Tier",
	npc = "Figur",
}

--
-- Reading what the other mods registered
--

-- Returns the animations of a definition as a sorted list of
-- {name, from, to, speed}. Mobs Redo writes them as walk_start/walk_end,
-- Creatura and Mobkit as walk = {range = {x, y}, speed}.
local function read_animations(def)
	local list = {}
	local source = def.animations or def.animation
	if type(source) ~= "table" then
		return list
	end
	for name, value in pairs(source) do
		if type(value) == "table" and type(value.range) == "table" then
			list[#list + 1] = {
				name = tostring(name),
				from = value.range.x or 0,
				to = value.range.y or 0,
				speed = math.abs(value.speed or 15),
			}
		end
	end
	if #list == 0 then
		for key, value in pairs(source) do
			local name = type(key) == "string" and key:match("^(.*)_start$")
			local last = name and (source[name .. "_end"] or source[name .. "_stop"])
			if name and type(value) == "number" and type(last) == "number" then
				list[#list + 1] = {
					name = name,
					from = value,
					to = last,
					speed = source[name .. "_speed"] or source.speed_normal or 15,
				}
			end
		end
	end
	-- Some mods give a range backwards to play it in reverse.
	for _, animation in ipairs(list) do
		if animation.from > animation.to then
			animation.from, animation.to = animation.to, animation.from
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

-- Returns the texture variants of a definition as a list of lists.
local function read_variants(def, props)
	local variants = {}
	local function add(list)
		if type(list) ~= "table" then
			return
		end
		if type(list[1]) == "table" then
			-- Mobs Redo: a list of variants, each a list of textures.
			for _, variant in ipairs(list) do
				variants[#variants + 1] = variant
			end
		elseif def._creatura_mob or def.male_textures or def.female_textures then
			-- Creatura and Mob Core: each entry is one variant.
			for _, texture in ipairs(list) do
				variants[#variants + 1] = {texture}
			end
		elseif #list > 0 then
			variants[#variants + 1] = list
		end
	end
	add(def.texture_list)
	if #variants == 0 then
		add(props.textures or def.textures)
	end
	add(def.male_textures)
	add(def.female_textures)
	if #variants == 0 then
		variants[1] = {"blank.png"}
	end
	return variants
end

local function read_health(def, props)
	local low = def.hp_min
	local high = props.hp_max or def.hp_max or def.max_health or def.max_hp
	if low and high and low ~= high then
		return low .. " bis " .. high
	end
	return tostring(high or low or "?")
end

local function read_damage(def)
	if type(def.damage) == "number" then
		return tostring(def.damage)
	end
	return "?"
end

local function collect()
	local per_source = {}
	for name, def in pairs(core.registered_entities) do
		local props = def.initial_properties or {}
		local mesh = props.mesh or def.mesh
		local visual = props.visual or def.visual
		local animations = read_animations(def)
		local is_creature = KIND_LABEL[def.type] or def._creatura_mob or #animations > 0
		local mod = name:match("^([^:]+):")
		if visual == "mesh" and mesh and is_creature and mod ~= "wl_catalog" then
			per_source[mod] = per_source[mod] or {}
			table.insert(per_source[mod], {
				name = name,
				mod = mod,
				mesh = mesh,
				kind = KIND_LABEL[def.type] or "unbekannt",
				health = read_health(def, props),
				damage = read_damage(def),
				variants = read_variants(def, props),
				animations = animations,
				visual_size = props.visual_size or def.visual_size or {x = 1, y = 1},
				collisionbox = props.collisionbox or def.collisionbox,
			})
		end
	end

	local mods = {}
	for mod in pairs(per_source) do
		mods[#mods + 1] = mod
	end
	table.sort(mods, function(a, b)
		local order_a = source_info[a] and source_info[a].order or 1000
		local order_b = source_info[b] and source_info[b].order or 1000
		if order_a ~= order_b then
			return order_a < order_b
		end
		return a < b
	end)

	for _, mod in ipairs(mods) do
		local info = source_info[mod] or {}
		local prefix = info.prefix ~= "" and info.prefix or mod:sub(1, 1):upper()
		local list = per_source[mod]
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
		for index, entry in ipairs(list) do
			entry.id = prefix .. index
			entry.short = entry.name:match(":(.*)$")
			catalog.entries[#catalog.entries + 1] = entry
			catalog.by_id[entry.id] = entry
		end
		catalog.sources[#catalog.sources + 1] = {
			mod = mod,
			title = info.title or mod,
			license = info.license or "unbekannt",
			url = info.url or "",
			count = #list,
		}
	end
	core.log("action", "[wl_catalog] " .. #catalog.entries .. " creatures from " ..
		#catalog.sources .. " sources")
end

core.register_on_mods_loaded(collect)

--
-- The window
--

local states = {}   -- player name -> what that player looks at

-- Picks the animation shown first: standing if the creature has it.
local function default_animation(entry)
	for index, animation in ipairs(entry.animations) do
		if animation.name == "stand" then
			return index
		end
	end
	return 1
end

local function select_entry(state, entry)
	state.entry = entry
	state.variant = 1
	state.animation = default_animation(entry)
end

local function get_state(name)
	local state = states[name]
	if not state then
		state = {filter = 0, animation = 1, variant = 1, spin = false, rows = {}}
		states[name] = state
	end
	if not state.entry and catalog.entries[1] then
		select_entry(state, catalog.entries[1])
	end
	return state
end

local function source_of(entry)
	for _, source in ipairs(catalog.sources) do
		if source.mod == entry.mod then
			return source
		end
	end
end

local function model_element(entry, state, x, y, w, h)
	local textures = {}
	for _, texture in ipairs(entry.variants[state.variant] or entry.variants[1]) do
		textures[#textures + 1] = core.formspec_escape(texture)
	end
	local animation = entry.animations[state.animation]
	local range = animation and (animation.from .. "," .. animation.to) or "0,0"
	local speed = animation and animation.speed or 0
	return ("model[%f,%f;%f,%f;model;%s;%s;0,200;%s;true;%s;%s]"):format(
		x, y, w, h, core.formspec_escape(entry.mesh), table.concat(textures, ","),
		state.spin and "true" or "false", range, speed)
end

local function build_formspec(name)
	local state = get_state(name)
	local entry = state.entry
	local fs = {
		"formspec_version[7]size[23,13.6]",
		"label[0.3,0.5;Wanderlore-Katalog: ", #catalog.entries, " Wesen aus ",
		#catalog.sources, " Quellen]",
	}
	if not entry then
		fs[#fs + 1] = "label[0.3,1.5;Keine Wesen gefunden. Sind die Quellen geladen?]"
		return table.concat(fs)
	end

	-- Filter by source.
	local options = {"Alle Quellen"}
	for _, source in ipairs(catalog.sources) do
		options[#options + 1] = core.formspec_escape(source.title .. " (" .. source.count .. ")")
	end
	fs[#fs + 1] = "dropdown[0.3,0.9;6.6,0.7;filter;" .. table.concat(options, ",") ..
		";" .. (state.filter + 1) .. ";true]"

	-- List of creatures.
	local rows, items, selected = {}, {}, 1
	local filter_mod = state.filter > 0 and catalog.sources[state.filter].mod
	for _, candidate in ipairs(catalog.entries) do
		if not filter_mod or candidate.mod == filter_mod then
			rows[#rows + 1] = candidate
			items[#items + 1] = core.formspec_escape(candidate.id .. "  " .. candidate.short)
			if candidate == entry then
				selected = #rows
			end
		end
	end
	state.rows = rows
	fs[#fs + 1] = "textlist[0.3,1.8;6.6,11.5;list;" .. table.concat(items, ",") ..
		";" .. selected .. ";false]"

	-- The model.
	fs[#fs + 1] = "box[7.2,0.9;9.6,9.6;#59606a]"
	fs[#fs + 1] = model_element(entry, state, 7.2, 0.9, 9.6, 9.6)
	fs[#fs + 1] = "label[7.3,10.75;Mit der Maus drehen.]"
	fs[#fs + 1] = "button[13.3,10.5;3.5,0.6;spin;" ..
		(state.spin and "Drehen anhalten" or "Von selbst drehen") .. "]"

	-- Animations.
	if #entry.animations == 0 then
		fs[#fs + 1] = "label[7.3,11.6;Keine Animationen angegeben.]"
	end
	for index, animation in ipairs(entry.animations) do
		if index > 12 then
			break
		end
		local column = (index - 1) % 4
		local row = math.floor((index - 1) / 4)
		local label = core.formspec_escape(animation.name)
		if index == state.animation then
			label = "> " .. label
		end
		fs[#fs + 1] = ("button[%f,%f;2.3,0.6;anim_%d;%s]"):format(
			7.2 + column * 2.43, 11.3 + row * 0.72, index, label)
	end

	-- Details.
	local source = source_of(entry)
	local animation = entry.animations[state.animation]
	local lines = {
		entry.id .. "  " .. entry.short,
		"",
		"Quelle: " .. source.title,
		"Art: " .. entry.kind,
		"Leben: " .. entry.health,
		"Schaden: " .. entry.damage,
		"",
		"Technischer Name: " .. entry.name,
		"Modell: " .. entry.mesh,
		"Animation: " .. (animation and
			(animation.name .. ", Bild " .. animation.from .. " bis " .. animation.to) or "keine"),
		"",
		"Lizenz der Quelle: " .. source.license,
		source.url,
	}
	fs[#fs + 1] = "textarea[17.1,0.9;5.6,8.2;;;" ..
		core.formspec_escape(table.concat(lines, "\n")) .. "]"

	-- Texture variants.
	fs[#fs + 1] = "label[17.1,9.5;Textur " .. state.variant .. " von " .. #entry.variants .. "]"
	fs[#fs + 1] = "button[17.1,9.8;2.7,0.7;variant_prev;Vorige]"
	fs[#fs + 1] = "button[20,9.8;2.7,0.7;variant_next;Nächste]"

	fs[#fs + 1] = "button[17.1,11.3;5.6,0.8;place;In die Welt stellen]"
	fs[#fs + 1] = "button_exit[17.1,12.3;5.6,0.8;close;Schließen]"
	return table.concat(fs)
end

local function show(name)
	core.show_formspec(name, FORMNAME, build_formspec(name))
end

--
-- Placing a model in the world
--

core.register_entity("wl_catalog:display", {
	initial_properties = {
		visual = "mesh",
		mesh = "",
		textures = {},
		physical = false,
		static_save = false,
		collisionbox = {-0.5, 0, -0.5, 0.5, 1, 0.5},
	},
	-- A punch removes the model again.
	on_punch = function(self)
		self.object:remove()
	end,
})

local function place(player, state)
	local entry = state.entry
	local pos = player:get_pos()
	local dir = core.yaw_to_dir(player:get_look_horizontal())
	local target = vector.add(pos, vector.multiply(dir, 5))
	target.y = pos.y + 0.1
	local object = core.add_entity(target, "wl_catalog:display")
	if not object then
		return
	end
	local box = entry.collisionbox or {-0.5, 0, -0.5, 0.5, 1, 0.5}
	object:set_properties({
		mesh = entry.mesh,
		textures = entry.variants[state.variant] or entry.variants[1],
		visual_size = entry.visual_size,
		collisionbox = box,
		selectionbox = box,
		nametag = entry.id .. " " .. entry.short,
	})
	-- Many models stand with their feet at the bottom of the collision
	-- box, which lies below the entity position.
	if box[2] < 0 then
		target.y = target.y - box[2]
		object:set_pos(target)
	end
	object:set_yaw(player:get_look_horizontal() + math.pi)
	local animation = entry.animations[state.animation]
	if animation then
		object:set_animation({x = animation.from, y = animation.to}, animation.speed, 0, true)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	local state = get_state(name)
	if fields.quit then
		return true
	end

	if fields.list then
		local event = core.explode_textlist_event(fields.list)
		local entry = state.rows[event.index]
		if event.type ~= "INV" and entry and entry ~= state.entry then
			select_entry(state, entry)
			show(name)
		end
		return true
	end
	if fields.filter then
		local filter = (tonumber(fields.filter) or 1) - 1
		if filter ~= state.filter and filter >= 0 and filter <= #catalog.sources then
			state.filter = filter
			local mod = filter > 0 and catalog.sources[filter].mod
			if mod and state.entry.mod ~= mod then
				for _, entry in ipairs(catalog.entries) do
					if entry.mod == mod then
						select_entry(state, entry)
						break
					end
				end
			end
			show(name)
			return true
		end
	end

	local entry = state.entry
	if not entry then
		return true
	end
	if fields.spin then
		state.spin = not state.spin
	elseif fields.variant_next then
		state.variant = state.variant % #entry.variants + 1
	elseif fields.variant_prev then
		state.variant = (state.variant - 2) % #entry.variants + 1
	elseif fields.place then
		place(player, state)
		core.close_formspec(name, FORMNAME)
		core.chat_send_player(name, entry.id .. " steht vor dir. Ein Schlag entfernt es wieder. " ..
			"Zurück zum Katalog mit /katalog.")
		return true
	else
		for index in ipairs(entry.animations) do
			if fields["anim_" .. index] then
				state.animation = index
			end
		end
	end
	show(name)
	return true
end)

core.register_chatcommand("katalog", {
	description = "Öffnet den Katalog der Wesen",
	func = function(name)
		show(name)
		return true
	end,
})

core.register_craftitem("wl_catalog:book", {
	description = "Katalog der Wesen",
	inventory_image = "default_book.png",
	on_use = function(_, user)
		show(user:get_player_name())
	end,
})

core.register_on_leaveplayer(function(player)
	states[player:get_player_name()] = nil
end)

--
-- Pictures of every creature, one after the other
--
-- With the setting wl_catalog_shots the catalogue shows each creature
-- alone in a window for a moment and writes its number to the log. A
-- script outside the game takes a screenshot at each line.

local function run_shots(name, index)
	local entry = catalog.entries[index]
	if not entry or not core.get_player_by_name(name) then
		core.log("action", "[wl_catalog] SHOTS DONE")
		return
	end
	local state = {variant = 1, animation = default_animation(entry), spin = false}
	local fs = "formspec_version[7]size[12,12.8]bgcolor[#59606aff;true]" ..
		"box[0,0;12,12.8;#59606a]" ..
		model_element(entry, state, 0.2, 0.2, 11.6, 11.4) ..
		"style_type[label;font_size=*1.6]" ..
		"label[0.4,12.2;" .. core.formspec_escape(entry.id .. "  " .. entry.short) .. "]"
	core.show_formspec(name, SHOTNAME, fs)
	core.after(1.0, function()
		core.log("action", "[wl_catalog] SHOT " .. index .. " " .. entry.id .. " " .. entry.name)
	end)
	core.after(2.4, run_shots, name, index + 1)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local inventory = player:get_inventory()
	if not inventory:contains_item("main", "wl_catalog:book") then
		inventory:add_item("main", "wl_catalog:book")
	end
	if core.settings:get_bool("wl_catalog_shots", false) then
		core.after(4, run_shots, name, 1)
	else
		core.after(1, show, name)
	end
end)
