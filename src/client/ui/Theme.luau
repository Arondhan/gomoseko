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

function Theme.tween(obj: Instance, time: number, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

return Theme
