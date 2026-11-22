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
