--!strict
-- Полоса значения в стиле WoW (HP / мана): тёмная подложка, цветная заливка и текст «текущее/максимум».
-- Используется в PlayerFrame и TargetFrame.

local Theme = require(script.Parent.Theme)

local StatusBar = {}

export type Bar = {
	frame: Frame,
	setValue: (current: number, max: number) -> (),
	setColor: (color: Color3) -> (),
}

function StatusBar.new(parent: Instance, position: UDim2, size: UDim2, color: Color3): Bar
	local back = Theme.new("Frame", {
		Name = "Bar",
		Position = position,
		Size = size,
		BackgroundColor3 = Theme.Inset,
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(back, 4)
	Theme.stroke(back, Theme.GoldDim, 1)

	local clip = Theme.new("Frame", {
		Name = "Clip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, back)
	Theme.corner(clip, 4)
	local fill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, clip)

	local label = Theme.new("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
	}, back)

	local bar = {} :: Bar
	bar.frame = back
	function bar.setValue(current: number, max: number)
		local fraction = if max > 0 then math.clamp(current / max, 0, 1) else 0
		Theme.tween(fill, 0.12, { Size = UDim2.fromScale(fraction, 1) })
		label.Text = math.ceil(current) .. " / " .. math.ceil(max)
	end
	function bar.setColor(newColor: Color3)
		fill.BackgroundColor3 = newColor
	end
	return bar
end

return StatusBar
