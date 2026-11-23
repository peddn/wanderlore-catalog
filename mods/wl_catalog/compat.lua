-- Runs in front of every source mod (scripts/setup.sh arranges that).
-- Old mods rely on behaviour that current Luanti rejects. The fixes here
-- only make them load so their creatures can be shown; they are not meant
-- for playing.

if rawget(_G, "wl_catalog_compat") then
	return
end
wl_catalog_compat = true

-- Luanti refuses a definition table that is registered twice. Some mods
-- reuse one table for several items, so every registration gets a copy.
for _, name in ipairs({"register_craftitem", "register_node", "register_tool"}) do
	local original = core[name]
	core[name] = function(item_name, def, ...)
		if type(def) == "table" then
			def = table.copy(def)
		end
		return original(item_name, def, ...)
	end
end

-- In the plants world nothing is generated from what the sources
-- register, the catalogue only reads it. Some sources clear the
-- decorations and biomes of the others to make room for their own; there
-- that would hide trees from the catalogue and break sources that look
-- their own decorations up again.
do
	local file = io.open(core.get_worldpath() .. "/catalog_set.txt", "r")
	local set = file and file:read("*l")
	if file then
		file:close()
	end
	if set == "plants" then
		core.clear_registered_decorations = function() end
		core.clear_registered_biomes = function() end
		-- The sources also must not generate anything themselves, and
		-- nothing may grow, spread or decay while one looks at it. Nor
		-- may they change the sky or the screen of a player. The mods of
		-- the game and the catalogue itself keep working.
		local function is_source()
			local name = core.get_current_modname()
			local path = name and core.get_modpath(name) or ""
			return name ~= "wl_catalog" and not path:find("/games/", 1, true)
		end
		for _, name in ipairs({"register_on_generated", "register_mapgen_script",
				"register_abm", "register_lbm", "register_globalstep",
				"register_on_joinplayer", "register_on_newplayer"}) do
			local original = core[name]
			core[name] = function(...)
				if not is_source() then
					return original(...)
				end
			end
		end
	end
end
