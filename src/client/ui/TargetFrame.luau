--!strict
-- Фрейм цели (как в WoW): панель с именем и здоровьем врага, круглый портрет справа в красноватом свечении.
-- Скрыт, пока цели нет. Управляется снаружи: setTarget(model) при смене цели (см. TargetController.changed).

local Chrome = require(script.Parent.Chrome)
local Portrait = require(script.Parent.Portrait)
local StatusBar = require(script.Parent.StatusBar)
local Theme = require(script.Parent.Theme)

local TargetFrame = {}

local PORTRAIT_SIZE = 78

function TargetFrame.build(parent: Instance)
	local root = Theme.new("Frame", {
		Name = "TargetFrame",
		Position = UDim2.fromOffset(340, 64),
		Size = UDim2.fromOffset(300, 92),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local scale = Theme.new("UIScale", { Scale = 1 }, root)

	local body = Chrome.panel(root, {
		Name = "Body",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.fromOffset(254, 66),
	}, 8)
	Chrome.glow(body, Theme.Enemy, 2).Transparency = 0.55

	local nameLabel = Chrome.label(body, {
		Name = "Name",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -66, 0, 20),
		Font = Theme.TitleFont,
		TextSize = 17,
		TextColor3 = Theme.EnemyName,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local health = StatusBar.new(body, UDim2.fromOffset(10, 28), UDim2.new(1, -66, 0, 26), Theme.Enemy)

	-- портрет справа
	local portrait = Portrait.new(root, PORTRAIT_SIZE, UDim2.fromOffset(218, 7))
	portrait.frame.ZIndex = 4
	local ring = Theme.new("Frame", {
		Name = "PortraitRing",
		Position = UDim2.fromOffset(214, 3),
		Size = UDim2.fromOffset(PORTRAIT_SIZE + 6, PORTRAIT_SIZE + 6),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, root)
	Theme.corner(ring, PORTRAIT_SIZE + 6)
	Chrome.bevel(ring, 3, PORTRAIT_SIZE + 6)

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
			root.Visible = false
			portrait.setModel(nil)
			return
		end
		local humanoid: Humanoid = found
		nameLabel.Text = if humanoid.DisplayName ~= "" then humanoid.DisplayName else model.Name
		local function refresh()
			health.setValue(humanoid.Health, humanoid.MaxHealth)
		end
		table.insert(connections, humanoid.HealthChanged:Connect(refresh))
		refresh()
		portrait.setModel(model)

		-- небольшой «выскок» при появлении
		scale.Scale = 0.92
		root.Visible = true
		Theme.tween(scale, 0.15, { Scale = 1 })
	end

	return { frame = root, setTarget = setTarget }
end

return TargetFrame
