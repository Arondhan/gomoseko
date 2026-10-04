--!strict
-- Иконка кольца без внешних ассетов: круг с толстым контуром цвета кольца и «камнем» сверху.
-- Заполняет родителя (по центру, 62% его размера), поэтому одинаково работает в слоте и в ячейке инвентаря.

local Theme = require(script.Parent.Theme)

local RingIcon = {}

function RingIcon.new(parent: Instance, color: Color3): Frame
	local holder = Theme.new("Frame", {
		Name = "RingIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		Active = false,
	}, parent)
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 1 }, holder)

	local band = Theme.new("Frame", { Name = "Band", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, holder)
	Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }, band)
	Theme.new("UIStroke", {
		Color = color,
		Thickness = 5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, band)

	local gem = Theme.new("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		BorderSizePixel = 0,
		Rotation = 45,
	}, holder)
	Theme.new("UIStroke", { Color = color, Thickness = 1.5 }, gem)
	return holder
end

return RingIcon
