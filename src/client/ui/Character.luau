--!strict
-- Окно «Character» (как в WoW): модель персонажа, 4 слота колец по бокам и список характеристик.
-- Слоты те же, что на панели колец (общее состояние InventoryController): кольца можно перетаскивать из инвентаря,
-- между слотами (обмен) и «в никуда» (снять); ПКМ по слоту снимает кольцо.

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Drag = require(script.Parent.Drag)
local ModelView = require(script.Parent.ModelView)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Character = {}

local SLOT_COUNT = 4
local SLOT_SIZE = 56

type Slot = {
	frame: Frame,
	bevel: UIStroke,
	glow: UIStroke,
	icon: Frame?,
	empty: Frame,
	hovered: boolean,
	dropTarget: boolean,
}

-- Строки характеристик: label, функция значения (nil — строка скрыта). Бонусы колец приходят атрибутами Player.
local function number(player: Player, name: string): number?
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

-- deps: { controller = InventoryController, tooltip = Tooltip, gui = ScreenGui, startDrag = (ring, fromSlot) -> () }
function Character.build(parent: Instance, deps: any)
	local controller = deps.controller
	local tooltip = deps.tooltip
	local player = Players.LocalPlayer

	local window = Window.new(parent, {
		name = "CharacterWindow",
		title = "Character",
		size = UDim2.fromOffset(420, 540),
		position = UDim2.new(0.26, 0, 0.47, 0),
	})
	local body = window.body

	-- модель персонажа по центру
	local view = ModelView.new(body, UDim2.fromOffset(196, 290), UDim2.new(0.5, -98, 0, 0))
	Chrome.bevel(view.frame, 2, 8, true)

	Chrome.label(body, {
		Position = UDim2.new(0.5, -98, 0, 292),
		Size = UDim2.fromOffset(196, 18),
		Text = "Drag to rotate",
		TextSize = 13,
		TextColor3 = Theme.Muted,
		FontFace = Theme.Fonts.Body,
	})

	-- слоты: 1-2 слева, 3-4 справа
	local slots: { Slot } = {}
	local function slotPosition(i: number): UDim2
		local row = (i - 1) % 2
		local y = 56 + row * 84
		if i <= 2 then
			return UDim2.fromOffset(6, y)
		end
		return UDim2.new(1, -(SLOT_SIZE + 6), 0, y)
	end

	local function refreshGlow(slot: Slot)
		local target = if slot.dropTarget then 0.05 elseif slot.hovered then 0.45 else 1
		Theme.tween(slot.glow, 0.12, { Transparency = target })
	end

	for i = 1, SLOT_COUNT do
		local frame, bevel = Chrome.slot(body, UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE), 6)
		frame.Name = "RingSlot" .. i
		frame.Position = slotPosition(i)
		local glow = Chrome.glow(frame, Theme.GoldLight, 3)

		local empty = Theme.new("Frame", {
			Name = "EmptyMark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.46, 0.46),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, frame)
		Theme.corner(empty, 999)
		Theme.new("UIStroke", { Color = Color3.fromRGB(80, 80, 96), Thickness = 3, Transparency = 0.6 }, empty)

		Chrome.label(frame, {
			Position = UDim2.fromOffset(5, 2),
			Size = UDim2.fromOffset(16, 19),
			Text = tostring(i),
			TextSize = 14,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
		})
		Chrome.label(body, {
			Position = slotPosition(i) + UDim2.fromOffset(0, SLOT_SIZE + 2),
			Size = UDim2.fromOffset(SLOT_SIZE, 18),
			Text = "Ring " .. i,
			TextSize = 13,
			TextColor3 = Theme.Muted,
			FontFace = Theme.Fonts.Body,
		})

		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 30,
		}, frame)

		local slot: Slot = {
			frame = frame,
			bevel = bevel,
			glow = glow,
			icon = nil,
			empty = empty,
			hovered = false,
			dropTarget = false,
		}
		slots[i] = slot

		hit.MouseEnter:Connect(function()
			slot.hovered = true
			glow.Color = Theme.GoldLight
			refreshGlow(slot)
			local ring = controller.getRingInSlot(i)
			if ring then
				tooltip.showRing(ring)
			end
		end)
		hit.MouseLeave:Connect(function()
			slot.hovered = false
			refreshGlow(slot)
			tooltip.hide()
		end)
		hit.MouseButton2Click:Connect(function()
			controller.unequip(i)
		end)
		Drag.makeSource(hit, function()
			return controller.getRingInSlot(i)
		end, function(ring)
			tooltip.hide()
			deps.startDrag(ring, i)
		end)
	end

	local function setSlot(i: number, ring: RingIcon.Def?)
		local slot = slots[i]
		if not slot then
			return
		end
		if slot.icon then
			slot.icon:Destroy()
			slot.icon = nil
		end
		slot.empty.Visible = ring == nil
		if ring then
			slot.icon = RingIcon.new(slot.frame, ring)
			Chrome.tintBevel(slot.bevel, Theme.Quality[ring.Quality or "Common"])
		else
			Chrome.tintBevel(slot.bevel, nil)
		end
	end

	local function getSlotAtPosition(position: Vector2): number?
		if not window.isOpen then
			return nil
		end
		for i, slot in slots do
			local pos, size = slot.frame.AbsolutePosition, slot.frame.AbsoluteSize
			if
				position.X >= pos.X
				and position.X <= pos.X + size.X
				and position.Y >= pos.Y
				and position.Y <= pos.Y + size.Y
			then
				return i
			end
		end
		return nil
	end

	local function highlightSlot(index: number?)
		for i, slot in slots do
			local isTarget = i == index
			if slot.dropTarget ~= isTarget then
				slot.dropTarget = isTarget
				slot.glow.Color = Theme.GoldLight
				refreshGlow(slot)
			end
		end
	end

	-- характеристики
	local statsPanel = Chrome.panel(body, {
		Name = "Stats",
		Position = UDim2.fromOffset(0, 312),
		Size = UDim2.new(1, 0, 1, -312),
	}, 8)
	local list = Theme.new("Frame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, statsPanel)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 6),
	}, list)
	Theme.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, list)

	type Row = { label: string, get: () -> string?, left: TextLabel, right: TextLabel, holder: Frame }
	local rows: { Row } = {}
	local function addRow(label: string, get: () -> string?)
		local holder = Theme.new("Frame", {
			LayoutOrder = #rows + 1,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, list)
		local left = Chrome.label(holder, {
			Size = UDim2.fromScale(0.5, 1),
			Text = label,
			TextSize = 15,
			FontFace = Theme.Fonts.Body,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		local right = Chrome.label(holder, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),
			Text = "",
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
		})
		table.insert(rows, { label = label, get = get, left = left, right = right, holder = holder })
	end

	local function percent(name: string, sign: boolean?): () -> string?
		return function()
			local value = number(player, name)
			if value == nil or value == 0 then
				return nil
			end
			return string.format(if sign then "%+g%%" else "%g%%", value)
		end
	end

	addRow("Level", function()
		return tostring(number(player, "Level") or 1)
	end)
	addRow("Health", function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		return if humanoid then string.format("%d / %d", humanoid.Health, humanoid.MaxHealth) else "—"
	end)
	addRow("Mana", function()
		return string.format("%d / %d", number(player, "Mana") or 0, number(player, "MaxMana") or 0)
	end)
	addRow("Experience", function()
		return string.format("%d / %d", number(player, "XP") or 0, number(player, "XPToNext") or 0)
	end)
	-- бонусы колец (выставляются сервером; строка скрыта, пока бонуса нет)
	addRow("Damage", percent("Bonus_DamagePct", true))
	addRow("Cooldown", function()
		local value = number(player, "Bonus_CooldownReductionPct")
		return if value and value ~= 0 then string.format("-%g%%", value) else nil
	end)
	addRow("Mana regen", function()
		local value = number(player, "Bonus_ManaRegen")
		return if value and value ~= 0 then string.format("%+g / s", value) else nil
	end)
	addRow("Luck", percent("Bonus_LuckPct", true))

	local function refreshStats()
		for _, row in rows do
			local text = row.get()
			row.holder.Visible = text ~= nil
			row.right.Text = text or ""
		end
	end

	for _, name in
		{
			"Level",
			"XP",
			"XPToNext",
			"Mana",
			"MaxMana",
			"Bonus_DamagePct",
			"Bonus_CooldownReductionPct",
			"Bonus_ManaRegen",
			"Bonus_LuckPct",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end

	-- модель: строим при открытии окна (внешность к тому времени загружена) и при респавне
	local healthConnection: RBXScriptConnection? = nil
	local function bindCharacter(character: Model)
		view.setModel(character)
		if healthConnection then
			healthConnection:Disconnect()
			healthConnection = nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			healthConnection = humanoid.HealthChanged:Connect(refreshStats)
		end
		refreshStats()
	end
	window.changed.Event:Connect(function(open: boolean)
		if open then
			if player.Character then
				bindCharacter(player.Character)
			end
			refreshStats()
		end
	end)
	player.CharacterAppearanceLoaded:Connect(function(character)
		if window.isOpen then
			bindCharacter(character)
		end
	end)
	refreshStats()

	return {
		window = window,
		slotCount = SLOT_COUNT,
		setSlot = setSlot,
		getSlotAtPosition = getSlotAtPosition,
		highlightSlot = highlightSlot,
	}
end

return Character
