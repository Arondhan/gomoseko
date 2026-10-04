-- Окно «Инвентарь»: сетка 6x5 как сумка WoW — слоты-«гнёзда» с рамкой цвета качества у предметов, метка слота
-- у надетых колец и строка золота. Кольцо надевается ПКМ (в первый свободный слот; повторный ПКМ — снять)
-- или перетаскиванием на слот RingBar. Данные берутся из InventoryController (сервер — источник правды).

local UserInputService = game:GetService("UserInputService")

local Chrome = require(script.Parent.Chrome)
local Glyphs = require(script.Parent.Glyphs)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Inventory = {}

local CELLS = 30
local CELL_SIZE = 48
local DRAG_SIZE = 56

-- deps: { controller = InventoryController, ringBar = RingBar.build(...), tooltip = Tooltip.build(...) }
function Inventory.build(parent: Instance, deps: any)
	local controller = deps.controller
	local ringBar = deps.ringBar
	local tooltip = deps.tooltip

	local window = Window.new(parent, {
		name = "InventoryWindow",
		title = "Инвентарь",
		size = UDim2.fromOffset(384, 420),
		position = UDim2.new(0.5, -200, 0.45, 0),
	})

	local grid =
		Theme.new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1 }, window.body)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local cells = {}
	local cellBevels = {}
	for i = 1, CELLS do
		local cell, bevel = Chrome.slot(grid, UDim2.fromOffset(CELL_SIZE, CELL_SIZE), 5)
		cell.Name = "Cell" .. i
		cell.LayoutOrder = i
		cells[i] = cell
		cellBevels[i] = bevel
	end

	-- строка золота: монета + сумма
	local goldRow = Theme.new("Frame", {
		Name = "Gold",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
	}, window.body)
	Chrome.label(goldRow, {
		Size = UDim2.new(1, -30, 1, 0),
		Text = "0",
		Font = Theme.BoldFont,
		TextSize = 16,
		TextColor3 = Theme.Coin,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local coinHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
	}, goldRow)
	Glyphs.coin(coinHolder)

	-- перетаскивание кольца на слот RingBar
	local function startDrag(ring: any)
		local ghost = Theme.new("Frame", {
			Name = "DragGhost",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(DRAG_SIZE, DRAG_SIZE),
			BackgroundTransparency = 1,
			ZIndex = 200,
		}, parent)
		RingIcon.new(ghost, ring)

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
		for i, cell in cells do
			local old = cell:FindFirstChild("Item")
			if old then
				old:Destroy()
			end
			Chrome.tintBevel(cellBevels[i], nil)
		end
		tooltip.hide()

		for index, ring in controller.getItems() do
			local cell = cells[index]
			if not cell then
				break
			end
			Chrome.tintBevel(cellBevels[index], Theme.Quality[ring.Quality])
			local item = Theme.new("TextButton", {
				Name = "Item",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
			}, cell)
			RingIcon.new(item, ring)

			-- пометка «надето» (номер слота)
			local equippedSlot = controller.getSlotOf(ring.Id)
			if equippedSlot then
				Chrome.label(item, {
					Name = "Equipped",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -3, 1, -1),
					Size = UDim2.fromOffset(16, 14),
					Text = tostring(equippedSlot),
					TextSize = 13,
					TextColor3 = Theme.GoldLight,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 12,
				})
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
