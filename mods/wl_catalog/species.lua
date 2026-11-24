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
-- A gnarled tree: roots that run from its foot like a star, a thick trunk
-- that forks low, and limbs that climb outwards from it to all sides and
-- then stand upright, each with a flat plate of leaves on top. So the
-- crown is plates at many heights with air between them, held up by
-- visible wood. The large form follows a tree
-- of Aotearoa the author picked, written from looking at it; the elder
-- form is the same grown on.
--
-- Built back with age: fewer and shorter limbs, smaller plates, a lower
-- fork, the trunk single and the roots gone. A young oak is a short trunk
-- with two or three small plates.

species.stages.oak = {klein = 0.2, mittel = 0.4, gross = 0.7, elder = 1}

local WAYS = {{1, 0}, {-1, 1}, {0, -1}, {1, 1}, {-1, 0}, {1, -1}, {0, 1}, {-1, -1}}

function species.oak(age, names, seed)
	local tree = kit.new(names, seed)
	local fork = round(lerp(3, 8, age))
	local top = fork + round(lerp(1, 15, age ^ 1.3))
	local stout = age > 0.5
	-- The trunk proper ends at the fork. Above it the tree is its limbs.
	tree:stem(fork, stout and fork + 1 or 0)
	if stout then
		tree:star(round(lerp(4, 8, (age - 0.5) / 0.5)), lerp(1.5, 3.2, (age - 0.5) / 0.5))
	end
	local turn = round(tree:chance(1, 5, 0) * 7)
	local plate = lerp(1.9, 4.1, age)

	-- A limb climbs outwards, one block out for one up, then stands
	-- upright for a little, and carries a plate of leaves.
	local function limb(number, from, length, straight, size)
		local way = WAYS[(number * 3 + turn) % 8 + 1]
		local x, y, z = tree:branch(from, way[1], way[2], length, 1)
		for _ = 1, straight do
			y = y + 1
			tree:set(x, y, z, "trunk")
		end
		tree:ball(x, y + 1, z, size, 1.15)
		return x, y, z, way
	end

	-- The side limbs leave the trunk below the fork, the lowest first.
	local sides = round(lerp(1, 6, age))
	for number = 1, sides do
		local from = round(lerp(math.max(2, fork - 5), fork, (number - 1) / math.max(1, sides - 1))
			+ tree:chance(number, 2, 0) * 1.6 - 0.8)
		local length = round(lerp(1.4, 4.4, age) * lerp(0.7, 1.2, tree:chance(number, 1, 0)))
		limb(number, math.max(2, from), math.max(1, length), round(tree:chance(number, 3, 0) * 2),
			plate * lerp(0.8, 1.05, tree:chance(number, 7, 0)))
	end

	-- The leaders start at the fork and go highest. Each carries a plate
	-- on top and, when it is long, a second one on a twig halfway.
	local leaders = stout and 3 or (age > 0.3 and 2 or 1)
	for number = 1, leaders do
		local reach = top - fork - (number - 1) * round(lerp(1, 4, age))
		local length = math.max(1, round(lerp(1, 3, age) * lerp(0.7, 1.2, tree:chance(number, 11, 0))))
		local x, y, z, way = limb(number + 20, fork, length, math.max(0, reach - length),
			plate * lerp(0.85, 1.1, tree:chance(number, 12, 0)))
		-- A long leader is not a bare pole: every fourth block of it a
		-- twig to one side and the other carries a plate of its own.
		local side = 1
		for height = y - 3, fork + length + 2, -4 do
			tree:set(x - way[2] * side, height, z + way[1] * side, "trunk", way[2] ~= 0 and 12 or 4)
			tree:ball(x - way[2] * side * 2, height + 1, z + way[1] * side * 2,
				plate * lerp(0.6, 0.8, tree:chance(number, 13, height)), 1.0)
			side = -side
		end
	end
	return tree:schematic()
end

return species
