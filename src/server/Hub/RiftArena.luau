--!strict
-- Арена Rift: круглая каменная площадка с барьером-стеной, колоннами и светящимся кольцом, далеко от хаба
-- (Configs/RiftConfig.Arena). build() создаёт модель в Workspace и возвращает её вместе с порталом выхода.

local Workspace = game:GetService("Workspace")

local RiftArena = {}

export type Arena = {
	model: Model,
	center: Vector3,
	exitPortal: Part,
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Цилиндр с вертикальной осью (ось цилиндра Roblox — X, поворачиваем вокруг Z)
local function disc(
	parent: Instance,
	name: string,
	center: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function RiftArena.build(config: {
	Center: Vector3,
	Radius: number,
	WallHeight: number,
	ExitPortalRadius: number,
	PillarCount: number,
}): Arena
	local old = Workspace:FindFirstChild("RiftArena")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "RiftArena"
	local center, radius = config.Center, config.Radius

	-- пол: толстый диск, верх на уровне center.Y
	disc(model, "Floor", center - Vector3.new(0, 3, 0), 6, radius * 2, Color3.fromRGB(52, 56, 74), Enum.Material.Slate)
	-- светящиеся кольца-руны на полу
	for index, ringRadius in { radius * 0.35, radius * 0.7 } do
		local ring = disc(
			model,
			"RuneRing" .. index,
			center + Vector3.new(0, 0.05, 0),
			0.2,
			ringRadius * 2,
			Color3.fromRGB(110, 70, 220),
			Enum.Material.Neon
		)
		ring.Transparency = 0.55
		ring.CanCollide = false
		-- «вырезаем» середину кольца: поверх лежит диск цвета пола чуть меньшего диаметра
		local inner = disc(
			model,
			"RuneInner" .. index,
			center + Vector3.new(0, 0.1, 0),
			0.2,
			ringRadius * 2 - 1.2,
			Color3.fromRGB(52, 56, 74),
			Enum.Material.Slate
		)
		inner.CanCollide = false
	end

	-- барьер-стена из сегментов по окружности (полупрозрачная, чтобы арена была закрыта, но не давила)
	local segments = 36
	local wallRadius = radius + 1
	local segmentWidth = 2 * math.pi * wallRadius / segments + 0.5
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local position = center
			+ Vector3.new(math.cos(angle) * wallRadius, config.WallHeight / 2, math.sin(angle) * wallRadius)
		local wall = part(
			model,
			"Wall",
			Vector3.new(2, config.WallHeight, segmentWidth),
			CFrame.lookAt(position, center + Vector3.new(0, config.WallHeight / 2, 0))
				* CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(40, 36, 62),
			Enum.Material.Slate
		)
		wall.Transparency = 0.25
	end
	-- «крышка»: невидимый потолок, чтобы нельзя было перепрыгнуть/перелететь стену
	local ceiling = disc(
		model,
		"Ceiling",
		center + Vector3.new(0, config.WallHeight + 1, 0),
		2,
		radius * 2 + 4,
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic
	)
	ceiling.Transparency = 1

	-- колонны с неоновыми поясами и огнями по кругу
	local lights = 0
	for i = 0, config.PillarCount - 1 do
		local angle = (i + 0.5) / config.PillarCount * math.pi * 2
		local base = center + Vector3.new(math.cos(angle) * radius * 0.6, 0, math.sin(angle) * radius * 0.6)
		disc(model, "Pillar", base + Vector3.new(0, 7, 0), 14, 5, Color3.fromRGB(78, 74, 100), Enum.Material.Concrete)
		local band = disc(
			model,
			"PillarGlow",
			base + Vector3.new(0, 14.4, 0),
			1,
			6,
			Color3.fromRGB(150, 100, 255),
			Enum.Material.Neon
		)
		band.CanCollide = false
		if lights < 4 and i % 2 == 0 then
			lights += 1
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(150, 100, 255)
			light.Range = 40
			light.Brightness = 3
			light.Parent = band
		end
	end

	-- портал выхода у края арены (на нём ProximityPrompt, который вешает RiftService)
	local exitAngle = math.pi
	local exitPosition = center
		+ Vector3.new(math.cos(exitAngle) * config.ExitPortalRadius, 5, math.sin(exitAngle) * config.ExitPortalRadius)
	local exitPortal = part(
		model,
		"ExitPortal",
		Vector3.new(1, 10, 6),
		CFrame.lookAt(exitPosition, center + Vector3.new(0, 5, 0)),
		Color3.fromRGB(0, 170, 255),
		Enum.Material.Neon
	)
	exitPortal.CanCollide = false
	exitPortal.Transparency = 0.2

	model.Parent = Workspace
	return { model = model, center = center, exitPortal = exitPortal }
end

return RiftArena
