-- Окно «Инвентарь»: пустая сетка 6x5 и строка золота. Данных пока нет.

local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Inventory = {}

local CELLS = 30

function Inventory.build(parent: Instance)
	local window = Window.new(parent, {
		name = "InventoryWindow",
		title = "Инвентарь",
		size = UDim2.fromOffset(372, 410),
		position = UDim2.new(0.5, -200, 0.45, 0),
	})

	local grid = Theme.new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1 }, window.body)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(48, 48),
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i = 1, CELLS do
		local cell = Theme.new("Frame", {
			Name = "Cell" .. i,
			LayoutOrder = i,
			BackgroundColor3 = Theme.Inset,
			BorderSizePixel = 0,
		}, grid)
		Theme.corner(cell, 5)
		Theme.stroke(cell, Theme.GoldDim, 1)
	end

	Theme.new("TextLabel", {
		Name = "Gold",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "Золото: 0",
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = Theme.Coin,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, window.body)

	return window
end

return Inventory
