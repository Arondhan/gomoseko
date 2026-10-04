--!strict
-- Одна большая кнопка «Attack» внизу справа вместо панели из 4 слотов: показывает кольцо со скиллом, радиальный
-- кулдаун и клавишу Q. Нажатие (клик/тап) вызывает deps.onPress; логика каста — в SkillController (сервер всё проверяет).

local Chrome = require(script.Parent.Chrome)
local RadialCooldown = require(script.Parent.RadialCooldown)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)

local AttackButton = {}

local SIZE = 108

-- deps: { onPress = () -> (), tooltip = Tooltip }
function AttackButton.build(parent: Instance, deps: any)
	local frame = Theme.new("Frame", {
		Name = "AttackButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -64),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	Theme.corner(frame, 28)
	local gradient = Theme.gradient(frame, 90, Color3.fromRGB(255, 110, 90), Color3.fromRGB(200, 40, 40))
	Chrome.bevel(frame, 3, 28, true)
	local scale = Theme.new("UIScale", { Scale = 1 }, frame)

	local iconHolder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(SIZE - 36, SIZE - 36),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, frame)
	local empty = Chrome.label(iconHolder, {
		Size = UDim2.fromScale(1, 1),
		Text = "?",
		FontFace = Theme.Fonts.Banner,
		TextSize = Theme.TextSize.Banner,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
	})
	Chrome.label(frame, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "ATTACK  [Q]",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 10,
	})

	local cooldown = RadialCooldown.new(frame, 20)
	local hit = Theme.new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 30,
	}, frame)

	local icon: Frame? = nil
	local api: any = { frame = frame }

	-- кольцо со скиллом (nil — скилла нет: кнопка серая)
	function api.setRing(ring: RingIcon.Def?)
		if icon then
			icon:Destroy()
			icon = nil
		end
		empty.Visible = ring == nil
		if ring then
			icon = RingIcon.new(iconHolder, ring)
			gradient.Color = ColorSequence.new(Color3.fromRGB(255, 110, 90), Color3.fromRGB(200, 40, 40))
		else
			gradient.Color = ColorSequence.new(Color3.fromRGB(150, 160, 185), Color3.fromRGB(90, 100, 130))
		end
	end

	function api.setCooldown(remaining: number, total: number)
		cooldown.set(remaining, total)
	end

	-- анимация нажатия (в том числе при касте клавишей)
	function api.press()
		scale.Scale = 0.9
		Theme.tween(scale, 0.15, { Scale = 1 })
	end

	hit.MouseButton1Click:Connect(function()
		api.press()
		deps.onPress()
	end)
	hit.MouseEnter:Connect(function()
		deps.tooltip.show("Attack", "Hotkey: Q", { "Casts the ring skill on the nearest enemy." }, Theme.Danger)
	end)
	hit.MouseLeave:Connect(function()
		deps.tooltip.hide()
	end)

	api.setRing(nil)
	return api
end

return AttackButton
