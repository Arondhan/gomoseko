--!strict
-- Компактный блок игрока слева сверху: уровень и имя, полосы здоровья и маны.
-- Здоровье — из Humanoid персонажа, мана и уровень — из атрибутов Player (их ведёт сервер).

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local StatusBar = require(script.Parent.StatusBar)
local Theme = require(script.Parent.Theme)

local PlayerFrame = {}

function PlayerFrame.build(parent: Instance)
	local player = Players.LocalPlayer

	-- компактный блок слева сверху: «Lv 5  Имя», полоса здоровья и полоса маны (без портрета и рамок)
	local root = Theme.new("Frame", {
		Name = "PlayerFrame",
		Position = UDim2.fromOffset(16, 56), -- ниже верхней панели Roblox (иконки меню/чата)
		Size = UDim2.fromOffset(260, 96),
		BackgroundTransparency = 1,
	}, parent)

	local nameLabel = Chrome.label(root, {
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 28),
		Text = player.DisplayName,
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Header,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local health = StatusBar.new(root, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 30), Theme.Health)
	local mana = StatusBar.new(root, UDim2.fromOffset(0, 64), UDim2.new(1, 0, 0, 22), Theme.Mana)
	health.setValue(100, 100)

	local function refreshLevel()
		local level = player:GetAttribute("Level")
		nameLabel.Text = string.format("Lv %d  %s", if type(level) == "number" then level else 1, player.DisplayName)
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

	player.CharacterAdded:Connect(function(character)
		task.spawn(bindCharacter, character)
	end)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end

	return { frame = root }
end

return PlayerFrame
