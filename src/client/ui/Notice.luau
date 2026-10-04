--!strict
-- Короткие сообщения об ошибках по центру экрана (красный текст, как «Нет цели» / «Недостаточно маны» в WoW).

local Theme = require(script.Parent.Theme)

local Notice = {}

local VISIBLE_TIME = 1.2

function Notice.build(parent: Instance)
	local label = Theme.new("TextLabel", {
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(400, 28),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 80, 60),
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, parent)

	local token = 0 -- номер последнего сообщения: старый таймер не гасит новое
	local function show(text: string)
		token += 1
		local mine = token
		label.Text = text
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.3
		task.delay(VISIBLE_TIME, function()
			if token == mine then
				Theme.tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end

	return { label = label, show = show }
end

return Notice
