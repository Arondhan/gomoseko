--!strict
-- Освещение и атмосфера хаба: холодный лунный полумрак, мягкий bloom, ночное небо в проёме свода
-- и лунный столб света над ямой. Все числа берутся из Config.Lighting (shared/Config).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Atmosphere = {}

-- Мерцающий источник тепла (факел, фонарь): тег "Torch" подхватывает client/VFX/TorchFlicker.
-- Базовые значения лежат в атрибутах, чтобы клиент мерцал вокруг них, не копя ошибку.
function Atmosphere.torchLight(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light:SetAttribute("BaseBrightness", brightness)
	light:SetAttribute("BaseRange", range)
	CollectionService:AddTag(light, "Torch")
	light.Parent = parent
	return light
end

local function invisibleAnchor(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

-- cfg = Config.Lighting, hub = корневая папка MainHub (сюда кладём лунный свет)
function Atmosphere.apply(cfg: any, hub: Folder)
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient
	Lighting.Brightness = cfg.Brightness
	Lighting.ExposureCompensation = cfg.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = cfg.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = cfg.EnvironmentSpecularScale
	Lighting.FogColor = cfg.FogColor
	Lighting.FogStart = cfg.FogStart
	Lighting.FogEnd = cfg.FogEnd

	-- убираем всё из шаблона (Sky, SunRays, второй Bloom, DepthOfField и т.д.)
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		end
	end

	-- ночное небо видно только в проёме свода над ямой
	local sky = Instance.new("Sky")
	sky.StarCount = cfg.StarCount
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local a = cfg.Atmosphere
	local atmo = Instance.new("Atmosphere")
	atmo.Density = a.Density
	atmo.Offset = a.Offset
	atmo.Color = a.Color
	atmo.Decay = a.Decay
	atmo.Glare = a.Glare
	atmo.Haze = a.Haze
	atmo.Parent = Lighting

	local b = cfg.Bloom
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "HubBloom"
	bloom.Intensity = b.Intensity
	bloom.Size = b.Size
	bloom.Threshold = b.Threshold
	bloom.Parent = Lighting

	local c = cfg.ColorCorrection
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HubColor"
	cc.TintColor = c.TintColor
	cc.Saturation = c.Saturation
	cc.Contrast = c.Contrast
	cc.Brightness = c.Brightness
	cc.Parent = Lighting

	-- лунный столб: прожектор вниз + едва заметный световой «цилиндр» + пылинки внутри
	local moon = cfg.Moon
	local folder = Instance.new("Folder")
	folder.Name = "Moonlight"
	folder.Parent = hub

	local source = invisibleAnchor(folder, "MoonSource", Vector3.one, CFrame.new(0, moon.SpotHeight, 0))
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Color = moon.Color
	spot.Brightness = moon.SpotBrightness
	spot.Angle = moon.SpotAngle
	spot.Range = moon.SpotRange
	spot.Shadows = false
	spot.Parent = source

	local shaftHeight = 110
	local function shaft(name: string, diameter: number, transparency: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(shaftHeight, diameter, diameter)
		p.CFrame = CFrame.new(0, shaftHeight / 2 - 12, 0) * CFrame.Angles(0, 0, math.pi / 2)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = moon.Color
		p.Transparency = transparency
		p.Parent = folder
	end
	shaft("MoonShaft", moon.ShaftDiameter, moon.ShaftTransparency)
	shaft("MoonShaftCore", moon.ShaftDiameter * 0.55, math.min(0.985, moon.ShaftTransparency + 0.04))

	local dustBox = invisibleAnchor(
		folder,
		"MoonDust",
		Vector3.new(moon.ShaftDiameter * 0.8, 80, moon.ShaftDiameter * 0.8),
		CFrame.new(0, 28, 0)
	)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Rate = 14
	dust.Lifetime = NumberRange.new(7, 11)
	dust.Speed = NumberRange.new(0.2, 0.7)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(0.35, 0.5)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.82),
		NumberSequenceKeypoint.new(0.8, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Color = ColorSequence.new(moon.Color:Lerp(Color3.new(1, 1, 1), 0.5))
	dust.LightEmission = 0.5
	dust.LightInfluence = 0
	dust.Parent = dustBox
end

return Atmosphere
