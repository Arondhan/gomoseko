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

-- Персонаж: голова, плечи и торс (силуэт как на кнопке Character в WoW)
function Glyphs.character(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local holder = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)

	local shoulders = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(24, 13),
		BorderSizePixel = 0,
		ZIndex = z,
	}, holder)
	Theme.corner(shoulders, 8)
	shaded(shoulders, Color3.fromRGB(176, 150, 110), Color3.fromRGB(104, 84, 56))
	Theme.new("UIStroke", { Color = Color3.fromRGB(50, 36, 20), Thickness = 1.5 }, shoulders)

	local head = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(head, 6)
	shaded(head, Color3.fromRGB(236, 206, 164), Color3.fromRGB(176, 140, 100))
	Theme.new("UIStroke", { Color = Color3.fromRGB(50, 36, 20), Thickness = 1.5 }, head)

	local belt = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(10, 3),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	shaded(belt, Theme.GoldLight, Theme.GoldDark)
end

-- Призыв: фиолетовый светящийся орб с золотым ободком и искрой
function Glyphs.summon(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local orb = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Theme.corner(orb, 12)
	shaded(orb, Color3.fromRGB(190, 120, 255), Color3.fromRGB(70, 30, 140))
	local rim = Theme.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, orb)
	Theme.new("UIGradient", { Rotation = 60, Color = ColorSequence.new(Theme.GoldLight, Theme.GoldDark) }, rim)

	local spark = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.34),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = z + 1,
	}, orb)
	Theme.corner(spark, 1)
end

-- Кристалл призыва: огранённый ромб с бликом
function Glyphs.crystal(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local gem = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Theme.corner(gem, 2)
	shaded(gem, Color3.fromRGB(160, 220, 255), Color3.fromRGB(70, 90, 230))
	Theme.new("UIStroke", { Color = Color3.fromRGB(30, 40, 120), Thickness = 1.5 }, gem)
	local facet = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.36),
		Size = UDim2.fromScale(0.35, 0.35),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, gem)
	Theme.corner(facet, 1)
end

-- Эссенция колец: золотисто-бирюзовая капля-орб
function Glyphs.essence(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local orb = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Theme.corner(orb, 9)
	shaded(orb, Color3.fromRGB(200, 255, 230), Color3.fromRGB(40, 150, 130))
	Theme.new("UIStroke", { Color = Theme.GoldDark, Thickness = 1.5 }, orb)
	local hole = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.4),
		BackgroundColor3 = Color3.fromRGB(20, 70, 64),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, orb)
	Theme.corner(hole, 6)
end

-- Зелье: колба с горлышком и пробкой
function Glyphs.potion(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local holder = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local neck = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromOffset(8, 9),
		BackgroundColor3 = Color3.fromRGB(190, 220, 200),
		BorderSizePixel = 0,
		ZIndex = z,
	}, holder)
	Theme.new("UIStroke", { Color = Color3.fromRGB(40, 70, 60), Thickness = 1.5 }, neck)
	local cork = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(10, 4),
		BackgroundColor3 = Color3.fromRGB(150, 100, 60),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(cork, 2)
	local body = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(20, 17),
		BorderSizePixel = 0,
		ZIndex = z,
	}, holder)
	Theme.corner(body, 9)
	shaded(body, Color3.fromRGB(150, 255, 150), Color3.fromRGB(30, 140, 60))
	Theme.new("UIStroke", { Color = Color3.fromRGB(20, 70, 40), Thickness = 1.5 }, body)
end

-- Прицел: кольцо с крестом (кнопка «следующая цель» на телефоне)
function Glyphs.target(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local ring = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	Theme.corner(ring, 12)
	Theme.new("UIStroke", { Color = Theme.GoldLight, Thickness = 2.5 }, ring)
	for _, size in { Vector2.new(2, 34), Vector2.new(34, 2) } do
		local bar = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = Theme.Danger,
			BorderSizePixel = 0,
			ZIndex = z + 1,
		}, ring)
		bar.BackgroundTransparency = 0.1
	end
end

-- Шестерёнка: диск с зубцами (повёрнутые прямоугольники) и отверстием
function Glyphs.gear(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local holder = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	for index = 0, 3 do
		local tooth = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 26),
			Rotation = index * 45,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		shaded(tooth, Color3.fromRGB(190, 190, 200), Color3.fromRGB(110, 110, 124))
	end
	local disc = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(disc, 9)
	shaded(disc, Color3.fromRGB(210, 210, 222), Color3.fromRGB(120, 120, 134))
	Theme.new("UIStroke", { Color = Color3.fromRGB(50, 50, 60), Thickness = 1.5 }, disc)
	local hole = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BorderSizePixel = 0,
		ZIndex = z + 2,
	}, disc)
	Theme.corner(hole, 4)
end

-- Кубок: чаша с ручками, ножка и основание (кнопка рейтинга)
function Glyphs.trophy(parent: Instance)
	local z = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2
	local holder = Theme.new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	for _, side in { 0, 1 } do
		local handle = Theme.new("Frame", {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.new(side, 0, 0, 3),
			Size = UDim2.fromOffset(8, 9),
			BackgroundTransparency = 1,
			ZIndex = z,
		}, holder)
		Theme.corner(handle, 4)
		Theme.new("UIStroke", { Color = Theme.GoldMid, Thickness = 2 }, handle)
	end
	local cup = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(cup, 5)
	shaded(cup, Theme.GoldLight, Theme.GoldDark)
	Theme.new("UIStroke", { Color = Color3.fromRGB(80, 56, 16), Thickness = 1.5 }, cup)
	local stem = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(4, 6),
		BorderSizePixel = 0,
		ZIndex = z,
	}, holder)
	shaded(stem, Theme.GoldMid, Theme.GoldDark)
	local base = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(14, 5),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(base, 2)
	shaded(base, Theme.GoldMid, Theme.GoldDark)
	Theme.new("UIStroke", { Color = Color3.fromRGB(80, 56, 16), Thickness = 1.5 }, base)
end

return Glyphs
