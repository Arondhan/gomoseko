-- Панель из 4 слотов для колец (внизу по центру): иконка надетого кольца, оверлей кулдауна,
-- подсказка при наведении. Логики здесь нет — действия уходят наружу через hooks (см. Main.client).

local Theme = require(script.Parent.Theme)
local RingIcon = require(script.Parent.RingIcon)

local RingBar = {}

local SLOT_COUNT = 4

-- hooks (все необязательные):
--   onActivate(slot)  — ЛКМ по слоту (применить кольцо)
--   onUnequip(slot)   — ПКМ по слоту (снять кольцо)
--   onHover(slot?)    — курсор над слотом / ушёл (nil)
function RingBar.build(
	parent: Instance,
	hooks: {
		onActivate: ((slot: number) -> ())?,
		onUnequip: ((slot: number) -> ())?,
		onHover: ((slot: number?) -> ())?,
	}?
)
	local callbacks = hooks or {}
	local bar = Theme.new("Frame", {
		Name = "RingBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(268, 76),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(bar, 8)
	Theme.stroke(bar, Theme.Gold, 1.5)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, bar)

	local list = Theme.new("Frame", { Name = "Slots", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bar)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, list)

	local slots = {}

	local function press(i: number)
		local slot = slots[i]
		if not slot then
			return
		end
		slot.stroke.Color = Theme.GoldBright
		slot.scale.Scale = 0.92
		Theme.tween(slot.scale, 0.15, { Scale = 1 })
		task.delay(0.15, function()
			Theme.tween(slot.stroke, 0.2, { Color = Theme.GoldDim })
		end)
	end

	for i = 1, SLOT_COUNT do
		local frame = Theme.new("Frame", {
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Theme.Inset,
			BorderSizePixel = 0,
		}, list)
		Theme.corner(frame, 6)
		local stroke = Theme.stroke(frame, Theme.GoldDim, 1.5)
		local scale = Theme.new("UIScale", { Name = "Scale", Scale = 1 }, frame)
		Theme.new("ImageLabel", {
			Name = "Icon",
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Image = "",
		}, frame)
		Theme.new("TextLabel", {
			Name = "Key",
			Size = UDim2.fromOffset(16, 14),
			Position = UDim2.fromOffset(4, 2),
			BackgroundTransparency = 1,
			Text = tostring(i),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}, frame)
		local cooldownOverlay = Theme.new("Frame", {
			Name = "Cooldown",
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 3,
		}, frame)
		Theme.corner(cooldownOverlay, 6)
		local cooldownText = Theme.new("TextLabel", {
			Name = "CooldownText",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.4,
			ZIndex = 4,
		}, frame)
		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		}, frame)

		slots[i] = {
			frame = frame,
			stroke = stroke,
			scale = scale,
			icon = nil,
			overlay = cooldownOverlay,
			cooldownText = cooldownText,
		}

		hit.MouseEnter:Connect(function()
			Theme.tween(stroke, 0.12, { Color = Theme.GoldBright })
			if callbacks.onHover and slots[i].icon then
				callbacks.onHover(i)
			end
		end)
		hit.MouseLeave:Connect(function()
			Theme.tween(stroke, 0.12, { Color = Theme.GoldDim })
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
	end

	-- показать кольцо в слоте (nil — очистить слот)
	local function setSlot(i: number, ring: { Color: Color3 }?)
		local slot = slots[i]
		if not slot then
			return
		end
		if slot.icon then
			slot.icon:Destroy()
			slot.icon = nil
		end
		if ring then
			slot.icon = RingIcon.new(slot.frame, ring.Color)
		end
	end

	-- оверлей кулдауна: затемнение «стекает» вниз, по центру — секунды
	local function setCooldown(i: number, remaining: number, total: number)
		local slot = slots[i]
		if not slot then
			return
		end
		if remaining > 0 and total > 0 then
			slot.overlay.Visible = true
			slot.overlay.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
			slot.cooldownText.Text = if remaining >= 1
				then tostring(math.ceil(remaining))
				else string.format("%.1f", remaining)
		else
			slot.overlay.Visible = false
			slot.cooldownText.Text = ""
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
			slot.stroke.Color = if i == index then Theme.GoldBright else Theme.GoldDim
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
