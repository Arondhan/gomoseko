--!strict
-- Юнит-фрейм игрока слева сверху (как в WoW): имя, полоса здоровья и полоса маны.
-- Здоровье — из Humanoid персонажа, мана — из атрибутов Player "Mana"/"MaxMana" (их ведёт сервер).

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local StatusBar = require(script.Parent.StatusBar)

local PlayerFrame = {}

local HEALTH_COLOR = Color3.fromRGB(60, 180, 75)
local MANA_COLOR = Color3.fromRGB(50, 110, 230)

function PlayerFrame.build(parent: Instance)
	local player = Players.LocalPlayer

	local frame = Theme.new("Frame", {
		Name = "PlayerFrame",
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.fromOffset(250, 74),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.Gold, 1.5)

	Theme.new("TextLabel", {
		Name = "Name",
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Text = player.DisplayName,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)

	local health = StatusBar.new(frame, UDim2.fromOffset(10, 28), UDim2.new(1, -20, 0, 18), HEALTH_COLOR)
	local mana = StatusBar.new(frame, UDim2.fromOffset(10, 50), UDim2.new(1, -20, 0, 16), MANA_COLOR)
	health.setValue(100, 100)

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
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end

	return { frame = frame }
end

return PlayerFrame
