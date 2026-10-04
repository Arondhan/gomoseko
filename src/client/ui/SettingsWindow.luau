--!strict
-- Окно «Settings»: громкость эффектов (ползунок) и переключатель Low graphics. Работает мышью и пальцем.

local UserInputService = game:GetService("UserInputService")

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local SettingsWindow = {}

-- deps: { settings = SettingsController }
function SettingsWindow.build(parent: Instance, deps: any)
	local settings = deps.settings

	local window = Window.new(parent, {
		name = "SettingsWindow",
		title = "Settings",
		size = UDim2.fromOffset(380, 270),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	-- громкость эффектов
	Chrome.label(body, {
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Sound effects volume",
		FontFace = Theme.Fonts.Title,
		TextSize = 15,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local valueLabel = Chrome.label(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(60, 22),
		Text = "100%",
		TextSize = 14,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local track = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Color3.fromRGB(10, 11, 15),
		BorderSizePixel = 0,
	}, body)
	Theme.corner(track, 6)
	Chrome.bevel(track, 1.5, 6, true)
	local fill = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.GoldMid,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	Theme.corner(fill, 6)
	Theme.gradient(fill, 90, Theme.GoldLight, Theme.GoldDark)
	local knob = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.GoldLight,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, track)
	Theme.corner(knob, 11)
	Theme.new("UIStroke", { Color = Theme.GoldDark, Thickness = 2 }, knob)

	local function showVolume(volume: number)
		fill.Size = UDim2.fromScale(volume, 1)
		knob.Position = UDim2.fromScale(volume, 0.5)
		valueLabel.Text = string.format("%d%%", math.floor(volume * 100 + 0.5))
	end
	showVolume(settings.getVolume())

	-- ползунок: ведём палец/курсор вдоль полосы; сохраняем при отпускании
	local dragging = false
	local function setFrom(input: InputObject)
		local width = math.max(1, track.AbsoluteSize.X)
		local volume = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
		showVolume(volume)
		settings.setVolume(volume, false)
	end
	track.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFrom(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFrom(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragging = false
			settings.setVolume(settings.getVolume(), true)
		end
	end)

	-- Low graphics
	Chrome.label(body, {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Graphics",
		FontFace = Theme.Fonts.Title,
		TextSize = 15,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local toggle = Theme.new("TextButton", {
		Position = UDim2.fromOffset(0, 106),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
	}, body)
	Theme.corner(toggle, 8)
	local toggleGradient = Theme.gradient(toggle, 90, Color3.fromRGB(110, 84, 36), Color3.fromRGB(58, 42, 16))
	Chrome.bevel(toggle, 2, 8, true)
	local toggleLabel = Chrome.label(toggle, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = 16,
		TextColor3 = Theme.GoldLight,
		ZIndex = 6,
	})
	local function showQuality()
		local low = settings.isLowQuality()
		toggleLabel.Text = if low then "Low graphics: ON" else "Low graphics: OFF"
		toggleGradient.Color = if low
			then ColorSequence.new(Color3.fromRGB(70, 110, 60), Color3.fromRGB(36, 60, 32))
			else ColorSequence.new(Color3.fromRGB(110, 84, 36), Color3.fromRGB(58, 42, 16))
	end
	showQuality()
	toggle.MouseButton1Click:Connect(function()
		settings.setLowQuality(not settings.isLowQuality())
		showQuality()
	end)
	Chrome.label(body, {
		Position = UDim2.fromOffset(0, 152),
		Size = UDim2.new(1, 0, 0, 54),
		Text = "Low graphics hides decorative lights and particles, shadows and glow. Recommended on phones and weaker devices.",
		FontFace = Theme.Fonts.Body,
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextStrokeTransparency = 1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	settings.changed.Event:Connect(function()
		if not dragging then
			showVolume(settings.getVolume())
		end
		showQuality()
	end)

	return window
end

return SettingsWindow
