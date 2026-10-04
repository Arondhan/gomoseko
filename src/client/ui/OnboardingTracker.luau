--!strict
-- Трекер целей для новых игроков (вверху по центру): текущий шаг обучения. Данные — атрибут Player.OnboardingStep
-- (номер шага; 0 или nil — обучение пройдено/не загружено). Тексты шагов — Configs/OnboardingConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local OnboardingConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("OnboardingConfig"))

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local OnboardingTracker = {}

-- onComplete() вызывается один раз, когда игрок завершает последний шаг (для поздравления)
function OnboardingTracker.build(parent: Instance, onComplete: (() -> ())?)
	local player = Players.LocalPlayer

	-- текст-подсказка без панели: крупный оранжевый шрифт с обводкой, мягко «дышит»
	local panel = Chrome.label(parent, {
		Name = "OnboardingTracker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(760, 84),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 170, 30),
		TextWrapped = true,
		Visible = false,
	})
	local pulse = Theme.new("UIScale", { Scale = 1 }, panel)
	task.spawn(function()
		while panel.Parent do
			TweenService:Create(pulse, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Scale = 1.04 }):Play()
			task.wait(0.9)
			TweenService:Create(pulse, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
			task.wait(0.9)
		end
	end)

	local previous: number? = nil
	local function refresh()
		local step = player:GetAttribute("OnboardingStep")
		local current = if type(step) == "number" then step else nil
		local info = if current then OnboardingConfig.Steps[current] else nil
		if info and current then
			panel.Visible = true
			panel.Text = string.format("%s  (%d/%d)", info.Text, current, #OnboardingConfig.Steps)
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
