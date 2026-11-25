-- The author's selection for Wanderlore, to see it before it is built
-- there: every chosen form of a tree, rewritten to the chosen trunk and
-- leaves. The plants world shows these in rows of their own; /auswahl
-- jumps there.
--
-- trunk and leaves name a block: by the number of a tree whose block is
-- meant ("MT-T3"), by the number of a block ("MT3") or by its technical
-- name. category names the wood category of the species and planks the
-- block of its planks. A form names a tree by its number; scale enlarges it. A form can
-- also be built here: build is a function that gets the names of trunk,
-- leaves and hanging leaves and returns a schematic.
--
-- A form with hang = true gets hanging leaves where its leaves hang free.
-- vary = 1, 2, ... makes a slightly different tree of the same form, as
-- Wanderlore is to do when it places one: mirrored, the trunk a little
-- longer or shorter, some leaves at the rim gone; a built form gets the
-- number as its fourth argument. stretch makes the bare trunk of a form
-- that many blocks longer, roots puts about that many trunk blocks on the
-- ground around its foot. tier adds one more tier of branches below the
-- lowest one, no wider than it, and gives the tier above it more leaves.
-- scale makes a form larger or, below 1, smaller.
--
-- study lists forms to look at closely: each stands alone, far from the
-- rows, once whole and once as its wood without leaves, and the pictures
-- show it from four sides, two corners and above.

-- The species that are built by a way of their own, see species.lua. A
-- form {species = "birch", age = 0.45} is such a tree at that age.
local species = dofile(core.get_modpath("wl_catalog") .. "/species.lua")
local function grown(name, age)
	return function(trunk, leaves, hanging, variant)
		return species[name](age, {trunk = trunk, leaves = leaves, hanging = hanging}, variant or 0)
	end
end

-- A number from 0 to 1 that depends only on the place and on salt, which
-- a builder sets to the number of the variant it builds.
local salt = 0
local function chance(x, y, z)
	local n = math.sin(x * 127.1 + y * 311.7 + z * 74.7 + salt * 53.3) * 43758.5453
	return n - math.floor(n)
end

-- An old birch, built by Claude after the forms the author chose from
-- Natural Biomes: a thick trunk that thins towards the top, branches that
-- rise a little, a crown on each of them, and leaves hanging down from the
-- rims of the crowns like curtains. The lower trunk stays free.
--
-- shape: W and H the size, thick how high the trunk is two by two, top
-- where it ends, branches as {height, dx, dz, length}, crowns as
-- {height, radius, half height} on the trunk, hang_to the lowest height a
-- curtain reaches, hang the share of columns that carry one, away how far
-- from the trunk the curtains begin, blob the radius of a crown on a
-- branch. With strands the curtains are of the block of hanging leaves.
local function elder_birch(shape, strands)
	return function(trunk, leaves, hanging, variant)
		salt = variant or 0
		local curtain = strands and hanging or leaves
		local W, H = shape.W, shape.H
		local c = math.floor(W / 2) - 1   -- the trunk stands on c and c + 1
		local cells = {}
		local function key(x, y, z)
			return (z * H + y) * W + x + 1
		end
		local function set(x, y, z, name, param2)
			if x >= 0 and x < W and y >= 0 and y < H and z >= 0 and z < W then
				local old = cells[key(x, y, z)]
				if not old or name == trunk then
					cells[key(x, y, z)] = {name = name, param2 = param2 or 0}
				end
			end
		end
		local function blob(cx, cy, cz, rx, ry)
			for z = math.floor(cz - rx), math.ceil(cz + rx) do
				for y = math.floor(cy - ry), math.ceil(cy + ry) do
					for x = math.floor(cx - rx), math.ceil(cx + rx) do
						local d = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 + ((z - cz) / rx) ^ 2
						if d <= 0.75 + 0.45 * chance(x, y, z) then
							set(x, y, z, leaves)
						end
					end
				end
			end
		end

		-- The trunk: two by two, then one, with a few roots.
		for y = 0, shape.thick do
			for dx = 0, 1 do
				for dz = 0, 1 do
					set(c + dx, y, c + dz, trunk)
				end
			end
		end
		for y = shape.thick + 1, shape.top do
			set(c, y, c, trunk)
		end
		for _, root in ipairs({{-1, 0}, {2, 1}, {0, -1}, {1, 2}, {-1, 1}}) do
			set(c + root[1], 0, c + root[2], trunk)
		end

		for number, branch in ipairs(shape.branches) do
			local y0, dx, dz, length = branch[1], branch[2], branch[3], branch[4]
			-- A variant has some branches one longer or shorter and one
			-- higher or lower.
			if salt ~= 0 then
				length = math.max(2, length + math.floor(chance(number, 1, 0) * 3) - 1)
				y0 = y0 + math.floor(chance(number, 2, 0) * 3) - 1
			end
			local x, z = c + (dx > 0 and 1 or 0), c + (dz > 0 and 1 or 0)
			if y0 > shape.thick then
				x, z = c, c
			end
			local y = y0
			-- A trunk block lying along x or z.
			local lying = dx ~= 0 and 12 or 4
			for step = 1, length do
				x, z = x + dx, z + dz
				if step % 2 == 0 then
					y = y + 1
				end
				set(x, y, z, trunk, lying)
			end
			blob(x, y + 1, z, shape.blob, shape.blob * 0.68)
			blob(x - dx * 2, y + 1, z - dz * 2, shape.blob * 0.8, shape.blob * 0.57)
		end
		for _, crown in ipairs(shape.crowns) do
			blob(c, crown[1], c, crown[2], crown[3])
		end
		set(c, H - 1, c, leaves)

		-- The curtains: from the lowest leaf of a column away from the
		-- trunk, leaves hang down, each a different length.
		for z = 0, W - 1 do
			for x = 0, W - 1 do
				local away = math.max(math.abs(x - c - 0.5), math.abs(z - c - 0.5))
				if away >= shape.away and chance(x, 0, z) < shape.hang then
					local lowest
					for y = 0, H - 1 do
						local cell = cells[key(x, y, z)]
						if cell and cell.name == leaves then
							lowest = y
							break
						end
					end
					if lowest then
						local length = 2 + math.floor(chance(z, 7, x) * 5)
						for y = lowest - 1, math.max(shape.hang_to, lowest - length), -1 do
							if cells[key(x, y, z)] then
								break
							end
							set(x, y, z, curtain)
						end
					end
				end
			end
		end

		local data = {}
		for index = 1, W * H * W do
			data[index] = cells[index] or {name = "air", prob = 0}
		end
		return {size = {x = W, y = H, z = W}, data = data}
	end
end

-- The elder form the author chose: about one and a half times the large
-- form, which is 9 by 14. A slim variant and two larger ones were dropped.
local ELDER_BROAD = {
	W = 17, H = 20, thick = 9, top = 15, hang = 0.45, hang_to = 5, away = 2.5, blob = 2.4,
	branches = {
		{6, 1, 0, 4}, {7, -1, 0, 4}, {8, 0, 1, 5}, {8, 0, -1, 4},
		{9, 1, 1, 3}, {9, -1, -1, 3}, {10, 1, -1, 3}, {10, -1, 1, 3},
		{12, 1, 0, 3}, {12, -1, 0, 3}, {13, 0, 1, 3}, {13, 0, -1, 3},
	},
	crowns = {{15, 2.6, 2.1}, {18, 1.5, 1.6}},
}

return {
	{
		name = "birch",
		title = "Birke",
		trunk = "MT-T3",
		leaves = "NB-T22",
		hanging_texture = "naturalbiomes_heath_birch_leaves.png",
		-- Blossom Downs. Chosen by the author on 2026-11-24: four forms, all
		-- with hanging leaves; the elder form was built by Claude. hang turns
		-- the leaves that hang free at the rim of a crown into hanging leaves.
		category = "Weichholz",
		planks = "EB25",
		-- Chosen by the author; the catalogue does not show it in the row yet.
		sapling = "EB86",
		-- Each form twice: as the author approved it, and built by the way
		-- of the species at that age, with one variant, to compare.
		forms = {
			{tree = "EB-T20", label = "klein", hang = true},
			{build = grown("birch", 0.2), label = "klein_Verfahren", hang = true},
			{build = grown("birch", 0.2), label = "klein_Verfahren_Variante", vary = 1, hang = true},
			{tree = "NB-T22", label = "mittel", hang = true},
			{build = grown("birch", 0.45), label = "mittel_Verfahren", hang = true},
			{build = grown("birch", 0.45), label = "mittel_Verfahren_Variante", vary = 1, hang = true},
			{tree = "NB-T21", label = "gross", hang = true},
			{build = grown("birch", 0.65), label = "gross_Verfahren", hang = true},
			{build = grown("birch", 0.65), label = "gross_Verfahren_Variante", vary = 1, hang = true},
			{build = elder_birch(ELDER_BROAD, true), label = "elder"},
			{build = grown("birch", 1), label = "elder_Verfahren"},
			{build = grown("birch", 1), label = "elder_Verfahren_Variante", vary = 1},
		},
	},
	{
		-- Blossom Downs and Old Wood, rare in both. Chosen by the author on
		-- 2026-11-24: the leaves of the beech of Extra Biomes and, after a
		-- first choice of its trunk too, the trunk BB1 of Better Biomes.
		name = "beech",
		title = "Buche",
		trunk = "BB1",
		leaves = "EB-T10",
		category = "Hartholz",
		planks = "EB33",
		sapling = "MG24",
		-- Each form twice: as the author approved it, and built by the way
		-- of the species at that age, with one variant, to compare.
		forms = {
			{tree = "BB-T5", label = "klein"},
			{build = grown("beech", 0.2), label = "klein_Verfahren"},
			{build = grown("beech", 0.2), label = "klein_Verfahren_Variante", vary = 1},
			{tree = "BB-T6", label = "mittel"},
			{build = grown("beech", 0.4), label = "mittel_Verfahren"},
			{build = grown("beech", 0.4), label = "mittel_Verfahren_Variante", vary = 1},
			-- Large: the elder form made smaller, to four fifths.
			{tree = "BB-T32", label = "gross", stretch = 5, roots = 10, tier = true, scale = 0.8},
			{build = grown("beech", 0.7), label = "gross_Verfahren"},
			{build = grown("beech", 0.7), label = "gross_Verfahren_Variante", vary = 1},
			-- Elder: the oak of Better Biomes with its trunk five longer, more
			-- roots and one more tier of branches at the bottom.
			{tree = "BB-T32", label = "elder", stretch = 5, roots = 10, tier = true},
			{build = grown("beech", 1), label = "elder_Verfahren"},
			{build = grown("beech", 1), label = "elder_Verfahren_Variante", vary = 1},
		},
	},
	{
		-- Old Wood, frequent. Chosen by the author on 2026-11-24: trunk and
		-- leaves of the oak of More Trees, and as the large form a tree of
		-- Aotearoa, AO-T47. The species is built after it; see species.lua.
		name = "oak",
		title = "Eiche",
		trunk = "MT-T8",
		leaves = "MT-T8",
		category = "Hartholz",
		planks = "EB33",
		sapling = "BB15",
		-- The tree the species is written after stands alone as well, whole
		-- and as its wood, for pictures from all sides.
		study = {{build = grown("oak", 1), label = "elder"}},
		forms = {
			{tree = "AO-T47", label = "Vorlage_gross"},
			{build = grown("oak", 0.2), label = "klein"},
			{build = grown("oak", 0.2), label = "klein_Variante", vary = 1},
			{build = grown("oak", 0.4), label = "mittel"},
			{build = grown("oak", 0.4), label = "mittel_Variante", vary = 1},
			{build = grown("oak", 0.7), label = "gross"},
			{build = grown("oak", 0.7), label = "gross_Variante", vary = 1},
			{build = grown("oak", 1), label = "elder"},
			{build = grown("oak", 1), label = "elder_Variante", vary = 1},
		},
	},
}
