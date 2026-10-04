--!strict
-- Юнит-фрейм игрока слева сверху (как в WoW Dragonflight): круглый портрет в золотом кольце с бейджем уровня,
-- панель с именем, полосой здоровья и полосой маны.
-- Здоровье — из Humanoid персонажа, мана и уровень — из атрибутов Player (их ведёт сервер).

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Portrait = require(script.Parent.Portrait)
local StatusBar = require(script.Parent.StatusBar)
local Theme = require(script.Parent.Theme)

local PlayerFrame = {}

local PORTRAIT_SIZE = 78

-- Золотое кольцо поверх круглого портрета
local function portraitRing(parent: Instance, size: number, position: UDim2, zIndex: number): Frame
	local ring = Theme.new("Frame", {
		Name = "PortraitRing",
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, parent)
	Theme.corner(ring, size)
	Chrome.bevel(ring, 3, size)
	return ring
end

function PlayerFrame.build(parent: Instance)
	local player = Players.LocalPlayer

	local root = Theme.new("Frame", {
		Name = "PlayerFrame",
		Position = UDim2.fromOffset(20, 64), -- ниже верхней панели Roblox (иконки меню/чата)
		Size = UDim2.fromOffset(300, 92),
		BackgroundTransparency = 1,
	}, parent)

	-- панель с полосами (под портретом)
	local body = Chrome.panel(root, {
		Name = "Body",
		Position = UDim2.fromOffset(46, 12),
		Size = UDim2.fromOffset(254, 66),
	}, 8)

	Chrome.label(body, {
		Name = "Name",
		Position = UDim2.fromOffset(46, 4),
		Size = UDim2.new(1, -56, 0, 20),
		Text = player.DisplayName,
		Font = Theme.TitleFont,
		TextSize = 17,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local health = StatusBar.new(body, UDim2.fromOffset(46, 26), UDim2.new(1, -56, 0, 20), Theme.Health)
	local mana = StatusBar.new(body, UDim2.fromOffset(46, 48), UDim2.new(1, -56, 0, 13), Theme.Mana)
	health.setValue(100, 100)

	-- портрет + кольцо + бейдж уровня
	local portrait = Portrait.new(root, PORTRAIT_SIZE, UDim2.fromOffset(2, 7))
	portrait.frame.ZIndex = 4
	portraitRing(root, PORTRAIT_SIZE + 6, UDim2.fromOffset(-2, 3), 6)

	local badge = Theme.new("Frame", {
		Name = "LevelBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(20, 78),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(14, 16, 22),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, root)
	Theme.corner(badge, 26)
	Chrome.bevel(badge, 2, 26)
	local levelLabel = Chrome.label(badge, {
		Name = "Level",
		Size = UDim2.fromScale(1, 1),
		Text = "1",
		TextSize = 13,
		TextColor3 = Theme.GoldLight,
		ZIndex = 9,
	})

	local function refreshLevel()
		local level = player:GetAttribute("Level")
		levelLabel.Text = tostring(if type(level) == "number" then level else 1)
	end
	player:GetAttributeChangedSignal("Level"):Connect(refreshLevel)
	refreshLevel()

	-- мана
	local function refreshMana()
		local current = player:GetAttribute("Mana")
		local max = player:GetAttribute("MaxMana")
		mana.setValue(if type(current) == "number" then current else 0, if type(max) == "number" then max else 0)
	end
	player:GetAttributeChangedSignal("Mana"):Connect(refreshMana)
	player:GetAttributeChangedSignal("MaxMana"):Connect(refreshMana)
	refreshMana()

	-- здоровье: перепривязываемся к Humanoid при каждом респавне
	local healthConnections: { RBXScriptConnection } = {}
	local function bindCharacter(character: Model)
		for _, connection in healthConnections do
			connection:Disconnect()
		end
		table.clear(healthConnections)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local function refresh()
			health.setValue(humanoid.Health, humanoid.MaxHealth)
		end
		table.insert(healthConnections, humanoid.HealthChanged:Connect(refresh))
		table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh))
		refresh()
	end

	-- портрет строим, когда загрузилась внешность (иначе будет «голый» персонаж)
	player.CharacterAppearanceLoaded:Connect(function(character)
		portrait.setModel(character)
	end)
	player.CharacterAdded:Connect(function(character)
		task.spawn(bindCharacter, character)
		task.delay(
			1.5,
			function() -- запасной вариант, если событие внешности не придёт
				if player.Character == character then
					portrait.setModel(character)
				end
			end
		)
	end)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
		task.delay(0.5, function()
			if player.Character then
				portrait.setModel(player.Character)
			end
		end)
	end

	return { frame = root }
end

return PlayerFrame
