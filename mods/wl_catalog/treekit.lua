-- A kit to build trees from: trunk, roots, branches, balls of leaves and
-- strands of hanging leaves, set into an open space of blocks and then
-- cut to a schematic. Every tree species describes itself with these
-- parts, in a function of its own; see species.lua.
--
-- Positions count from the foot of the trunk: x and z sideways, y up.
-- A trunk two by two stands on x and z 0 and 1.

local kit = {}
kit.__index = kit

-- names: the blocks to build with, as {trunk =, leaves =, hanging =}.
-- seed: the number of the variant; 0 is the tree as described.
function kit.new(names, seed)
	return setmetatable({names = names, seed = seed or 0, cells = {}}, kit)
end

-- A number from 0 to 1 that depends only on the place and the variant.
function kit:chance(x, y, z)
	local n = math.sin(x * 127.1 + y * 311.7 + z * 74.7 + self.seed * 53.3) * 43758.5453
	return n - math.floor(n)
end

local function key(x, y, z)
	return x .. "," .. y .. "," .. z
end

function kit:get(x, y, z)
	local cell = self.cells[key(x, y, z)]
	return cell and cell.kind
end

-- Trunk replaces leaves, leaves replace nothing but hanging leaves, and
-- hanging leaves only fill what is empty.
function kit:set(x, y, z, kind, param2)
	if y < 0 then
		return
	end
	local old = self.cells[key(x, y, z)]
	if kind == "trunk" or not old or kind == "leaves" and old.kind == "hanging" then
		self.cells[key(x, y, z)] = {x = x, y = y, z = z, kind = kind, param2 = param2 or 0}
	end
end

-- The trunk from the ground up to height top: two by two up to thick,
-- then single. thick 0 or nil gives a single trunk all the way.
function kit:stem(top, thick)
	thick = thick or 0
	for y = 0, top do
		self:set(0, y, 0, "trunk")
		if y < thick then
			self:set(1, y, 0, "trunk")
			self:set(0, y, 1, "trunk")
			self:set(1, y, 1, "trunk")
		end
	end
	self.thick = thick
end

-- Roots on the ground around a thick trunk, some of them two high.
function kit:roots(count)
	local places = {{-1, 0}, {2, 1}, {0, -1}, {1, 2}, {-1, 1}, {2, 0}, {1, -1}, {0, 2}, {-1, -1}, {2, 2}}
	for index = 1, math.min(count, #places) do
		local x, z = places[index][1], places[index][2]
		self:set(x, 0, z, "trunk")
		if self:chance(x, 1, z) < 0.35 then
			self:set(x, 1, z, "trunk")
		end
	end
end

-- A branch from the trunk at height y towards dx, dz, of lying trunk
-- blocks, rising one block every `rise` steps. A branch that rises with
-- every step is a limb: its blocks stand upright and it is filled in
-- below each step, so that it holds together. Returns where it ends.
function kit:branch(y, dx, dz, length, rise)
	local x, z = 0, 0
	if y < (self.thick or 0) then
		x, z = dx > 0 and 1 or 0, dz > 0 and 1 or 0
	end
	local limb = rise == 1
	for step = 1, length do
		x, z = x + dx, z + dz
		if limb then
			self:set(x, y, z, "trunk")
		end
		if rise and step % rise == 0 then
			y = y + 1
		end
		self:set(x, y, z, "trunk", limb and 0 or (dx ~= 0 and 12 or 4))
	end
	return x, y, z
end

-- Roots like a star: `count` of them run from the foot of a thick trunk
-- along the ground, each up to `length` blocks, the first block of each
-- two high.
function kit:star(count, length)
	local ways = {{1, 0}, {-1, -1}, {0, 1}, {1, -1}, {-1, 0}, {1, 1}, {0, -1}, {-1, 1}}
	for index = 1, math.min(count, #ways) do
		local dx, dz = ways[index][1], ways[index][2]
		local x, z = dx > 0 and 1 or 0, dz > 0 and 1 or 0
		local long = math.max(1, math.floor(length * (0.6 + 0.6 * self:chance(index, 0, 9)) + 0.5))
		for step = 1, long do
			x, z = x + dx, z + dz
			self:set(x, 0, z, "trunk")
			if step == 1 then
				self:set(x, 1, z, "trunk")
			end
		end
	end
end

-- A ball of leaves around a place, rx wide and ry high, ragged at its rim.
function kit:ball(cx, cy, cz, rx, ry)
	for z = math.floor(cz - rx), math.ceil(cz + rx) do
		for y = math.floor(cy - ry), math.ceil(cy + ry) do
			for x = math.floor(cx - rx), math.ceil(cx + rx) do
				local d = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 + ((z - cz) / rx) ^ 2
				if d <= 0.75 + 0.45 * self:chance(x, y, z) then
					self:set(x, y, z, "leaves")
				end
			end
		end
	end
end

-- A crown in one piece around the trunk, from height y1 to y2: round in
-- every layer, widest (`radius`) at the share `peak` of its height and
-- flowing to a point at top and bottom, without steps. With `open`, the
-- part below the widest place is only a rim, about that many blocks
-- thick, so the tree is light inside; its two lowest layers are ragged.
function kit:egg(y1, y2, radius, peak, open)
	for y = y1, y2 do
		local u = (y - y1 + 0.5) / (y2 - y1 + 1)
		-- Rises to the peak and falls from it, each as a quarter wave.
		local shape = u < peak and math.sin(math.pi / 2 * u / peak)
			or math.cos(math.pi / 2 * (u - peak) / (1 - peak))
		local r = radius * shape ^ 0.75
		local reach = math.ceil(r + 1)
		for z = -reach, reach do
			for x = -reach, reach do
				local far = math.sqrt(x * x + z * z)
				local edge = r * (0.88 + 0.2 * self:chance(x, y, z)) + 0.35
				local inside = far <= edge
				if inside and open and u < peak then
					inside = far > edge - open and (y - y1 >= 2 or self:chance(x, y + 40, z) < 0.6)
				end
				if inside then
					self:set(x, y, z, "leaves")
				end
			end
		end
	end
end

-- A gap: takes the leaves away around a place, r wide and high. Trunk
-- stays.
function kit:bite(cx, cy, cz, r)
	for z = math.floor(cz - r), math.ceil(cz + r) do
		for y = math.floor(cy - r), math.ceil(cy + r) do
			for x = math.floor(cx - r), math.ceil(cx + r) do
				local cell = self.cells[key(x, y, z)]
				if cell and cell.kind ~= "trunk"
						and (x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2 <= r * r * (0.8 + 0.4 * self:chance(x, y, z)) then
					self.cells[key(x, y, z)] = nil
				end
			end
		end
	end
end

-- Strands: in a share of the columns further than `away` from the trunk,
-- hanging leaves below the lowest leaf, each up to `length` long and none
-- lower than `floor`.
function kit:strands(share, away, length, floor)
	local lowest = {}
	for _, cell in pairs(self.cells) do
		if cell.kind == "leaves" then
			local column = cell.x .. "," .. cell.z
			if not lowest[column] or cell.y < lowest[column].y then
				lowest[column] = cell
			end
		end
	end
	for _, cell in pairs(lowest) do
		local far = math.max(math.abs(cell.x - 0.5 * (self.thick > 0 and 1 or 0)),
			math.abs(cell.z - 0.5 * (self.thick > 0 and 1 or 0)))
		if far >= away and self:chance(cell.x, 0, cell.z) < share then
			local long = 1 + math.floor(self:chance(cell.z, 7, cell.x) * length)
			for y = cell.y - 1, math.max(floor, cell.y - long), -1 do
				if self:get(cell.x, y, cell.z) then
					break
				end
				self:set(cell.x, y, cell.z, "hanging")
			end
		end
	end
end

-- The tree as a schematic, cut to its size.
function kit:schematic()
	local x1, x2, y2, z1, z2 = 0, 0, 0, 0, 0
	for _, cell in pairs(self.cells) do
		x1, x2 = math.min(x1, cell.x), math.max(x2, cell.x)
		z1, z2 = math.min(z1, cell.z), math.max(z2, cell.z)
		y2 = math.max(y2, cell.y)
	end
	-- The trunk in the middle, so that the tree stands where it is put.
	local half = math.max(-x1, x2, -z1, z2)
	local size = {x = 2 * half + 1, y = y2 + 1, z = 2 * half + 1}
	local data = {}
	for index = 1, size.x * size.y * size.z do
		data[index] = {name = "air", prob = 0}
	end
	for _, cell in pairs(self.cells) do
		local index = ((cell.z + half) * size.y + cell.y) * size.x + cell.x + half + 1
		data[index] = {name = self.names[cell.kind] or self.names.leaves, param2 = cell.param2}
	end
	return {size = size, data = data}
end

return kit
