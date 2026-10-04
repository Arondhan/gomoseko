--!strict
-- «Хром» интерфейса в мультяшном стиле: толстая тёмная обводка, скруглённые панели с градиентом, лёгкий
-- светлый блик внутри рамки, внутренняя тень слотов и свечение. Все окна и слоты строятся на этих функциях.
-- Размеры/цвета правятся здесь и в Theme.

local Theme = require(script.Parent.Theme)

local Chrome = {}

-- Тёмный контур (по умолчанию); у слотов с качеством заменяется цветом качества (см. tintBevel)
local function outlineSequence(): ColorSequence
	return ColorSequence.new(Theme.Outline, Theme.Outline)
end

-- Обводка: толстый тёмный контур + светлая линия внутри (блик).
-- simple = true — только внешний контур, без вложенного фрейма BevelInner. ОБЯЗАТЕЛЬНО для объектов, внутри
-- которых лежит UIListLayout / UIGridLayout (например, Tooltip): иначе BevelInner попадает в раскладку
-- как обычный элемент и раздувается на весь экран.
function Chrome.bevel(frame: GuiObject, thickness: number?, radius: number?, simple: boolean?): UIStroke
	local width = (thickness or 2) + 1
	local stroke = Theme.new("UIStroke", {
		Name = "Bevel",
		Color = Color3.new(1, 1, 1),
		Thickness = width,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	Theme.new("UIGradient", { Rotation = 90, Color = outlineSequence() }, stroke)
	if simple then
		return stroke
	end

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
		Color = Color3.new(1, 1, 1),
		Transparency = 0.78,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inner)
	return stroke
end

-- Тёмная панель с вертикальным градиентом и фаской.
-- Не кладите UIListLayout внутрь панели с обычной фаской — используйте simple = true (см. Chrome.bevel).
function Chrome.panel(parent: Instance, props: { [string]: any }, radius: number?, simple: boolean?): Frame
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
	Chrome.bevel(frame, 2, r, simple)
	return frame
end

-- Ромбы-заклёпки WoW-стиля больше не рисуются: функция оставлена для совместимости и возвращает скрытый фрейм
function Chrome.diamond(parent: Instance, _size: number, _position: UDim2, _zIndex: number?): Frame
	return Theme.new("Frame", { Name = "Diamond", Visible = false, Size = UDim2.new() }, parent)
end

-- Раньше — ромбы по углам окна; в мультяшном стиле ничего не рисует
function Chrome.corners(_frame: GuiObject, _size: number?, _inset: number?) end

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

-- Слот: тёмное «гнездо» с внутренней тенью и толстой обводкой. Возвращает (frame, bevelStroke)
function Chrome.slot(parent: Instance, size: UDim2, radius: number?): (Frame, UIStroke)
	local r = radius or 6
	local frame = Theme.new("Frame", {
		Size = size,
		BackgroundColor3 = Color3.fromRGB(26, 34, 84),
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

-- Текст с толстой чёрной обводкой (UIStroke по контуру букв): читается на любом фоне, как на референсе.
-- TextStrokeTransparency из props задаёт прозрачность обводки (1 — без обводки).
function Chrome.label(parent: Instance, props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Numbers,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local outline = merged.TextStrokeTransparency
	merged.TextStrokeTransparency = 1 -- настоящую обводку рисует UIStroke ниже
	local label = Theme.new("TextLabel", merged, parent)
	if outline < 1 then
		Theme.new("UIStroke", {
			Name = "TextOutline",
			Color = merged.TextStrokeColor3,
			Thickness = if merged.TextSize >= 28 then 3 else 2,
			Transparency = outline,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
		}, label)
	end
	return label
end

-- Окрасить обводку слота в цвет качества (color = nil — вернуть тёмный контур)
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
		gradient.Color = outlineSequence()
	end
end

return Chrome
