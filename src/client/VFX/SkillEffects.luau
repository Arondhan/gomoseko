--!strict
-- Визуал площадных скиллов (без внешних ассетов): Fireball — огненный шар летит и взрывается, Meteor — метка на земле,
-- затем с неба падает метеор. Сервер присылает событие SkillEffect (from/to/radius/duration) и сам считает урон;
-- здесь только части, твины, свет, частицы и звук. Все объекты чистятся по окончании анимации.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local SkillConfigs = Shared:WaitForChild("Configs"):WaitForChild("Skills")
local FireballConfig = require(SkillConfigs:WaitForChild("FireballConfig"))
local MeteorConfig = require(SkillConfigs:WaitForChild("MeteorConfig"))

local VFX = script.Parent
local Quality = require(VFX:WaitForChild("Quality"))
local Sfx = require(VFX:WaitForChild("Sfx"))

local SkillEffects = {}

local CONFIGS: { [string]: Types.SkillConfig } = {
	[FireballConfig.Id] = FireballConfig,
	[MeteorConfig.Id] = MeteorConfig,
}

local MAX_ACTIVE = 24 -- одновременных эффектов; лишние пропускаем (защита от спама)
local MAX_DURATION = 4

local active = 0
local container: Folder? = nil

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local folder = Instance.new("Folder")
	folder.Name = "SkillVFX"
	folder.Parent = Workspace
	container = folder
	return folder
end

local function newPart(shape: Enum.PartType, size: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = getContainer()
	return part
end

-- Плоский диск на земле: ось цилиндра Roblox — X, поэтому поворачиваем на 90° вокруг Z
local function newDisc(position: Vector3, diameter: number, color: Color3, transparency: number): Part
	local disc = newPart(Enum.PartType.Cylinder, Vector3.new(0.3, diameter, diameter), color, transparency)
	disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return disc
end

local function fade(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		:Play()
end

local function burstEmitter(parent: Instance, config: Types.SkillConfig, count: number, speed: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(config.CoreColor, config.Color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = parent
	emitter:Emit(count)
end

-- Взрыв: огненная сфера, яркое ядро, ударная волна по земле, вспышка света, искры и звук
local function explode(position: Vector3, radius: number, config: Types.SkillConfig)
	local low = Quality.isLow()
	local ball = newPart(Enum.PartType.Ball, Vector3.one * 2, config.Color, 0.25)
	ball.Position = position
	fade(ball, 0.5, { Size = Vector3.one * radius * 2, Transparency = 1 })

	local core = newPart(Enum.PartType.Ball, Vector3.one * 2, config.CoreColor, 0.1)
	core.Position = position
	fade(core, 0.35, { Size = Vector3.one * radius * 1.1, Transparency = 1 })

	local wave = newDisc(position - Vector3.new(0, 1.2, 0), 2, config.Color, 0.4)
	fade(wave, 0.6, { Size = Vector3.new(0.3, radius * 2.4, radius * 2.4), Transparency = 1 })

	if not low then
		local light = Instance.new("PointLight")
		light.Color = config.Color
		light.Range = math.min(60, radius * 3)
		light.Brightness = 6
		light.Parent = ball
		fade(light, 0.6, { Brightness = 0 })
	end
	burstEmitter(ball, config, if low then 10 else 36, radius * 3)

	local soundId = if config.SoundId ~= "" then config.SoundId else Sounds.id("Explosion")
	if soundId ~= "" then
		Sfx.play3D(soundId, ball, config.SoundVolume, 0.06, 250)
	end
	Debris:AddItem(ball, 2)
	Debris:AddItem(core, 1)
	Debris:AddItem(wave, 1)
end

-- Fireball: шар с хвостом летит from -> to за duration секунд и взрывается
local function playProjectile(effect: Types.SkillEffect, config: Types.SkillConfig)
	local low = Quality.isLow()
	local ball = newPart(Enum.PartType.Ball, Vector3.one * 2.4, config.CoreColor, 0)
	ball.Position = effect.from

	local shell = newPart(Enum.PartType.Ball, Vector3.one * 3.6, config.Color, 0.45)
	shell.Position = effect.from

	if not low then
		local light = Instance.new("PointLight")
		light.Color = config.Color
		light.Range = 16
		light.Brightness = 4
		light.Parent = ball
	end
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(config.CoreColor, config.Color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(2, 0)
	trail.Lifetime = NumberRange.new(0.3, 0.5)
	trail.Speed = NumberRange.new(0, 2)
	trail.Rate = if low then 25 else 70
	trail.Parent = ball

	local castId = if config.SoundId ~= "" then config.SoundId else Sounds.id("FireballCast")
	if castId ~= "" then
		Sfx.play3D(castId, ball, config.SoundVolume, 0.06, 150)
	end

	local info = TweenInfo.new(effect.duration, Enum.EasingStyle.Linear)
	TweenService:Create(ball, info, { Position = effect.to }):Play()
	local flight = TweenService:Create(shell, info, { Position = effect.to })
	flight.Completed:Once(function()
		ball:Destroy()
		shell:Destroy()
		explode(effect.to, effect.radius, config)
		active -= 1
	end)
	flight:Play()
end

-- Meteor: кольцо-метка, внутри растёт заполнение до удара; метеор падает с ускорением и взрывается
local function playMeteor(effect: Types.SkillEffect, config: Types.SkillConfig)
	local low = Quality.isLow()
	local markerPosition = effect.to + Vector3.new(0, 0.2, 0)
	local outer = newDisc(markerPosition, effect.radius * 2, config.Color, 0.65)
	local fill = newDisc(markerPosition + Vector3.new(0, 0.05, 0), 2, config.Color, 0.35)
	fade(
		fill,
		effect.duration,
		{ Size = Vector3.new(0.3, effect.radius * 2, effect.radius * 2) },
		Enum.EasingStyle.Linear
	)

	local core = newPart(Enum.PartType.Ball, Vector3.one * 8, config.CoreColor, 0)
	core.Position = effect.from
	local shell = newPart(Enum.PartType.Ball, Vector3.one * 12, config.Color, 0.4)
	shell.Position = effect.from
	if not low then
		local light = Instance.new("PointLight")
		light.Color = config.Color
		light.Range = 40
		light.Brightness = 5
		light.Parent = core
	end
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(config.CoreColor, config.Color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(7, 0)
	trail.Lifetime = NumberRange.new(0.5, 0.9)
	trail.Speed = NumberRange.new(0, 4)
	trail.Rate = if low then 30 else 90
	trail.Parent = core

	local landing = effect.to + Vector3.new(0, 5, 0)
	local info = TweenInfo.new(effect.duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(core, info, { Position = landing }):Play()
	local fall = TweenService:Create(shell, info, { Position = landing })
	fall.Completed:Once(function()
		core:Destroy()
		shell:Destroy()
		outer:Destroy()
		fill:Destroy()
		explode(effect.to + Vector3.new(0, 2, 0), effect.radius, config)
		active -= 1
	end)
	fall:Play()
end

local function isValid(effect: any): boolean
	return type(effect) == "table"
		and type(effect.skillId) == "string"
		and typeof(effect.from) == "Vector3"
		and typeof(effect.to) == "Vector3"
		and type(effect.radius) == "number"
		and type(effect.duration) == "number"
end

function SkillEffects.start()
	local remote = Remotes.get("SkillEffect") :: RemoteEvent
	remote.OnClientEvent:Connect(function(effect: Types.SkillEffect)
		if not isValid(effect) then
			return
		end
		local config = CONFIGS[effect.skillId]
		if not config or active >= MAX_ACTIVE then
			return
		end
		effect.duration = math.clamp(effect.duration, 0, MAX_DURATION)
		effect.radius = math.clamp(effect.radius, 1, 60)
		active += 1
		if effect.kind == "Projectile" then
			playProjectile(effect, config)
		elseif effect.kind == "Meteor" then
			playMeteor(effect, config)
		else
			active -= 1
		end
	end)
end

return SkillEffects
