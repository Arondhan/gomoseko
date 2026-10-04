--!strict
-- Полоса значения в стиле WoW (HP / мана / XP): тёмное «стекло», градиентная заливка с бликом,
-- «ghost»-полоса, плавно догоняющая при убывании, и текст «текущее / максимум» с обводкой.

local Theme = require(script.Parent.Theme)

local StatusBar = {}

export type Bar = {
	frame: Frame,
	setValue: (current: number, max: number) -> (),
	setColor: (color: Color3) -> (),
	setText: (text: string) -> (),
}

local GHOST_DELAY = 0.3

function StatusBar.new(parent: Instance, position: UDim2, size: UDim2, color: Color3): Bar
	local back = Theme.new("Frame", {
		Name = "Bar",
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(10, 11, 15),
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(back, 4)
	local border = Theme.new("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, back)
	Theme.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Theme.GoldMid, Theme.GoldDark),
	}, border)

	local clip = Theme.new("Frame", {
		Name = "Clip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, back)
	Theme.corner(clip, 4)

	-- отстающая полоса (светлая): показывает, сколько только что потеряно
	local ghost = Theme.new("Frame", {
		Name = "Ghost",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, clip)

	local fill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, clip)
	local fillGradient = Theme.new("UIGradient", {
		Rotation = 90,
		Color = Theme.shade(color),
	}, fill)

	-- блик на верхней половине полосы
	local shine = Theme.new("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 0.45),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, clip)
	Theme.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(0.7, 1),
	}, shine)

	local label = Theme.new("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.BoldFont,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.25,
		ZIndex = 5,
	}, back)

	local lastFraction = 1
	local token = 0

	local bar = {} :: Bar
	bar.frame = back

	function bar.setValue(current: number, max: number)
		local fraction = if max > 0 then math.clamp(current / max, 0, 1) else 0
		Theme.tween(fill, 0.12, { Size = UDim2.fromScale(fraction, 1) })
		if fraction < lastFraction then
			-- убыло: ghost держится и затем догоняет
			token += 1
			local mine = token
			task.delay(GHOST_DELAY, function()
				if token == mine then
					Theme.tween(ghost, 0.3, { Size = UDim2.fromScale(fraction, 1) })
				end
			end)
		else
			token += 1
			ghost.Size = UDim2.fromScale(fraction, 1)
		end
		lastFraction = fraction
		label.Text = math.ceil(current) .. " / " .. math.ceil(max)
	end

	function bar.setColor(newColor: Color3)
		fillGradient.Color = Theme.shade(newColor)
	end

	function bar.setText(text: string)
		label.Text = text
	end

	return bar
end

return StatusBar
