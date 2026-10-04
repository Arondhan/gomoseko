--!strict
-- «Часики» кулдауна как в WoW, без картинок. Две половинки (правая/левая) с затемняющим Frame; тёмная
-- область — полуплоскость, образованная UIGradient с жёсткой границей по центру (см. shared/Combat/CooldownMath).
-- По окончании кулдауна — короткая вспышка «готово». Размещайте поверх иконки в квадратном слоте.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CooldownMath =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("CooldownMath"))
local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local RadialCooldown = {}

local DARK_TRANSPARENCY = 0.35

export type Radial = {
	frame: Frame,
	set: (remaining: number, total: number) -> (),
}

-- Градиент с жёсткой границей по центру: t < 0.5 прозрачно, t >= 0.5 тёмное
local function hardEdge(): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4999, 1),
		NumberSequenceKeypoint.new(0.5, DARK_TRANSPARENCY),
		NumberSequenceKeypoint.new(1, DARK_TRANSPARENCY),
	})
end

function RadialCooldown.new(parent: Instance, zIndex: number): Radial
	local root = Theme.new("Frame", {
		Name = "RadialCooldown",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = zIndex,
	}, parent)

	-- половинка: контейнер с клипом + полноразмерный (в координатах всего квадрата) затемняющий Frame
	local function half(name: string, anchorX: number): (Frame, UIGradient)
		local container = Theme.new("Frame", {
			Name = name,
			Position = UDim2.fromScale(anchorX, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = zIndex,
		}, root)
		local overlay = Theme.new("Frame", {
			Name = "Overlay",
			Position = UDim2.fromScale(if anchorX == 0 then 0 else -1, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, container)
		local gradient = Theme.new("UIGradient", { Transparency = hardEdge() }, overlay)
		return overlay, gradient
	end
	local rightOverlay, rightGradient = half("Right", 0.5)
	local leftOverlay, leftGradient = half("Left", 0)

	local label = Chrome.label(root, {
		Name = "Seconds",
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		ZIndex = zIndex + 1,
	})

	-- вспышка «готово»
	local flash = Theme.new("Frame", {
		Name = "ReadyFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.GoldLight,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 2,
	}, parent)
	Theme.corner(flash, 6)

	local wasActive = false

	local function set(remaining: number, total: number)
		local active = remaining > 0 and total > 0
		if not active then
			root.Visible = false
			if wasActive then
				flash.BackgroundTransparency = 0.35
				Theme.tween(flash, 0.35, { BackgroundTransparency = 1 })
			end
			wasActive = false
			return
		end
		wasActive = true
		root.Visible = true

		local sweep = CooldownMath.sweep(remaining, total)
		rightOverlay.Visible = sweep.rightDark
		rightGradient.Rotation = sweep.rightRotation
		-- левая: пока стрелка справа — вся тёмная (поворот 0 даёт тёмную правую часть, поэтому закрываем сплошным цветом)
		leftGradient.Rotation = if sweep.leftDark then sweep.leftRotation else 0
		leftOverlay.BackgroundTransparency = if sweep.leftDark then 0 else DARK_TRANSPARENCY
		leftGradient.Enabled = sweep.leftDark

		label.Text = if remaining >= 1 then tostring(math.ceil(remaining)) else string.format("%.1f", remaining)
	end

	return { frame = root, set = set }
end

return RadialCooldown
