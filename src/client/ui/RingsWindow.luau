--!strict
-- Окно «Rings» (вместо отдельных Character и Inventory): сверху 4 слота надетых колец, под ними строка бонусов,
-- ниже сетка всех колец игрока. Тап по кольцу в сетке — надеть (повторно — снять), тап по слоту — снять;
-- перетаскивание кольца на слот и между слотами остаётся как дополнение для ПК (ui/Drag).

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Drag = require(script.Parent.Drag)
local Inventory = require(script.Parent.Inventory)
local RingBadges = require(script.Parent.RingBadges)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local RingsWindow = {}

local SLOT_COUNT = 4
local SLOT_SIZE = 68

type Slot = {
	frame: Frame,
	bevel: UIStroke,
	glow: UIStroke,
	icon: Frame?,
	empty: Frame,
	badges: { update: () -> (), destroy: () -> () }?,
	hovered: boolean,
	dropTarget: boolean,
}

local function number(player: Player, name: string): number?
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

-- deps: { controller = InventoryController, tooltip = Tooltip, startDrag = (ring, fromSlot) -> (), notify = (text, color?) -> () }
function RingsWindow.build(parent: Instance, deps: any)
	local controller = deps.controller
	local tooltip = deps.tooltip
	local notify: (string, Color3?) -> () = deps.notify or function() end
	local player = Players.LocalPlayer

	local window = Window.new(parent, {
		name = "RingsWindow",
		title = "Rings",
		size = UDim2.fromOffset(470, 560),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	-- слоты надетых колец (по центру в ряд)
	local row = Theme.new("Frame", {
		Name = "Slots",
		Size = UDim2.new(1, 0, 0, SLOT_SIZE + 6),
		BackgroundTransparency = 1,
	}, body)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)

	local slots: { Slot } = {}
	local function refreshGlow(slot: Slot)
		local target = if slot.dropTarget then 0.05 elseif slot.hovered then 0.45 else 1
		Theme.tween(slot.glow, 0.12, { Transparency = target })
	end

	for i = 1, SLOT_COUNT do
		local frame, bevel = Chrome.slot(row, UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE), 12)
		frame.Name = "RingSlot" .. i
		frame.LayoutOrder = i
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
		Theme.new("UIStroke", { Color = Color3.fromRGB(150, 170, 230), Thickness = 3, Transparency = 0.6 }, empty)

		Chrome.label(frame, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(20, 22),
			Text = tostring(i),
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
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
			badges = nil,
			hovered = false,
			dropTarget = false,
		}
		slots[i] = slot

		local lastDragAt = 0
		hit.MouseEnter:Connect(function()
			slot.hovered = true
			glow.Color = Theme.GoldLight
			refreshGlow(slot)
			local ring = controller.getRingInSlot(i)
			if ring then
				tooltip.showRing(ring, controller.getLevel(ring.Id))
			end
		end)
		hit.MouseLeave:Connect(function()
			slot.hovered = false
			refreshGlow(slot)
			tooltip.hide()
		end)
		hit.MouseButton1Click:Connect(function()
			if os.clock() - lastDragAt > 0.3 then
				controller.unequip(i) -- тап по слоту снимает кольцо
			end
		end)
		hit.MouseButton2Click:Connect(function()
			controller.unequip(i)
		end)
		Drag.makeSource(hit, function()
			return controller.getRingInSlot(i)
		end, function(ring)
			tooltip.hide()
			lastDragAt = os.clock()
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
		if slot.badges then
			slot.badges.destroy()
			slot.badges = nil
		end
		slot.empty.Visible = ring == nil
		if ring then
			slot.icon = RingIcon.new(slot.frame, ring)
			slot.badges = RingBadges.add(slot.frame, ring, controller, notify)
			Chrome.tintBevel(slot.bevel, Theme.Quality[ring.Quality or "Common"])
		else
			Chrome.tintBevel(slot.bevel, nil)
		end
	end

	for _, name in { "Essence", "Gold" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			for _, slot in slots do
				if slot.badges then
					slot.badges.update()
				end
			end
		end)
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

	-- бонусы колец одной строкой (показываем только ненулевые)
	local statsLabel = Chrome.label(body, {
		Position = UDim2.fromOffset(0, SLOT_SIZE + 10),
		Size = UDim2.new(1, 0, 0, 46),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Good,
		TextWrapped = true,
	})
	Chrome.label(body, {
		Position = UDim2.fromOffset(0, SLOT_SIZE + 58),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Tap a ring to wear it. Tap a slot to take it off.",
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Muted,
	})

	local function refreshStats()
		local parts: { string } = {}
		local function add(label: string, value: number?, format: string)
			if value and value ~= 0 then
				table.insert(parts, label .. " " .. string.format(format, value))
			end
		end
		local totalDamage = number(player, "Bonus_DamagePct")
		if totalDamage and totalDamage ~= 0 then
			local fromLevel = number(player, "Bonus_LevelDamagePct") or 0
			table.insert(parts, string.format("Damage %+g%% (level %+g%%)", totalDamage, fromLevel))
		end
		add("Cooldown", -(number(player, "Bonus_CooldownReductionPct") or 0), "%+g%%")
		add("Mana regen", number(player, "Bonus_ManaRegen"), "%+g/s")
		add("Luck", number(player, "Bonus_LuckPct"), "%+g%%")
		statsLabel.Text = if #parts > 0 then table.concat(parts, "   ·   ") else "Wear rings to get bonuses"
	end
	for _, name in
		{ "Bonus_DamagePct", "Bonus_LevelDamagePct", "Bonus_CooldownReductionPct", "Bonus_ManaRegen", "Bonus_LuckPct" }
	do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	refreshStats()

	-- сетка всех колец
	local gridHolder = Theme.new("Frame", {
		Name = "GridHolder",
		Position = UDim2.fromOffset(0, SLOT_SIZE + 86),
		Size = UDim2.new(1, 0, 1, -(SLOT_SIZE + 86)),
		BackgroundTransparency = 1,
	}, body)
	Inventory.build(parent, gridHolder, { controller = controller, tooltip = tooltip, notify = notify })

	return {
		window = window,
		slotCount = SLOT_COUNT,
		setSlot = setSlot,
		getSlotAtPosition = getSlotAtPosition,
		highlightSlot = highlightSlot,
	}
end

return RingsWindow
