-- Меню справа внизу: кнопки «Инвентарь» (I) и «Магазин» (B) + подсказка.

local Theme = require(script.Parent.Theme)

local MicroMenu = {}

-- пиктограмма рюкзака из рамок
local function drawBag(button: Frame)
	local body = Theme.new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(176, 120, 60),
		BorderSizePixel = 0,
	}, button)
	Theme.corner(body, 5)
	Theme.new("Frame", {
		Name = "Pocket",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromOffset(12, 7),
		BackgroundColor3 = Color3.fromRGB(120, 78, 38),
		BorderSizePixel = 0,
	}, body)
	local strap = Theme.new("Frame", {
		Name = "Strap",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromOffset(10, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, body)
	Theme.corner(strap, 4)
	Theme.stroke(strap, Color3.fromRGB(176, 120, 60), 2)
end

-- пиктограмма монеты
local function drawCoin(button: Frame)
	local coin = Theme.new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Coin,
		BorderSizePixel = 0,
	}, button)
	Theme.corner(coin, 10)
	Theme.stroke(coin, Color3.fromRGB(170, 130, 30), 2)
	local inner = Theme.new("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, coin)
	Theme.corner(inner, 5)
	Theme.stroke(inner, Color3.fromRGB(170, 130, 30), 2)
end

function MicroMenu.build(parent: Instance)
	local menu = Theme.new("Frame", {
		Name = "MicroMenu",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(92, 52),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(menu, 8)
	Theme.stroke(menu, Theme.Gold, 1.5)

	local row = Theme.new("Frame", { Name = "Buttons", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, menu)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)

	local tooltip = Theme.new("Frame", {
		Name = "Tooltip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -76),
		Size = UDim2.fromOffset(140, 28),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	}, parent)
	Theme.corner(tooltip, 6)
	Theme.stroke(tooltip, Theme.Gold, 1)
	local tipLabel = Theme.new("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Theme.Text,
		ZIndex = 21,
	}, tooltip)

	local function addButton(name: string, order: number, hotkey: string, tip: string, draw: (Frame) -> ())
		local frame = Theme.new("Frame", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = Theme.Inset,
			BorderSizePixel = 0,
		}, row)
		Theme.corner(frame, 6)
		local stroke = Theme.stroke(frame, Theme.GoldDim, 1.5)
		draw(frame)
		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		}, frame)

		local button = { frame = frame, active = false, hotkey = hotkey, click = Instance.new("BindableEvent") }

		function button.setActive(active: boolean)
			button.active = active
			Theme.tween(stroke, 0.12, { Color = active and Theme.GoldBright or Theme.GoldDim })
		end

		hit.MouseEnter:Connect(function()
			Theme.tween(stroke, 0.12, { Color = Theme.GoldBright })
			tipLabel.Text = tip .. " (" .. hotkey .. ")"
			tooltip.Visible = true
		end)
		hit.MouseLeave:Connect(function()
			if not button.active then
				Theme.tween(stroke, 0.12, { Color = Theme.GoldDim })
			end
			tooltip.Visible = false
		end)
		hit.MouseButton1Click:Connect(function()
			button.click:Fire()
		end)
		return button
	end

	return {
		frame = menu,
		inventory = addButton("InventoryButton", 1, "I", "Инвентарь", drawBag),
		shop = addButton("ShopButton", 2, "B", "Магазин", drawCoin),
	}
end

return MicroMenu
