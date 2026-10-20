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
	Fațetele sunt triunghiuri reale, fiecare făcut din două WedgePart subțiri.
	Rularea din nou înlocuiește modelele vechi.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = Enum.Material
local V = Vector3.new
local rad = math.rad
local PI = math.pi
local COS8 = math.cos(PI / 8) -- apotema / raza unui octogon
local T = 0.03 -- grosimea unui triunghi

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function mix(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

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

local PHI = (1 + math.sqrt(5)) / 2
local ICO_V = {
	V(-1, PHI, 0), V(1, PHI, 0), V(-1, -PHI, 0), V(1, -PHI, 0),
	V(0, -1, PHI), V(0, 1, PHI), V(0, -1, -PHI), V(0, 1, -PHI),
	V(PHI, 0, -1), V(PHI, 0, 1), V(-PHI, 0, -1), V(-PHI, 0, 1),
}
local ICO_F = {
	{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
	{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
	{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
	{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
}

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

local function newItem(id, seed)
	local model = Instance.new("Model")
	model.Name = id

	local handle = makePart(model, "Part", "Handle", V(1, 1, 1), CFrame.new(), rgb(255, 255, 255), M.SmoothPlastic, {
		Transparency = 1,
		CastShadow = false,
	})
	model.PrimaryPart = handle
	model:SetAttribute("ResourceId", id)

	local rand = rng(seed)
	-- cât variază luminozitatea între fațete (dă aspectul low-poly)
	local b = { model = model, handle = handle, rand = rand, jit = 0.05 }

	local function vary(c, amt)
		local k = 1 + rand(-amt, amt)
		return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
	end
	b.vary = vary

	function b.box(name, size, cf, color, mat, props)
		return makePart(model, "Part", name, size, cf, color, mat, props)
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

	-- Prismă octogonală pe axa Y a lui cf (colțurile la 22.5° + k·45°, la fel ca lathe cu n = 8).
	function b.prism(name, apothem, height, cf, color, mat, props)
		return b.octagon(name, apothem, height, cf * VERT, color, mat, props)
	end

	-- Bilă fațetată ieftină: trei cuburi rotite diferit.
	function b.fball(name, d, cf, color, mat, props)
		local s = V(d * 0.72, d * 0.72, d * 0.72)
		local spin = cf * CFrame.Angles(rand(0, PI), rand(0, PI), rand(0, PI))
		b.box(name, s, spin, color, mat, props)
		b.box(name, s, spin * CFrame.Angles(PI / 4, PI / 4, 0), vary(color, 0.04), mat, props)
		b.box(name, s, spin * CFrame.Angles(0, PI / 4, PI / 4), vary(color, 0.04), mat, props)
	end

	function b.chunk(name, size, cf, color, mat, maxAngle)
		local a = maxAngle or PI
		return b.box(name, size, cf * CFrame.Angles(rand(-a, a), rand(-a, a), rand(-a, a)), color, mat)
	end

	-- Bară între două puncte.
	function b.rod(name, p0, p1, w, color, mat, props)
		local d = p1 - p0
		local up = d.Unit
		local ref = math.abs(up.Z) > 0.95 and V(1, 0, 0) or V(0, 0, 1)
		local x = up:Cross(ref).Unit
		local z = x:Cross(up)
		return b.box(name, V(w, d.Magnitude, w), CFrame.fromMatrix((p0 + p1) / 2, x, up, z), color, mat, props)
	end

	-- Triunghi oarecare din două WedgePart (tehnica clasică Roblox).
	function b.tri(name, a, bb, c, color, mat, props)
		local ab, ac, bc = bb - a, c - a, c - bb
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, bb = bb, a
		end
		ab, ac, bc = bb - a, c - a, c - bb
		local n = ac:Cross(ab)
		if n.Magnitude < 1e-6 then
			return
		end
		local right = n.Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local h = math.abs(ab:Dot(up))
		local d1, d2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
		if h < 0.002 then
			return
		end
		if d1 > 0.002 then
			makePart(model, "WedgePart", name, V(T, h, d1), CFrame.fromMatrix((a + bb) / 2, right, up, back), color, mat, props)
		end
		if d2 > 0.002 then
			makePart(model, "WedgePart", name, V(T, h, d2), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, mat, props)
		end
	end

	-- paint = Color3 sau function(centruFațetă) -> Color3; fiecare fațetă primește o mică variație.
	function b.face(name, p1, p2, p3, paint, mat, props)
		local c = paint
		if type(paint) == "function" then
			c = paint((p1 + p2 + p3) / 3)
		end
		b.tri(name, p1, p2, p3, vary(c, b.jit), mat, props)
	end

	function b.mesh(name, verts, faces, cf, paint, mat, props)
		local w = {}
		for i, v in ipairs(verts) do
			w[i] = cf * v
		end
		for _, f in ipairs(faces) do
			b.face(name, w[f[1]], w[f[2]], w[f[3]], paint, mat, props)
		end
	end

	-- Piatră / bulgăre: icosaedru deformat aleator.
	function b.lumpy(name, cf, radii, jitter, paint, mat, props)
		local verts = {}
		for i, v in ipairs(ICO_V) do
			local u = v.Unit * (1 + rand(-jitter, jitter))
			verts[i] = V(u.X * radii.X, u.Y * radii.Y, u.Z * radii.Z)
		end
		b.mesh(name, verts, ICO_F, cf, paint, mat, props)
	end

	-- Sferă geodezică (80 de fețe); bump(v, i) dă raza relativă pentru vârful i.
	function b.geo(name, cf, radius, bump, paint, mat, props)
		local verts = {}
		for i, v in ipairs(ICO_V) do
			verts[i] = v.Unit
		end
		local cache = {}
		local function midpoint(i, j)
			local key = math.min(i, j) * 100 + math.max(i, j)
			if not cache[key] then
				verts[#verts + 1] = ((verts[i] + verts[j]) / 2).Unit
				cache[key] = #verts
			end
			return cache[key]
		end
		local faces = {}
		for _, f in ipairs(ICO_F) do
			local a, bb, c = f[1], f[2], f[3]
			local ab, bc, ca = midpoint(a, bb), midpoint(bb, c), midpoint(c, a)
			table.insert(faces, { a, ab, ca })
			table.insert(faces, { bb, bc, ab })
			table.insert(faces, { c, ca, bc })
			table.insert(faces, { ab, bc, ca })
		end
		for i, v in ipairs(verts) do
			verts[i] = v * (radius * bump(v, i))
		end
		b.mesh(name, verts, faces, cf, paint, mat, props)
	end

	-- Corp de revoluție cu n laturi; profile = {{raza, y}, ...}, raza 0 = vârf.
	function b.lathe(name, cf, profile, n, paint, mat, props, phase)
		phase = phase or PI / n
		local function pt(r, y, k)
			local a = phase + k * 2 * PI / n
			return cf * V(r * math.cos(a), y, r * math.sin(a))
		end
		for i = 1, #profile - 1 do
			local r1, y1 = profile[i][1], profile[i][2]
			local r2, y2 = profile[i + 1][1], profile[i + 1][2]
			for k = 0, n - 1 do
				local p1, p2 = pt(r1, y1, k), pt(r1, y1, k + 1)
				local q1, q2 = pt(r2, y2, k), pt(r2, y2, k + 1)
				if r1 == 0 then
					b.face(name, p1, q1, q2, paint, mat, props)
				elseif r2 == 0 then
					b.face(name, p1, p2, q1, paint, mat, props)
				else
					b.face(name, p1, p2, q2, paint, mat, props)
					b.face(name, p1, q2, q1, paint, mat, props)
				end
			end
		end
	end

	-- Movilă neregulată: vârf + inele de puncte cu jitter, cusute cu triunghiuri.
	-- rings = {{n, raza, y, jitterRaza, jitterY, faza}, ...}; stretch lățește pe X.
	function b.mound(name, cf, apex, rings, stretch, paint, mat, props)
		local pts = {}
		for ri, r in ipairs(rings) do
			local ring = {}
			for k = 0, r[1] - 1 do
				local a = (r[6] or 0) + k * 2 * PI / r[1]
				local rr = r[2] * (1 + rand(-r[4], r[4]))
				ring[k + 1] = cf * V(rr * math.cos(a) * stretch, r[3] + rand(-r[5], r[5]), rr * math.sin(a))
			end
			pts[ri] = ring
		end
		local top = cf * apex
		local first = pts[1]
		for k = 1, #first do
			b.face(name, top, first[k], first[k % #first + 1], paint, mat, props)
		end
		for ri = 1, #pts - 1 do
			local A, B = pts[ri], pts[ri + 1]
			local nA, nB = #A, #B
			local i, j = 0, 0
			while i < nA or j < nB do
				local advanceA
				if i >= nA then
					advanceA = false
				elseif j >= nB then
					advanceA = true
				else
					advanceA = (i + 1) / nA <= (j + 1) / nB
				end
				if advanceA then
					b.face(name, A[i % nA + 1], A[(i + 1) % nA + 1], B[j % nB + 1], paint, mat, props)
					i += 1
				else
					b.face(name, A[i % nA + 1], B[(j + 1) % nB + 1], B[j % nB + 1], paint, mat, props)
					j += 1
				end
			end
		end
	end

	-- Romb plat (sclipici).
	function b.diamond(name, cf, w, h, color, mat, props)
		local t, r, bt, l = cf * V(0, h / 2, 0), cf * V(w / 2, 0, 0), cf * V(0, -h / 2, 0), cf * V(-w / 2, 0, 0)
		b.tri(name, t, r, l, color, mat, props)
		b.tri(name, bt, l, r, color, mat, props)
	end

	-- Arc în planul XY al lui root: pornește în sus și se curbează spre +X.
	-- fn(i, t, cf, segLen) primește cadrul fiecărui segment (Y = tangenta).
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

---------------------------------------------------------------------------

local function buildFeather()
	local b = newItem("Feather", 3)
	b.jit = 0.02
	local L, N, t0 = 1.6, 8, 0.12
	local root = CFrame.Angles(0, 0, rad(-40))
	local white, shade = rgb(250, 250, 252), rgb(222, 226, 236)
	local notch = { [-1] = { [5] = true }, [1] = { [3] = true, [6] = true } }

	local function spine(t)
		return root * V(0.1 * L * t * t, L * t, 0)
	end
	local function spineT(i)
		return t0 + (1 - t0) * i / N
	end
	-- marginea lamei: barbele urcă spre vârf, iar marginile sunt trase puțin în spate (pliu în V)
	local function edge(i, side)
		local u = i / N
		local w = (side < 0 and 0.34 or 0.3) * math.sin(PI * u ^ 0.8) ^ 0.6
		if notch[side][i] then
			w *= 0.72
		end
		local t = math.min(spineT(i) + 0.3 * w / L, 1)
		return root * V(0.1 * L * t * t + side * w, L * t, -0.12 * w)
	end

	for _, side in ipairs({ -1, 1 }) do
		local col = side < 0 and white or shade
		for i = 0, N - 1 do
			local s0, s1 = spine(spineT(i)), spine(spineT(i + 1))
			local e0, e1 = edge(i, side), edge(i + 1, side)
			b.face("Vane", s0, e0, e1, col)
			b.face("Vane", s0, e1, s1, col)
		end
	end

	b.rod("Quill", spine(-0.24), spine(t0 + 0.04), 0.055, rgb(206, 160, 98))
	for i = 0, N - 2 do
		b.rod("Rachis", spine(spineT(i)), spine(spineT(i + 1)), 0.03, rgb(236, 230, 214))
	end

	return finalize(b)
end

local function buildWool()
	local b = newItem("Wool", 7)
	local cols = { rgb(246, 243, 236), rgb(232, 227, 216), rgb(252, 251, 247) }

	b.jit = 0.04
	-- cele 12 vârfuri de bază ies în afară ca niște smocuri, restul sunt puțin adâncite
	b.geo("Wool", CFrame.new(), 0.62, function(v, i)
		local r = i <= 12 and b.rand(1.08, 1.16) or b.rand(0.9, 0.97)
		return r * (1 - 0.12 * math.max(0, -v.Y))
	end, function(p)
		return cols[(math.floor((p.X + p.Y * 3 + p.Z * 5) * 10) % 3) + 1]
	end)

	return finalize(b)
end

local function buildMilk()
	local b = newItem("Milk", 9)
	b.jit = 0.03
	local glass, gp = rgb(196, 224, 244), { Transparency = 0.55 }
	local cork, corkTop = rgb(180, 116, 62), rgb(206, 146, 86)

	b.prism("Glass", 0.34, 0.8, at(0, 0.4, 0), glass, M.Glass, gp)
	b.prism("Milk", 0.31, 0.6, at(0, 0.32, 0), rgb(250, 248, 242))
	b.prism("MilkTop", 0.25, 0.02, at(0, 0.625, 0) * CFrame.Angles(0, PI / 8, 0), rgb(255, 255, 255))
	b.lathe("Glass", CFrame.new(), { { 0.34 / COS8, 0.8 }, { 0.15 / COS8, 0.98 } }, 8, glass, M.Glass, gp)
	b.prism("Neck", 0.15, 0.2, at(0, 1.08, 0), glass, M.Glass, gp)
	b.prism("Lip", 0.18, 0.06, at(0, 1.17, 0), glass, M.Glass, gp)
	b.prism("Cork", 0.13, 0.16, at(0, 1.22, 0), cork)
	b.prism("CorkTop", 0.165, 0.12, at(0, 1.34, 0), cork)
	b.prism("CorkCap", 0.13, 0.02, at(0, 1.405, 0) * CFrame.Angles(0, PI / 8, 0), corkTop)

	return finalize(b)
end

local function buildBerry()
	local b = newItem("Berry", 11)
	b.jit = 0.03
	local reds = { rgb(226, 32, 44), rgb(204, 22, 36), rgb(238, 52, 58) }
	local berries = {
		{ -0.27, 0.19, 0.08 },
		{ 0.02, 0.16, 0.18 },
		{ 0.3, 0.2, 0.05 },
		{ -0.12, 0.46, -0.02 },
		{ 0.18, 0.47, -0.06 },
	}
	for i, p in ipairs(berries) do
		b.lumpy("Berry", at(p[1], p[2], p[3]), V(0.19, 0.19, 0.19), 0.05, reds[i % 3 + 1])
	end

	-- frunză în formă de romb, cu nervura ridicată: jumătatea stângă și dreaptă au nuanțe diferite
	local function leaf(base, tip, width)
		local dir = tip - base
		local n = V(0, 0.25, 1).Unit
		local perp = dir:Cross(n).Unit * width
		local mid = base + dir * 0.42 + n * 0.04
		local left = base + dir * 0.4 - perp - n * 0.05
		local right = base + dir * 0.4 + perp - n * 0.05
		local g1, g2 = rgb(74, 172, 72), rgb(40, 124, 50)
		b.face("Leaf", base, left, mid, g1)
		b.face("Leaf", mid, left, tip, g1)
		b.face("Leaf", base, mid, right, g2)
		b.face("Leaf", mid, tip, right, g2)
	end
	leaf(V(-0.1, 0.5, -0.12), V(-0.62, 0.92, -0.2), 0.17)
	leaf(V(0.12, 0.55, -0.15), V(0.55, 1.05, -0.22), 0.2)

	return finalize(b)
end

local function buildHoney()
	local b = newItem("Honey", 13)
	local cloth, string = rgb(222, 190, 140), rgb(112, 70, 40)

	b.lathe("Jar", CFrame.new(), { { 0.36, 0 }, { 0.47, 0.36 }, { 0.34, 0.7 } }, 8, function(p)
		return p.Y < 0.36 and rgb(236, 140, 18) or rgb(250, 172, 40)
	end, M.SmoothPlastic, { Reflectance = 0.05 })
	b.prism("JarBottom", 0.36 * COS8, 0.03, at(0, 0.015, 0), rgb(220, 124, 12))
	b.prism("JarNeck", 0.31 * COS8, 0.12, at(0, 0.76, 0), rgb(250, 172, 40))

	-- pânza: capac octogonal + fustă cu tiv zimțat
	b.prism("Cloth", 0.36 * COS8, 0.05, at(0, 0.86, 0), cloth, M.Fabric)
	local top, hem = {}, {}
	for k = 0, 7 do
		local a = PI / 8 + k * PI / 4
		top[k + 1] = V(0.36 * math.cos(a), 0.86, 0.36 * math.sin(a))
		local ah = a + PI / 8
		local hy = k % 2 == 0 and 0.6 or 0.68
		hem[k + 1] = V(0.47 * math.cos(ah), hy, 0.47 * math.sin(ah))
	end
	for k = 1, 8 do
		local k2 = k % 8 + 1
		b.face("Cloth", top[k], top[k2], hem[k], cloth, M.Fabric)
		b.face("Cloth", top[k2], hem[k], hem[k2], cloth, M.Fabric)
	end

	-- sfoară + fundă în față
	b.prism("String", 0.39, 0.04, at(0, 0.79, 0), string, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		b.box("Bow", V(0.12, 0.07, 0.03), at(s * 0.065, 0.8, 0.42) * CFrame.Angles(0, 0, rad(25 * s)), string, M.Fabric)
		b.rod("BowTail", V(s * 0.02, 0.78, 0.42), V(s * 0.08, 0.66, 0.45), 0.025, string, M.Fabric)
	end
	b.box("Knot", V(0.05, 0.05, 0.04), at(0, 0.79, 0.43), string, M.Fabric)

	return finalize(b)
end

local function buildTruffle()
	local b = newItem("Truffle", 17)
	b.jit = 0.12
	local dark, rim = rgb(68, 46, 36), rgb(58, 40, 30)

	b.lumpy("Truffle", at(-0.15, 0.42, -0.1), V(0.42, 0.42, 0.4), 0.12, dark)

	-- bucată tăiată, cu interiorul vizibil
	local cf = at(0.4, 0.22, 0.36) * CFrame.Angles(rad(-8), rad(30), rad(-6))
	b.lumpy("Truffle", cf * at(0, 0, -0.14), V(0.22, 0.22, 0.12), 0.1, dark)
	b.octagon("Rim", 0.22, 0.18, cf * at(0, 0, -0.09) * CFrame.Angles(0, 0, PI / 8), rim)
	b.octagon("Inside", 0.175, 0.03, cf * at(0, 0, 0.005) * CFrame.Angles(0, 0, PI / 8), rgb(196, 140, 92))
	b.octagon("InsideLight", 0.1, 0.03, cf * at(0, 0, 0.012), rgb(222, 174, 120))

	return finalize(b)
end

local function buildFur()
	local b = newItem("Fur", 19)
	b.jit = 0.06
	local brown, brownD = rgb(150, 92, 50), rgb(116, 68, 36)
	local tan, tanD = rgb(228, 194, 150), rgb(198, 160, 116)

	local function spikes(n, rb, yb, rt, yt, c1, c2, jt)
		local d = PI / n * 1.25
		for k = 0, n - 1 do
			local a = k * 2 * PI / n + b.rand(-0.1, 0.1)
			local tr = rt + b.rand(-jt, jt)
			b.face("Fur",
				V(rb * math.cos(a - d), yb, rb * math.sin(a - d)),
				V(rb * math.cos(a + d), yb, rb * math.sin(a + d)),
				V(tr * math.cos(a), yt + b.rand(-jt, jt), tr * math.sin(a)),
				k % 2 == 0 and c1 or c2)
		end
	end

	b.prism("Under", 0.3, 0.26, at(0, 0.24, 0), tan)
	b.lumpy("Fur", at(0, 0.6, 0), V(0.44, 0.3, 0.44), 0.12, brown)
	spikes(12, 0.33, 0.38, 0.4, 0.02, tan, tanD, 0.04)
	spikes(14, 0.38, 0.66, 0.52, 0.28, brown, brownD, 0.04)
	spikes(10, 0.26, 0.84, 0.46, 0.52, brown, brownD, 0.04)

	return finalize(b)
end

local function buildClaw()
	local b = newItem("Claw", 23)
	b.jit = 0.04
	local clawBase, clawTip = rgb(198, 162, 118), rgb(238, 216, 180)
	local knuckle = rgb(122, 74, 44)

	-- pornește din dreapta-sus, spre stânga, și se curbează în jos
	local root = at(0.3, 0.55, 0) * CFrame.Angles(0, 0, rad(110)) * CFrame.Angles(0, PI, 0)
	local lastCF, lastA, lastSeg
	b.sweep(root, 0.95, 72, 7, function(_, t, cf, seg)
		local a = 0.21 * (1 - t) ^ 0.8 + 0.02
		b.prism("Claw", a, seg * 1.15, cf, b.vary(mix(clawBase, clawTip, t), 0.03))
		lastCF, lastA, lastSeg = cf, a, seg
	end)
	b.lathe("ClawTip", lastCF * at(0, lastSeg * 0.5, 0), { { lastA / COS8, 0 }, { 0, 0.24 } }, 8, clawTip)

	b.prism("Band", 0.245, 0.06, root * at(0, 0.03, 0), rgb(86, 52, 30))
	b.lumpy("Knuckle", root * at(0, -0.14, 0), V(0.27, 0.24, 0.27), 0.12, knuckle)

	return finalize(b)
end

local function buildScale()
	local b = newItem("Scale", 29)
	b.jit = 0.1
	local verts = { V(0, 0.8, 0) }
	for k = 0, 5 do
		local a = k * PI / 3
		verts[#verts + 1] = V(0.42 * math.cos(a), 0.22, 0.15 * math.sin(a))
	end
	for k = 0, 5 do
		local a = k * PI / 3 + PI / 6
		verts[#verts + 1] = V(0.34 * math.cos(a), -0.32, 0.12 * math.sin(a))
	end
	verts[#verts + 1] = V(0, -0.8, 0)

	local faces = {}
	for k = 0, 5 do
		local a1, a2 = 2 + k, 2 + (k + 1) % 6
		local b1, b2 = 8 + k, 8 + (k + 1) % 6
		table.insert(faces, { 1, a1, a2 })
		table.insert(faces, { a1, a2, b1 })
		table.insert(faces, { a2, b2, b1 })
		table.insert(faces, { b1, b2, 14 })
	end

	local cf = CFrame.Angles(0, rad(-20), rad(35))
	local dark, light = rgb(176, 22, 26), rgb(238, 58, 48)
	b.mesh("Scale", verts, faces, cf, function(p)
		return mix(dark, light, math.clamp((p.Y + 0.7) / 1.4, 0, 1))
	end, M.SmoothPlastic, { Reflectance = 0.08 })

	return finalize(b)
end

local function buildShell()
	local b = newItem("Shell", 31)
	local tanA, tanB = rgb(232, 202, 158), rgb(210, 178, 130)

	-- tub octogonal pe o spirală logaritmică (ca o cochilie de melc / amonit)
	local k, th0, th1, N = 0.24, 0.5 * PI, 2.25 * PI, 14
	local rEnd, c = 0.42, 0.72
	local r0 = rEnd / math.exp(k * th1)
	local root = CFrame.Angles(0, rad(-25), rad(200))
	local function P(th)
		local r = r0 * math.exp(k * th)
		return V(r * math.cos(th), r * math.sin(th), 0), r
	end

	local lastCF, lastR
	for i = 1, N do
		local pa, ra = P(th0 + (th1 - th0) * (i - 1) / N)
		local pb, rb = P(th0 + (th1 - th0) * i / N)
		local y = (pb - pa).Unit
		local z = V(0, 0, 1)
		local cf = root * CFrame.fromMatrix((pa + pb) / 2, y:Cross(z), y, z)
		-- segmentele alternează rotația cu 22.5°, ca să apară nervurile
		b.prism("Shell", c * (ra + rb) / 2, (pb - pa).Magnitude * 1.25, cf * CFrame.Angles(0, (i % 2) * PI / 8, 0), i % 2 == 0 and tanA or tanB)
		lastCF, lastR = cf * at(0, (pb - pa).Magnitude * 0.6, 0), rb
	end
	b.prism("Opening", c * lastR * 0.8, 0.04, lastCF, rgb(150, 108, 68))
	b.lathe("Spire", root * at(0, 0, 0.04) * VERT, { { 0.17, 0 }, { 0, 0.28 } }, 8, rgb(220, 188, 140))

	return finalize(b)
end

local function buildHorn()
	local b = newItem("Horn", 37)
	local tip, mid = rgb(244, 234, 210), rgb(212, 180, 134)

	-- semilună: subțire la ambele capete, cea mai groasă spre baza din dreapta-jos
	local root = at(0.3, 0.95, 0) * CFrame.Angles(0, 0, rad(200))
	b.sweep(root, 0.52, 190, 11, function(i, t, cf, seg)
		local a = math.max(0.03, 0.2 * math.sin(PI * t ^ 1.5))
		local col = t < 0.6 and mix(tip, mid, t / 0.6) or mid
		b.prism("Horn", a, seg * 1.18, cf, b.vary(col, 0.03))
		if i == 8 then
			b.prism("Band", a * 1.15, seg * 0.75, cf, rgb(122, 74, 40), M.Leather)
			b.prism("BandEdge", a * 1.18, seg * 0.12, cf * at(0, seg * 0.3, 0), rgb(92, 54, 28), M.Leather)
		end
	end)

	return finalize(b)
end

local function buildGel()
	local b = newItem("Gel", 41)
	local cyan, green = rgb(60, 236, 216), rgb(84, 236, 120)

	b.mound("Gel", CFrame.new(), V(0.02, 0.78, 0), {
		{ 5, 0.2, 0.68, 0.1, 0.03, 0 },
		{ 7, 0.42, 0.45, 0.1, 0.04, 0.3 },
		{ 8, 0.54, 0.18, 0.08, 0.03, 0.1 },
		{ 8, 0.7, 0.02, 0.18, 0, 0.4 },
	}, 1, function(p)
		return mix(green, cyan, math.clamp(p.Y / 0.6, 0, 1))
	end)

	b.fball("Droplet", 0.14, at(0.35, 1.0, 0.1), cyan, M.Neon)
	b.fball("Droplet", 0.11, at(0.56, 0.82, 0.05), cyan, M.Neon)
	b.light(b.handle, cyan, 8, 1.5)

	return finalize(b)
end

local function buildAshes()
	local b = newItem("Ashes", 43)
	b.jit = 0.12

	b.mound("Ash", CFrame.new(), V(0.05, 0.72, 0), {
		{ 5, 0.24, 0.54, 0.2, 0.06, 0 },
		{ 7, 0.48, 0.3, 0.15, 0.06, 0.2 },
		{ 9, 0.72, 0.02, 0.12, 0, 0.1 },
	}, 1.15, function(p)
		return mix(rgb(54, 54, 58), rgb(106, 106, 112), math.clamp(p.Y / 0.6, 0, 1))
	end)

	for k = 0, 6 do
		local a = k * 2 * PI / 7 + b.rand(-0.3, 0.3)
		local r = b.rand(0.88, 1.0)
		local s = b.rand(0.06, 0.12)
		b.chunk("Chip", V(s, s * 0.7, s), at(r * math.cos(a) * 1.15, s * 0.3, r * math.sin(a)), b.vary(rgb(52, 52, 56), 0.15))
	end

	return finalize(b)
end

local function buildStardust()
	local b = newItem("Stardust", 47)
	b.jit = 0.1
	local deep, light, glow = rgb(80, 120, 236), rgb(176, 206, 255), rgb(120, 160, 255)

	b.mound("Dust", CFrame.new(), V(0, 0.74, 0), {
		{ 6, 0.2, 0.42, 0.25, 0.06, 0 },
		{ 8, 0.45, 0.2, 0.2, 0.05, 0.2 },
		{ 10, 0.66, 0.02, 0.2, 0, 0.1 },
	}, 1.15, function(p)
		return mix(deep, light, math.clamp(p.Y / 0.55, 0, 1))
	end)

	for k = 0, 9 do
		local a = k * 2 * PI / 10 + b.rand(-0.2, 0.2)
		local r = b.rand(0.62, 0.86)
		local s = b.rand(0.05, 0.1)
		b.chunk("Bit", V(s, s, s), at(r * math.cos(a) * 1.15, s * 0.4, r * math.sin(a)), b.vary(mix(deep, light, b.rand(0, 1)), 0.05), k % 3 == 0 and M.Neon or M.SmoothPlastic)
	end

	local sparkles = { { -0.3, 0.95, 0, 0.22 }, { 0.05, 1.22, 0, 0.26 }, { 0.36, 1.0, 0, 0.2 }, { 0.58, 0.66, 0.1, 0.14 }, { -0.55, 0.62, 0.1, 0.14 } }
	for _, s in ipairs(sparkles) do
		b.diamond("Sparkle", at(s[1], s[2], s[3]) * CFrame.Angles(0, b.rand(-0.5, 0.5), 0), s[4] * 0.55, s[4], glow, M.Neon)
	end

	b.particles(b.handle, glow, light, 4, { size = 0.1 })
	b.light(b.handle, glow, 6, 1)

	return finalize(b)
end

local function buildEssence()
	local b = newItem("Essence", 53)
	b.jit = 0.06
	local purple, purpleL = rgb(128, 46, 220), rgb(178, 100, 255)
	local gold, goldD = rgb(238, 182, 60), rgb(198, 140, 40)
	local shine = { Reflectance = 0.15 }

	b.lathe("Foot", CFrame.new(), { { 0.3, 0 }, { 0.14, 0.2 } }, 8, gold, M.SmoothPlastic, shine)
	b.prism("FootBase", 0.3 * COS8, 0.03, at(0, 0.015, 0), goldD)
	b.lathe("Bottle", CFrame.new(), { { 0.12, 0.19 }, { 0.44, 0.74 }, { 0.17, 1.0 } }, 8, function(p)
		return p.Y < 0.74 and purple or purpleL
	end, M.Glass, { Transparency = 0.25 })
	local core = b.box("Core", V(0.36, 0.36, 0.36), at(0, 0.66, 0) * CFrame.Angles(PI / 4, PI / 4, 0), rgb(200, 130, 255), M.Neon)
	b.prism("Neck", 0.13, 0.12, at(0, 1.06, 0), purpleL, M.Glass, { Transparency = 0.3 })
	b.prism("Collar", 0.17, 0.06, at(0, 1.15, 0), gold, M.SmoothPlastic, shine)
	b.lathe("Stopper", CFrame.new(), { { 0, 1.17 }, { 0.16, 1.3 }, { 0, 1.5 } }, 8, gold, M.SmoothPlastic, shine)

	b.light(core, purpleL, 8, 1.6)
	b.particles(core, purpleL, rgb(255, 200, 255), 3, { rise = 0.8, size = 0.1 })

	return finalize(b)
end

local function buildShard()
	local b = newItem("Shard", 59)
	b.jit = 0.08
	local blue, purple = rgb(70, 130, 255), rgb(190, 80, 255)
	local shine = { Reflectance = 0.1 }

	local function paint(p)
		local c = mix(blue, purple, math.clamp((p.X + 0.35) / 0.7, 0, 1))
		return mix(c, rgb(235, 220, 255), math.clamp((p.Y - 1.3) / 0.6, 0, 1) * 0.35)
	end
	b.lathe("Crystal", at(0, 0.9, 0) * CFrame.Angles(0, rad(20), rad(-10)), { { 0, -0.85 }, { 0.26, -0.45 }, { 0.33, 0.4 }, { 0, 0.95 } }, 6, paint, M.SmoothPlastic, shine)

	local small = {
		{ -0.58, 1.15, 0.05, 20, 0.2 },
		{ 0.58, 1.0, 0.1, -25, 0.18 },
		{ -0.48, 0.45, 0.15, -15, 0.13 },
		{ 0.44, 0.38, 0.1, 30, 0.12 },
	}
	for _, s in ipairs(small) do
		local h = s[5]
		b.lathe("Mini", at(s[1], s[2], s[3]) * CFrame.Angles(0, b.rand(0, PI), rad(s[4])), { { 0, -h }, { h * 0.45, 0 }, { 0, h } }, 4, rgb(150, 70, 255), M.SmoothPlastic, shine)
	end

	b.light(b.handle, rgb(140, 110, 255), 12, 2)
	b.particles(b.handle, rgb(150, 120, 255), rgb(110, 230, 255), 6)

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
