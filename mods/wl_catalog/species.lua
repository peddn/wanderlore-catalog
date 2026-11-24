-- The tree species of Wanderlore, each as a way of its own to build a
-- tree from the parts of treekit.lua.
--
-- A species is designed as its elder form, age 1. The younger forms come
-- from the same description built back: the rules say what a tree of that
-- species has less of when it is younger. A young tree is not a small
-- old one.
--
-- species.<name>(kit, age, names, seed) returns a schematic. stages names
-- the ages of the forms the author asked for.

local kit = dofile(core.get_modpath("wl_catalog") .. "/treekit.lua")

local species = {stages = {}}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function round(n)
	return math.floor(n + 0.5)
end

--
-- Birch
--
-- Elder: a trunk two by two that thins out, branches in four tiers that
-- rise a little, a ball of leaves on each of them and two on top, and
-- strands of hanging leaves from the rims. After the forms the author
-- chose from Natural Biomes and Extra Biomes, written from looking at
-- them.
--
-- Built back with age: the trunk gets shorter and, below the elder form,
-- single and without roots. It has no branches thick enough to be
-- blocks, and its crown is one piece instead of balls on branches: a
-- slender column when young, fuller with the years, round in every layer
-- and flowing to a point at the top. The younger the tree, the more of
-- its rim hangs.

species.stages.birch = {klein = 0.2, mittel = 0.45, gross = 0.65, elder = 1}

-- {height, dx, dz, length} of the elder form.
local BIRCH_BRANCHES = {
	{6, 1, 0, 4}, {7, -1, 0, 4}, {8, 0, 1, 5}, {8, 0, -1, 4},
	{9, 1, 1, 3}, {9, -1, -1, 3}, {10, 1, -1, 3}, {10, -1, 1, 3},
	{12, 1, 0, 3}, {12, -1, 0, 3}, {13, 0, 1, 3}, {13, 0, -1, 3},
}

function species.birch(age, names, seed)
	local tree = kit.new(names, seed)
	local top = round(lerp(3, 15, age))
	local old = age > 0.8
	tree:stem(top, old and round(9 * age) or 0)
	if old then
		tree:roots(5)
	end

	if old then
		-- The tuft on top: broad and flat.
		tree:ball(0, top + 1, 0, 3.2, 1.8)
		tree:ball(0, top + 2.6, 0, 1.9, 1.0)
		for number, branch in ipairs(BIRCH_BRANCHES) do
			local length = branch[4] * age * 0.95
			-- A variant has some branches a little longer or shorter.
			if seed ~= 0 then
				length = length + (tree:chance(number, 1, 0) - 0.5) * 1.6
			end
			length = round(length)
			if length >= 2 then
				local y = round(branch[1] * top / 15) + (seed ~= 0 and round(tree:chance(number, 2, 0) * 2 - 1) or 0)
				local x, by, z = tree:branch(math.max(2, y), branch[2], branch[3], length, 2)
				tree:ball(x, by + 1, z, 2.4, 1.6)
				if length >= 3 then
					tree:ball(x - branch[2] * 2, by + 1, z - branch[3] * 2, 1.9, 1.4)
				end
			end
		end
	else
		-- A younger birch has no branches thick enough to be blocks. Its
		-- crown is one piece: slender when young, fuller with the years,
		-- widest in its lower third and flowing to a point at the top.
		local base = round(lerp(2, 4, age))
		local radius = 1 + 4.6 * (math.max(0, age - 0.2) / 0.8) ^ 0.75
			+ (seed ~= 0 and (tree:chance(3, 1, 4) - 0.5) * 0.6 * age or 0)
		tree:egg(base, top + 2, radius, 0.32)
	end

	-- The younger the tree, the more of its rim hangs.
	tree:strands(lerp(0.75, 0.45, age), lerp(0.9, 2.5, age), round(lerp(2, 6, age)), round(lerp(1, 5, age)))
	return tree:schematic()
end

return species
