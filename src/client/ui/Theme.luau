-- Палитра и мелкие помощники для UI в стиле WoW (Dragonflight).

local TweenService = game:GetService("TweenService")

local Theme = {
	Bg = Color3.fromRGB(14, 16, 22),
	Panel = Color3.fromRGB(18, 20, 26),
	Header = Color3.fromRGB(26, 28, 36),
	Inset = Color3.fromRGB(22, 24, 30),
	Gold = Color3.fromRGB(190, 160, 90),
	GoldBright = Color3.fromRGB(245, 215, 130),
	GoldDim = Color3.fromRGB(95, 85, 60),
	Text = Color3.fromRGB(235, 220, 170),
	Coin = Color3.fromRGB(230, 190, 60),
	Muted = Color3.fromRGB(150, 140, 110),

	-- Золото для объёмных рамок: тёмное -> среднее -> светлое
	GoldLight = Color3.fromRGB(255, 226, 150),
	GoldMid = Color3.fromRGB(200, 160, 80),
	GoldDark = Color3.fromRGB(96, 70, 30),

	-- Фон панелей: вертикальный градиент сверху вниз
	PanelTop = Color3.fromRGB(36, 40, 54),
	PanelBottom = Color3.fromRGB(12, 14, 20),

	-- Полосы и сообщения
	Health = Color3.fromRGB(60, 190, 80),
	Mana = Color3.fromRGB(50, 120, 240),
	Xp = Color3.fromRGB(160, 80, 220),
	Enemy = Color3.fromRGB(200, 55, 45),
	EnemyName = Color3.fromRGB(255, 105, 90),
	Danger = Color3.fromRGB(255, 80, 60),
	Good = Color3.fromRGB(30, 255, 0),
	Warn = Color3.fromRGB(255, 209, 0),

	-- Шрифты: заголовки — антиква, числа и мелкий текст — Gotham, описания — Garamond
	TitleFont = Enum.Font.Antique,
	BodyFont = Enum.Font.GothamMedium,
	BoldFont = Enum.Font.GothamBold,
	SerifFont = Enum.Font.Garamond,

	-- Качество предметов (как в WoW): серый, зелёный, синий, фиолетовый, оранжевый
	Quality = {
		Common = Color3.fromRGB(157, 157, 157),
		Uncommon = Color3.fromRGB(30, 255, 0),
		Rare = Color3.fromRGB(0, 112, 221),
		Epic = Color3.fromRGB(163, 53, 238),
		Legendary = Color3.fromRGB(255, 128, 0),
	} :: { [string]: Color3 },
	QualityNames = {
		Common = "Обычное",
		Uncommon = "Необычное",
		Rare = "Редкое",
		Epic = "Эпическое",
		Legendary = "Легендарное",
	} :: { [string]: string },
}

function Theme.new(class: string, props: { [string]: any }, parent: Instance?): any
	local obj = Instance.new(class)
	for key, value in props do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

function Theme.corner(parent: Instance, radius: number)
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number)
	return Theme.new("UIStroke", {
		Name = "Stroke",
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Трёхцветная последовательность (верх / середина / низ) для объёмных заливок
function Theme.threeStop(top: Color3, mid: Color3, bottom: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.5, mid),
		ColorSequenceKeypoint.new(1, bottom),
	})
end

-- Объёмная заливка одним цветом: светлее сверху, темнее снизу
function Theme.shade(color: Color3): ColorSequence
	return Theme.threeStop(color:Lerp(Color3.new(1, 1, 1), 0.35), color, color:Lerp(Color3.new(0, 0, 0), 0.45))
end

-- Горизонтальный/вертикальный градиент по двум цветам (rotation 90 = сверху вниз)
function Theme.gradient(parent: Instance, rotation: number, from: Color3, to: Color3)
	return Theme.new("UIGradient", { Rotation = rotation, Color = ColorSequence.new(from, to) }, parent)
end

function Theme.tween(obj: Instance, time: number, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

return Theme
