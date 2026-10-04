--!strict
-- Единое перетаскивание колец: из инвентаря в слот, из слота в слот (обмен), из слота «в никуда» (снять).
-- Цели (панель колец, окно персонажа) регистрируются через Drag.registerTarget; подсветка и поиск слота — их дело.

local UserInputService = game:GetService("UserInputService")

local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)

local Drag = {}

export type Target = {
	getSlotAtPosition: (position: Vector2) -> number?,
	highlight: (slot: number?) -> (),
}

local GHOST_SIZE = 56

local targets: { Target } = {}
local active = false

function Drag.registerTarget(target: Target)
	table.insert(targets, target)
end

function Drag.isDragging(): boolean
	return active
end

-- Слот под курсором среди всех целей (nil — ни один)
local function slotAt(position: Vector2): (Target?, number?)
	for _, target in targets do
		local slot = target.getSlotAtPosition(position)
		if slot then
			return target, slot
		end
	end
	return nil, nil
end

-- Начать перенос кольца. onDrop(slot) вызывается при отпускании: slot — номер слота-цели или nil, если отпустили
-- вне слотов. gui — ScreenGui, в котором рисуем «призрак».
function Drag.start(gui: Instance, ring: any, onDrop: (slot: number?) -> ())
	if active then
		return
	end
	active = true

	local ghost = Theme.new("Frame", {
		Name = "DragGhost",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(GHOST_SIZE, GHOST_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 200,
	}, gui)
	RingIcon.new(ghost, ring)

	local function place()
		local mouse = UserInputService:GetMouseLocation()
		ghost.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		local target, slot = slotAt(mouse)
		for _, t in targets do
			t.highlight(if t == target then slot else nil)
		end
	end
	place()

	local moveConnection: RBXScriptConnection
	local endConnection: RBXScriptConnection
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
		local _, slot = slotAt(UserInputService:GetMouseLocation())
		for _, t in targets do
			t.highlight(nil)
		end
		ghost:Destroy()
		active = false
		onDrop(slot)
	end)
end

-- Делает кнопку источником переноса: зажали ЛКМ и сдвинули курсор > 8 px — вызывается onStart(ring).
-- Обычный клик (без сдвига) не затрагивается. getRing возвращает кольцо в источнике или nil, если слот пуст.
function Drag.makeSource(button: GuiObject, getRing: () -> any?, onStart: (ring: any) -> ())
	local pressing = false
	local startPos = Vector2.zero
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = true
			startPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if pressing and not active and input.UserInputType == Enum.UserInputType.MouseMovement then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if (position - startPos).Magnitude > 8 then
				pressing = false
				local ring = getRing()
				if ring then
					onStart(ring)
				end
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = false
		end
	end)
end

return Drag
