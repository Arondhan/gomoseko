--!strict
-- Процедурные пиктограммы для кнопок меню (без картинок): рюкзак, монета.
-- Каждая функция рисует иконку по центру родителя (кнопка ~38 px).

local Theme = require(script.Parent.Theme)

local Glyphs = {}

local function shaded(frame: GuiObject, from: Color3, to: Color3)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Theme.gradient(frame, 90, from, to)
end

-- Рюкзак: корпус с градиентом, клапан, карман, ремешок и пряжка
function Glyphs.bag(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local holder = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)

	local strap = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, holder)
	Theme.corner(strap, 6)
	Theme.new("UIStroke", { Color = Color3.fromRGB(120, 78, 38), Thickness = 2.5 }, strap)

	local body = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(24, 19),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(body, 7)
	shaded(body, Color3.fromRGB(214, 150, 80), Color3.fromRGB(128, 80, 36))
	Theme.new("UIStroke", { Color = Color3.fromRGB(60, 36, 14), Thickness = 1.5 }, body)

	local flap = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 7),
		BorderSizePixel = 0,
		ZIndex = z + 2,
	}, body)
	Theme.corner(flap, 6)
	shaded(flap, Color3.fromRGB(150, 98, 46), Color3.fromRGB(100, 62, 28))

	local pocket = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(15, 8),
		BorderSizePixel = 0,
		ZIndex = z + 2,
	}, body)
	Theme.corner(pocket, 3)
	shaded(pocket, Color3.fromRGB(150, 98, 46), Color3.fromRGB(96, 58, 26))

	-- золотая пряжка
	local buckle = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.fromOffset(5, 5),
		BorderSizePixel = 0,
		ZIndex = z + 3,
	}, body)
	Theme.corner(buckle, 2)
	shaded(buckle, Theme.GoldLight, Theme.GoldDark)
end

-- Монета: золотой диск с градиентом, ободок и вдавленный центр
function Glyphs.coin(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local coin = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Theme.corner(coin, 12)
	shaded(coin, Theme.GoldLight, Color3.fromRGB(176, 128, 36))
	Theme.new("UIStroke", { Color = Color3.fromRGB(110, 74, 16), Thickness = 2 }, coin)

	local inner = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, coin)
	Theme.corner(inner, 7)
	shaded(inner, Color3.fromRGB(176, 128, 36), Theme.GoldLight)
	Theme.new("UIStroke", { Color = Color3.fromRGB(110, 74, 16), Thickness = 1.5 }, inner)
end

return Glyphs
