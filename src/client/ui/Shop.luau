-- Окно «Магазин»: список строк-заглушек. Покупок пока нет.

local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Shop = {}

local ROWS = 6

function Shop.build(parent: Instance)
	local window = Window.new(parent, {
		name = "ShopWindow",
		title = "Магазин",
		size = UDim2.fromOffset(380, 420),
		position = UDim2.new(0.5, 200, 0.45, 0),
	})

	local list = Theme.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window.body)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	for i = 1, ROWS do
		local row = Theme.new("Frame", {
			Name = "Item" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 54),
			BackgroundColor3 = Theme.Inset,
			BorderSizePixel = 0,
		}, list)
		Theme.corner(row, 6)
		Theme.stroke(row, Theme.GoldDim, 1)

		local icon = Theme.new("Frame", {
			Name = "Icon",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(42, 42),
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
		}, row)
		Theme.corner(icon, 5)
		Theme.stroke(icon, Theme.GoldDim, 1)

		Theme.new("TextLabel", {
			Name = "Name",
			Position = UDim2.fromOffset(58, 8),
			Size = UDim2.new(1, -150, 0, 20),
			BackgroundTransparency = 1,
			Text = "Товар №" .. i,
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		Theme.new("TextLabel", {
			Name = "Sub",
			Position = UDim2.fromOffset(58, 28),
			Size = UDim2.new(1, -150, 0, 18),
			BackgroundTransparency = 1,
			Text = "Скоро в продаже",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		Theme.new("TextLabel", {
			Name = "Price",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(80, 24),
			BackgroundTransparency = 1,
			Text = "— з.",
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Theme.Coin,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
	end

	return window
end

return Shop
