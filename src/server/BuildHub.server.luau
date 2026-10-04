--[[
	BuildHub: генерирует подземный хаб в Workspace.MainHub при старте сервера.
	Центральная боевая яма с манекенами, 4 лестницы, верхний ярус, жаровни, палатки,
	храм «Комната порталов», пещерные скалы, свод со сталактитами, освещение и SpawnLocation.

	Координаты: центр ямы = (0,0,0), верхний ярус Y = 0, дно ямы Y = -10.
	Храм на севере (-Z), точка спавна на юге (+Z), лицом к храму.
]]

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))
local Hub = script.Parent:WaitForChild("Hub")
local Atmosphere = require(Hub:WaitForChild("Atmosphere"))
local Decor = require(Hub:WaitForChild("Decor"))
local DpsBoard = require(Hub:WaitForChild("DpsBoard"))

local PI, TAU = math.pi, math.pi * 2
local H = Config.HALF
local PIT_FLOOR_Y = Config.PIT_FLOOR_Y
local PIT_BOTTOM_Y = Config.PIT_BOTTOM_Y
local WALL_R = Config.WALL_R
local RCUT = Config.RCUT
local CEIL_Y = Config.CEIL_Y
local C = Config.Colors
local TENT_COLORS = Config.TentColors
local M = Enum.Material

local partCount = 0

-------------------------------------------------------------------------------
-- Утилиты
-------------------------------------------------------------------------------
local function mk(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	partCount += 1
	return p
end

-- вертикальный цилиндр: height по Y, dia — диаметр
local function cylV(parent, name, x, y, z, height, dia, color, material)
	return mk(
		parent,
		name,
		Vector3.new(height, dia, dia),
		CFrame.new(x, y, z) * CFrame.Angles(0, 0, PI / 2),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function radial(angle, r, y)
	return Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
end

-- CFrame в точке pos, локальный -Z смотрит к оси хаба
local function faceCenter(pos)
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

-- попадает ли точка (угол a, радиус r) в проход шириной 2*half вдоль одного из dirCount направлений
local function inGap(a, r, half, dirCount)
	local px, pz = math.cos(a) * r, math.sin(a) * r
	for k = 0, dirCount - 1 do
		local d = k * TAU / dirCount
		local ax, az = math.cos(d), math.sin(d)
		local along = px * ax + pz * az
		local perp = math.abs(px * az - pz * ax)
		if along > 0 and perp < half then
			return true
		end
	end
	return false
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function ghost(parent, name, pos)
	local p = mk(parent, name, Vector3.new(1, 1, 1), CFrame.new(pos), C.Warm, M.SmoothPlastic)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function addLight(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

local function colorClose(a, b)
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.03
end

-------------------------------------------------------------------------------
-- Корневая папка
-------------------------------------------------------------------------------
local old = Workspace:FindFirstChild("MainHub")
if old then
	old:Destroy()
end

local hub = Instance.new("Folder")
hub.Name = "MainHub"

local fPit = folder(hub, "Pit")
local fStairs = folder(hub, "Stairs")
local fPlaza = folder(hub, "Plaza")
local fBraziers = folder(hub, "Braziers")
local fStalls = folder(hub, "Stalls")
local fBuildings = folder(hub, "Buildings")
local fTemple = folder(hub, "PortalTemple")
local fCave = folder(hub, "Cave")
local fLights = folder(hub, "Lights")
local fDummies = folder(hub, "Dummies")

-------------------------------------------------------------------------------
-- 1. Центральная боевая яма
-------------------------------------------------------------------------------
mk(
	fPit,
	"PitFloor",
	Vector3.new(2, RCUT * 2, RCUT * 2),
	CFrame.new(0, PIT_FLOOR_Y - 1, 0) * CFrame.Angles(0, 0, PI / 2),
	C.Sand,
	M.Sandstone,
	Enum.PartType.Cylinder
)
mk(
	fPit,
	"ArenaRingOuter",
	Vector3.new(0.2, 56, 56),
	CFrame.new(0, PIT_FLOOR_Y + 0.1, 0) * CFrame.Angles(0, 0, PI / 2),
	C.SandDark,
	M.Concrete,
	Enum.PartType.Cylinder
)
mk(
	fPit,
	"ArenaRingInner",
	Vector3.new(0.3, 40, 40),
	CFrame.new(0, PIT_FLOOR_Y + 0.15, 0) * CFrame.Angles(0, 0, PI / 2),
	C.SandLight,
	M.Concrete,
	Enum.PartType.Cylinder
)
mk(
	fPit,
	"ArenaRingCenter",
	Vector3.new(0.4, 18, 18),
	CFrame.new(0, PIT_FLOOR_Y + 0.2, 0) * CFrame.Angles(0, 0, PI / 2),
	C.SandDark,
	M.Concrete,
	Enum.PartType.Cylinder
)

-- стены-бортики по периметру (с проёмами под 4 лестницы)
do
	local N = 72
	local wallY = (3 + PIT_BOTTOM_Y) / 2
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * TAU
		if not inGap(a, WALL_R, 10, 4) then
			local pos = radial(a, WALL_R, wallY)
			mk(
				fPit,
				"Wall",
				Vector3.new(3.8, 3 - PIT_BOTTOM_Y, 3.2),
				CFrame.lookAt(pos, Vector3.new(0, wallY, 0)),
				C.StoneBrown,
				M.Cobblestone
			)
			local capPos = radial(a, WALL_R, 3.35)
			mk(
				fPit,
				"WallCap",
				Vector3.new(4.3, 0.7, 4.2),
				CFrame.lookAt(capPos, Vector3.new(0, 3.35, 0)),
				C.StoneLight,
				M.Concrete
			)
		end
	end
end

-- каменные скамейки-укрытия по кругу (по 2 на каждой диагонали)
for k = 0, 3 do
	local base = PI / 4 + k * PI / 2
	for _, off in { -0.19, 0.19 } do
		local pos = radial(base + off, 24, PIT_FLOOR_Y + 1.1)
		local cf = faceCenter(pos)
		mk(fPit, "Bench", Vector3.new(10, 2.2, 3), cf, C.StoneBrown, M.Cobblestone)
		mk(fPit, "BenchTop", Vector3.new(10.6, 0.5, 3.4), cf * CFrame.new(0, 1.35, 0), C.StoneLight, M.Concrete)
	end
end

-------------------------------------------------------------------------------
-- 2. Лестницы и верхний ярус
-------------------------------------------------------------------------------
-- 4 лестницы (С/Ю/З/В): площадка на уровне яруса + 7 ступеней вниз, подъём 1.25
for k = 0, 3 do
	local a = k * PI / 2
	local landing = radial(a, 35.5, -6)
	mk(fStairs, "Landing", Vector3.new(20, 12, 5), CFrame.lookAt(landing, Vector3.new(0, -6, 0)), C.Plaza, M.Concrete)
	for i = 1, 7 do
		local top = -1.25 * i
		local h = top - PIT_BOTTOM_Y
		local pos = radial(a, 34 - 2 * i, top - h / 2)
		mk(
			fStairs,
			"Step",
			Vector3.new(16, h, 2.05),
			CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
			C.StoneLight,
			M.Concrete
		)
	end
	for _, s in { -1, 1 } do
		local cf = CFrame.lookAt(radial(a, 36, 0), Vector3.new(0, 0, 0)) * CFrame.new(s * 11, 0, 0)
		mk(fStairs, "StairPylon", Vector3.new(2.6, 5, 2.6), cf * CFrame.new(0, 2.5, 0), C.StoneBrown, M.Cobblestone)
		mk(fStairs, "StairPylonCap", Vector3.new(3.4, 0.8, 3.4), cf * CFrame.new(0, 5.4, 0), C.StoneLight, M.Concrete)
	end
end

-- плита верхнего яруса: полосы с вырезом круга радиусом RCUT
do
	local STRIP = 2
	local rows = math.floor(2 * RCUT / STRIP)
	local thick = 12
	for k = 0, rows - 1 do
		local z0 = -RCUT + k * STRIP
		local z1 = z0 + STRIP
		local zc = (z0 + z1) / 2
		local zfar = math.max(math.abs(z0), math.abs(z1))
		local xcut = math.sqrt(math.max(RCUT * RCUT - zfar * zfar, 0))
		if xcut < 0.01 then
			mk(fPlaza, "Floor", Vector3.new(H * 2, thick, STRIP), CFrame.new(0, -thick / 2, zc), C.Plaza, M.Concrete)
		else
			local w = H - xcut
			mk(
				fPlaza,
				"FloorW",
				Vector3.new(w, thick, STRIP),
				CFrame.new(-(H + xcut) / 2, -thick / 2, zc),
				C.Plaza,
				M.Concrete
			)
			mk(
				fPlaza,
				"FloorE",
				Vector3.new(w, thick, STRIP),
				CFrame.new((H + xcut) / 2, -thick / 2, zc),
				C.Plaza,
				M.Concrete
			)
		end
	end
	local d = H - RCUT
	mk(fPlaza, "FloorN", Vector3.new(H * 2, thick, d), CFrame.new(0, -thick / 2, -(RCUT + H) / 2), C.Plaza, M.Concrete)
	mk(fPlaza, "FloorS", Vector3.new(H * 2, thick, d), CFrame.new(0, -thick / 2, (RCUT + H) / 2), C.Plaza, M.Concrete)
end

-- декоративная плитка вокруг ямы
for i = 0, 47 do
	local a = (i + 0.5) / 48 * TAU
	if not inGap(a, 44, 10, 8) then
		local pos = radial(a, 44, 0.05)
		mk(
			fPlaza,
			"PaverTile",
			Vector3.new(5, 0.12, 5),
			CFrame.lookAt(pos, Vector3.new(0, 0.05, 0)),
			(i % 2 == 0) and C.SandLight or C.SandDark,
			M.Slate
		)
	end
end

-- внешний низкий парапет (перила) с проходами по 8 направлениям
do
	local N = 96
	local R = 50
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * TAU
		if not inGap(a, R, 10, 8) then
			local pos = radial(a, R, 1.25)
			local cf = CFrame.lookAt(pos, Vector3.new(0, 1.25, 0))
			mk(fPlaza, "Parapet", Vector3.new(3.6, 2.5, 2), cf, C.StoneBrown, M.Cobblestone)
			if i % 4 == 0 then
				mk(
					fPlaza,
					"ParapetPost",
					Vector3.new(2.6, 3.6, 2.6),
					cf * CFrame.new(0, 0.55, 0),
					C.StoneLight,
					M.Concrete
				)
			end
		end
	end
end

-- жаровня: каменная тумба + настоящее пламя (Fire) + тёплый мерцающий свет + искры
local function brazier(pos)
	local m = Instance.new("Model")
	m.Name = "Brazier"
	mk(m, "Base", Vector3.new(3.2, 1, 3.2), CFrame.new(pos + Vector3.new(0, 0.5, 0)), C.StoneBrown, M.Cobblestone)
	mk(m, "Pillar", Vector3.new(2.2, 3.5, 2.2), CFrame.new(pos + Vector3.new(0, 2.75, 0)), C.StoneLight, M.Concrete)
	mk(m, "Bowl", Vector3.new(3, 0.8, 3), CFrame.new(pos + Vector3.new(0, 4.9, 0)), C.StoneDark, M.Slate)
	-- угли в чаше: тёмный камень, без сплошного светящегося блока
	mk(m, "Embers", Vector3.new(2.2, 0.4, 2.2), CFrame.new(pos + Vector3.new(0, 5.4, 0)), Color3.fromRGB(120, 40, 14), M.Slate)
	local flame = ghost(m, "Flame", pos + Vector3.new(0, 6.4, 0))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 170, 70)
	fire.SecondaryColor = Color3.fromRGB(200, 50, 10)
	fire.Parent = flame
	local torch = Config.Lighting.Torch
	Atmosphere.torchLight(flame, torch.Color, torch.Brightness, torch.Range)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 8
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = Vector3.new(0, 5, 0)
	pe.LightEmission = 1
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = flame
	m.Parent = fBraziers
end

for k = 0, 11 do
	brazier(radial(math.rad(15 + 30 * k), 42, 0))
end
for _, x in { -65, -45, 45, 65 } do
	brazier(Vector3.new(x, 0, -92))
end

-------------------------------------------------------------------------------
-- Палатки: модель из каталога, запасной вариант — процедурные
-------------------------------------------------------------------------------
local STALL_PIVOT_HEIGHT = 5.609 -- половина высоты палатки после ScaleTo(0.5)

local function countParts(inst)
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- ищем одну палатку (150-300 деталей) внутри загруженной модели
local function pickStall(container)
	for _, d in container:GetDescendants() do
		if d:IsA("Model") then
			local n = countParts(d)
			if n >= 150 and n <= 300 then
				return d
			end
		end
	end
	return nil
end

local function prepareStallTemplate()
	local ok, result = pcall(function()
		return InsertService:LoadAsset(Config.StallAssetId)
	end)
	if not ok or not result then
		warn("[BuildHub] Stall LoadAsset failed, using procedural stalls: " .. tostring(result))
		return nil
	end
	local picked = pickStall(result)
	if not picked then
		warn("[BuildHub] no stall found in the loaded model, using procedural stalls")
		result:Destroy()
		return nil
	end
	local template = picked:Clone()
	result:Destroy()
	for _, d in template:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Fire") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("PointLight") then
			d.Range = 14
			d.Brightness = 0.8
			d.Shadows = false
		end
	end
	template:ScaleTo(0.5)
	template:PivotTo(CFrame.new(0, STALL_PIVOT_HEIGHT, 0))
	return template
end

local STRIPE_COLOR = Color3.fromRGB(170, 85, 0)
local ROOF_COLOR = Color3.fromRGB(255, 176, 0)

local function assetStall(template, pos, idx)
	local m = template:Clone()
	m.Name = "Stall"
	local color = TENT_COLORS[(idx % #TENT_COLORS) + 1]
	for _, d in m:GetDescendants() do
		if d:IsA("UnionOperation") then
			d.UsePartColor = true -- иначе Color у Union игнорируется
		end
		if d:IsA("BasePart") and (colorClose(d.Color, STRIPE_COLOR) or colorClose(d.Color, ROOF_COLOR)) then
			d.Color = color
		end
	end
	-- «лицо» палатки = локальный +X, должно смотреть в центр хаба
	local base = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	m:PivotTo(base * CFrame.Angles(0, PI / 2, 0) + Vector3.new(0, STALL_PIVOT_HEIGHT, 0))
	m.Parent = fStalls
	partCount += countParts(m)
end

local function proceduralStall(pos, idx)
	local cf = faceCenter(pos)
	local m = Instance.new("Model")
	m.Name = "Stall"
	local tent = TENT_COLORS[(idx % #TENT_COLORS) + 1]
	local function L(name, size, off, color, mat, rot)
		return mk(m, name, size, cf * CFrame.new(off) * (rot or CFrame.new()), color, mat)
	end
	for _, sx in { -3, 3 } do
		for _, sz in { -2.5, 2.5 } do
			L("Post", Vector3.new(0.6, 7.4, 0.6), Vector3.new(sx, 3.7, sz), C.Wood, M.Wood)
		end
	end
	L("Counter", Vector3.new(6.6, 3, 2), Vector3.new(0, 1.5, -2.5), C.WoodLight, M.WoodPlanks)
	L("CounterTop", Vector3.new(7, 0.4, 2.6), Vector3.new(0, 3.2, -2.5), C.Wood, M.Wood)
	L("BackBoard", Vector3.new(6.6, 5, 0.4), Vector3.new(0, 2.5, 2.7), C.Wood, M.WoodPlanks)
	L("Tent", Vector3.new(8.6, 0.4, 7), Vector3.new(0, 7.5, 0), tent, M.Fabric, CFrame.Angles(math.rad(-10), 0, 0))
	L("Valance", Vector3.new(8.6, 0.9, 0.2), Vector3.new(0, 6.9, -3.5), Color3.fromRGB(235, 225, 200), M.Fabric)
	local goods = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(230, 190, 60), Color3.fromRGB(80, 150, 70) }
	for i = -1, 1 do
		L("Goods", Vector3.new(1.1, 0.9, 1.1), Vector3.new(i * 2, 3.85, -2.5), goods[i + 2], M.SmoothPlastic)
	end
	m.Parent = fStalls
end

do
	local positions = {}
	for k = 0, 7 do -- кольцо за парапетом (между проходами)
		table.insert(positions, radial(math.rad(22.5 + 45 * k), 64, 0))
	end
	for _, x in { -112, 112 } do -- вдоль боковых краёв площади
		for _, z in { -60, -30, 0, 30, 60 } do
			table.insert(positions, Vector3.new(x, 0, z))
		end
	end

	local template = prepareStallTemplate()
	for i, pos in positions do
		if template then
			assetStall(template, pos, i - 1)
		else
			proceduralStall(pos, i - 1)
		end
	end
	if template then
		template:Destroy()
	end
end

-- боковые здания (гильдии)
local function building(pos, w, d, h)
	local cf = faceCenter(pos)
	local m = Instance.new("Model")
	m.Name = "Guildhouse"
	local function L(name, size, off, color, mat)
		return mk(m, name, size, cf * CFrame.new(off), color, mat)
	end
	L("Plinth", Vector3.new(w + 2, 2, d + 2), Vector3.new(0, 1, 0), C.StoneLight, M.Concrete)
	L("Body", Vector3.new(w, h, d), Vector3.new(0, 2 + h / 2, 0), C.StoneBrown, M.Cobblestone)
	L("Cornice", Vector3.new(w + 3, 2, d + 3), Vector3.new(0, 2 + h + 1, 0), C.StoneLight, M.Concrete)
	L("Upper", Vector3.new(w - 6, 6, d - 6), Vector3.new(0, 2 + h + 5, 0), C.StoneBrown, M.Cobblestone)
	L("RoofCap", Vector3.new(w - 4, 1.2, d - 4), Vector3.new(0, 2 + h + 8.6, 0), C.StoneDark, M.Slate)
	local fz = -d / 2 - 0.3
	L("Door", Vector3.new(8, 12, 0.6), Vector3.new(0, 8, fz), Color3.fromRGB(30, 22, 18), M.Wood)
	L("DoorLintel", Vector3.new(11, 1.8, 1.4), Vector3.new(0, 14.8, fz - 0.3), C.StoneLight, M.Concrete)
	for _, s in { -1, 1 } do
		L("DoorJamb", Vector3.new(1.6, 12.8, 1.4), Vector3.new(s * 4.8, 8.4, fz - 0.3), C.StoneLight, M.Concrete)
		L(
			"Window",
			Vector3.new(2.6, 4, 0.5),
			Vector3.new(s * (w / 2 - 5), 2 + h * 0.62, fz),
			Color3.fromRGB(190, 140, 70), -- тусклее: окна не должны пересвечивать bloom
			M.Neon
		)
		L(
			"WindowSill",
			Vector3.new(3.6, 0.6, 1),
			Vector3.new(s * (w / 2 - 5), 2 + h * 0.62 - 2.2, fz - 0.2),
			C.StoneLight,
			M.Concrete
		)
	end
	m.Parent = fBuildings
end

for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		building(Vector3.new(sx * 138, 0, sz * 48), 30, 28, 26)
	end
end

-------------------------------------------------------------------------------
-- 3. Храм «Комната порталов» (север, -Z)
-------------------------------------------------------------------------------
do
	local Y0 = 4 -- уровень платформы

	mk(fTemple, "Platform", Vector3.new(150, 4, 58), CFrame.new(0, 2, -129), C.StoneLight, M.Concrete)
	for k = 1, 3 do
		local depth = 8 - (k - 1) * 2.67
		local height = k * 1.33
		mk(
			fTemple,
			"TempleStep",
			Vector3.new(70, height, depth),
			CFrame.new(0, height / 2, -100 + depth / 2),
			C.StoneLight,
			M.Concrete
		)
	end

	-- главный объём, пилястры, уступы
	mk(fTemple, "MainBlock", Vector3.new(120, 60, 25), CFrame.new(0, Y0 + 30, -142.5), C.StoneBrown, M.Cobblestone)
	mk(fTemple, "BaseCourse", Vector3.new(124, 4, 3), CFrame.new(0, Y0 + 2, -128.5), C.StoneLight, M.Concrete)
	for _, s in { -1, 1 } do
		for _, x in { 44, 54 } do
			mk(fTemple, "Pilaster", Vector3.new(4, 56, 2), CFrame.new(s * x, Y0 + 28, -131), C.StoneLight, M.Concrete)
		end
	end
	mk(fTemple, "TierA", Vector3.new(110, 6, 22), CFrame.new(0, 67, -143), C.StoneBrown, M.Cobblestone)
	mk(fTemple, "TierB", Vector3.new(80, 6, 18), CFrame.new(0, 73, -145), C.StoneLight, M.Concrete)
	mk(fTemple, "TierC", Vector3.new(44, 7, 14), CFrame.new(0, 79.5, -147), C.StoneBrown, M.Cobblestone)
	mk(fTemple, "TierCap", Vector3.new(30, 1.5, 10), CFrame.new(0, 83.75, -147), C.Gold, M.Metal)

	-- тёмная ниша входной арки
	mk(
		fTemple,
		"Recess",
		Vector3.new(68, 30, 0.4),
		CFrame.new(0, Y0 + 15, -129.8),
		Color3.fromRGB(34, 26, 22),
		M.Slate
	)

	-- входная арка (полуэллипс из клиньев-вуссуаров)
	do
		local cy, rx, ry = 34, 36, 10
		local n = 21
		for i = 0, n - 1 do
			local phi = (i + 0.5) / n * PI
			local x, y = rx * math.cos(phi), cy + ry * math.sin(phi)
			local theta = math.atan2(ry * math.cos(phi), -rx * math.sin(phi))
			mk(
				fTemple,
				"Voussoir",
				Vector3.new(4.8, 5, 5),
				CFrame.new(x, y, -127.5) * CFrame.Angles(0, 0, theta),
				(i % 2 == 0) and C.StoneLight or C.SandLight,
				M.Concrete
			)
		end
		mk(fTemple, "Keystone", Vector3.new(5.5, 6.5, 5.6), CFrame.new(0, cy + ry, -127.4), C.Gold, M.Metal)
	end

	-- колонны портика
	for _, s in { -1, 1 } do
		for _, x in { 38, 50, 62 } do
			local cx = s * x
			mk(fTemple, "ColumnBase", Vector3.new(7, 2, 7), CFrame.new(cx, Y0 + 1, -112), C.StoneLight, M.Concrete)
			cylV(fTemple, "ColumnShaft", cx, Y0 + 2 + 18, -112, 36, 5, C.StoneLight, M.Concrete)
			for ring = 0, 2 do
				cylV(fTemple, "ColumnBand", cx, Y0 + 8 + ring * 12, -112, 1, 5.6, C.StoneBrown, M.Cobblestone)
			end
			mk(fTemple, "ColumnCapital", Vector3.new(7, 2, 7), CFrame.new(cx, Y0 + 39, -112), C.StoneLight, M.Concrete)
		end
	end
	mk(fTemple, "Architrave", Vector3.new(140, 4, 7), CFrame.new(0, 46, -112), C.StoneBrown, M.Cobblestone)
	mk(fTemple, "ArchitraveTrim", Vector3.new(140, 0.6, 0.4), CFrame.new(0, 46, -108.3), C.Gold, M.Metal)
	mk(fTemple, "PorticoRoof", Vector3.new(144, 2.5, 24), CFrame.new(0, 49.25, -118), C.StoneLight, M.Concrete)
	mk(fTemple, "PorticoCornice", Vector3.new(148, 1.2, 3), CFrame.new(0, 48.4, -106.5), C.StoneBrown, M.Cobblestone)

	-- вывеска «Комната порталов»
	mk(fTemple, "SignFrame", Vector3.new(50, 9, 0.8), CFrame.new(0, 56.5, -129.6), C.Gold, M.Metal)
	local board = mk(
		fTemple,
		"SignBoard",
		Vector3.new(46, 6.4, 0.6),
		CFrame.new(0, 56.5, -129.0),
		Color3.fromRGB(46, 34, 28),
		M.WoodPlanks
	)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = Enum.NormalId.Back -- смотрит в +Z, к игрокам
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(920, 128)
	sg.LightInfluence = 0
	sg.Parent = board
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "Portal Room"
	tl.TextScaled = true
	tl.FontFace = Fonts.Banner
	tl.TextColor3 = Color3.fromRGB(255, 214, 140)
	tl.TextStrokeColor3 = Color3.fromRGB(40, 20, 8)
	tl.TextStrokeTransparency = 0.4
	tl.Parent = sg

	-- 4 портала-арки: каменная рама-капсула + светящаяся Neon-капсула (блок и два полукруглых торца)
	local rot = CFrame.Angles(0, PI / 2, 0) -- ось цилиндра вдоль Z
	for _, pd in Config.Portals do
		local n, x, color = pd.name, pd.x, pd.color

		local fw, fh = 13, 27
		mk(
			fTemple,
			n .. "_Frame",
			Vector3.new(0.8, fh - fw, fw),
			CFrame.new(x, Y0 + fh / 2, -129.3) * rot,
			C.StoneDark,
			M.Slate
		)
		mk(
			fTemple,
			n .. "_FrameTop",
			Vector3.new(0.8, fw, fw),
			CFrame.new(x, Y0 + fh - fw / 2, -129.3) * rot,
			C.StoneDark,
			M.Slate,
			Enum.PartType.Cylinder
		)
		mk(
			fTemple,
			n .. "_FrameBot",
			Vector3.new(0.8, fw, fw),
			CFrame.new(x, Y0 + fw / 2, -129.3) * rot,
			C.StoneDark,
			M.Slate,
			Enum.PartType.Cylinder
		)

		local pw, ph = 9.6, 24
		local body = mk(
			fTemple,
			n,
			Vector3.new(0.6, ph - pw, pw),
			CFrame.new(x, Y0 + ph / 2 + 0.2, -128.5) * rot,
			color,
			M.Neon
		)
		mk(
			fTemple,
			n .. "_Top",
			Vector3.new(0.6, pw, pw),
			CFrame.new(x, Y0 + 0.2 + ph - pw / 2, -128.5) * rot,
			color,
			M.Neon,
			Enum.PartType.Cylinder
		)
		mk(
			fTemple,
			n .. "_Bot",
			Vector3.new(0.6, pw, pw),
			CFrame.new(x, Y0 + 0.2 + pw / 2, -128.5) * rot,
			color,
			M.Neon,
			Enum.PartType.Cylinder
		)
		addLight(body, color, 2, 26)

		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 14
		pe.Lifetime = NumberRange.new(1.2, 2.2)
		pe.Speed = NumberRange.new(1, 3)
		pe.SpreadAngle = Vector2.new(35, 35)
		pe.LightEmission = 1
		pe.Color = ColorSequence.new(color)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		pe.EmissionDirection = Enum.NormalId.Back
		pe.Parent = body

		-- светящийся круг на полу
		local pad = cylV(fTemple, n .. "_Pad", x, Y0 + 0.12, -125.5, 0.2, 9.5, color, M.Neon)
		pad.Transparency = 0.45
	end
end

-------------------------------------------------------------------------------
-- 4. Пещерное окружение: скалы, свод, сталактиты, лампы
-------------------------------------------------------------------------------
do
	local rng = Random.new(1337)

	for side = 0, 3 do
		local dir = Vector3.new(math.cos(side * PI / 2), 0, math.sin(side * PI / 2))
		local tan = Vector3.new(-dir.Z, 0, dir.X)
		local count = 16
		local span = H + 30
		for i = 0, count - 1 do
			local t = (i + 0.5) / count * 2 * span - span
			local w = rng:NextNumber(28, 42)
			local hgt = rng:NextNumber(100, 125)
			local th = rng:NextNumber(20, 34)
			local pos = dir * (H + th / 2 - 4 + rng:NextNumber(0, 6)) + tan * t + Vector3.new(0, hgt / 2 - 8, 0)
			local cf = CFrame.lookAt(pos, pos - dir) * CFrame.Angles(
				rng:NextNumber(-0.06, 0.06),
				rng:NextNumber(-0.18, 0.18),
				rng:NextNumber(-0.05, 0.05)
			)
			local shade = rng:NextInteger(-8, 8)
			mk(
				fCave,
				"Cliff",
				Vector3.new(w, hgt, th),
				cf,
				Color3.fromRGB(46 + shade, 50 + shade, 64 + shade), -- холодный сине-серый камень
				M.Slate
			)
		end
		-- глухая задняя стена, чтобы не было просветов
		local backPos = dir * (H + 38) + Vector3.new(0, 55, 0)
		mk(
			fCave,
			"CliffBacking",
			Vector3.new(2 * span + 40, 130, 10),
			CFrame.lookAt(backPos, backPos - dir),
			C.RockDark,
			M.Rock
		)
	end

	-- свод
	-- в центре — квадратный проём над ямой: через него падает лунный свет (см. Hub/Atmosphere)
	local hole = Config.Lighting.Moon.HoleHalf
	local ceilY = CEIL_Y + 6
	local span = 220 -- половина стороны свода
	local strip = span - hole
	mk(fCave, "Ceiling", Vector3.new(span * 2, 12, strip), CFrame.new(0, ceilY, -(hole + span) / 2), C.RockDark, M.Slate)
	mk(fCave, "Ceiling", Vector3.new(span * 2, 12, strip), CFrame.new(0, ceilY, (hole + span) / 2), C.RockDark, M.Slate)
	mk(fCave, "Ceiling", Vector3.new(strip, 12, hole * 2), CFrame.new(-(hole + span) / 2, ceilY, 0), C.RockDark, M.Slate)
	mk(fCave, "Ceiling", Vector3.new(strip, 12, hole * 2), CFrame.new((hole + span) / 2, ceilY, 0), C.RockDark, M.Slate)

	-- сталактиты: ступенчатые перевёрнутые конусы
	local function stalactite(x, z, len, base)
		local tiers = 4
		local seg = len / tiers
		for t = 1, tiers do
			local dia = base * (1 - (t - 1) / tiers * 0.85)
			cylV(
				fCave,
				"Stalactite",
				x,
				CEIL_Y - (t - 0.5) * seg,
				z,
				seg + 0.2,
				dia,
				C.CaveStone,
				M.Slate
			)
		end
		mk(
			fCave,
			"StalactiteTip",
			Vector3.new(base * 0.3, base * 0.3, base * 0.3),
			CFrame.new(x, CEIL_Y - len, z),
			C.CaveStone,
			M.Slate,
			Enum.PartType.Ball
		)
	end
	for _ = 1, 70 do
		local sx, sz = rng:NextNumber(-170, 170), rng:NextNumber(-170, 170)
		local len, base = rng:NextNumber(8, 30), rng:NextNumber(3, 8)
		if math.abs(sx) > hole + base or math.abs(sz) > hole + base then -- не перекрываем проём
			stalactite(sx, sz, len, base)
		end
	end

	-- скрытые тёплые источники света под сводом
	for _, p in {
		Vector3.new(0, 55, 0),
		Vector3.new(-75, 50, 0),
		Vector3.new(75, 50, 0),
		Vector3.new(0, 50, 75),
		Vector3.new(0, 55, -85),
		Vector3.new(-90, 50, -90),
		Vector3.new(90, 50, -90),
	} do
		addLight(ghost(fLights, "CaveLight", p), Color3.fromRGB(110, 140, 220), 0.5, 60) -- холодный подсвет свода
	end

	-- подсветка скал: 28 ламп вдоль четырёх стен, тёплые и холодные вперемешку
	for side = 0, 3 do
		local a = side * PI / 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tan = Vector3.new(-dir.Z, 0, dir.X)
		for i = -3, 3 do
			local y = (i % 2 == 0) and 14 or 38
			local p = ghost(fLights, "CliffLight", dir * 138 + tan * (i * 48) + Vector3.new(0, y, 0))
			-- холодные синие тени по скалам; тёплый акцент только по центру трёх сторон (храм на севере светит сам)
			local warm = i == 0 and side ~= 3
			addLight(p, warm and C.Warm or C.Cool, warm and 1 or 0.9, 55)
		end
	end
end

-------------------------------------------------------------------------------
-- Манекены (4 шт.) в центре ямы. Логика — server/Dummies.
-------------------------------------------------------------------------------
local function buildDummy(index, cf)
	local m = Instance.new("Model")
	m.Name = "Dummy" .. index
	local function L(name, size, off, color, mat, shape)
		return mk(m, name, size, cf * CFrame.new(off), color, mat, shape)
	end
	local skin = Color3.fromRGB(226, 190, 140)
	local hrp = L("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), C.Wood, M.Wood)
	hrp.Transparency = 1
	hrp.CanCollide = false
	L("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), Color3.fromRGB(190, 120, 50), M.Fabric)
	local head = L("Head", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 4.7, 0), skin, M.Wood, Enum.PartType.Ball)
	L("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), skin, M.Wood)
	L("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), skin, M.Wood)
	L("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), C.WoodLight, M.Wood)
	L("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), C.WoodLight, M.Wood)
	L("Stand", Vector3.new(4, 0.4, 4), Vector3.new(0, 0.2, 0), C.StoneDark, M.Slate)
	L(
		"TargetMark",
		Vector3.new(1.4, 1.4, 0.1),
		Vector3.new(0, 3, -0.55),
		Color3.fromRGB(200, 40, 30),
		M.SmoothPlastic,
		Enum.PartType.Cylinder
	)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = Config.Dummies.MaxHealth
	hum.Health = Config.Dummies.MaxHealth
	hum.DisplayName = "Training Dummy"
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = m

	-- тег "Enemy": по таким моделям бьют скиллы (CombatService); клонирование шаблона при респавне сохраняет тег.
	-- ClickDetector убран: клик теперь выбирает цель (TargetController), а не бьёт манекен.
	CollectionService:AddTag(m, "Enemy")
	m:SetAttribute("Immortal", true) -- манекены не умирают: урон идёт в DPS-замер (Services/DpsService)

	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.MaxDistance = 110
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.FontFace = Fonts.Title
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Training Dummy 100/100"
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.new(1, 0, 0, 12)
	back.Position = UDim2.new(0, 0, 0, 18)
	back.BackgroundColor3 = Color3.fromRGB(25, 20, 18)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromHSV(0.33, 0.8, 0.9)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = head

	m.PrimaryPart = hrp
	m.Parent = fDummies
end

for k = 0, 3 do
	local pos = radial(PI / 4 + k * PI / 2, 6, PIT_FLOOR_Y)
	buildDummy(k + 1, CFrame.lookAt(pos, Vector3.new(pos.X * 2, pos.Y, pos.Z * 2)))
end

-------------------------------------------------------------------------------
-- SpawnLocation на верхнем ярусе (юг), взгляд на яму и порталы
-------------------------------------------------------------------------------
do
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(Config.SPAWN_POSITION, Vector3.new(0, Config.SPAWN_POSITION.Y, 0))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Transparency = 1
	spawn.CanCollide = true
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = hub
end

-------------------------------------------------------------------------------
-- 5. Освещение, атмосфера и декор (Hub/Atmosphere, Hub/Decor; числа — Config.Lighting)
-------------------------------------------------------------------------------
Atmosphere.apply(Config.Lighting, hub)
Decor.build({
	hub = hub,
	Config = Config,
	mk = mk,
	ghost = ghost,
	radial = radial,
	faceCenter = faceCenter,
	inGap = inGap,
	folder = folder,
})
DpsBoard.build(hub, Vector3.new(16, 0, 72)) -- доска DPS-лидерборда справа от аллеи к яме (текст обновляет DpsService)

-------------------------------------------------------------------------------
hub.Parent = Workspace
Workspace:SetAttribute("HubReady", true) -- Dummies дожидается этого флага
print(string.format("[BuildHub] Workspace.MainHub built: %d parts.", partCount))
