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
		size = UDim2.fromOffset(420, 600),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	-- громкость эффектов
	Chrome.label(body, {
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Sound effects volume",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Header,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local valueLabel = Chrome.label(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(60, 22),
		Text = "100%",
		TextSize = Theme.TextSize.Body,
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

	-- переключатели: (заголовок секции +) кнопка ON/OFF и пояснение
	local refreshers: { () -> () } = {}
	local function addToggle(y: number, label: string, isOn: () -> boolean, set: (boolean) -> ())
		local toggle = Theme.new("TextButton", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 42),
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
			TextSize = Theme.TextSize.Header,
			TextColor3 = Theme.GoldLight,
			ZIndex = 6,
		})
		local function show()
			local on = isOn()
			toggleLabel.Text = label .. (if on then ": ON" else ": OFF")
			toggleGradient.Color = if on
				then ColorSequence.new(Color3.fromRGB(70, 110, 60), Color3.fromRGB(36, 60, 32))
				else ColorSequence.new(Color3.fromRGB(110, 84, 36), Color3.fromRGB(58, 42, 16))
		end
		show()
		toggle.MouseButton1Click:Connect(function()
			set(not isOn())
			show()
		end)
		table.insert(refreshers, show)
	end
	local function addNote(y: number, height: number, text: string)
		Chrome.label(body, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			Text = text,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Muted,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end
	local function addHeading(y: number, text: string)
		Chrome.label(body, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 24),
			Text = text,
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Header,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	addHeading(84, "Graphics")
	addToggle(112, "Low graphics", settings.isLowQuality, settings.setLowQuality)
	addNote(
		158,
		60,
		"Hides decorative lights and particles, shadows and glow. Recommended on phones and weaker devices."
	)

	addHeading(226, "Summon effects")
	local function flag(name: string): (() -> boolean, (boolean) -> ())
		return function()
			return settings.getFlag(name)
		end, function(value: boolean)
			settings.setFlag(name, value)
		end
	end
	addToggle(254, "Cinematic rare rolls", flag("Cinematic"))
	addToggle(302, "Screen shake", flag("Shake"))
	addToggle(350, "Quick roll (skip animation)", flag("SkipAnim"))
	addToggle(398, "Controller vibration", flag("Haptics"))
	addNote(
		446,
		76,
		"Cinematic rolls briefly take over the camera when you find a very rare ring. Quick roll shows results instantly. Vibration works on gamepads (Roblox has no phone vibration)."
	)

	settings.changed.Event:Connect(function()
		if not dragging then
			showVolume(settings.getVolume())
		end
		for _, refresh in refreshers do
			refresh()
		end
	end)

	return window
end

return SettingsWindow
