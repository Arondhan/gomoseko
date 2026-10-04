--!strict
-- Титул над головой: BillboardGui на Head с ником, названием самого редкого надетого кольца и его редкостью
-- «[1 in X]». Строится на сервере (виден всем, заменяет стандартную табличку с именем) и перестраивается при
-- любом изменении экипировки. Для колец не реже GachaConfig.Overhead.MinGradientOneIn на тексте лежит UIGradient
-- с тегом "RareTitleGradient" — волну анимирует клиент (client/VFX/TitleGradient.luau); для самых редких
-- (RainbowOneIn+) цвета радужные.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fonts = require(Shared:WaitForChild("Fonts"))
local Types = require(Shared:WaitForChild("Types"))
local GachaMath = require(Shared:WaitForChild("Gacha"):WaitForChild("GachaMath"))
local Rarity = require(Shared:WaitForChild("Gacha"):WaitForChild("Rarity"))
local GachaConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GachaConfig"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local StatsService = require(Services:WaitForChild("StatsService"))

local OverheadTitleService = {}

local GRADIENT_TAG = "RareTitleGradient"
local GUI_NAME = "RingTitle"
local MAX_DISTANCE = 90

-- Самое редкое надетое кольцо (по OneIn); nil — ничего не надето
local function bestEquipped(player: Player): Types.RingDef?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local best: any = nil
	for _, ringId in profile.Equipped do
		local ring = RingsConfig.Rings[ringId]
		if ring and (best == nil or ring.OneIn > best.OneIn) then
			best = ring
		end
	end
	return best
end

local function makeLabel(parent: Instance, order: number, y: number, height: number, text: string, size: number)
	local label = Instance.new("TextLabel")
	label.Name = "Line" .. order
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, y)
	label.Size = UDim2.new(1, 0, 0, height)
	label.Text = text
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.FontFace = Fonts.Title
	label.Parent = parent
	return label
end

local function addGradient(label: TextLabel, ring: Types.RingDef, color: Color3)
	local gradient = Instance.new("UIGradient")
	local rainbow = ring.OneIn >= GachaConfig.Overhead.RainbowOneIn
	gradient.Color = if rainbow then Rarity.rainbowSequence(0) else Rarity.waveSequence(color)
	gradient:SetAttribute("Rainbow", rainbow)
	gradient.Parent = label
	CollectionService:AddTag(gradient, GRADIENT_TAG)
end

local function build(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- стандартная табличка не нужна
	end
	local old = head:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end

	local ring = bestEquipped(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = GUI_NAME
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(280, if ring then 82 else 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local nameLabel = makeLabel(gui, 1, 0, 28, player.DisplayName, 20)
	nameLabel.FontFace = Fonts.Body
	if ring then
		local color = Rarity.Colors[ring.Quality] or Color3.new(1, 1, 1)
		local ringLabel = makeLabel(gui, 2, 28, 30, ring.Name, 24)
		ringLabel.TextColor3 = color
		local oddsLabel = makeLabel(gui, 3, 58, 22, "[" .. GachaMath.formatOneIn(ring.OneIn) .. "]", 18)
		oddsLabel.FontFace = Fonts.Numbers
		oddsLabel.TextColor3 = color
		if ring.OneIn >= GachaConfig.Overhead.MinGradientOneIn then
			ringLabel.TextColor3 = Color3.new(1, 1, 1) -- градиент тонирует белый текст
			oddsLabel.TextColor3 = Color3.new(1, 1, 1)
			addGradient(ringLabel, ring, color)
			addGradient(oddsLabel, ring, color)
		end
	end
	gui.Parent = head
end

local function onCharacter(player: Player, character: Model)
	character:WaitForChild("Head", 10)
	build(player)
end

function OverheadTitleService.start()
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	-- надели/сняли кольцо (или загрузился профиль) -> перестраиваем титул
	StatsService.changed.Event:Connect(function(player: Player)
		build(player)
	end)
end

return OverheadTitleService
