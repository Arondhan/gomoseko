-- Панель из 4 слотов для колец (внизу по центру). Пока только UI-заглушка.

local Theme = require(script.Parent.Theme)

local RingBar = {}

local SLOT_COUNT = 4

function RingBar.build(parent: Instance)
	local bar = Theme.new("Frame", {
		Name = "RingBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(268, 76),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(bar, 8)
	Theme.stroke(bar, Theme.Gold, 1.5)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, bar)

	local list = Theme.new("Frame", { Name = "Slots", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bar)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, list)

	local slots = {}

	local function press(i: number)
		local slot = slots[i]
		if not slot then
			return
		end
		slot.stroke.Color = Theme.GoldBright
		slot.scale.Scale = 0.92
		Theme.tween(slot.scale, 0.15, { Scale = 1 })
		task.delay(0.15, function()
			Theme.tween(slot.stroke, 0.2, { Color = Theme.GoldDim })
		end)
	end

	for i = 1, SLOT_COUNT do
		local frame = Theme.new("Frame", {
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Theme.Inset,
			BorderSizePixel = 0,
		}, list)
		Theme.corner(frame, 6)
		local stroke = Theme.stroke(frame, Theme.GoldDim, 1.5)
		local scale = Theme.new("UIScale", { Name = "Scale", Scale = 1 }, frame)
		Theme.new("ImageLabel", {
			Name = "Icon",
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Image = "",
		}, frame)
		Theme.new("TextLabel", {
			Name = "Key",
			Size = UDim2.fromOffset(16, 14),
			Position = UDim2.fromOffset(4, 2),
			BackgroundTransparency = 1,
			Text = tostring(i),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, frame)
		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		}, frame)

		slots[i] = { frame = frame, stroke = stroke, scale = scale }

		hit.MouseEnter:Connect(function()
			Theme.tween(stroke, 0.12, { Color = Theme.GoldBright })
		end)
		hit.MouseLeave:Connect(function()
			Theme.tween(stroke, 0.12, { Color = Theme.GoldDim })
		end)
		hit.MouseButton1Click:Connect(function()
			press(i)
		end)
	end

	return { frame = bar, slotCount = SLOT_COUNT, press = press }
end

return RingBar
