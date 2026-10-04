--!strict
-- Панель скиллов справа внизу: большая кнопка «Attack» для первого надетого кольца со скиллом и до трёх малых кнопок
-- дугой вокруг неё для остальных. На каждой — иконка кольца, радиальный кулдаун и номер слота (клавиша 1–4).
-- Кнопки без скилла скрыты. Логика каста — в SkillController (сервер всё проверяет); здесь только показ и ввод.

local Chrome = require(script.Parent.Chrome)
local RadialCooldown = require(script.Parent.RadialCooldown)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)

local SkillPad = {}

local MAIN_SIZE = 108
local SMALL_SIZE = 68
local ARC_RADIUS = 98
local ARC_ANGLES = { 180, 135, 90 } -- малые кнопки: слева, по диагонали, сверху (градусы от оси вправо)
local MAX_BUTTONS = 4

type Button = {
	frame: Frame,
	gradient: UIGradient,
	scale: UIScale,
	iconHolder: Frame,
	empty: TextLabel,
	key: TextLabel?,
	cooldown: RadialCooldown.Radial,
	icon: Frame?,
}

local FILLED = ColorSequence.new(Color3.fromRGB(255, 110, 90), Color3.fromRGB(200, 40, 40))
local SMALL_FILLED = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(210, 100, 20))
local EMPTY = ColorSequence.new(Color3.fromRGB(150, 160, 185), Color3.fromRGB(90, 100, 130))

-- deps: { onPress = (index: number) -> (), tooltip = Tooltip }; index 1 — большая кнопка, 2..4 — малые
function SkillPad.build(parent: Instance, deps: any)
	local root = Theme.new("Frame", {
		Name = "SkillPad",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -64),
		Size = UDim2.fromOffset(MAIN_SIZE, MAIN_SIZE),
		BackgroundTransparency = 1,
	}, parent)

	local buttons: { Button } = {}

	local function makeButton(index: number): Button
		local main = index == 1
		local size = if main then MAIN_SIZE else SMALL_SIZE
		local frame = Theme.new("Frame", {
			Name = if main then "Attack" else "Skill" .. index,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.fromOffset(size, size),
		}, root)
		if main then
			frame.Position = UDim2.fromScale(0, 0)
		else
			local angle = math.rad(ARC_ANGLES[index - 1])
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromOffset(
				MAIN_SIZE / 2 + math.cos(angle) * ARC_RADIUS,
				MAIN_SIZE / 2 - math.sin(angle) * ARC_RADIUS
			)
		end
		Theme.corner(frame, if main then 28 else 20)
		local gradient = Theme.gradient(frame, 90, Color3.fromRGB(150, 160, 185), Color3.fromRGB(90, 100, 130))
		Chrome.bevel(frame, 3, if main then 28 else 20, true)
		local scale = Theme.new("UIScale", { Scale = 1 }, frame)

		local iconSize = if main then size - 36 else size - 22
		local iconHolder = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, if main then 8 else 6),
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, frame)
		local empty = Chrome.label(iconHolder, {
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			FontFace = Theme.Fonts.Banner,
			TextSize = if main then Theme.TextSize.Banner else Theme.TextSize.Title,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 4,
		})
		local key: TextLabel? = nil
		if main then
			Chrome.label(frame, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, 0, 0, 24),
				Text = "ATTACK",
				FontFace = Theme.Fonts.Title,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 10,
			})
		end
		key = Chrome.label(frame, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(24, 22),
			Text = "",
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
		})

		local cooldown = RadialCooldown.new(frame, 20)
		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 30,
		}, frame)

		local button: Button = {
			frame = frame,
			gradient = gradient,
			scale = scale,
			iconHolder = iconHolder,
			empty = empty,
			key = key,
			cooldown = cooldown,
			icon = nil,
		}
		hit.MouseButton1Click:Connect(function()
			scale.Scale = 0.9
			Theme.tween(scale, 0.15, { Scale = 1 })
			deps.onPress(index)
		end)
		hit.MouseEnter:Connect(function()
			deps.tooltip.show(
				if main then "Attack" else "Skill",
				"Hotkey: " .. (if key then key.Text else ""),
				{ "Casts the ring skill on the selected enemy or the nearest one." },
				Theme.Danger
			)
		end)
		hit.MouseLeave:Connect(function()
			deps.tooltip.hide()
		end)
		return button
	end

	for index = 1, MAX_BUTTONS do
		local button = makeButton(index)
		button.frame.Visible = index == 1 -- малые кнопки появляются, когда есть что кастовать
		buttons[index] = button
	end

	local api: any = { frame = root, count = MAX_BUTTONS }

	-- entries[i] = { ring, slot } для i-й кнопки (nil — кнопка пуста: большая серая, малые скрыты)
	function api.setSkills(entries: { { ring: RingIcon.Def, slot: number }? })
		for index, button in buttons do
			local entry = entries[index]
			if button.icon then
				button.icon:Destroy()
				button.icon = nil
			end
			button.empty.Visible = entry == nil
			if index > 1 then
				button.frame.Visible = entry ~= nil
			end
			if entry then
				button.icon = RingIcon.new(button.iconHolder, entry.ring)
				button.gradient.Color = if index == 1 then FILLED else SMALL_FILLED
				if button.key then
					button.key.Text = tostring(entry.slot)
				end
			else
				button.gradient.Color = EMPTY
				if button.key then
					button.key.Text = ""
				end
			end
		end
	end

	function api.setCooldown(index: number, remaining: number, total: number)
		local button = buttons[index]
		if button then
			button.cooldown.set(remaining, total)
		end
	end

	-- анимация нажатия большой кнопки (например, при касте клавишей)
	function api.press(index: number?)
		local button = buttons[index or 1]
		if button then
			button.scale.Scale = 0.9
			Theme.tween(button.scale, 0.15, { Scale = 1 })
		end
	end

	return api
end

return SkillPad
