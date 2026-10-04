--!strict
-- Плавающие цифры урона (как в WoW): сервер присылает DamageDealt только тому, кто бьёт; здесь над целью
-- появляется число, всплывает вверх и растворяется (TweenService), после чего всё удаляется.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ArcLightningConfig =
	require(Shared:WaitForChild("Configs"):WaitForChild("Skills"):WaitForChild("ArcLightningConfig"))

local DamageNumbers = {}

local SKILLS: { [string]: Types.SkillConfig } = {
	[ArcLightningConfig.Id] = ArcLightningConfig,
}

local MAX_ACTIVE = 30 -- одновременных цифр
local RISE_HEIGHT = 4 -- на сколько studs всплывает цифра
local LIFETIME = 1.1
local SPREAD = 1.2 -- случайный разброс по горизонтали, чтобы цифры не слипались

local active = 0
local container: Folder? = nil

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local folder = Instance.new("Folder")
	folder.Name = "DamageVFX"
	folder.Parent = Workspace
	container = folder
	return folder
end

local function spawnNumber(event: Types.DamageEvent)
	if active >= MAX_ACTIVE then
		return
	end
	active += 1

	local config = SKILLS[event.skillId]
	local color = if config then config.CoreColor else Color3.new(1, 1, 1)

	local offset = Vector3.new((math.random() - 0.5) * 2 * SPREAD, 0, (math.random() - 0.5) * 2 * SPREAD)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(event.position + offset)
	anchor.Parent = getContainer()

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(math.floor(event.amount + 0.5))
	label.TextSize = 30
	label.TextColor3 = color
	label.TextStrokeColor3 = if config then config.Color else Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.1
	label.Parent = gui

	-- всплытие + растворение; «pop» в начале через размер текста
	local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, RISE_HEIGHT, 0) }):Play()
	label.TextSize = 40
	TweenService:Create(label, TweenInfo.new(0.15), { TextSize = 30 }):Play()
	local fade = TweenService:Create(
		label,
		TweenInfo.new(LIFETIME * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	task.delay(LIFETIME * 0.4, function()
		fade:Play()
	end)
	Debris:AddItem(anchor, LIFETIME + 0.1)
	task.delay(LIFETIME + 0.1, function()
		active -= 1
	end)
end

function DamageNumbers.start()
	local remote = Remotes.get("DamageDealt") :: RemoteEvent
	remote.OnClientEvent:Connect(function(event: Types.DamageEvent)
		if type(event) == "table" and typeof(event.position) == "Vector3" and type(event.amount) == "number" then
			spawnNumber(event)
		end
	end)
end

return DamageNumbers
