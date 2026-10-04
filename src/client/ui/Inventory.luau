-- Окно «Инвентарь»: сетка 6x5 со всеми предметами игрока (кольца) и строка золота.
-- Кольцо можно надеть: ПКМ (в первый свободный слот; если надето — снять) или перетащить на слот RingBar.
-- Данные берутся из InventoryController (сервер — источник правды), здесь только отрисовка и ввод.

local UserInputService = game:GetService("UserInputService")

local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Inventory = {}

local CELLS = 30
local DRAG_SIZE = 52

-- deps: { controller = InventoryController, ringBar = RingBar.build(...), tooltip = Tooltip.build(...) }
function Inventory.build(parent: Instance, deps: any)
	local controller = deps.controller
	local ringBar = deps.ringBar
	local tooltip = deps.tooltip

	local window = Window.new(parent, {
		name = "InventoryWindow",
		title = "Инвентарь",
		size = UDim2.fromOffset(372, 410),
		position = UDim2.new(0.5, -200, 0.45, 0),
	})

	local grid =
		Theme.new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1 }, window.body)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(48, 48),
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local cells = {}
	for i = 1, CELLS do
		local cell = Theme.new("Frame", {
			Name = "Cell" .. i,
			LayoutOrder = i,
			BackgroundColor3 = Theme.Inset,
			BorderSizePixel = 0,
		}, grid)
		Theme.corner(cell, 5)
		Theme.stroke(cell, Theme.GoldDim, 1)
		cells[i] = cell
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

	-- перетаскивание кольца на слот RingBar
	local function startDrag(ring: any)
		local ghost = Theme.new("Frame", {
			Name = "DragGhost",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(DRAG_SIZE, DRAG_SIZE),
			BackgroundTransparency = 1,
			ZIndex = 200,
		}, parent)
		RingIcon.new(ghost, ring.Color)

		local function place()
			local mouse = UserInputService:GetMouseLocation()
			ghost.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			ringBar.highlightSlot(ringBar.getSlotAtPosition(mouse))
		end
		place()

		local moveConnection, endConnection
		moveConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				place()
			end
		end)
		endConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			moveConnection:Disconnect()
			endConnection:Disconnect()
			local slot = ringBar.getSlotAtPosition(UserInputService:GetMouseLocation())
			ringBar.highlightSlot(nil)
			ghost:Destroy()
			if slot then
				controller.equip(ring.Id, slot)
			end
		end)
	end

	local function equipOrUnequip(ring: any)
		local current = controller.getSlotOf(ring.Id)
		if current then
			controller.unequip(current)
		else
			controller.equip(ring.Id, controller.firstFreeSlot() or 1)
		end
	end

	-- перерисовка предметов по состоянию контроллера
	local function refresh()
		for _, cell in cells do
			local old = cell:FindFirstChild("Item")
			if old then
				old:Destroy()
			end
		end
		tooltip.hide()

		for index, ring in controller.getItems() do
			local cell = cells[index]
			if not cell then
				break
			end
			local item = Theme.new("TextButton", {
				Name = "Item",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
			}, cell)
			RingIcon.new(item, ring.Color)

			-- пометка «надето» (номер слота)
			local equippedSlot = controller.getSlotOf(ring.Id)
			if equippedSlot then
				Theme.new("TextLabel", {
					Name = "Equipped",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -3, 1, -2),
					Size = UDim2.fromOffset(16, 14),
					BackgroundTransparency = 1,
					Text = tostring(equippedSlot),
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = Theme.GoldBright,
					TextStrokeTransparency = 0.4,
					ZIndex = 3,
				}, item)
			end

			item.MouseEnter:Connect(function()
				tooltip.showRing(ring)
			end)
			item.MouseLeave:Connect(function()
				tooltip.hide()
			end)
			item.MouseButton2Click:Connect(function()
				equipOrUnequip(ring)
			end)
			item.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					tooltip.hide()
					startDrag(ring)
				end
			end)
		end
	end

	controller.changed.Event:Connect(refresh)
	refresh()

	return window
end

return Inventory
