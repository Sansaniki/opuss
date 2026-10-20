--[[
	ResourceBuilder — generează 16 modele low-poly pentru resurse.

	Cum îl folosești (o singură dată, în Roblox Studio):
	  View → Command Bar, lipești tot fișierul și apeși Enter.

	Rezultat:
	  ReplicatedStorage.Resources.<Id>  — modelele template, cu numele = cheia din tabel (Feather, Wool, ...)
	  Workspace.ResourceShowcase        — două rânduri de preview cu etichete (poate fi șters)

	Convenții:
	  • PrimaryPart = "Handle", invizibil, cât tot modelul și centrat în model;
	    pentru a-l pune pe sol: model:PivotTo(CFrame.new(pos + Vector3.new(0, model.Handle.Size.Y / 2, 0)));
	  • toate piesele sunt sudate (WeldConstraint) de Handle, Anchored = true în template;
	  • atribut ResourceId = cheia din tabel.
	Rularea din nou înlocuiește modelele vechi.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = Enum.Material
local V = Vector3.new
local rad = math.rad
local PI = math.pi

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function mix(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

-- Cilindrii Roblox au axa pe X: FWD o întoarce spre Z.
local FWD = CFrame.Angles(0, rad(90), 0)
-- Octogoanele se construiesc în planul XY; VERT le culcă orizontal (prismă pe Y).
local VERT = CFrame.Angles(PI / 2, 0, 0)

-- Generator determinist, ca modelele să iasă la fel la fiecare rulare.
local function rng(seed)
	local s = seed
	return function(a, b)
		s = (s * 16807) % 2147483647
		return a + (b - a) * (s / 2147483647)
	end
end

local function makePart(parent, className, name, size, cf, color, material, props)
	local p = Instance.new(className)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function newItem(id)
	local model = Instance.new("Model")
	model.Name = id

	local handle = makePart(model, "Part", "Handle", V(1, 1, 1), CFrame.new(), rgb(255, 255, 255), M.SmoothPlastic, {
		Transparency = 1,
		CastShadow = false,
	})
	model.PrimaryPart = handle
	model:SetAttribute("ResourceId", id)

	local b = { model = model, handle = handle }

	function b.box(name, size, cf, color, mat, props)
		return makePart(model, "Part", name, size, cf, color, mat, props)
	end

	-- WedgePart: fața înclinată coboară spre -Z.
	function b.wedge(name, size, cf, color, mat, props)
		return makePart(model, "WedgePart", name, size, cf, color, mat, props)
	end

	function b.cyl(name, length, diameter, cf, color, mat, props)
		props = table.clone(props or {})
		props.Shape = Enum.PartType.Cylinder
		return makePart(model, "Part", name, V(length, diameter, diameter), cf, color, mat, props)
	end

	function b.ball(name, diameter, cf, color, mat, props)
		props = table.clone(props or {})
		props.Shape = Enum.PartType.Ball
		return makePart(model, "Part", name, V(diameter, diameter, diameter), cf, color, mat, props)
	end

	-- Octogon = 4 benzi rotite la 0/45/90/135°, în planul XY al lui cf, gros pe Z.
	function b.octagon(name, apothem, thickness, cf, color, mat, props)
		local s = V(apothem * 2, apothem * 2 * math.tan(PI / 8), thickness)
		local first
		for k = 0, 3 do
			local p = b.box(name, s, cf * CFrame.Angles(0, 0, k * PI / 4), color, mat, props)
			first = first or p
		end
		return first
	end

	-- Prismă octogonală pe axa Y a lui cf (fețe plate spre ±X și ±Z).
	function b.prism(name, apothem, height, cf, color, mat, props)
		return b.octagon(name, apothem, height, cf * VERT, color, mat, props)
	end

	-- Stea cu 8 colțuri = două pătrate rotite la 45°, în planul XY al lui cf.
	function b.star(name, radius, thickness, cf, color, mat, props)
		local s = V(radius * 2, radius * 2, thickness)
		local first = b.box(name, s, cf, color, mat, props)
		b.box(name, s, cf * CFrame.Angles(0, 0, PI / 4), color, mat, props)
		return first
	end

	-- „Bilă” fațetată low-poly = două cuburi suprapuse, rotite.
	function b.gem(name, d, cf, color, mat, props)
		local s = V(d * 0.8, d * 0.8, d * 0.8)
		local first = b.box(name, s, cf, color, mat, props)
		b.box(name, s, cf * CFrame.Angles(PI / 4, PI / 4, 0), color, mat, props)
		return first
	end

	function b.chunk(name, size, cf, color, mat, rand, maxAngle)
		local a = maxAngle or PI
		return b.box(name, size, cf * CFrame.Angles(rand(-a, a), rand(-a, a), rand(-a, a)), color, mat)
	end

	-- Cristal: corp cu secțiune romb + vârf în două ape. Baza e la originea lui cf, crește pe Y.
	function b.crystal(name, w, h, tip, cf, color, mat, props)
		local c = cf * CFrame.Angles(0, PI / 4, 0)
		local body = b.box(name, V(w, h, w), c * at(0, h / 2, 0), color, mat, props)
		b.wedge(name, V(w, tip, w / 2), c * at(0, h + tip / 2, -w / 4), color, mat, props)
		b.wedge(name, V(w, tip, w / 2), c * at(0, h + tip / 2, w / 4) * CFrame.Angles(0, PI, 0), color, mat, props)
		return body
	end

	-- Inel de n blocuri pe un cerc orizontal; tilt > 0 apleacă partea de sus spre exterior.
	function b.ring(name, n, radius, y, size, color, mat, tilt, phase, color2)
		for i = 0, n - 1 do
			local a = (phase or 0) + i * 2 * PI / n
			local cf = at(radius * math.cos(a), y, radius * math.sin(a))
				* CFrame.Angles(0, PI / 2 - a, 0)
				* CFrame.Angles(tilt or 0, 0, 0)
			b.box(name, size, cf, (color2 and i % 2 == 1) and color2 or color, mat)
		end
	end

	-- Arc în planul XY al lui root: pornește în sus și se curbează spre +X.
	-- fn(i, t, cf, segLen) primește cadrul fiecărui segment (Y = tangenta, +X = interiorul curbei).
	function b.sweep(root, radius, arcDeg, n, fn)
		local arc = rad(arcDeg)
		local segLen = radius * arc / n
		for i = 1, n do
			local th = (i - 0.5) / n * arc
			local cf = root * at(radius * (1 - math.cos(th)), radius * math.sin(th), 0) * CFrame.Angles(0, 0, -th)
			fn(i, (i - 0.5) / n, cf, segLen)
		end
	end

	function b.light(part, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = part
		return l
	end

	function b.particles(part, c0, c1, rate, opts)
		opts = opts or {}
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(c0, c1)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, opts.size or 0.15),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new(0.2)
		e.LightEmission = 1
		e.Lifetime = NumberRange.new(opts.lifeMin or 0.8, opts.lifeMax or 1.4)
		e.Rate = rate
		e.Speed = NumberRange.new(opts.speedMin or 0.1, opts.speedMax or 0.4)
		if opts.rise then
			e.EmitDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(25, 25)
			e.Acceleration = V(0, opts.rise, 0)
		else
			e.SpreadAngle = Vector2.new(180, 180)
		end
		e.Parent = part
		return e
	end

	return b
end

-- Centrează modelul, potrivește Handle pe tot modelul și sudează piesele.
local function finalize(b)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	local parts = {}
	for _, d in ipairs(b.model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= b.handle then
			parts[#parts + 1] = d
			local s = d.Size
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						local w = d.CFrame * V(s.X * sx, s.Y * sy, s.Z * sz)
						lo[1], hi[1] = math.min(lo[1], w.X), math.max(hi[1], w.X)
						lo[2], hi[2] = math.min(lo[2], w.Y), math.max(hi[2], w.Y)
						lo[3], hi[3] = math.min(lo[3], w.Z), math.max(hi[3], w.Z)
					end
				end
			end
		end
	end

	local shift = CFrame.new(-(lo[1] + hi[1]) / 2, -(lo[2] + hi[2]) / 2, -(lo[3] + hi[3]) / 2)
	for _, d in ipairs(parts) do
		d.CFrame = shift * d.CFrame
		local w = Instance.new("WeldConstraint")
		w.Part0 = b.handle
		w.Part1 = d
		w.Parent = d
	end
	b.handle.Size = V(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
	b.handle.CFrame = CFrame.new()
	return b.model
end

-- Pană: lamele care urmează un arc ușor; colorAt(i, n) dă culoarea fiecărui segment.
local function featherShape(b, root, length, colorAt, matAt)
	local n = 12
	local width = length * 0.32
	b.sweep(root * CFrame.Angles(0, PI, 0), length * 2.4, math.deg(1 / 2.4), n, function(i, t, cf, seg)
		b.box("Quill", V(length * 0.035, seg * 1.1, length * 0.035), cf, rgb(236, 226, 200), M.SmoothPlastic)
		if t > 0.16 then
			local u = (t - 0.16) / 0.84
			local w = width * math.sin(PI * (0.08 + 0.84 * u)) ^ 0.7
			-- partea din față a lamei e mai îngustă, ca la o pană reală
			b.box("Vane", V(w, seg * 1.08, length * 0.02), cf * at(w * 0.08, 0, 0), colorAt(i, n), matAt and matAt(i, n) or M.SmoothPlastic)
		end
	end)
end

---------------------------------------------------------------------------

local function buildFeather()
	local b = newItem("Feather")
	local L = 1.6
	local root = CFrame.Angles(0, 0, rad(-20))
	local white, blue, deep = rgb(250, 250, 246), rgb(160, 200, 236), rgb(70, 112, 176)
	local rand = rng(3)

	featherShape(b, root, L, function(i, n)
		if i == n then
			return deep
		elseif i >= n - 3 then
			return (n - i) % 2 == 1 and blue or white
		end
		return white
	end)

	for _, s in ipairs({ -1, 1 }) do
		b.chunk("Down", V(0.12, 0.12, 0.12), root * at(s * 0.07, L * 0.2, 0), white, M.Fabric, rand)
	end

	return finalize(b)
end

local function buildWool()
	local b = newItem("Wool")
	local rand = rng(7)
	local cols = { rgb(246, 242, 232), rgb(234, 227, 212), rgb(252, 250, 244) }

	b.chunk("Fluff", V(0.62, 0.62, 0.62), at(0, 0.42, 0), cols[1], M.Fabric, rand)
	for i = 0, 6 do
		local a = i * 2 * PI / 7
		local s = rand(0.42, 0.52)
		b.chunk("Fluff", V(s, s, s), at(0.4 * math.cos(a), 0.28 + rand(-0.04, 0.06), 0.4 * math.sin(a)), cols[i % 3 + 1], M.Fabric, rand)
	end
	for i = 0, 2 do
		local a = i * 2 * PI / 3 + 0.5
		b.chunk("Fluff", V(0.4, 0.4, 0.4), at(0.2 * math.cos(a), 0.68, 0.2 * math.sin(a)), cols[(i + 1) % 3 + 1], M.Fabric, rand)
	end

	-- capăt de fir care se încolăcește din ghem
	b.sweep(at(0.62, 0.15, 0.1) * CFrame.Angles(0, rad(-30), rad(-100)), 0.12, 260, 7, function(_, _, cf, seg)
		b.box("Strand", V(0.06, seg * 1.25, 0.06), cf, cols[2], M.Fabric)
	end)

	return finalize(b)
end

local function buildMilk()
	local b = newItem("Milk")
	local white = rgb(248, 248, 245)
	local blue, light = rgb(70, 130, 210), rgb(150, 195, 240)

	b.prism("Bottle", 0.34, 0.95, at(0, 0.475, 0), white)
	b.prism("Shoulder", 0.27, 0.14, at(0, 1.0, 0) * CFrame.Angles(0, PI / 8, 0), white)
	b.prism("Neck", 0.18, 0.22, at(0, 1.17, 0), white)
	b.prism("Lip", 0.21, 0.06, at(0, 1.29, 0) * CFrame.Angles(0, PI / 8, 0), white)
	b.prism("Cap", 0.215, 0.1, at(0, 1.35, 0), blue)
	b.prism("CapTop", 0.17, 0.03, at(0, 1.41, 0) * CFrame.Angles(0, PI / 8, 0), light)

	b.prism("Label", 0.355, 0.38, at(0, 0.46, 0), blue)
	b.prism("LabelStripe", 0.36, 0.05, at(0, 0.68, 0), light)
	b.prism("LabelStripe", 0.36, 0.05, at(0, 0.24, 0), light)

	-- picătură de lapte pe etichetă
	b.box("Drop", V(0.13, 0.13, 0.03), at(0, 0.52, 0.36) * CFrame.Angles(0, 0, PI / 4), white)
	b.cyl("Drop", 0.03, 0.17, at(0, 0.45, 0.36) * FWD, white)

	return finalize(b)
end

local function buildBerry()
	local b = newItem("Berry")
	local leaf, vein, twig = rgb(86, 156, 64), rgb(56, 112, 42), rgb(110, 74, 44)
	local red, red2 = rgb(204, 38, 62), rgb(170, 26, 50)
	local blue, blue2 = rgb(64, 74, 158), rgb(46, 54, 124)

	local function addLeaf(cf)
		b.box("Leaf", V(0.28, 0.03, 0.5), cf, leaf, M.Grass)
		for _, s in ipairs({ -1, 1 }) do
			b.box("LeafTip", V(0.2, 0.03, 0.2), cf * at(0, 0, s * 0.25) * CFrame.Angles(0, PI / 4, 0), leaf, M.Grass)
		end
		b.box("Vein", V(0.03, 0.04, 0.62), cf, vein, M.Grass)
	end
	addLeaf(at(-0.3, 0.05, -0.05) * CFrame.Angles(0, rad(30), 0) * CFrame.Angles(rad(-10), 0, 0))
	addLeaf(at(0.3, 0.05, 0.08) * CFrame.Angles(0, rad(-40), 0) * CFrame.Angles(rad(10), 0, 0))

	local berries = {
		{ 0, 0.2, 0, red },
		{ 0.2, 0.17, 0.08, blue },
		{ -0.18, 0.17, 0.1, blue2 },
		{ 0.05, 0.17, -0.2, red2 },
		{ -0.08, 0.38, -0.02, red },
		{ 0.12, 0.36, 0.04, blue },
		{ 0.02, 0.17, 0.24, red2 },
	}
	for _, br in ipairs(berries) do
		b.gem("Berry", 0.25, at(br[1], br[2], br[3]), br[4])
		if br[4] == blue or br[4] == blue2 then
			b.box("Crown", V(0.07, 0.04, 0.07), at(br[1], br[2] + 0.11, br[3]), rgb(30, 30, 60))
		end
	end

	b.box("Twig", V(0.04, 0.28, 0.04), at(0.0, 0.55, 0) * CFrame.Angles(0, 0, rad(-15)), twig, M.Wood)
	b.box("TopLeaf", V(0.16, 0.025, 0.24), at(0.07, 0.68, 0.02) * CFrame.Angles(rad(20), rad(30), rad(-25)), leaf, M.Grass)

	return finalize(b)
end

local function buildHoney()
	local b = newItem("Honey")
	local honey, rim, drip = rgb(232, 150, 30), rgb(250, 212, 130), rgb(255, 184, 40)
	local cloth, white, twine = rgb(200, 60, 52), rgb(250, 246, 238), rgb(200, 170, 120)

	b.prism("Jar", 0.42, 0.78, at(0, 0.39, 0), honey, M.SmoothPlastic, { Reflectance = 0.1 })
	b.prism("Rim", 0.36, 0.08, at(0, 0.82, 0), rim)

	-- pânză cadrilată legată cu sfoară
	b.ring("ClothSkirt", 8, 0.44, 0.8, V(0.36, 0.2, 0.03), cloth, M.Fabric, rad(18), 0)
	b.star("Cloth", 0.4, 0.04, at(0, 0.9, 0) * VERT, cloth, M.Fabric)
	for ix = -1, 1 do
		for iz = -1, 1 do
			if (ix + iz) % 2 == 0 then
				b.box("Check", V(0.17, 0.045, 0.17), at(ix * 0.17, 0.9, iz * 0.17), white, M.Fabric)
			end
		end
	end
	b.prism("Twine", 0.455, 0.05, at(0, 0.8, 0), twine, M.Fabric)

	-- miere scursă pe borcan
	b.box("Drip", V(0.08, 0.28, 0.04), at(-0.15, 0.62, 0.43), drip)
	b.ball("Drip", 0.1, at(-0.15, 0.48, 0.43), drip)
	b.box("Drip", V(0.07, 0.16, 0.04), at(0.13, 0.68, 0.43), drip)
	b.ball("Drip", 0.09, at(0.13, 0.6, 0.43), drip)

	b.box("Label", V(0.32, 0.26, 0.03), at(0, 0.3, 0.425), rgb(245, 232, 200))
	b.octagon("LabelHex", 0.07, 0.02, at(0, 0.3, 0.44) * CFrame.Angles(0, 0, PI / 8), honey)

	-- albină pe capac
	local bee = at(0.18, 0.97, 0.14) * CFrame.Angles(0, rad(30), 0)
	b.box("Bee", V(0.16, 0.1, 0.1), bee, rgb(250, 200, 40))
	for _, x in ipairs({ -0.03, 0.03 }) do
		b.box("BeeStripe", V(0.025, 0.105, 0.105), bee * at(x, 0, 0), rgb(30, 26, 22))
	end
	b.box("BeeHead", V(0.07, 0.08, 0.08), bee * at(0.1, 0, 0), rgb(30, 26, 22))
	for _, s in ipairs({ -1, 1 }) do
		b.box("BeeWing", V(0.07, 0.015, 0.1), bee * at(-0.01, 0.06, s * 0.06) * CFrame.Angles(rad(-20 * s), 0, 0), white, M.SmoothPlastic, { Transparency = 0.3 })
	end

	return finalize(b)
end

local function buildTruffle()
	local b = newItem("Truffle")
	local rand = rng(23)
	local cols = { rgb(72, 50, 38), rgb(58, 40, 30), rgb(90, 64, 46) }

	b.chunk("Truffle", V(0.6, 0.52, 0.58), at(0, 0.3, 0), cols[1], M.Slate, rand)
	for i = 1, 9 do
		local a = rand(0, 2 * PI)
		local e = rand(-0.2, 1.0)
		local s = rand(0.2, 0.32)
		local pos = at(0.27 * math.cos(a) * math.cos(e), 0.3 + 0.22 * math.sin(e), 0.27 * math.sin(a) * math.cos(e))
		b.chunk("Lump", V(s, s, s), pos, cols[i % 3 + 1], M.Slate, rand)
	end

	-- felie care arată interiorul marmorat
	local slice = at(0.52, 0.2, 0.18) * CFrame.Angles(0, rad(-30), rad(-15))
	b.octagon("SliceRim", 0.2, 0.06, slice, cols[2], M.Slate)
	b.octagon("SliceInside", 0.165, 0.065, slice, rgb(196, 168, 140))
	for k, v in ipairs({ { -0.05, 25 }, { 0.04, -35 }, { 0.0, 80 } }) do
		b.box("Vein", V(0.02, 0.22 - k * 0.03, 0.07), slice * at(v[1], 0, 0) * CFrame.Angles(0, 0, rad(v[2])), cols[1])
	end

	-- frunză de stejar
	local leafCF = at(-0.5, 0.02, 0.22) * CFrame.Angles(0, rad(40), 0)
	local oak = rgb(120, 150, 60)
	b.box("OakLeaf", V(0.12, 0.03, 0.5), leafCF, oak, M.Grass)
	for k, z in ipairs({ -0.14, 0.0, 0.14 }) do
		b.box("OakLobe", V(0.36 - k * 0.07, 0.03, 0.1), leafCF * at(0, 0, z), oak, M.Grass)
	end

	return finalize(b)
end

local function buildFur()
	local b = newItem("Fur")
	local rand = rng(31)
	local fur, furLight, furDark = rgb(170, 124, 84), rgb(222, 192, 150), rgb(130, 92, 60)
	local strap, brass = rgb(80, 52, 32), rgb(212, 170, 70)

	-- blană rulată; straturile interioare ies puțin la capete și formează spirala
	local roll = at(0, 0.3, 0) * CFrame.Angles(0, PI / 2, 0)
	b.octagon("Roll", 0.3, 1.1, roll, fur, M.Fabric)
	b.octagon("RollInner", 0.24, 1.12, roll * CFrame.Angles(0, 0, PI / 8), furLight, M.Fabric)
	b.octagon("RollInner", 0.17, 1.14, roll, fur, M.Fabric)
	b.octagon("RollInner", 0.1, 1.16, roll * CFrame.Angles(0, 0, PI / 8), furLight, M.Fabric)

	for _, x in ipairs({ -0.3, 0.3 }) do
		b.octagon("Strap", 0.315, 0.08, at(x, 0.3, 0) * CFrame.Angles(0, PI / 2, 0), strap, M.Leather)
		b.box("Buckle", V(0.1, 0.05, 0.12), at(x, 0.63, 0), brass, M.Metal)
	end

	-- capătul blănii, întins în față, cu margine zimțată
	b.box("Flap", V(1.0, 0.03, 0.35), at(0, 0.015, 0.38), fur, M.Fabric)
	for k = 0, 4 do
		b.wedge("FurEdge", V(0.03, 0.2, 0.12), at(-0.4 + k * 0.2, 0.015, 0.61) * CFrame.Angles(0, PI, 0) * CFrame.Angles(0, 0, PI / 2), fur, M.Fabric)
	end

	for k = 0, 3 do
		b.chunk("Tuft", V(0.14, 0.12, 0.14), at(-0.36 + k * 0.24, 0.6, rand(-0.06, 0.06)), k % 2 == 0 and furDark or furLight, M.Fabric, rand)
	end
	for k = 0, 2 do
		b.chunk("Tuft", V(0.12, 0.06, 0.12), at(-0.3 + k * 0.3, 0.035, 0.42), furDark, M.Fabric, rand, rad(20))
	end

	return finalize(b)
end

local function buildClaw()
	local b = newItem("Claw")
	local rand = rng(41)
	local dark, pale = rgb(64, 56, 52), rgb(236, 228, 208)
	local leather, cord, furDark = rgb(110, 70, 40), rgb(206, 168, 116), rgb(84, 64, 52)

	local root = at(-0.3, 0.12, 0) * CFrame.Angles(0, 0, rad(10))
	local n = 8
	b.sweep(root, 0.75, 115, n, function(i, t, cf, seg)
		local w = 0.42 * (1 - t * 0.85)
		local col = mix(dark, pale, t)
		if i < n then
			b.box("Claw", V(w, seg * 1.12, w * 0.55), cf, col)
		else
			-- vârf ascuțit: fața dreaptă pe exteriorul curbei
			b.wedge("ClawTip", V(w * 0.55, seg * 1.3, w), cf * at(0, seg * 0.1, 0) * CFrame.Angles(0, -PI / 2, 0), col)
		end
	end)

	b.prism("Wrap", 0.23, 0.16, root * at(0, 0.06, 0), leather, M.Leather)
	b.prism("WrapBand", 0.24, 0.04, root * at(0, 0.1, 0) * CFrame.Angles(0, PI / 8, 0), cord, M.Fabric)
	b.chunk("Knuckle", V(0.36, 0.2, 0.3), root * at(0, -0.06, 0), furDark, M.Fabric, rand, rad(15))
	b.box("Cord", V(0.2, 0.03, 0.03), root * at(-0.2, 0.0, 0.06) * CFrame.Angles(0, 0, rad(30)), cord, M.Fabric)
	b.gem("Bead", 0.11, root * at(-0.3, -0.06, 0.06), rgb(200, 40, 40))

	return finalize(b)
end

local function buildScale()
	local b = newItem("Scale")
	local shine = { Reflectance = 0.15 }

	local function scale(cf, s, colA, colB, ridge)
		b.octagon("Scale", 0.5 * s, 0.08 * s, cf * at(0, 0.15 * s, 0) * CFrame.Angles(0, 0, PI / 8), colA, M.SmoothPlastic, shine)
		b.box("Scale", V(0.72 * s, 0.72 * s, 0.08 * s), cf * at(0, -0.1 * s, 0) * CFrame.Angles(0, 0, PI / 4), colA, M.SmoothPlastic, shine)
		b.octagon("ScaleInner", 0.37 * s, 0.1 * s, cf * at(0, 0.15 * s, 0) * CFrame.Angles(0, 0, PI / 8), colB, M.SmoothPlastic, shine)
		b.box("ScaleInner", V(0.53 * s, 0.53 * s, 0.1 * s), cf * at(0, -0.1 * s, 0) * CFrame.Angles(0, 0, PI / 4), colB, M.SmoothPlastic, shine)
		b.box("Ridge", V(0.05 * s, 1.0 * s, 0.12 * s), cf * at(0, 0.02 * s, 0), ridge)
		for _, sx in ipairs({ -1, 1 }) do
			b.box("Rib", V(0.04 * s, 0.36 * s, 0.11 * s), cf * at(sx * 0.13 * s, 0.12 * s, 0) * CFrame.Angles(0, 0, rad(-40 * sx)), ridge)
		end
	end

	scale(at(0.45, 0.42, -0.3) * CFrame.Angles(rad(-12), rad(-20), rad(-22)), 0.7, rgb(90, 14, 20), rgb(130, 22, 28), rgb(200, 90, 50))
	scale(at(0, 0.62, 0) * CFrame.Angles(rad(-12), 0, 0), 1, rgb(120, 18, 26), rgb(190, 40, 36), rgb(255, 160, 70))

	return finalize(b)
end

local function buildShell()
	local b = newItem("Shell")
	local rim, core = rgb(78, 60, 34), rgb(52, 40, 24)
	local plateA, plateB, scute = rgb(140, 112, 56), rgb(162, 132, 64), rgb(198, 168, 98)

	b.prism("Rim", 0.76, 0.08, at(0, 0.04, 0), rim, M.Slate)
	b.prism("Core", 0.52, 0.3, at(0, 0.23, 0), core, M.Slate)
	b.prism("Core", 0.3, 0.15, at(0, 0.455, 0), core, M.Slate)

	-- dom din plăci înclinate, cu solzi mai deschiși în mijloc
	b.ring("Plate", 8, 0.635, 0.23, V(0.5, 0.36, 0.07), plateA, M.Slate, rad(-29.5), 0, plateB)
	b.ring("Scute", 8, 0.635, 0.23, V(0.32, 0.2, 0.08), scute, M.Slate, rad(-29.5), 0)
	b.ring("Plate", 8, 0.415, 0.465, V(0.32, 0.32, 0.07), plateB, M.Slate, rad(-57.8), PI / 8, plateA)
	b.ring("Scute", 8, 0.415, 0.465, V(0.18, 0.18, 0.08), scute, M.Slate, rad(-57.8), PI / 8)
	b.prism("Top", 0.3, 0.07, at(0, 0.55, 0), plateA, M.Slate)
	b.prism("TopScute", 0.18, 0.08, at(0, 0.555, 0) * CFrame.Angles(0, PI / 8, 0), scute, M.Slate)

	for _, z in ipairs({ -0.15, 0, 0.15 }) do
		b.box("Spike", V(0.12, 0.12, 0.12), at(0, 0.6, z) * CFrame.Angles(PI / 4, 0, PI / 4), rim, M.Slate)
	end

	return finalize(b)
end

local function buildHorn()
	local b = newItem("Horn")
	local base, mid, tip = rgb(84, 64, 50), rgb(176, 150, 116), rgb(244, 236, 214)
	local gold = rgb(232, 186, 72)

	local root = CFrame.Angles(0, rad(-25), rad(15))
	local n = 9
	b.sweep(root, 0.8, 120, n, function(i, t, cf, seg)
		local a = 0.24 * (1 - t * 0.82)
		local col = t < 0.5 and mix(base, mid, t * 2) or mix(mid, tip, (t - 0.5) * 2)
		b.prism("Horn", a, seg * 1.12, cf, col)
		if i == 2 then
			b.prism("GoldBand", a * 1.12, seg * 0.35, cf, gold, M.Metal)
			b.box("Gem", V(0.08, 0.08, 0.04), cf * at(0, 0, a * 1.12) * CFrame.Angles(0, 0, PI / 4), rgb(60, 180, 255), M.Neon)
		elseif i % 2 == 0 and i < n then
			b.prism("Ridge", a * 1.06, seg * 0.16, cf * at(0, seg * 0.5, 0), mix(col, base, 0.35))
		end
	end)
	b.prism("Base", 0.26, 0.06, root * at(0, 0.02, 0), rgb(60, 46, 36))

	return finalize(b)
end

local function buildGel()
	local b = newItem("Gel")
	local gel, core, bubble = rgb(140, 255, 110), rgb(210, 255, 170), rgb(240, 255, 230)
	local gp = { Transparency = 0.3 }

	b.prism("Gel", 0.55, 0.12, at(0, 0.06, 0), gel, M.Glass, gp)
	b.prism("Gel", 0.44, 0.22, at(0, 0.22, 0) * CFrame.Angles(0, PI / 8, 0), gel, M.Glass, gp)
	b.prism("Gel", 0.3, 0.2, at(0, 0.42, 0), gel, M.Glass, gp)
	b.prism("Gel", 0.16, 0.14, at(0, 0.58, 0) * CFrame.Angles(0, PI / 8, 0), gel, M.Glass, gp)
	b.box("Gel", V(0.14, 0.14, 0.14), at(0, 0.68, 0) * CFrame.Angles(PI / 4, 0, PI / 4), gel, M.Glass, gp)

	local corePart = b.gem("Core", 0.3, at(0, 0.26, 0), core, M.Neon)
	for _, p in ipairs({ { 0.2, 0.1, 0.25 }, { -0.25, 0.16, 0.1 }, { 0.1, 0.45, -0.1 }, { -0.1, 0.3, -0.25 } }) do
		b.box("Bubble", V(0.06, 0.06, 0.06), at(p[1], p[2], p[3]) * CFrame.Angles(PI / 4, PI / 4, 0), bubble, M.Neon)
	end

	b.prism("Droplet", 0.12, 0.05, at(0.68, 0.025, 0.15), gel, M.Glass, gp)
	b.gem("Droplet", 0.1, at(-0.62, 0.05, -0.25), gel, M.Glass, gp)

	b.light(corePart, gel, 7, 1.5)

	return finalize(b)
end

local function buildAshes()
	local b = newItem("Ashes")
	local rand = rng(53)
	local orange, yellow, red = rgb(255, 120, 30), rgb(255, 200, 60), rgb(200, 50, 30)

	b.prism("Ash", 0.62, 0.1, at(0, 0.05, 0), rgb(84, 82, 84), M.Sand)
	b.prism("Ash", 0.48, 0.12, at(0, 0.15, 0) * CFrame.Angles(0, PI / 8, 0), rgb(106, 104, 104), M.Sand)
	b.prism("Ash", 0.34, 0.12, at(0, 0.26, 0), rgb(128, 126, 124), M.Sand)
	local top = b.prism("Ash", 0.2, 0.1, at(0, 0.36, 0) * CFrame.Angles(0, PI / 8, 0), rgb(150, 148, 146), M.Sand)

	local embers = { { 0.5, 0.1, 0.1 }, { -0.3, 0.21, 0.3 }, { 0.15, 0.32, -0.2 }, { -0.42, 0.1, -0.35 }, { 0.05, 0.42, 0.08 }, { 0.3, 0.21, -0.3 } }
	for k, e in ipairs(embers) do
		b.box("Ember", V(0.07, 0.07, 0.07), at(e[1], e[2], e[3]) * CFrame.Angles(PI / 4, PI / 4, 0), k % 2 == 0 and yellow or orange, M.Neon)
	end
	for _, p in ipairs({ { 0.55, 0.06, -0.2 }, { -0.5, 0.07, 0.25 }, { 0.2, 0.2, 0.38 } }) do
		b.chunk("Char", V(0.18, 0.08, 0.12), at(p[1], p[2], p[3]), rgb(28, 24, 24), M.Slate, rand, rad(30))
	end

	-- pană de phoenix ieșind din cenușă
	featherShape(b, at(0.08, 0.3, 0) * CFrame.Angles(rad(15), rad(30), rad(-25)), 0.85, function(i, n)
		if i >= n - 1 then
			return yellow
		elseif i >= n - 4 then
			return orange
		end
		return red
	end, function(i, n)
		return i >= n - 4 and M.Neon or M.SmoothPlastic
	end)

	b.particles(top, orange, red, 3, { rise = 1.5, size = 0.08, speedMin = 0.3, speedMax = 0.6, lifeMin = 1, lifeMax = 2 })
	b.light(top, orange, 5, 1)

	return finalize(b)
end

local function buildStardust()
	local b = newItem("Stardust")
	local glass, gold = rgb(200, 225, 255), rgb(255, 214, 110)
	local gp = { Transparency = 0.55 }

	b.prism("Vial", 0.3, 0.55, at(0, 0.275, 0), glass, M.Glass, gp)
	b.prism("Shoulder", 0.22, 0.08, at(0, 0.59, 0) * CFrame.Angles(0, PI / 8, 0), glass, M.Glass, gp)
	b.prism("Neck", 0.12, 0.2, at(0, 0.73, 0), glass, M.Glass, gp)
	b.prism("Lip", 0.15, 0.04, at(0, 0.84, 0), glass, M.Glass, gp)
	b.prism("Cork", 0.11, 0.16, at(0, 0.9, 0), rgb(196, 150, 100), M.Wood)
	b.prism("Twine", 0.13, 0.04, at(0, 0.7, 0), rgb(150, 110, 70), M.Fabric)
	b.star("Star", 0.11, 0.04, at(0, 1.08, 0), gold, M.Neon)

	-- straturi de praf strălucitor
	b.prism("Dust", 0.26, 0.2, at(0, 0.12, 0), rgb(70, 90, 255), M.Neon)
	b.prism("Dust", 0.26, 0.14, at(0, 0.29, 0), rgb(170, 90, 255), M.Neon)
	local top = b.prism("Dust", 0.26, 0.1, at(0, 0.41, 0), gold, M.Neon)

	for _, p in ipairs({ { 0.38, 0.02, 0.25 }, { -0.36, 0.02, 0.18 }, { 0.3, 0.02, -0.3 } }) do
		b.box("Spill", V(0.05, 0.03, 0.05), at(p[1], p[2], p[3]) * CFrame.Angles(0, PI / 4, 0), rgb(170, 90, 255), M.Neon)
	end
	b.star("Star", 0.06, 0.03, at(0.42, 0.07, 0.05) * CFrame.Angles(0, rad(25), rad(20)), gold, M.Neon)
	b.star("Star", 0.07, 0.03, at(-0.32, 0.95, 0.1) * CFrame.Angles(0, rad(-20), 0), rgb(255, 255, 255), M.Neon)

	b.particles(top, gold, rgb(110, 130, 255), 5, { size = 0.1 })
	b.light(top, rgb(150, 120, 255), 6, 1)

	return finalize(b)
end

local function buildEssence()
	local b = newItem("Essence")
	local outer, inner, mote = rgb(255, 100, 200), rgb(255, 225, 245), rgb(255, 170, 230)
	local gp = { Transparency = 0.35 }

	-- flacără de suflet: cuburi rotite care se îngustează în sus
	local layers = { { 0.5, 0.32, 0 }, { 0.4, 0.62, 0.04 }, { 0.3, 0.88, -0.03 }, { 0.2, 1.08, 0.03 }, { 0.12, 1.24, 0 } }
	local corePart
	for i, l in ipairs(layers) do
		local cf = at(l[3], l[2], 0) * CFrame.Angles(PI / 4, rad(i * 20), PI / 4)
		b.box("Flame", V(l[1], l[1], l[1]), cf, outer, M.Glass, gp)
		if i <= 3 then
			local s = l[1] * 0.55
			local p = b.box("FlameCore", V(s, s, s), cf, inner, M.Neon)
			corePart = corePart or p
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		b.box("Flame", V(0.16, 0.16, 0.16), at(s * 0.26, 0.55, 0) * CFrame.Angles(PI / 4, 0, PI / 4), outer, M.Glass, gp)
	end

	for k = 0, 5 do
		local a = k * PI / 3
		b.box("Mote", V(0.06, 0.06, 0.06), at(0.5 * math.cos(a), 0.35 + 0.1 * k, 0.5 * math.sin(a)) * CFrame.Angles(PI / 4, PI / 4, 0), mote, M.Neon)
	end

	b.light(corePart, outer, 9, 1.8)
	b.particles(corePart, outer, inner, 6, { rise = 1, size = 0.12 })

	return finalize(b)
end

local function buildShard()
	local b = newItem("Shard")
	local rand = rng(97)
	local crystal, core, light = rgb(110, 60, 255), rgb(205, 165, 255), rgb(150, 110, 255)
	local rock, rock2 = rgb(42, 36, 58), rgb(58, 50, 78)
	local gp = { Transparency = 0.2, Reflectance = 0.1 }

	b.chunk("Rock", V(0.9, 0.3, 0.75), at(0, 0.12, 0), rock, M.Slate, rand, rad(12))
	b.chunk("Rock", V(0.45, 0.3, 0.4), at(0.38, 0.1, 0.2), rock2, M.Slate, rand, rad(20))
	b.chunk("Rock", V(0.4, 0.25, 0.45), at(-0.4, 0.08, -0.15), rock2, M.Slate, rand, rad(20))

	local mainCF = at(0, 0.15, 0) * CFrame.Angles(rad(6), 0, rad(-8))
	local main = b.crystal("Crystal", 0.36, 0.95, 0.3, mainCF, crystal, M.Glass, gp)
	b.crystal("CrystalCore", 0.16, 0.85, 0.16, mainCF * at(0, 0.05, 0), core, M.Neon)
	b.crystal("Crystal", 0.22, 0.5, 0.18, at(0.28, 0.15, 0.1) * CFrame.Angles(rad(-10), rad(20), rad(-35)), crystal, M.Glass, gp)
	b.crystal("Crystal", 0.18, 0.4, 0.15, at(-0.25, 0.15, -0.05) * CFrame.Angles(rad(15), rad(-10), rad(32)), crystal, M.Glass, gp)
	b.crystal("Crystal", 0.14, 0.28, 0.12, at(-0.1, 0.18, 0.28) * CFrame.Angles(rad(35), 0, rad(10)), light, M.Neon)

	for _, s in ipairs({ { 0.55, 1.0, 0.1, 0.07 }, { -0.5, 0.8, 0, 0.06 }, { 0.35, 1.38, -0.1, 0.05 } }) do
		b.star("Star", s[4], 0.03, at(s[1], s[2], s[3]) * CFrame.Angles(0, rad(30), 0), rgb(255, 255, 255), M.Neon)
	end

	b.light(main, crystal, 12, 2)
	b.particles(main, light, rgb(110, 230, 255), 8)

	return finalize(b)
end

---------------------------------------------------------------------------

local items = {
	{ "Feather", "Feather", buildFeather },
	{ "Wool", "Wool", buildWool },
	{ "Milk", "Milk", buildMilk },
	{ "Berry", "Forest Berries", buildBerry },
	{ "Honey", "Honey", buildHoney },
	{ "Truffle", "Truffle", buildTruffle },
	{ "Fur", "Soft Fur", buildFur },
	{ "Claw", "Beast Claw", buildClaw },
	{ "Scale", "Dragon Scale", buildScale },
	{ "Shell", "Hard Shell", buildShell },
	{ "Horn", "Horn", buildHorn },
	{ "Gel", "Luminescent Gel", buildGel },
	{ "Ashes", "Ashes", buildAshes },
	{ "Stardust", "Stardust", buildStardust },
	{ "Essence", "Essence", buildEssence },
	{ "Shard", "Cosmic Shard", buildShard },
}

local old = ReplicatedStorage:FindFirstChild("Resources")
if old then
	old:Destroy()
end
local oldShowcase = workspace:FindFirstChild("ResourceShowcase")
if oldShowcase then
	oldShowcase:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "Resources"

local showcase = Instance.new("Folder")
showcase.Name = "ResourceShowcase"

for i, item in ipairs(items) do
	local model = item[3]()
	model.Parent = folder

	local preview = model:Clone()
	local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
	preview:PivotTo(CFrame.new((col - 3.5) * 2.5, 0.5 + preview.PrimaryPart.Size.Y / 2, 12 + row * 3))

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 160, 0, 30)
	gui.StudsOffset = Vector3.new(0, preview.PrimaryPart.Size.Y / 2 + 0.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = preview.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = item[2]
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	preview.Parent = showcase
end

folder.Parent = ReplicatedStorage
showcase.Parent = workspace

print(string.format("[ResourceBuilder] %d resurse create în ReplicatedStorage.Resources", #items))
