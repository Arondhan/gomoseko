-- Окно «Inventory»: сетка 6x5 как сумка WoW — слоты-«гнёзда» с рамкой цвета качества у предметов, метка слота
-- у надетых колец, счётчик ячеек и строка золота. Кольцо надевается ПКМ (в первый свободный слот; повторный ПКМ —
-- снять) или перетаскиванием на слот панели колец / окна персонажа (ui/Drag).
-- Данные берутся из InventoryController (сервер — источник правды).

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Drag = require(script.Parent.Drag)
local Glyphs = require(script.Parent.Glyphs)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Inventory = {}

local CELLS = 30
local CELL_SIZE = 48
local CELL_GAP = 6

-- deps: { controller = InventoryController, tooltip = Tooltip.build(...) }
function Inventory.build(parent: Instance, deps: any)
	local controller = deps.controller
	local tooltip = deps.tooltip
	local player = Players.LocalPlayer

	-- ширина: 6 ячеек + отступы окна; высота: заголовок + 5 рядов + строка золота
	local gridWidth = 6 * CELL_SIZE + 5 * CELL_GAP
	local gridHeight = 5 * CELL_SIZE + 4 * CELL_GAP
	local window = Window.new(parent, {
		name = "InventoryWindow",
		title = "Inventory",
		size = UDim2.fromOffset(gridWidth + 28, 42 + 12 + gridHeight + 8 + 28 + 14),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})

	local grid = Theme.new("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, gridHeight),
		BackgroundTransparency = 1,
	}, window.body)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
		CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
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
		local glow = Chrome.glow(cell, Theme.GoldLight, 2)
		cell.MouseEnter:Connect(function()
			Theme.tween(glow, 0.1, { Transparency = 0.55 })
		end)
		cell.MouseLeave:Connect(function()
			Theme.tween(glow, 0.1, { Transparency = 1 })
		end)
	end

	-- нижняя строка: счётчик ячеек слева, золото справа (монета + сумма)
	local footer = Theme.new("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
	}, window.body)
	local countLabel = Chrome.label(footer, {
		Size = UDim2.fromScale(0.5, 1),
		Text = "0 / " .. CELLS,
		TextSize = 16,
		TextColor3 = Theme.Muted,
		FontFace = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local goldLabel = Chrome.label(footer, {
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, -30, 1, 0),
		Text = "0",
		FontFace = Theme.Fonts.Numbers,
		TextSize = 18,
		TextColor3 = Theme.Coin,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local coinHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
	}, footer)
	Glyphs.coin(coinHolder)

	-- золото живёт в атрибуте Player.Gold (его ведёт сервер); пока атрибута нет — 0
	local function refreshGold()
		local gold = player:GetAttribute("Gold")
		goldLabel.Text = tostring(if type(gold) == "number" then gold else 0)
	end
	player:GetAttributeChangedSignal("Gold"):Connect(refreshGold)
	refreshGold()

	-- перетаскивание кольца на слот (панель колец или окно персонажа)
	local function startDrag(ring: any)
		Drag.start(parent, ring, function(slot)
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

		local items = controller.getItems()
		countLabel.Text = #items .. " / " .. CELLS
		for index, ring in items do
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
					Size = UDim2.fromOffset(16, 20),
					Text = tostring(equippedSlot),
					TextSize = 15,
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
			Drag.makeSource(item, function()
				return ring
			end, function()
				tooltip.hide()
				startDrag(ring)
			end)
		end
	end

	controller.changed.Event:Connect(refresh)
	refresh()

	return window
end

return Inventory
