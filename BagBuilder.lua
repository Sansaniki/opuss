--[[
	BagBuilder — generează 7 ghiozdane low-poly, de la tier 1 la tier 7.

	Cum îl folosești (o singură dată, în Roblox Studio):
	  • View → Command Bar, lipești tot fișierul și apeși Enter, SAU
	  • îl pui într-un Script în ServerScriptService, apeși Run, apoi copiezi
	    ReplicatedStorage.Bags din sesiunea de Run înapoi în Edit (copy/paste).

	Rezultat:
	  ReplicatedStorage.Bags.<Nume>  — modelele template (PrimaryPart = "Handle")
	  Workspace.BagShowcase          — un rând de preview cu toate ghiozdanele (poate fi șters)

	Convenții:
	  • fața -Z a ghiozdanului stă lipită de spatele personajului, fața +Z (buzunarele) e spre exterior;
	  • toate piesele sunt sudate (WeldConstraint) de Handle, deci când faci Unanchor se mișcă împreună;
	  • atribute pe fiecare model: Tier, Capacity, Rarity, MountHeight (folosit de BagEquip).
	Rularea din nou înlocuiește modelele vechi.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = Enum.Material
local rad = math.rad
local PI = math.pi

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

-- Cilindrii Roblox au axa pe X; astea îi întorc pe verticală (Y) sau înainte (Z).
local UP = CFrame.Angles(0, 0, rad(90))
local FWD = CFrame.Angles(0, rad(90), 0)

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

-- Creează modelul gol + un "builder" cu primitive low-poly.
local function newBag(info)
	local model = Instance.new("Model")
	model.Name = info.name

	local handle = makePart(model, "Part", "Handle", info.body, CFrame.new(), rgb(255, 255, 255), M.SmoothPlastic, {
		Transparency = 1,
		CastShadow = false,
	})
	model.PrimaryPart = handle

	model:SetAttribute("Tier", info.tier)
	model:SetAttribute("Capacity", info.capacity)
	model:SetAttribute("Rarity", info.rarity)
	model:SetAttribute("MountHeight", info.mount)

	local b = { model = model, handle = handle }

	function b.box(name, size, cf, color, mat, props)
		return makePart(model, "Part", name, size, cf, color, mat, props)
	end

	-- WedgePart: fața înclinată coboară spre -Z.
	function b.wedge(name, size, cf, color, mat, props)
		return makePart(model, "WedgePart", name, size, cf, color, mat, props)
	end

	-- Cilindru cu axa pe X-ul local al lui cf.
	function b.cyl(name, length, diameter, cf, color, mat, props)
		props = props or {}
		props.Shape = Enum.PartType.Cylinder
		return makePart(model, "Part", name, Vector3.new(length, diameter, diameter), cf, color, mat, props)
	end

	function b.ball(name, diameter, cf, color, mat, props)
		props = props or {}
		props.Shape = Enum.PartType.Ball
		return makePart(model, "Part", name, Vector3.new(diameter, diameter, diameter), cf, color, mat, props)
	end

	-- Octogon = 4 benzi (lățime = latura) rotite la 0/45/90/135°. Planul e XY-ul local al lui cf.
	function b.octagon(name, apothem, thickness, cf, color, mat, props)
		local s = Vector3.new(apothem * 2, apothem * 2 * math.tan(PI / 8), thickness)
		local first
		for k = 0, 3 do
			local p = b.box(name, s, cf * CFrame.Angles(0, 0, k * PI / 4), color, mat, props)
			first = first or p
		end
		return first
	end

	-- Stea cu 8 colțuri = două pătrate suprapuse, rotite la 45°.
	function b.star(name, radius, thickness, cf, color, mat, props)
		local s = Vector3.new(radius * 2, radius * 2, thickness)
		local first = b.box(name, s, cf, color, mat, props)
		b.box(name, s, cf * CFrame.Angles(0, 0, PI / 4), color, mat, props)
		return first
	end

	-- Inel de N blocuri pe un cerc orizontal (pereți de coș, benzi, ramă).
	-- tilt > 0 apleacă partea de sus a blocurilor spre exterior.
	function b.ring(name, n, radius, y, size, color, mat, tilt)
		local parts = {}
		for i = 0, n - 1 do
			local a = i * 2 * PI / n
			local cf = at(radius * math.cos(a), y, radius * math.sin(a))
				* CFrame.Angles(0, PI / 2 - a, 0)
				* CFrame.Angles(tilt or 0, 0, 0)
			parts[#parts + 1] = b.box(name, size, cf, color, mat)
		end
		return parts
	end

	-- Două bretele verticale pe spate (fața -Z).
	function b.straps(depth, spread, height, width, color, mat, thickness)
		thickness = thickness or 0.08
		for _, s in ipairs({ -1, 1 }) do
			b.box("Strap", Vector3.new(width, height, thickness), at(s * spread, 0, -depth / 2 - thickness / 2), color, mat)
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

	function b.particles(part, c0, c1, rate)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(c0, c1)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new(0.2)
		e.LightEmission = 1
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Rate = rate
		e.Speed = NumberRange.new(0.2, 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = part
		return e
	end

	return b
end

local function finalize(b)
	for _, d in ipairs(b.model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= b.handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = b.handle
			w.Part1 = d
			w.Parent = d
		end
	end
	return b.model
end

---------------------------------------------------------------------------
-- Tier 1 — Wooden Basket: coș octogonal din șipci, ramă, curele de sfoară.
---------------------------------------------------------------------------
local function buildWoodenBasket()
	local H, R = 1.5, 0.7
	local tilt = rad(7)
	local b = newBag({ name = "Wooden Basket", tier = 1, capacity = 10, rarity = "Basic", mount = 0.05, body = Vector3.new(1.6, H, 1.6) })

	local woodA, woodB = rgb(181, 130, 76), rgb(150, 102, 56)
	local dark = rgb(112, 74, 40)
	local rope = rgb(214, 190, 140)
	local slatW = 2 * R * math.tan(PI / 8)

	local slats = b.ring("Slat", 8, R, 0, Vector3.new(slatW, H, 0.1), woodA, M.Wood, tilt)
	for i, s in ipairs(slats) do
		if i % 2 == 0 then
			s.Color = woodB
		end
	end

	-- benzi împletite (urmează înclinarea pereților)
	for _, y in ipairs({ -0.4, 0.3 }) do
		local r = R + y * math.tan(tilt) + 0.06
		b.ring("Band", 8, r, y, Vector3.new(2 * r * math.tan(PI / 8) + 0.03, 0.14, 0.05), dark, M.Wood, tilt)
	end

	local rimR = R + (H / 2) * math.tan(tilt) + 0.02
	b.ring("Rim", 8, rimR, H / 2, Vector3.new(2 * rimR * math.tan(PI / 8) + 0.06, 0.14, 0.18), dark, M.Wood)

	b.octagon("Bottom", R - (H / 2) * math.tan(tilt) - 0.02, 0.12, at(0, -H / 2 + 0.04, 0) * CFrame.Angles(PI / 2, 0, 0), dark, M.Wood)

	-- curele de sfoară pe spate, înclinate ca peretele
	for _, s in ipairs({ -1, 1 }) do
		b.box("Rope", Vector3.new(0.1, H, 0.06), at(s * 0.28, 0, -(R + 0.08)) * CFrame.Angles(-tilt, 0, 0), rope, M.Fabric)
		b.box("RopeLoop", Vector3.new(0.1, 0.08, 0.3), at(s * 0.28, H / 2 + 0.08, -rimR + 0.02), rope, M.Fabric)
	end

	-- puțin conținut ca să pară folosit
	b.ball("Apple", 0.38, at(-0.22, H / 2 - 0.02, 0.12), rgb(196, 40, 40), M.SmoothPlastic)
	b.box("AppleStem", Vector3.new(0.04, 0.12, 0.04), at(-0.22, H / 2 + 0.2, 0.12), rgb(90, 60, 30), M.Wood)
	b.box("Stick", Vector3.new(0.08, 0.7, 0.08), at(0.22, H / 2 + 0.05, 0.05) * CFrame.Angles(0, 0, rad(-18)), rgb(122, 86, 48), M.Wood)

	return finalize(b)
end

---------------------------------------------------------------------------
-- Tier 2 — Leather Pouch: săculeț mic cu șnur, clapă și nasture de alamă.
---------------------------------------------------------------------------
local function buildLeatherPouch()
	local b = newBag({ name = "Leather Pouch", tier = 2, capacity = 20, rarity = "Common", mount = 0, body = Vector3.new(1.2, 1.0, 0.6) })

	local leather = rgb(124, 74, 42)
	local dark = rgb(86, 50, 28)
	local cord = rgb(206, 168, 116)
	local brass = rgb(212, 170, 70)

	b.box("Body", Vector3.new(1.2, 1.0, 0.6), at(0, 0, 0), leather, M.Leather)
	b.box("BottomBevel", Vector3.new(0.95, 0.2, 0.5), at(0, -0.58, 0), leather, M.Leather)
	b.box("Neck", Vector3.new(0.9, 0.22, 0.46), at(0, 0.6, 0), leather, M.Leather)
	b.box("Cord", Vector3.new(0.96, 0.08, 0.52), at(0, 0.62, 0), cord, M.Fabric)
	b.box("TopPuff", Vector3.new(1.0, 0.14, 0.5), at(0, 0.78, 0), leather, M.Leather)

	b.box("Flap", Vector3.new(1.06, 0.55, 0.06), at(0, 0.2, 0.33), dark, M.Leather)
	b.box("FlapTip", Vector3.new(0.4, 0.4, 0.05), at(0, -0.07, 0.325) * CFrame.Angles(0, 0, PI / 4), dark, M.Leather)
	b.box("Stitch", Vector3.new(1.0, 0.03, 0.02), at(0, 0.43, 0.365), cord, M.Fabric)
	b.ball("Button", 0.14, at(0, -0.2, 0.37), brass, M.Metal)

	for _, s in ipairs({ -1, 1 }) do
		b.box("CordTail", Vector3.new(0.05, 0.3, 0.05), at(s * 0.08, 0.47, 0.38) * CFrame.Angles(0, 0, rad(15 * s)), cord, M.Fabric)
	end

	-- o singură curea, purtată în diagonală
	b.box("Strap", Vector3.new(0.14, 1.9, 0.06), at(0, 0, -0.33) * CFrame.Angles(0, 0, rad(35)), dark, M.Leather)

	return finalize(b)
end

---------------------------------------------------------------------------
-- Tier 3 — Canvas Bag: rucsac simplu de pânză, cu partea de sus rulată.
---------------------------------------------------------------------------
local function buildCanvasBag()
	local b = newBag({ name = "Canvas Bag", tier = 3, capacity = 35, rarity = "Uncommon", mount = -0.15, body = Vector3.new(1.4, 1.5, 0.7) })

	local canvas = rgb(214, 196, 150)
	local canvasLight = rgb(228, 212, 170)
	local canvasDark = rgb(176, 158, 112)
	local strap = rgb(112, 80, 50)

	b.box("Body", Vector3.new(1.4, 1.5, 0.7), at(0, 0, 0), canvas, M.Fabric)
	b.box("Bottom", Vector3.new(1.44, 0.22, 0.74), at(0, -0.7, 0), canvasDark, M.Fabric)
	b.cyl("RollTop", 1.46, 0.36, at(0, 0.82, 0), canvasLight, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		b.box("RollTie", Vector3.new(0.1, 0.42, 0.42), at(s * 0.45, 0.82, 0), strap, M.Leather)
	end

	b.box("Pocket", Vector3.new(0.9, 0.6, 0.1), at(0, -0.25, 0.39), canvasDark, M.Fabric)
	b.box("PocketFlap", Vector3.new(0.94, 0.18, 0.13), at(0, 0.08, 0.4), canvasDark, M.Fabric)
	b.box("Patch", Vector3.new(0.22, 0.22, 0.03), at(0.25, -0.3, 0.45) * CFrame.Angles(0, 0, rad(10)), rgb(170, 72, 52), M.Fabric)

	b.straps(0.7, 0.4, 1.4, 0.18, strap, M.Leather)

	return finalize(b)
end

---------------------------------------------------------------------------
-- Tier 4 — Explorer Pack: rucsac de drumeție cu sac de dormit și bidon.
---------------------------------------------------------------------------
local function buildExplorerPack()
	local b = newBag({ name = "Explorer Pack", tier = 4, capacity = 60, rarity = "Rare", mount = -0.45, body = Vector3.new(1.5, 1.7, 0.8) })

	local green = rgb(78, 110, 64)
	local greenDark = rgb(58, 84, 48)
	local leather = rgb(120, 80, 46)
	local roll = rgb(156, 62, 50)
	local metal = rgb(175, 175, 180)

	b.box("Body", Vector3.new(1.5, 1.7, 0.8), at(0, 0, 0), green, M.Fabric)
	b.box("Lid", Vector3.new(1.56, 0.32, 0.86), at(0, 0.8, 0), greenDark, M.Fabric)
	b.box("Badge", Vector3.new(0.26, 0.15, 0.03), at(0, 0.8, 0.445), rgb(232, 192, 70), M.SmoothPlastic)
	b.box("Bottom", Vector3.new(1.54, 0.2, 0.84), at(0, -0.8, 0), leather, M.Leather)

	b.box("FrontPocket", Vector3.new(1.1, 0.8, 0.24), at(0, -0.28, 0.5), green, M.Fabric)
	b.box("PocketFlap", Vector3.new(1.14, 0.26, 0.3), at(0, 0.14, 0.51), greenDark, M.Fabric)
	b.box("BuckleStrap", Vector3.new(0.1, 0.3, 0.03), at(0, -0.08, 0.635), leather, M.Leather)
	b.box("Buckle", Vector3.new(0.2, 0.16, 0.06), at(0, 0.04, 0.67), metal, M.Metal)

	b.box("SidePocket", Vector3.new(0.22, 0.65, 0.5), at(-0.85, -0.35, 0.05), greenDark, M.Fabric)

	b.cyl("Canteen", 0.55, 0.36, at(0.93, -0.3, 0.05) * UP, rgb(92, 112, 122), M.Metal)
	b.cyl("CanteenBand", 0.06, 0.38, at(0.93, -0.2, 0.05) * UP, leather, M.Leather)
	b.cyl("CanteenCap", 0.1, 0.16, at(0.93, 0.02, 0.05) * UP, rgb(60, 60, 64), M.Metal)

	b.cyl("Bedroll", 1.7, 0.46, at(0, 1.18, 0), roll, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		b.box("BedrollStrap", Vector3.new(0.1, 0.5, 0.5), at(s * 0.5, 1.18, 0), leather, M.Leather)
	end

	b.straps(0.8, 0.45, 1.5, 0.2, leather, M.Leather, 0.1)

	return finalize(b)
end

---------------------------------------------------------------------------
-- Tier 5 — Reinforced Pack: cușcă de metal pe muchii, plăci blindate, nituri.
---------------------------------------------------------------------------
local function buildReinforcedPack()
	local W, H, D = 1.6, 1.8, 0.85
	local b = newBag({ name = "Reinforced Pack", tier = 5, capacity = 100, rarity = "Epic", mount = -0.25, body = Vector3.new(W, H, D) })

	local body = rgb(58, 64, 76)
	local panel = rgb(80, 88, 102)
	local strap = rgb(40, 44, 52)
	local steel = rgb(152, 157, 167)
	local darkSteel = rgb(96, 101, 112)
	local accent = rgb(232, 150, 40)
	local t = 0.14

	b.box("Body", Vector3.new(W, H, D), at(0, 0, 0), body, M.Fabric)

	-- cele 12 muchii + colțare
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			b.box("FrameV", Vector3.new(t, H + t, t), at(sx * W / 2, 0, sz * D / 2), steel, M.Metal)
		end
	end
	for _, sy in ipairs({ -1, 1 }) do
		for _, s in ipairs({ -1, 1 }) do
			b.box("FrameX", Vector3.new(W + t, t, t), at(0, sy * H / 2, s * D / 2), steel, M.Metal)
			b.box("FrameZ", Vector3.new(t, t, D + t), at(s * W / 2, sy * H / 2, 0), steel, M.Metal)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				b.box("Corner", Vector3.new(0.2, 0.2, 0.2), at(sx * W / 2, sy * H / 2, sz * D / 2), darkSteel, M.Metal)
			end
		end
	end

	b.box("ArmorPlate", Vector3.new(1.1, 0.95, 0.08), at(0, 0.2, 0.46), steel, M.DiamondPlate)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			b.ball("Rivet", 0.1, at(sx * 0.47, 0.2 + sy * 0.4, 0.51), darkSteel, M.Metal)
		end
		b.box("SidePlate", Vector3.new(0.06, 0.9, 0.5), at(sx * (W / 2 + 0.03), 0, 0), steel, M.DiamondPlate)
	end
	b.box("HazardStripe", Vector3.new(1.32, 0.1, 0.04), at(0, -0.36, 0.445), accent, M.SmoothPlastic)

	b.box("LowerPocket", Vector3.new(1.2, 0.42, 0.18), at(0, -0.62, 0.5), panel, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		b.box("PocketBuckle", Vector3.new(0.16, 0.14, 0.05), at(s * 0.35, -0.5, 0.61), steel, M.Metal)
	end

	b.box("HandleBar", Vector3.new(0.6, 0.09, 0.12), at(0, 1.15, 0), steel, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		b.box("HandlePost", Vector3.new(0.09, 0.22, 0.12), at(s * 0.3, 1.04, 0), steel, M.Metal)
		b.box("StrapPad", Vector3.new(0.28, 0.2, 0.06), at(s * 0.45, 0.35, -D / 2 - 0.15), steel, M.Metal)
	end

	b.straps(D, 0.45, 1.6, 0.26, strap, M.Fabric, 0.12)

	return finalize(b)
end

---------------------------------------------------------------------------
-- Tier 6 — Enchanted Satchel: geantă violet cu ornamente aurii, gemă și cristale.
---------------------------------------------------------------------------
local function buildEnchantedSatchel()
	local b = newBag({ name = "Enchanted Satchel", tier = 6, capacity = 175, rarity = "Legendary", mount = -0.15, body = Vector3.new(1.5, 1.3, 0.7) })

	local leather = rgb(88, 42, 136)
	local dark = rgb(60, 26, 96)
	local gold = rgb(232, 186, 72)
	local gem = rgb(120, 230, 255)
	local rune = rgb(196, 128, 255)

	b.box("Body", Vector3.new(1.5, 1.3, 0.7), at(0, 0, 0), leather, M.Leather)
	b.cyl("RoundTop", 1.5, 0.7, at(0, 0.65, 0), leather, M.Leather)
	for _, s in ipairs({ -1, 1 }) do
		b.cyl("Medallion", 0.04, 0.74, at(s * 0.76, 0.65, 0), gold, M.Metal)
	end

	b.box("Flap", Vector3.new(1.54, 0.75, 0.08), at(0, 0.28, 0.39), dark, M.Leather)
	b.box("TrimBottom", Vector3.new(1.58, 0.07, 0.1), at(0, -0.095, 0.39), gold, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		b.box("TrimSide", Vector3.new(0.07, 0.75, 0.1), at(s * 0.77, 0.28, 0.39), gold, M.Metal)
	end

	b.cyl("GemSetting", 0.06, 0.46, at(0, 0.05, 0.44) * FWD, gold, M.Metal)
	local gemPart = b.box("Gem", Vector3.new(0.24, 0.24, 0.24), at(0, 0.05, 0.5) * CFrame.Angles(rad(45), rad(45), 0), gem, M.Neon)

	-- rune simple pe clapă
	for _, s in ipairs({ -1, 1 }) do
		b.box("Rune", Vector3.new(0.05, 0.24, 0.02), at(s * 0.45, 0.32, 0.435), rune, M.Neon)
		b.box("Rune", Vector3.new(0.18, 0.05, 0.02), at(s * 0.45, 0.36, 0.436) * CFrame.Angles(0, 0, rad(30 * s)), rune, M.Neon)
	end

	-- cristale care „plutesc” lângă geantă (sudate, statice)
	local crystals = {
		{ -0.98, 0.8, 0.2, 20, 45, 10 },
		{ 1.02, 0.3, 0.3, 45, 10, 35 },
		{ -0.92, -0.42, 0.25, 10, 30, 45 },
	}
	for _, c in ipairs(crystals) do
		b.box("Crystal", Vector3.new(0.16, 0.26, 0.16), at(c[1], c[2], c[3]) * CFrame.Angles(rad(c[4]), rad(c[5]), rad(c[6])), gem, M.Neon)
	end

	b.straps(0.7, 0.4, 1.2, 0.18, dark, M.Leather)

	b.light(gemPart, gem, 8, 1.2)
	b.particles(b.handle, rune, gem, 4)

	return finalize(b)
end

---------------------------------------------------------------------------
-- Tier 7 — Void Bag: carcasă neagră, muchii neon, portal octogonal, cioburi plutitoare.
---------------------------------------------------------------------------
local function buildVoidBag()
	local W, H, D = 1.6, 1.8, 0.85
	local b = newBag({ name = "Void Bag", tier = 7, capacity = 300, rarity = "Mythic", mount = -0.35, body = Vector3.new(W, H, D) })

	local shell = rgb(18, 12, 30)
	local shellEdge = rgb(38, 28, 60)
	local neon = rgb(170, 70, 255)
	local neon2 = rgb(90, 220, 255)
	local core = rgb(4, 0, 10)

	b.box("Body", Vector3.new(W, H, D), at(0, 0, 0), shell, M.SmoothPlastic, { Reflectance = 0.1 })
	-- acoperiș înclinat spre față (rotit 180° ca panta să coboare spre +Z)
	b.wedge("Roof", Vector3.new(W, 0.35, D), at(0, H / 2 + 0.175, 0) * CFrame.Angles(0, PI, 0), shell, M.SmoothPlastic, { Reflectance = 0.1 })

	for _, s in ipairs({ -1, 1 }) do
		b.box("NeonEdge", Vector3.new(0.06, H, 0.06), at(s * W / 2, 0, D / 2), neon, M.Neon)
		b.box("NeonEdgeBack", Vector3.new(0.06, H + 0.35, 0.06), at(s * W / 2, 0.175, -D / 2), neon, M.Neon)
		-- crăpături în zig-zag pe laterale
		local zig = { { 0.5, 0.06, 28 }, { 0.2, -0.06, -28 }, { -0.1, 0.06, 28 }, { -0.4, -0.06, -28 } }
		for _, z in ipairs(zig) do
			b.box("Crack", Vector3.new(0.02, 0.34, 0.05), at(s * (W / 2 + 0.01), z[1], z[2]) * CFrame.Angles(rad(z[3]), 0, 0), neon, M.Neon)
		end
	end
	b.box("NeonBottom", Vector3.new(W, 0.06, 0.06), at(0, -H / 2, D / 2), neon, M.Neon)

	-- portal: stele suprapuse, alternate la 22.5° ca să pară că se rotește
	local portalCF = at(0, 0.05, D / 2)
	local layers = {
		{ 0.6, 0.06, shellEdge, M.SmoothPlastic, 0 },
		{ 0.52, 0.08, neon, M.Neon, 22.5 },
		{ 0.42, 0.1, core, M.SmoothPlastic, 0 },
		{ 0.26, 0.12, neon2, M.Neon, 22.5 },
		{ 0.15, 0.14, core, M.SmoothPlastic, 0 },
	}
	local portalCore
	for i, l in ipairs(layers) do
		local p = b.star("Portal", l[1], l[2], portalCF * CFrame.Angles(0, 0, rad(l[5])), l[3], l[4])
		if i == #layers then
			portalCore = p
		end
	end

	local shards = {
		{ -1.05, 0.7, 0.1, Vector3.new(0.14, 0.3, 0.14), neon, M.Neon, 20, 35, 15 },
		{ 1.05, 0.45, 0.0, Vector3.new(0.2, 0.2, 0.2), shellEdge, M.SmoothPlastic, 45, 45, 0 },
		{ -1.0, -0.5, 0.2, Vector3.new(0.16, 0.16, 0.16), neon2, M.Neon, 30, 15, 45 },
		{ 1.0, -0.6, 0.15, Vector3.new(0.12, 0.28, 0.12), neon, M.Neon, 10, 40, 25 },
	}
	for _, s in ipairs(shards) do
		b.box("Shard", s[4], at(s[1], s[2], s[3]) * CFrame.Angles(rad(s[7]), rad(s[8]), rad(s[9])), s[5], s[6])
	end

	b.straps(D, 0.45, 1.6, 0.22, shellEdge, M.SmoothPlastic, 0.1)
	for _, s in ipairs({ -1, 1 }) do
		b.box("StrapNeon", Vector3.new(0.05, 1.5, 0.02), at(s * 0.45, 0, -D / 2 - 0.11), neon, M.Neon)
	end

	b.light(portalCore, neon, 10, 2)
	b.particles(b.handle, neon, core, 10)

	return finalize(b)
end

---------------------------------------------------------------------------

local builders = {
	buildWoodenBasket,
	buildLeatherPouch,
	buildCanvasBag,
	buildExplorerPack,
	buildReinforcedPack,
	buildEnchantedSatchel,
	buildVoidBag,
}

local old = ReplicatedStorage:FindFirstChild("Bags")
if old then
	old:Destroy()
end
local oldShowcase = workspace:FindFirstChild("BagShowcase")
if oldShowcase then
	oldShowcase:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "Bags"

local showcase = Instance.new("Folder")
showcase.Name = "BagShowcase"

for i, build in ipairs(builders) do
	local model = build()
	model.Parent = folder

	local preview = model:Clone()
	preview:PivotTo(CFrame.new((i - 4) * 3.5, 4, 0))

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 200, 0, 40)
	gui.StudsOffset = Vector3.new(0, 1.9, 0)
	gui.AlwaysOnTop = true
	gui.Parent = preview.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = string.format("T%d  %s", model:GetAttribute("Tier"), model.Name)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	preview.Parent = showcase
end

folder.Parent = ReplicatedStorage
showcase.Parent = workspace

print(string.format("[BagBuilder] %d ghiozdane create în ReplicatedStorage.Bags", #builders))
