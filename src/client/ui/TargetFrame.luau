--!strict
-- Фрейм цели (как в WoW): имя врага и его здоровье рядом с PlayerFrame. Скрыт, пока цели нет.
-- Управляется снаружи: setTarget(model) при смене цели (см. TargetController.changed).

local Theme = require(script.Parent.Theme)
local StatusBar = require(script.Parent.StatusBar)

local TargetFrame = {}

local ENEMY_NAME_COLOR = Color3.fromRGB(255, 100, 85)
local ENEMY_HEALTH_COLOR = Color3.fromRGB(200, 55, 45)

function TargetFrame.build(parent: Instance)
	local frame = Theme.new("Frame", {
		Name = "TargetFrame",
		Position = UDim2.fromOffset(282, 20),
		Size = UDim2.fromOffset(250, 56),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, parent)
	Theme.corner(frame, 8)
	Theme.stroke(frame, Color3.fromRGB(150, 50, 40), 1.5)

	local nameLabel = Theme.new("TextLabel", {
		Name = "Name",
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = ENEMY_NAME_COLOR,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	local health = StatusBar.new(frame, UDim2.fromOffset(10, 28), UDim2.new(1, -20, 0, 18), ENEMY_HEALTH_COLOR)

	local connections: { RBXScriptConnection } = {}
	local function disconnectAll()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function setTarget(model: Model?)
		disconnectAll()
		local found = model and model:FindFirstChildOfClass("Humanoid")
		if not (model and found) then
			frame.Visible = false
			return
		end
		local humanoid: Humanoid = found
		nameLabel.Text = if humanoid.DisplayName ~= "" then humanoid.DisplayName else model.Name
		local function refresh()
			health.setValue(humanoid.Health, humanoid.MaxHealth)
		end
		table.insert(connections, humanoid.HealthChanged:Connect(refresh))
		refresh()
		frame.Visible = true
	end

	return { frame = frame, setTarget = setTarget }
end

return TargetFrame
