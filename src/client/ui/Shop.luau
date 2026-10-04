-- Окно «Магазин»: список строк-заглушек в стиле WoW (панели с фаской и слотами под иконки). Покупок пока нет.

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Shop = {}

local ROWS = 6

function Shop.build(parent: Instance)
	local window = Window.new(parent, {
		name = "ShopWindow",
		title = "Store",
		size = UDim2.fromOffset(392, 430),
		position = UDim2.new(0.74, 0, 0.47, 0),
	})

	local list = Theme.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.GoldMid,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window.body)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	for i = 1, ROWS do
		local row = Chrome.panel(list, {
			Name = "Item" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, -10, 0, 58),
		}, 6)

		Chrome.slot(row, UDim2.fromOffset(42, 42), 5).Position = UDim2.fromOffset(8, 8)

		Chrome.label(row, {
			Name = "Name",
			Position = UDim2.fromOffset(60, 9),
			Size = UDim2.new(1, -160, 0, 20),
			Text = "Item #" .. i,
			FontFace = Theme.Fonts.Title,
			TextSize = 16,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Chrome.label(row, {
			Name = "Sub",
			Position = UDim2.fromOffset(60, 31),
			Size = UDim2.new(1, -160, 0, 18),
			Text = "Coming soon",
			FontFace = Theme.Fonts.Serif,
			TextSize = 14,
			TextColor3 = Theme.Muted,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Chrome.label(row, {
			Name = "Price",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(80, 24),
			Text = "— gold",
			TextSize = 15,
			TextColor3 = Theme.Coin,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	return window
end

return Shop
