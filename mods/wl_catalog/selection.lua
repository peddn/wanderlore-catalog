-- The author's selection for Wanderlore, to see it before it is built
-- there: every chosen form of a tree, rewritten to the chosen trunk and
-- leaves. The plants world shows these in rows of their own; /auswahl
-- jumps there.
--
-- trunk and leaves name a block: by the number of a tree whose block is
-- meant ("MT-T3"), by the number of a block ("MT3") or by its technical
-- name. A form names a tree by its number; scale enlarges it. A form can
-- also be built here: build is a function that gets the names of trunk,
-- leaves and hanging leaves and returns a schematic.
--
-- A form with hang = true gets hanging leaves where its leaves hang free.
--
-- hanging_texture is the texture of the leaves. With it the catalogue
-- makes a block of hanging leaves for the species: the same leaves, cut
-- into strands. It is only there to judge the idea.

-- A number from 0 to 1 that depends only on the place.
local function chance(x, y, z)
	local n = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
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
	return function(trunk, leaves, hanging)
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

		for _, branch in ipairs(shape.branches) do
			local y0, dx, dz, length = branch[1], branch[2], branch[3], branch[4]
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

-- The first elder forms. The author found the step from the large form,
-- 9 by 14, to these too big.
local ELDER_SLIM_BIG = {
	W = 19, H = 31, thick = 15, top = 25, hang = 0.4, hang_to = 8, away = 3, blob = 2.8,
	branches = {
		{11, 1, 0, 4}, {12, -1, 0, 4}, {13, 0, 1, 5}, {14, 0, -1, 5},
		{15, 1, 1, 3}, {15, -1, -1, 3}, {16, 1, -1, 3}, {17, -1, 1, 3},
		{19, 1, 0, 3}, {20, -1, 0, 3}, {21, 0, 1, 3}, {21, 0, -1, 2},
		{23, 1, 1, 2}, {23, -1, -1, 2},
	},
	crowns = {{25, 2.6, 2.2}, {28, 1.7, 2.0}},
}

local ELDER_BROAD_BIG = {
	W = 25, H = 28, thick = 14, top = 22, hang = 0.4, hang_to = 7, away = 3, blob = 2.8,
	branches = {
		{9, 1, 0, 6}, {10, -1, 0, 6}, {11, 0, 1, 7}, {11, 0, -1, 6},
		{13, 1, 1, 5}, {13, -1, -1, 5}, {14, 1, -1, 4}, {14, -1, 1, 5},
		{17, 1, 0, 4}, {17, -1, 0, 4}, {18, 0, 1, 4}, {18, 0, -1, 4},
		{20, 1, 1, 2}, {20, -1, -1, 2},
	},
	crowns = {{22, 3.0, 2.3}, {25, 1.8, 2.0}},
}

-- The same two, about one and a half times the large form.
local ELDER_SLIM = {
	W = 13, H = 21, thick = 9, top = 16, hang = 0.45, hang_to = 5, away = 2.5, blob = 2.2,
	branches = {
		{7, 1, 0, 3}, {8, -1, 0, 3}, {9, 0, 1, 3}, {9, 0, -1, 3},
		{10, 1, 1, 2}, {11, -1, -1, 2}, {11, 1, -1, 2}, {12, -1, 1, 2},
		{13, 1, 0, 2}, {14, -1, 0, 2}, {14, 0, 1, 2}, {15, 0, -1, 2},
	},
	crowns = {{16, 2.2, 2.0}, {19, 1.4, 1.6}},
}

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
		-- Blossom Downs. Five forms, chosen by the author on 2026-11-24; the
		-- two elder forms were built by Claude. Each stands twice: as chosen
		-- and with hanging leaves, to compare. hang turns the leaves that
		-- hang free at the rim of a crown into hanging leaves.
		forms = {
			{tree = "EB-T20", label = "klein"},
			{tree = "EB-T20", label = "klein_Haengelaub", hang = true},
			{tree = "NB-T22", label = "mittel"},
			{tree = "NB-T22", label = "mittel_Haengelaub", hang = true},
			{tree = "NB-T21", label = "gross"},
			{tree = "NB-T21", label = "gross_Haengelaub", hang = true},
			{build = elder_birch(ELDER_SLIM), label = "elder_schlank"},
			{build = elder_birch(ELDER_SLIM, true), label = "elder_schlank_Haengelaub"},
			{build = elder_birch(ELDER_BROAD), label = "elder_breit"},
			{build = elder_birch(ELDER_BROAD, true), label = "elder_breit_Haengelaub"},
		},
	},
}
