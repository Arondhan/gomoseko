--!strict
-- Иконка кольца без внешних ассетов: золотой ободок (градиент), огранённый камень цвета кольца и аура качества.
-- Если у кольца задан Image ("rbxassetid://...") — вместо процедурной иконки рисуется картинка.
-- Заполняет родителя (по центру), поэтому одинаково работает в слоте RingBar, ячейке инвентаря и при перетаскивании.

local Theme = require(script.Parent.Theme)

local RingIcon = {}

export type Def = { Color: Color3, Quality: string?, Image: string?, [any]: any }

local function goldBand(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.GoldLight),
		ColorSequenceKeypoint.new(0.5, Theme.GoldMid),
		ColorSequenceKeypoint.new(1, Theme.GoldDark),
	})
end

-- ромб-грань камня: цвет и размер в долях холдера
local function facet(parent: Instance, size: number, color: Color3, zIndex: number, offsetY: number?): Frame
	local f = Theme.new("Frame", {
		Name = "Facet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, offsetY or 0.5),
		Size = UDim2.fromScale(size, size),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, parent)
	return f
end

function RingIcon.new(parent: Instance, def: Def): Frame
	local holder = Theme.new("Frame", {
		Name = "RingIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.82),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2,
	}, parent)
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }, holder)
	local z = holder.ZIndex

	if def.Image and def.Image ~= "" then
		Theme.new("ImageLabel", {
			Name = "Image",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = def.Image,
			ZIndex = z,
		}, holder)
		return holder
	end

	local color = def.Color
	local quality = Theme.Quality[def.Quality or "Common"] or color

	-- аура качества (мягкое свечение за кольцом)
	local aura = Theme.new("Frame", {
		Name = "Aura",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.92, 0.92),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, holder)
	Theme.corner(aura, 999)
	Theme.new("UIStroke", { Color = quality, Thickness = 5, Transparency = 0.7 }, aura)

	-- золотой ободок: UIStroke с градиентом на круглом прозрачном Frame
	local band = Theme.new("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
	}, holder)
	Theme.corner(band, 999)
	local stroke = Theme.new("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, band)
	Theme.new("UIGradient", { Rotation = 60, Color = goldBand() }, stroke)
	-- тёмная внутренняя линия ободка для глубины
	local innerHole = Theme.new("Frame", {
		Name = "Hole",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
	}, band)
	Theme.corner(innerHole, 999)
	Theme.new("UIStroke", { Color = Color3.fromRGB(30, 20, 5), Thickness = 1.5, Transparency = 0.2 }, innerHole)

	-- камень: тёмная оправа, основная грань, светлая грань, блик
	local setting = facet(holder, 0.34, Theme.GoldDark, z + 2, 0.18)
	Theme.new("UIStroke", { Color = Color3.fromRGB(40, 28, 10), Thickness = 1 }, setting)
	facet(holder, 0.26, color:Lerp(Color3.new(0, 0, 0), 0.25), z + 3, 0.18)
	local light = facet(holder, 0.17, color:Lerp(Color3.new(1, 1, 1), 0.35), z + 4, 0.17)
	Theme.new("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), color) }, light)
	facet(holder, 0.06, Color3.new(1, 1, 1), z + 5, 0.1)

	return holder
end

return RingIcon
