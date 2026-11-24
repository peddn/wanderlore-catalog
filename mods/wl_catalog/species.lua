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
		-- crown is one piece: a leafy column when young, fuller with the
		-- years, widest in its lower third and flowing to a point at the
		-- top. From the middle years on its lower part is only a rim and
		-- ragged, so that the tree is light inside and its strands show.
		local base = round(lerp(2, 4, age)) + (age > 0.3 and 1 or 0)
		local radius = 1.7 + 3.9 * (math.max(0, age - 0.2) / 0.8) ^ 0.75
			+ (seed ~= 0 and (tree:chance(3, 1, 4) - 0.5) * 0.6 * age or 0)
		tree:egg(base, top + 2, radius, age > 0.3 and 0.38 or 0.32, age > 0.3 and 1.5 or nil)
		tree:strands(0.85, radius * 0.45, round(lerp(2, 5, age)), math.max(1, base - 3))
	end

	if old then
		tree:strands(0.45, 2.5, 6, 5)
	end
	return tree:schematic()
end

--
-- Beech
--
-- Elder: a tall trunk two by two with roots around its foot, free for
-- five blocks, then tiers of branches, each tier turned against the one
-- below. Every branch carries a flat ball of leaves at its end and a
-- smaller one halfway, so the crown is made of layers with gaps between
-- them, and a round top. After the forms the author approved, which came
-- from an oak and from aspens of Better Biomes, written from looking at
-- them.
--
-- Built back with age: the trunk gets shorter and, below the elder form,
-- single; the roots get fewer; the branches and their balls get smaller.
-- A young beech has no tiers at all. Its crown is one piece, a leafy
-- column that begins near the ground.

species.stages.beech = {klein = 0.2, mittel = 0.4, gross = 0.7, elder = 1}

-- {height, number of branches, length} of the tiers of the elder form.
local BEECH_TIERS = {{6, 4, 5}, {10, 4, 5}, {14, 4, 4}, {17, 4, 3}, {20, 2, 2}}
local STRAIGHT = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
local SLANTED = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}

function species.beech(age, names, seed)
	local tree = kit.new(names, seed)
	local top = round(7 + 14 * age ^ 0.8)
	local thick = age > 0.85 and round(14 * age) or 0
	tree:stem(top, thick)

	if age < 0.55 then
		-- The young beech: a column of leaves, widest in the middle, with
		-- a few bulges at its rim so that it is not smooth.
		local radius = lerp(2.3, 2.7, age / 0.55)
		tree:egg(3, top + 2, radius, 0.42)
		for number = 1, round(lerp(4, 7, age / 0.55)) do
			local turn = tree:chance(number, 3, 1) * 2 * math.pi
			local y = round(lerp(4, top, tree:chance(number, 4, 1)))
			tree:ball(math.cos(turn) * 1.8, y, math.sin(turn) * 1.8, 1.7, 1.2)
		end
		return tree:schematic()
	end

	tree:roots(round(lerp(2, 10, (age - 0.55) / 0.45)))
	local scale = lerp(0.7, 1, (age - 0.55) / 0.45)
	for number, tier in ipairs(BEECH_TIERS) do
		local sides = number % 2 == 1 and STRAIGHT or SLANTED
		local turn = round(tree:chance(number, 5, 0) * 3)
		for index = 1, tier[2] do
			local side = sides[(index - 1 + turn) % 4 + 1]
			-- Two branches of the top tier point opposite ways.
			if tier[2] == 2 then
				side = sides[((index - 1) * 2 + turn) % 4 + 1]
			end
			-- No tree grows evenly: every branch has a height, a length
			-- and a ball of leaves of its own, and one in five of the
			-- branches of a full tier is missing.
			local there = tier[2] < 4 or tree:chance(number, 6, index) > 0.2
			if there then
				local y = round(tier[1] * top / 21 + tree:chance(number, 2, index) * 3 - 1.5)
				local length = tier[3] * scale * (sides == SLANTED and 0.75 or 1)
					* lerp(0.7, 1.2, tree:chance(number, 1, index))
				length = math.max(1, round(length))
				local size = 3 * scale * lerp(0.8, 1.1, tree:chance(number, 7, index))
				local x, by, z = tree:branch(math.max(4, y), side[1], side[2], length, 3)
				tree:ball(x, by + 1, z, size, size * 0.6)
				if length >= 3 then
					tree:ball(x - side[1] * 2, by + 1, z - side[2] * 2, size * 0.8, size * 0.5)
				end
			end
		end
	end
	local size = 3 * scale
	tree:ball(0, top + 1, 0, size, size * 0.75)
	tree:ball(0, top + 2.5, 0, size * 0.55, size * 0.4)
	return tree:schematic()
end

return species
