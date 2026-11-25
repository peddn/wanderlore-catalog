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
-- single; the roots get fewer; the branches and their balls get smaller,
-- and the layers of leaves grow together, with twigs between the tiers,
-- so that only single gaps stay. A young beech has no tiers at all. Its
-- crown is one full piece that begins near the ground, with a few bulges
-- and gaps.

species.stages.beech = {klein = 0.2, mittel = 0.4, gross = 0.7, elder = 1}

-- {height, number of branches, length} of the tiers of the elder form.
local BEECH_TIERS = {{6, 4, 5}, {10, 4, 5}, {14, 4, 4}, {17, 4, 3}, {20, 2, 2}}
local STRAIGHT = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
local SLANTED = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}

function species.beech(age, names, seed)
	local tree = kit.new(names, seed)
	-- The elder form stands three blocks taller than its age alone gives.
	local top = round(7 + 14 * age ^ 0.8) + (age > 0.85 and 3 or 0)
	local thick = age > 0.85 and round(16 * age) or 0
	tree:stem(top, thick)

	if age < 0.55 then
		-- The young beech: a full crown in one piece, widest in the
		-- middle, with a few bulges at its rim and a few gaps in it, so
		-- that it is neither smooth nor solid.
		local radius = lerp(3.0, 3.5, age / 0.55)
		tree:egg(3, top + 2, radius, 0.42)
		local count = round(lerp(4, 7, age / 0.55))
		for number = 1, count do
			local turn = tree:chance(number, 3, 1) * 2 * math.pi
			local y = round(lerp(4, top, tree:chance(number, 4, 1)))
			tree:ball(math.cos(turn) * 2.4, y, math.sin(turn) * 2.4, 1.8, 1.2)
		end
		for number = 1, count + 4 do
			local turn = tree:chance(number, 8, 1) * 2 * math.pi
			local y = round(lerp(4, top + 1, tree:chance(number, 9, 1)))
			tree:bite(math.cos(turn) * radius * 0.85, y, math.sin(turn) * radius * 0.85, 1.7)
		end
		return tree:schematic()
	end

	tree:roots(round(lerp(2, 10, (age - 0.55) / 0.45)))
	local scale = lerp(0.7, 1, (age - 0.55) / 0.45)
	-- The crown is full: leaves along the trunk join the layers, the
	-- balls are high, few branches are missing, and between the tiers
	-- there are twigs with leaves of their own. Single gaps stay. The
	-- elder form is a little more open than the large one, but its balls
	-- of leaves still touch.
	local full = age < 0.85
	tree:egg(round(BEECH_TIERS[1][1] * top / 21), top + 1, full and 2.4 or 2.8, 0.4)
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
			-- and a ball of leaves of its own, and some of the branches
			-- of a full tier are missing.
			local there = tier[2] < 4 or tree:chance(number, 6, index) > 0.1
			if there then
				local y = round(tier[1] * top / 21 + tree:chance(number, 2, index) * 3 - 1.5)
				local length = tier[3] * scale * (sides == SLANTED and 0.75 or 1)
					* lerp(0.7, 1.2, tree:chance(number, 1, index))
				length = math.max(1, round(length))
				local size = 3 * scale * lerp(0.8, 1.1, tree:chance(number, 7, index))
				local x, by, z = tree:branch(math.max(4, y), side[1], side[2], length, 3)
				tree:ball(x, by + 1, z, size, size * (full and 0.8 or 0.72))
				if length >= 3 then
					tree:ball(x - side[1] * 2, by + 1, z - side[2] * 2, size * 0.8, size * (full and 0.65 or 0.6))
				end
				if tree:chance(number, 10, index) < (full and 0.7 or 0.6) then
					-- A twig between this tier and the next, to the side.
					local other = sides == STRAIGHT and SLANTED or STRAIGHT
					local to = other[(index - 1 + turn) % 4 + 1]
					local far = math.max(2, length * 0.7)
					tree:ball(to[1] * far * 0.75, by + 3, to[2] * far * 0.75, size * 0.75, size * 0.6)
				end
			end
		end
	end
	local size = 3 * scale
	tree:ball(0, top + 1, 0, size, size * 0.75)
	tree:ball(0, top + 2.5, 0, size * 0.55, size * 0.4)
	return tree:schematic()
end

--
-- Oak
--
-- Written after two things the author gave: a tree of Aotearoa in the
-- catalogue, looked at from all sides, whole and as its wood alone, and
-- then a photograph of an old oak standing free in a field, which he
-- described. From the tree come the roots and the way the wood forks;
-- from the photograph the proportions and the crown:
--
--  * The trunk is short and thick: a bundle of stems, a fifth to a
--    quarter of the height of the tree, on roots that run out over the
--    ground like a star and stand high next to the trunk.
--  * All the great limbs leave the top of this trunk and fork on their
--    way. The lowest run out nearly level, as far as the crown is wide,
--    and their ends droop a little; the higher a limb aims, the steeper
--    it climbs. Close to the trunk the limbs are thick.
--  * The crown is half a ball, flat below and round above, wider than it
--    is high. Its flat underside lies just above the top of the trunk.
--  * The leaves sit in airy tufts around the ends of the limbs and along
--    the long ones: lumpy, flattened balls with holes in them. They lie
--    on the skin of the half ball in rings, and under them the crown is
--    open: one sees the limbs from below.
--
-- The elder form is the model. How a younger oak is built back is not
-- worked out yet; for now it only gets smaller.

species.stages.oak = {klein = 0.2, mittel = 0.4, gross = 0.7, elder = 1}

function species.oak(age, names, seed)
	local tree = kit.new(names, seed)
	local width = round(1 + 26 * age)
	local height = round(6 + 16 * age)
	local stout = age > 0.5

	-- The trunk: a core two by two and stems close beside it, all short.
	local trunk = math.max(2, round(height * 0.24))
	tree:stem(trunk + 1, stout and trunk + 1 or 0)
	if stout then
		local beside = {{-1, 0}, {2, 1}, {0, 2}, {1, -1}, {-1, 1}, {2, 0}, {1, 2}, {0, -1}}
		local first = round(tree:chance(1, 4, 0) * 7)
		for number = 1, round(lerp(4, 7, (age - 0.5) / 0.5)) do
			local place = beside[(number + first) % 8 + 1]
			for y = 0, round(trunk * lerp(0.5, 1.1, tree:chance(number, 4, 1))) do
				tree:set(place[1], y, place[2], "trunk")
			end
		end
		tree:star(8, width * 0.2, 3)
	end

	-- The places of the tufts: on the skin of half a ball that stands on
	-- the top of the trunk. They lie in rings, the widest at the rim, so
	-- that the crown is flat below and round above, and as many in a ring
	-- as fit side by side; each is then moved a little.
	local tuft = math.max(1.9, width * 0.14)
	local base = trunk + 2
	local across, upward = width / 2 - tuft * 0.9, height - base - tuft * 0.7
	local spin = tree:chance(2, 5, 0) * 2 * math.pi
	local places = {}
	for number, level in ipairs({0.06, 0.45, 0.76, 0.96}) do
		local ring = math.sqrt(1 - level * level)
		local fit = math.max(1, round(2 * math.pi * across * ring / (tuft * 2.15)))
		for index = 1, fit do
			local turn = spin + number * 0.9 + (index + tree:chance(number, 5, index) * 0.5) * 2 * math.pi / fit
			places[#places + 1] = {
				x = round(math.cos(turn) * ring * across + tree:chance(number, 6, index) * 2 - 1),
				y = round(base + level * upward + tree:chance(number, 7, index) * 1.4 - 0.7),
				z = round(math.sin(turn) * ring * across + tree:chance(number, 8, index) * 2 - 1),
				rim = number == 1,
			}
		end
	end
	-- The wood grows to the near places first, so that the far ones can
	-- fork off limbs that are already there.
	table.sort(places, function(a, b)
		local far_a = math.abs(a.x) + math.abs(a.z) + (a.y - trunk)
		local far_b = math.abs(b.x) + math.abs(b.z) + (b.y - trunk)
		if far_a ~= far_b then
			return far_a < far_b
		end
		return a.y < b.y
	end)

	-- A tuft: a flattened ball with holes and two smaller ones against
	-- it, so that it is a lump and not a disc.
	local function leaves(x, y, z, size)
		tree:ball(x, y, z, size, size * 0.7, 0.22)
		for lump = 1, 2 do
			local turn = tree:chance(x + lump, y, z) * 2 * math.pi
			tree:ball(x + math.cos(turn) * size * 0.6, y + lump - 1, z + math.sin(turn) * size * 0.6,
				size * 0.62, size * 0.5, 0.22)
		end
	end

	for number, place in ipairs(places) do
		local path = tree:reach(place.x, place.y, place.z, {x = 0.5, y = trunk, z = 0.5})
		local x, y, z = place.x, place.y, place.z
		-- The end of a limb at the rim droops.
		if place.rim and #path >= 5 then
			local out_x = x > 0 and 1 or (x < 0 and -1 or 0)
			local out_z = z > 0 and 1 or (z < 0 and -1 or 0)
			if math.abs(x) >= math.abs(z) then
				out_z = 0
			else
				out_x = 0
			end
			x, y, z = x + out_x, y - 1, z + out_z
			tree:set(x, y, z, "trunk")
		end
		leaves(x, y + 1, z, tuft * lerp(0.85, 1.15, tree:chance(number, 9, 0)))
		-- A long limb carries leaves on its way as well.
		if #path >= 8 then
			local half = path[round(#path * 0.6)]
			leaves(half.x, half.y + 1, half.z, tuft * 0.7)
		end
	end
	return tree:schematic()
end

return species
