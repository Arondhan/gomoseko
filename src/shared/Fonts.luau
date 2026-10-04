--!strict
-- Шрифты проекта. Используются встроенные шрифты Roblox (FontFace): они подгружаются у всех игроков сами,
-- свои TTF пришлось бы вручную загружать в Creator Hub. Менять шрифт — правьте только этот файл.
-- Использование: label.FontFace = Fonts.Title

local ContentProvider = game:GetService("ContentProvider")

local Fonts = {}

-- Обычное начертание встроенного шрифта по Enum.Font
local function regular(font: Enum.Font): Font
	return Font.fromEnum(font)
end

-- Тот же шрифт нужной жирности (если нет такого начертания, Roblox берёт ближайшее)
local function weighted(font: Enum.Font, weight: Enum.FontWeight): Font
	return Font.new(Font.fromEnum(font).Family, weight, Enum.FontStyle.Normal)
end

Fonts.Title = weighted(Enum.Font.Merriweather, Enum.FontWeight.Bold) -- заголовки, имена, названия предметов
Fonts.Banner = regular(Enum.Font.Fondamento) -- крупные баннеры и уведомления (каллиграфия)
Fonts.Serif = regular(Enum.Font.Merriweather) -- описания и «художественный» текст
Fonts.Body = weighted(Enum.Font.Nunito, Enum.FontWeight.Medium) -- обычный текст
Fonts.Numbers = weighted(Enum.Font.GothamBold, Enum.FontWeight.Bold) -- числа, ключи, полосы HP/маны
Fonts.Impact = weighted(Enum.Font.GothamBlack, Enum.FontWeight.Heavy) -- цифры урона

-- Прогрев: создаём скрытые TextLabel с каждым шрифтом и ждём загрузки, чтобы текст не «мигал» при первом показе.
-- Вызывать на клиенте один раз при старте (в отдельном потоке — PreloadAsync yield'ит).
function Fonts.preload()
	local holder = Instance.new("Folder")
	local labels: { Instance } = {}
	for _, font in { Fonts.Title, Fonts.Banner, Fonts.Serif, Fonts.Body, Fonts.Numbers, Fonts.Impact } do
		local label = Instance.new("TextLabel")
		label.FontFace = font
		label.Text = "AaBbCc 0123456789"
		label.Parent = holder
		table.insert(labels, label)
	end
	pcall(function()
		ContentProvider:PreloadAsync(labels)
	end)
	holder:Destroy()
end

return Fonts
