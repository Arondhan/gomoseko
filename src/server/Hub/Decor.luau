--!strict
-- Декор главной локации: инкрустация арены, деревянная отделка ям и лестниц, фонари, знамёна, ящики и бочки,
-- мох, кристаллы и светлячки. Строится поверх геометрии BuildHub (ничего не меняет в планировке).
-- Всё детерминировано (Random с фиксированным seed), все детали Anchored.

local Atmosphere = require(script.Parent.Atmosphere)

local Decor = {}

local PI, TAU = math.pi, math.pi * 2
local M = Enum.Material

-- Помощники из BuildHub, передаются целиком (см. BuildHub: ctx)
export type Ctx = {
	hub: Folder,
	Config: any,
	mk: (
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	) -> Part,
	ghost: (parent: Instance, name: string, pos: Vector3) -> Part,
	radial: (angle: number, r: number, y: number) -> Vector3,
	faceCenter: (pos: Vector3) -> CFrame,
	inGap: (a: number, r: number, half: number, dirCount: number) -> boolean,
	folder: (parent: Instance, name: string) -> Folder,
}

function Decor.build(ctx: Ctx)
	local Config = ctx.Config
	local C = Config.Colors
	local mk, ghost, radial, faceCenter, inGap = ctx.mk, ctx.ghost, ctx.radial, ctx.faceCenter, ctx.inGap
	local rng = Random.new(2025)

	local fInlay = ctx.folder(ctx.hub, "DecorInlay")
	local fWood = ctx.folder(ctx.hub, "DecorWood")
	local fProps = ctx.folder(ctx.hub, "DecorProps")
	local fBanners = ctx.folder(ctx.hub, "DecorBanners")
	local fLamps = ctx.folder(ctx.hub, "DecorLamps")
	local fNature = ctx.folder(ctx.hub, "DecorNature")

	local PIT_FLOOR_Y = Config.PIT_FLOOR_Y
	local WALL_R = Config.WALL_R
	local center = Vector3.zero

	local iron = Color3.fromRGB(44, 40, 38)

	-- вертикальный цилиндр: height по Y, dia — диаметр
	local function cyl(
		parent: Instance,
		name: string,
		x: number,
		y: number,
		z: number,
		height: number,
		dia: number,
		color: Color3,
		material: Enum.Material
	): Part
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

	---------------------------------------------------------------------------
	-- 1. Арена: золотая инкрустация (кольца + 8 лучей)
	---------------------------------------------------------------------------
	do
		-- top — высота верхней грани над полом ямы; кольца чуть выше нижележащих дисков BuildHub
		local function disc(name: string, dia: number, top: number, color: Color3, material: Enum.Material)
			local thick = 0.1
			cyl(fInlay, name, 0, PIT_FLOOR_Y + top - thick / 2, 0, thick, dia, color, material)
		end
		disc("InlayOuterGold", 57.4, 0.15, C.Gold, M.Metal)
		disc("InlayMidGold", 42.4, 0.25, C.Gold, M.Metal)
		disc("InlayCenterGold", 19.8, 0.35, C.Gold, M.Metal)

		-- лучи от центра к краю между кольцами (по осям и диагоналям)
		for k = 0, 7 do
			local a = k * PI / 4
			local y = PIT_FLOOR_Y + 0.33
			local pos = radial(a, 30, y)
			mk(
				fInlay,
				"InlayRay",
				Vector3.new(0.9, 0.06, 18),
				CFrame.lookAt(pos, Vector3.new(0, y, 0)),
				C.Gold,
				M.Metal
			)
		end
	end

	---------------------------------------------------------------------------
	-- 2. Деревянная отделка: брус по верху стены ямы + дощатые ступени и поручни лестниц
	---------------------------------------------------------------------------
	do
		local N = 72
		for i = 0, N - 1 do
			local a = (i + 0.5) / N * TAU
			if not inGap(a, WALL_R, 10, 4) then
				local pos = radial(a, WALL_R - 1.3, 3.85)
				mk(
					fWood,
					"WoodTrim",
					Vector3.new(4.4, 0.3, 1.3),
					CFrame.lookAt(pos, Vector3.new(0, 3.85, 0)),
					C.WoodTrim,
					M.WoodPlanks
				)
			end
		end

		for k = 0, 3 do
			local a = k * PI / 2
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			-- накладки-доски на 7 ступенях (геометрия ступеней — BuildHub §2)
			for i = 1, 7 do
				local top = -1.25 * i
				local pos = radial(a, 34 - 2 * i, top + 0.08)
				mk(
					fWood,
					"StairPlank",
					Vector3.new(16.3, 0.16, 2.1),
					CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
					C.WoodLight,
					M.WoodPlanks
				)
			end
			-- поручни: столбики на каждой ступени + наклонная перекладина
			for _, s in { -1, 1 } do
				local function railPoint(r: number, y: number): Vector3
					return radial(a, r, y) + tangent * (s * 8.4)
				end
				for i = 0, 7 do
					local top = -1.25 * i
					local post = railPoint(34 - 2 * i, top + 1.5)
					mk(fWood, "RailPost", Vector3.new(0.4, 3, 0.4), CFrame.new(post), C.WoodTrim, M.Wood)
				end
				local from, to = railPoint(34, 3), railPoint(20, -1.25 * 7 + 3)
				local len = (to - from).Magnitude
				mk(
					fWood,
					"Handrail",
					Vector3.new(0.45, 0.45, len),
					CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2),
					C.WoodLight,
					M.Wood
				)
			end
		end
	end

	---------------------------------------------------------------------------
	-- 3. Знамёна: на пилонах лестниц и перед храмом
	---------------------------------------------------------------------------
	local function banner(baseCf: CFrame, poleHeight: number, color: Color3)
		mk(
			fBanners,
			"BannerPole",
			Vector3.new(0.35, poleHeight, 0.35),
			baseCf * CFrame.new(0, poleHeight / 2, 0),
			iron,
			M.Metal
		)
		mk(
			fBanners,
			"BannerArm",
			Vector3.new(2.8, 0.25, 0.25),
			baseCf * CFrame.new(0, poleHeight - 0.4, 0),
			iron,
			M.Metal
		)
		local clothH = 6
		local clothCf = baseCf * CFrame.new(0, poleHeight - 0.5 - clothH / 2, 0)
		mk(fBanners, "BannerCloth", Vector3.new(2.3, clothH, 0.12), clothCf, color, M.Fabric)
		mk(
			fBanners,
			"BannerTrim",
			Vector3.new(2.3, 0.4, 0.16),
			clothCf * CFrame.new(0, -clothH / 2 + 0.2, 0),
			C.Gold,
			M.Metal
		)
		mk(
			fBanners,
			"BannerCrest",
			Vector3.new(0.9, 0.9, 0.16),
			clothCf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, PI / 4),
			C.Gold,
			M.Metal
		)
	end

	do
		local index = 0
		for k = 0, 3 do
			local a = k * PI / 2
			for _, s in { -1, 1 } do
				local cf = CFrame.lookAt(radial(a, 36, 0), center) * CFrame.new(s * 11, 5.8, 0)
				banner(cf, 7, if index % 2 == 0 then C.BannerRed else C.BannerBlue)
				index += 1
			end
		end
		-- перед храмом
		for i, x in { -30, -12, 12, 30 } do
			banner(
				CFrame.lookAt(Vector3.new(x, 0, -88), Vector3.new(x, 0, 0)),
				13,
				if i % 2 == 0 then C.BannerRed else C.BannerBlue
			)
		end
	end

	---------------------------------------------------------------------------
	-- 4. Фонари: 16 столбов за парапетом (мерцает на клиенте, тег Torch)
	---------------------------------------------------------------------------
	do
		local R = 54
		for k = 0, 15 do
			local a = (k + 0.5) / 16 * TAU
			if not inGap(a, R, 10, 8) then
				local base = radial(a, R, 0)
				local cf = CFrame.lookAt(base, Vector3.new(0, 0, 0))
				mk(
					fLamps,
					"LampBase",
					Vector3.new(1.6, 0.8, 1.6),
					cf * CFrame.new(0, 0.4, 0),
					C.StoneDark,
					M.Cobblestone
				)
				mk(fLamps, "LampPole", Vector3.new(0.35, 6.4, 0.35), cf * CFrame.new(0, 4, 0), iron, M.Metal)
				mk(fLamps, "LampCap", Vector3.new(1.5, 0.3, 1.5), cf * CFrame.new(0, 7.6, 0), iron, M.Metal)
				mk(fLamps, "LampFrame", Vector3.new(1.2, 1.5, 1.2), cf * CFrame.new(0, 6.7, 0), iron, M.Metal)
				local glass = mk(
					fLamps,
					"LampGlass",
					Vector3.new(0.8, 1.1, 0.8),
					cf * CFrame.new(0, 6.7, 0),
					C.LanternGlass,
					M.Neon
				)
				glass.Transparency = 0.15
				Atmosphere.torchLight(glass, Color3.fromRGB(255, 185, 110), 1.4, 28)
			end
		end
	end

	---------------------------------------------------------------------------
	-- 5. Ящики и бочки рядом с палатками (позиции палаток — как в BuildHub)
	---------------------------------------------------------------------------
	do
		local stalls: { Vector3 } = {}
		for k = 0, 7 do
			table.insert(stalls, radial(math.rad(22.5 + 45 * k), 64, 0))
		end
		for _, x in { -112, 112 } do
			for _, z in { -60, -30, 0, 30, 60 } do
				table.insert(stalls, Vector3.new(x, 0, z))
			end
		end

		local wood, woodDark = C.WoodLight, C.Wood
		for index, pos in stalls do
			local side = if index % 2 == 0 then 1 else -1
			local cf = faceCenter(pos) * CFrame.new(side * 7, 0, 1.5)
			local function crate(name: string, size: number, off: Vector3, yaw: number)
				mk(
					fProps,
					name,
					Vector3.new(size, size, size),
					cf * CFrame.new(off.X, off.Y + size / 2, off.Z) * CFrame.Angles(0, yaw, 0),
					wood,
					M.WoodPlanks
				)
			end
			crate("Crate", 2.6, Vector3.new(0, 0, 0), rng:NextNumber(-0.3, 0.3))
			crate("Crate", 2, Vector3.new(2.9, 0, 0.6), rng:NextNumber(-0.4, 0.4))
			crate("Crate", 1.6, Vector3.new(0.2, 2.6, 0), rng:NextNumber(-0.5, 0.5))
			for _, off in { Vector3.new(-2.5, 0, 0.8), Vector3.new(-3.2, 0, -1.8) } do
				local p = cf * CFrame.new(off)
				local pos2 = p.Position
				mk(
					fProps,
					"Barrel",
					Vector3.new(2.8, 2.2, 2.2),
					CFrame.new(pos2.X, 1.4, pos2.Z) * CFrame.Angles(0, 0, PI / 2),
					woodDark,
					M.Wood,
					Enum.PartType.Cylinder
				)
				for _, by in { 0.6, 2.2 } do
					mk(
						fProps,
						"BarrelBand",
						Vector3.new(0.15, 2.3, 2.3),
						CFrame.new(pos2.X, by, pos2.Z) * CFrame.Angles(0, 0, PI / 2),
						iron,
						M.Metal,
						Enum.PartType.Cylinder
					)
				end
			end
		end
	end

	---------------------------------------------------------------------------
	-- 6. Природа: мох/трава, кристаллы, светлячки (у краёв площади, у скал)
	---------------------------------------------------------------------------
	do
		local function blocked(x: number, z: number): boolean
			-- домики-гильдии (±138, ±48) и палатки вдоль краёв
			if math.abs(x) > 118 and math.abs(z) > 28 and math.abs(z) < 68 then
				return true
			end
			return false
		end

		-- точка у края площади (у скал): возвращает x, z
		local function edgePoint(): (number, number)
			for _ = 1, 20 do
				local side = rng:NextInteger(0, 3)
				local along = rng:NextNumber(-150, 150)
				local out = rng:NextNumber(142, 157)
				local x, z = along, along
				if side < 2 then
					x, z = out * (if side == 0 then 1 else -1), along
				else
					x, z = along, out * (if side == 2 then 1 else -1)
				end
				if not blocked(x, z) then
					return x, z
				end
			end
			return 150, 150
		end

		-- мох и кусты
		local fireflySpots: { Vector3 } = {}
		for i = 1, 30 do
			local x, z = edgePoint()
			local dia = rng:NextNumber(5, 13)
			local tint = rng:NextNumber(-10, 10)
			cyl(fNature, "Moss", x, 0.06, z, 0.12, dia, Color3.fromRGB(70 + tint, 112 + tint, 58), M.Grass)
			if i % 3 == 0 then
				for b = 1, rng:NextInteger(2, 3) do
					local size = rng:NextNumber(2, 3.6)
					mk(
						fNature,
						"Bush",
						Vector3.new(size, size * 0.8, size),
						CFrame.new(
							x + rng:NextNumber(-dia / 3, dia / 3),
							size * 0.35,
							z + rng:NextNumber(-dia / 3, dia / 3)
						),
						Color3.fromRGB(58 + b * 6, 104 + b * 6, 50),
						M.Grass,
						Enum.PartType.Ball
					)
				end
				if i % 6 == 0 then
					table.insert(fireflySpots, Vector3.new(x, 2.5, z))
				end
			end
		end

		for _, spot in fireflySpots do
			local anchor = ghost(fNature, "FireflyAnchor", spot)
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 3
			pe.Lifetime = NumberRange.new(4, 7)
			pe.Speed = NumberRange.new(0.4, 1.2)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Acceleration = Vector3.new(0, 0.3, 0)
			pe.Size = NumberSequence.new(0.35)
			pe.LightEmission = 1
			pe.LightInfluence = 0
			pe.Color = ColorSequence.new(Color3.fromRGB(200, 255, 140))
			pe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.2),
				NumberSequenceKeypoint.new(0.7, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			pe.Parent = anchor
		end

		-- кристаллы: холодный голубой акцент у скал
		for _ = 1, 12 do
			local x, z = edgePoint()
			local group = ghost(fNature, "CrystalGlow", Vector3.new(x, 2.5, z))
			local light = Instance.new("PointLight")
			light.Color = C.Crystal
			light.Brightness = 0.9
			light.Range = 20
			light.Shadows = false
			light.Parent = group
			for _ = 1, rng:NextInteger(3, 5) do
				local len = rng:NextNumber(2.5, 5.5)
				local w = rng:NextNumber(0.5, 0.9)
				local tilt = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, TAU), rng:NextNumber(-0.4, 0.4))
				mk(
					fNature,
					"Crystal",
					Vector3.new(w, len, w),
					CFrame.new(x + rng:NextNumber(-1.4, 1.4), len * 0.45, z + rng:NextNumber(-1.4, 1.4)) * tilt,
					C.Crystal,
					M.Neon
				).Transparency =
					0.1
			end
		end
	end

	---------------------------------------------------------------------------
	-- 7. Подсветка вывески храма
	---------------------------------------------------------------------------
	do
		local anchor = ghost(fLamps, "SignLight", Vector3.new(0, 58, -120))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Brightness = 1.2
		light.Range = 40
		light.Shadows = false
		light.Parent = anchor
	end
end

return Decor
