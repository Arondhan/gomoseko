--!strict
-- Трекер целей для новых игроков (вверху по центру): текущий шаг обучения. Данные — атрибут Player.OnboardingStep
-- (номер шага; 0 или nil — обучение пройдено/не загружено). Тексты шагов — Configs/OnboardingConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OnboardingConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("OnboardingConfig"))

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local OnboardingTracker = {}

-- onComplete() вызывается один раз, когда игрок завершает последний шаг (для поздравления)
function OnboardingTracker.build(parent: Instance, onComplete: (() -> ())?)
	local player = Players.LocalPlayer

	local panel = Chrome.panel(parent, {
		Name = "OnboardingTracker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(440, 62),
		Visible = false,
	}, 8)
	Chrome.diamond(panel, 9, UDim2.new(0, 10, 0.5, 0), 8)
	local glow = Chrome.glow(panel, Theme.GoldLight, 3)

	local title = Chrome.label(panel, {
		Position = UDim2.fromOffset(26, 6),
		Size = UDim2.new(1, -36, 0, 21),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = 16,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local text = Chrome.label(panel, {
		Position = UDim2.fromOffset(26, 24),
		Size = UDim2.new(1, -36, 0, 34),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextStrokeTransparency = 0.6,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 4,
	})

	local previous: number? = nil
	local function refresh()
		local step = player:GetAttribute("OnboardingStep")
		local current = if type(step) == "number" then step else nil
		local info = if current then OnboardingConfig.Steps[current] else nil
		if info and current then
			panel.Visible = true
			title.Text = string.format("Getting started  %d / %d", current, #OnboardingConfig.Steps)
			text.Text = info.Text
			if previous ~= current then
				glow.Transparency = 0
				Theme.tween(glow, 1.2, { Transparency = 1 })
			end
		else
			panel.Visible = false
			if previous and previous > 0 and current == 0 and onComplete then
				onComplete()
			end
		end
		previous = current
	end
	player:GetAttributeChangedSignal("OnboardingStep"):Connect(refresh)
	refresh()

	return { frame = panel }
end

return OnboardingTracker
