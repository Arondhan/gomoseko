-- Сетка колец игрока (встраивается в окно Rings): слоты-«гнёзда» с рамкой цвета качества, метка слота у надетых
-- колец, счётчик ячеек и строка золота. Тап/клик по кольцу надевает его (повторный — снимает), кольцо можно и
-- перетащить на слот (ui/Drag). Данные берутся из InventoryController (сервер — источник правды).

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Drag = require(script.Parent.Drag)
local Glyphs = require(script.Parent.Glyphs)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)

local Inventory = {}

local CELLS = 28
local CELL_SIZE = 52
local CELL_GAP = 6

-- parent — ScreenGui (для «призрака» при переносе), container — Frame внутри окна Rings,
-- deps: { controller = InventoryController, tooltip = Tooltip.build(...) }
function Inventory.build(parent: Instance, container: GuiObject, deps: any)
	local controller = deps.controller
	local tooltip = deps.tooltip
	local player = Players.LocalPlayer

	-- ряды сетки; нижняя строка (ячейки + золото) — 28 px
	local gridHeight = 4 * CELL_SIZE + 3 * CELL_GAP
	local lastDragAt = 0 -- момент последнего переноса: клик сразу после переноса не должен надевать кольцо

	local grid = Theme.new("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, gridHeight),
		BackgroundTransparency = 1,
	}, container)
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
	}, container)
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
			lastDragAt = os.clock()
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
			item.MouseButton1Click:Connect(function()
				if os.clock() - lastDragAt > 0.3 then
					equipOrUnequip(ring)
				end
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
end

return Inventory
