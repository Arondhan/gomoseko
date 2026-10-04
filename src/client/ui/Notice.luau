--!strict
-- Короткие сообщения по центру экрана в стиле WoW: красные ошибки («Нет цели», «Не хватает маны»)
-- и золотые события («Новый уровень!»). Лёгкий «выезд» вверх и затухание.

local Theme = require(script.Parent.Theme)

local Notice = {}

local VISIBLE_TIME = 1.4
local BASE_POSITION = UDim2.fromScale(0.5, 0.62)

function Notice.build(parent: Instance)
	local label = Theme.new("TextLabel", {
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = BASE_POSITION,
		Size = UDim2.fromOffset(500, 32),
		BackgroundTransparency = 1,
		Text = "",
		Font = Theme.TitleFont,
		TextSize = 24,
		TextColor3 = Theme.Danger,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextTransparency = 1,
	}, parent)

	local token = 0 -- номер последнего сообщения: старый таймер не гасит новое
	-- color — цвет текста (по умолчанию красный, для ошибок)
	local function show(text: string, color: Color3?)
		token += 1
		local mine = token
		label.Text = text
		label.TextColor3 = color or Theme.Danger
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.2
		label.Position = BASE_POSITION + UDim2.fromOffset(0, 14)
		Theme.tween(label, 0.15, { Position = BASE_POSITION })
		task.delay(VISIBLE_TIME, function()
			if token == mine then
				Theme.tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end

	return { label = label, show = show }
end

return Notice
