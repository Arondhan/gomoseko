--!strict
-- Клиентская отрисовка цепной молнии. Сервер присылает каждое звено цепи (from -> to) событием SkillVFX;
-- здесь мы строим зигзаг из Attachment + Beam, играем звук и плавно растворяем молнию через TweenService.
-- Все временные объекты уничтожаются сразу после анимации. Никакого урона и логики здесь нет.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local ArcLightningConfig =
	require(Shared:WaitForChild("Configs"):WaitForChild("Skills"):WaitForChild("ArcLightningConfig"))

local LightningRenderer = {}

local SKILLS: { [string]: Types.SkillConfig } = {
	[ArcLightningConfig.Id] = ArcLightningConfig,
}

local MAX_ACTIVE = 40 -- одновременных звеньев; лишние пропускаем, чтобы не плодить объекты при спаме
local SOUND_LIFETIME = 3 -- сколько живёт якорь со звуком (сек)

local active = 0
local container: Folder? = nil

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local folder = Instance.new("Folder")
	folder.Name = "LightningVFX"
	folder.Parent = Workspace
	container = folder
	return folder
end

-- Ломаная от from до to: промежуточные точки смещены в стороны перпендикулярно направлению луча
local function zigzagPoints(from: Vector3, to: Vector3, segments: number, amplitude: number): { Vector3 }
	local points = { from }
	local delta = to - from
	local length = delta.Magnitude
	if length > 0.01 then
		local forward = delta / length
		local reference = if math.abs(forward.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local side = forward:Cross(reference).Unit
		local up = side:Cross(forward).Unit
		for i = 1, segments - 1 do
			local angle = math.random() * math.pi * 2
			local offset = (side * math.cos(angle) + up * math.sin(angle)) * (math.random() * amplitude)
			table.insert(points, from + delta * (i / segments) + offset)
		end
	end
	table.insert(points, to)
	return points
end

local function newBeam(parent: Instance, a0: Attachment, a1: Attachment, color: Color3, width: number): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = width
	beam.Width1 = width
	beam.Transparency = NumberSequence.new(0)
	beam.Parent = parent
	return beam
end

-- Вспышка и искры в точке попадания
local function impactEffect(anchor: BasePart, position: Vector3, config: Types.SkillConfig)
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	attachment.WorldPosition = position

	local light = Instance.new("PointLight")
	light.Color = config.Color
	light.Brightness = 4
	light.Range = 12
	light.Parent = attachment

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(config.CoreColor)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 0
	sparks.Parent = attachment
	sparks:Emit(12)
end

local function playHop(hop: Types.LightningHop)
	local config = SKILLS[hop.skillId]
	if not config or active >= MAX_ACTIVE then
		return
	end
	active += 1

	-- один невидимый якорь на звено: на нём все Attachment, и один Destroy чистит всё
	local anchor = Instance.new("Part")
	anchor.Name = "LightningHop"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(hop.from)
	anchor.Parent = getContainer()

	local attachments: { Attachment } = {}
	for _, point in zigzagPoints(hop.from, hop.to, config.ZigzagSegments or 7, config.ZigzagAmplitude or 1.6) do
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		attachment.WorldPosition = point
		table.insert(attachments, attachment)
	end

	-- на каждое звено ломаной: широкое цветное свечение + узкое яркое ядро
	local width = config.Width or 1.4
	local coreWidth = config.CoreWidth or 0.45
	local fadeTime = config.FadeTime or 0.3
	local beams: { { beam: Beam, width: number } } = {}
	for i = 1, #attachments - 1 do
		local a0, a1 = attachments[i], attachments[i + 1]
		table.insert(beams, { beam = newBeam(anchor, a0, a1, config.Color, width), width = width })
		table.insert(beams, { beam = newBeam(anchor, a0, a1, config.CoreColor, coreWidth), width = coreWidth })
	end

	impactEffect(anchor, hop.to, config)

	-- звук разряда в точке попадания (последний Attachment ломаной); ID из конфига скилла или из Assets (Asphalt)
	local lifetime = fadeTime
	local zapId = if config.SoundId ~= "" then config.SoundId else Sounds.id("ArcLightningZap")
	if zapId ~= "" then
		Sfx.play3D(zapId, attachments[#attachments], config.SoundVolume)
		lifetime = math.max(lifetime, SOUND_LIFETIME) -- якорь живёт, пока доиграет звук
	end

	-- плавное растворение: NumberSequence не твинится напрямую, поэтому твиним NumberValue и применяем его вручную
	local fade = Instance.new("NumberValue")
	local connection = fade.Changed:Connect(function(progress: number)
		for _, entry in beams do
			entry.beam.Transparency = NumberSequence.new(progress)
			local width = entry.width * (1 - progress * 0.6)
			entry.beam.Width0 = width
			entry.beam.Width1 = width
		end
	end)
	local tween = TweenService:Create(
		fade,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween.Completed:Once(function()
		connection:Disconnect()
		fade:Destroy()
		tween:Destroy()
		for _, entry in beams do
			entry.beam:Destroy()
		end
		active -= 1
	end)
	tween:Play()

	Debris:AddItem(anchor, lifetime + 0.1)
end

function LightningRenderer.start()
	local remote = Remotes.get("SkillVFX") :: RemoteEvent
	remote.OnClientEvent:Connect(function(hop: Types.LightningHop)
		if type(hop) == "table" and typeof(hop.from) == "Vector3" and typeof(hop.to) == "Vector3" then
			playHop(hop)
		end
	end)
end

return LightningRenderer
