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
-- single and without roots. The branches get shorter and are only twigs
-- inside the leaves, not blocks; those that would be shorter than two
-- blocks are not there at all. So a young birch is a slender column: one
-- long ball of leaves along the trunk, which in old age shrinks to the
-- tuft on top. And the younger the tree, the more of its rim hangs.

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

	-- The crown along the trunk: long and slender when young, a tuft on
	-- top when old. Above it the tip: a small ball, and on a young tree a
	-- single leaf or two.
	local t = age ^ 1.5
	tree:ball(0, lerp(0.7 * top, top, t), 0, lerp(1.3, 2.6, age), lerp(0.32 * top + 0.8, 2.1, t))
	if old then
		tree:ball(0, top + 3, 0, 1.5, 1.6)
		tree:set(0, top + 5, 0, "leaves")
	else
		tree:ball(0, top, 0, 1.1, 1.2)
		tree:set(0, top + 1, 0, "leaves")
		tree:set(0, top + 2, 0, "leaves")
	end

	for number, branch in ipairs(BIRCH_BRANCHES) do
		local length = branch[4] * age * 0.95
		-- A variant has some branches a little longer or shorter.
		if seed ~= 0 then
			length = length + (tree:chance(number, 1, 0) - 0.5) * 1.6 * age
		end
		length = round(length)
		if length >= 2 then
			local y = round(branch[1] * top / 15) + (seed ~= 0 and round(tree:chance(number, 2, 0) * 2 - 1) or 0)
			y = math.max(2, y)
			local x, z = branch[2] * length, branch[3] * length
			-- Only an old birch has branches thick enough to be blocks.
			-- On a younger one they are twigs inside the leaves.
			if old then
				x, y, z = tree:branch(y, branch[2], branch[3], length, 2)
			end
			local size = lerp(1.3, 2.4, age)
			tree:ball(x, y + 1, z, size, size * 0.68)
			if length >= 3 then
				tree:ball(x - branch[2] * 2, y + 1, z - branch[3] * 2, size * 0.8, size * 0.57)
			end
		end
	end

	-- The younger the tree, the more of its rim hangs.
	tree:strands(lerp(0.75, 0.45, age), lerp(0.9, 2.5, age), round(lerp(2, 6, age)), round(lerp(1, 5, age)))
	return tree:schematic()
end

return species
