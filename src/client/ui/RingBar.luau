--!strict
-- Панель из 4 слотов для колец (внизу по центру), как панель способностей WoW: объёмная золотая рамка
-- с ромбами по бокам, слоты-«гнёзда», рамка цвета качества у надетого кольца, радиальный кулдаун,
-- свечение при наведении и вспышка при нажатии. Логики здесь нет — действия уходят через hooks (см. Main.client).

local Chrome = require(script.Parent.Chrome)
local Drag = require(script.Parent.Drag)
local RadialCooldown = require(script.Parent.RadialCooldown)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)

local RingBar = {}

local SLOT_COUNT = 4
local SLOT_SIZE = 56
local SLOT_GAP = 8

type Slot = {
	frame: Frame,
	bevel: UIStroke,
	glow: UIStroke,
	scale: UIScale,
	emptyMark: Frame,
	cooldown: RadialCooldown.Radial,
	icon: Frame?,
	hovered: boolean,
	dropTarget: boolean,
}

-- hooks (все необязательные):
--   onActivate(slot)  — ЛКМ по слоту (применить кольцо)
--   onUnequip(slot)   — ПКМ по слоту (снять кольцо)
--   onHover(slot?)    — курсор над слотом / ушёл (nil)
export type Hooks = {
	onActivate: ((slot: number) -> ())?,
	onUnequip: ((slot: number) -> ())?,
	onHover: ((slot: number?) -> ())?,
	onDragStart: ((slot: number) -> ())?, -- зажали и потащили кольцо из слота
}

function RingBar.build(parent: Instance, hooks: Hooks?)
	local callbacks: Hooks = hooks or {}

	local bar = Chrome.panel(parent, {
		Name = "RingBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(300, 84),
	}, 10)
	-- ромбы-«грифоны» по бокам панели и по углам
	Chrome.diamond(bar, 16, UDim2.new(0, -4, 0.5, 0), 8)
	Chrome.diamond(bar, 16, UDim2.new(1, 4, 0.5, 0), 8)
	Chrome.diamond(bar, 8, UDim2.new(0, 6, 0, 6), 8)
	Chrome.diamond(bar, 8, UDim2.new(1, -6, 0, 6), 8)
	Chrome.diamond(bar, 8, UDim2.new(0, 6, 1, -6), 8)
	Chrome.diamond(bar, 8, UDim2.new(1, -6, 1, -6), 8)

	local list = Theme.new("Frame", { Name = "Slots", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bar)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, SLOT_GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, list)

	local slots: { Slot } = {}

	local function refreshGlow(slot: Slot)
		local target = if slot.dropTarget then 0.05 elseif slot.hovered then 0.45 else 1
		Theme.tween(slot.glow, 0.12, { Transparency = target })
	end

	local function press(i: number)
		local slot = slots[i]
		if not slot then
			return
		end
		slot.glow.Color = Theme.GoldLight
		slot.glow.Transparency = 0
		slot.scale.Scale = 0.92
		Theme.tween(slot.scale, 0.15, { Scale = 1 })
		task.delay(0.12, function()
			refreshGlow(slot)
		end)
	end

	for i = 1, SLOT_COUNT do
		local frame, bevel = Chrome.slot(list, UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE), 6)
		frame.Name = "Slot" .. i
		frame.LayoutOrder = i
		local scale = Theme.new("UIScale", { Name = "Scale", Scale = 1 }, frame)
		local glow = Chrome.glow(frame, Theme.GoldLight, 3)

		-- еле заметный силуэт кольца в пустом слоте
		local emptyMark = Theme.new("Frame", {
			Name = "EmptyMark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.46, 0.46),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, frame)
		Theme.corner(emptyMark, 999)
		Theme.new("UIStroke", { Color = Color3.fromRGB(80, 80, 96), Thickness = 3, Transparency = 0.6 }, emptyMark)

		Chrome.label(frame, {
			Name = "Key",
			Position = UDim2.fromOffset(5, 2),
			Size = UDim2.fromOffset(16, 14),
			Text = tostring(i),
			TextSize = 12,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
		})

		local cooldown = RadialCooldown.new(frame, 20)
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
			scale = scale,
			emptyMark = emptyMark,
			cooldown = cooldown,
			icon = nil,
			hovered = false,
			dropTarget = false,
		}
		slots[i] = slot

		hit.MouseEnter:Connect(function()
			slot.hovered = true
			glow.Color = Theme.GoldLight
			refreshGlow(slot)
			if callbacks.onHover and slot.icon then
				callbacks.onHover(i)
			end
		end)
		hit.MouseLeave:Connect(function()
			slot.hovered = false
			refreshGlow(slot)
			if callbacks.onHover then
				callbacks.onHover(nil)
			end
		end)
		hit.MouseButton1Click:Connect(function()
			press(i)
			if callbacks.onActivate then
				callbacks.onActivate(i)
			end
		end)
		hit.MouseButton2Click:Connect(function()
			if callbacks.onUnequip then
				callbacks.onUnequip(i)
			end
		end)
		-- перенос кольца из слота (обмен слотов / снять): сам перенос запускает Main через onDragStart
		Drag.makeSource(hit, function()
			return if slot.icon then true else nil
		end, function()
			if callbacks.onDragStart then
				callbacks.onDragStart(i)
			end
		end)
	end

	-- показать кольцо в слоте (nil — очистить слот)
	local function setSlot(i: number, ring: RingIcon.Def?)
		local slot = slots[i]
		if not slot then
			return
		end
		if slot.icon then
			slot.icon:Destroy()
			slot.icon = nil
		end
		slot.emptyMark.Visible = ring == nil
		if ring then
			slot.icon = RingIcon.new(slot.frame, ring)
			Chrome.tintBevel(slot.bevel, Theme.Quality[ring.Quality or "Common"])
		else
			Chrome.tintBevel(slot.bevel, nil)
		end
	end

	-- радиальный кулдаун слота
	local function setCooldown(i: number, remaining: number, total: number)
		local slot = slots[i]
		if slot then
			slot.cooldown.set(remaining, total)
		end
	end

	-- номер слота под экранной точкой (для drag-and-drop из инвентаря)
	local function getSlotAtPosition(position: Vector2): number?
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

	-- подсветка слота-приёмника во время перетаскивания (nil — убрать)
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

	return {
		frame = bar,
		slotCount = SLOT_COUNT,
		press = press,
		setSlot = setSlot,
		setCooldown = setCooldown,
		getSlotAtPosition = getSlotAtPosition,
		highlightSlot = highlightSlot,
	}
end

return RingBar
