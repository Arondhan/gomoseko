--!strict
-- «Хром» интерфейса в стиле WoW: объёмные золотые рамки (фаска), панели с градиентом, угловые ромбы-заклёпки,
-- внутренняя тень слотов и свечение. Все окна и слоты строятся на этих функциях — один вид везде.
-- Размеры/цвета правятся здесь и в Theme.

local Theme = require(script.Parent.Theme)

local Chrome = {}

-- Золотой градиент для обводки/заливок: светлый «блик» сверху, тёмный низ
local function goldSequence(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.GoldLight),
		ColorSequenceKeypoint.new(0.45, Theme.GoldMid),
		ColorSequenceKeypoint.new(1, Theme.GoldDark),
	})
end

-- Фаска: внешняя золотая обводка с градиентом + тонкая тёмная внутренняя линия (иллюзия толщины металла)
function Chrome.bevel(frame: GuiObject, thickness: number?, radius: number?): UIStroke
	local width = thickness or 2
	local stroke = Theme.new("UIStroke", {
		Name = "Bevel",
		Color = Color3.new(1, 1, 1),
		Thickness = width,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	Theme.new("UIGradient", { Rotation = 90, Color = goldSequence() }, stroke)

	local inner = Theme.new("Frame", {
		Name = "BevelInner",
		Position = UDim2.fromOffset(width, width),
		Size = UDim2.new(1, -width * 2, 1, -width * 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex,
	}, frame)
	if radius and radius > 1 then
		Theme.corner(inner, radius - 1)
	end
	Theme.new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Transparency = 0.35,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inner)
	return stroke
end

-- Тёмная панель с вертикальным градиентом и фаской
function Chrome.panel(parent: Instance, props: { [string]: any }, radius: number?): Frame
	local r = radius or 8
	local merged: { [string]: any } = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame = Theme.new("Frame", merged, parent)
	Theme.corner(frame, r)
	Theme.gradient(frame, 90, Theme.PanelTop, Theme.PanelBottom)
	Chrome.bevel(frame, 2, r)
	return frame
end

-- Золотой ромб (заклёпка/орнамент)
function Chrome.diamond(parent: Instance, size: number, position: UDim2, zIndex: number?): Frame
	local diamond = Theme.new("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = zIndex or 5,
	}, parent)
	Theme.new("UIGradient", { Rotation = 90, Color = goldSequence() }, diamond)
	Theme.new("UIStroke", { Color = Color3.fromRGB(40, 28, 10), Thickness = 1 }, diamond)
	return diamond
end

-- Ромбы по четырём углам рамки (внутри, чтобы работали и в CanvasGroup)
function Chrome.corners(frame: GuiObject, size: number?, inset: number?)
	local s = size or 9
	local o = inset or 5
	Chrome.diamond(frame, s, UDim2.new(0, o, 0, o))
	Chrome.diamond(frame, s, UDim2.new(1, -o, 0, o))
	Chrome.diamond(frame, s, UDim2.new(0, o, 1, -o))
	Chrome.diamond(frame, s, UDim2.new(1, -o, 1, -o))
end

-- Внутренняя тень слота: сверху темно, к середине светлеет (эффект «утопленности»)
function Chrome.inset(frame: GuiObject, radius: number?): Frame
	local shade = Theme.new("Frame", {
		Name = "InnerShadow",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = frame.ZIndex,
	}, frame)
	if radius then
		Theme.corner(shade, radius)
	end
	Theme.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.45, 0.8),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
	}, shade)
	return shade
end

-- Слот в стиле WoW: тёмное «гнездо» с внутренней тенью и золотой фаской. Возвращает (frame, bevelStroke)
function Chrome.slot(parent: Instance, size: UDim2, radius: number?): (Frame, UIStroke)
	local r = radius or 6
	local frame = Theme.new("Frame", {
		Size = size,
		BackgroundColor3 = Color3.fromRGB(16, 17, 23),
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(frame, r)
	Chrome.inset(frame, r)
	local bevel = Chrome.bevel(frame, 2, r)
	return frame, bevel
end

-- Свечение вокруг объекта: возвращает UIStroke (Transparency 1 = выключено). Включайте tween'ом по Transparency.
function Chrome.glow(frame: GuiObject, color: Color3, thickness: number?): UIStroke
	return Theme.new("UIStroke", {
		Name = "Glow",
		Color = color,
		Thickness = thickness or 3,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

-- Текст с чёрной обводкой (читается на любом фоне, как в WoW)
function Chrome.label(parent: Instance, props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.BoldFont,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.35,
	}
	for key, value in props do
		merged[key] = value
	end
	return Theme.new("TextLabel", merged, parent)
end

-- Окрасить фаску слота в цвет качества (color = nil — вернуть золото)
function Chrome.tintBevel(bevel: UIStroke, color: Color3?)
	local gradient = bevel:FindFirstChildOfClass("UIGradient")
	if not gradient then
		return
	end
	if color then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.45)),
			ColorSequenceKeypoint.new(0.45, color),
			ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.55)),
		})
	else
		gradient.Color = goldSequence()
	end
end

return Chrome
