--!strict
-- Онбординг: короткая цепочка целей для новых игроков. Шаг завершает сервер (другие сервисы зовут notify),
-- прогресс лежит в профиле; клиенту публикуется атрибут Player.OnboardingStep (номер шага, 0 — пройден).
-- Каждый шаг логируется в воронку онбординга Roblox (AnalyticsService:LogOnboardingFunnelStepEvent).

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OnboardingConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("OnboardingConfig"))

local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local OnboardingService = {}

local function publish(player: Player)
	local profile = DataService.get(player)
	if profile then
		player:SetAttribute("OnboardingStep", if profile.Onboarding.Done then 0 else profile.Onboarding.Step)
	end
end

-- Игрок сделал действие key; если это текущий шаг — переходим к следующему (при завершении — награда)
function OnboardingService.notify(player: Player, key: string)
	local profile = DataService.get(player)
	if not profile or profile.Onboarding.Done then
		return
	end
	local step = OnboardingConfig.Steps[profile.Onboarding.Step]
	if not step or step.Key ~= key then
		return
	end

	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, profile.Onboarding.Step, step.Key)
	end)
	profile.Onboarding.Step += 1
	if profile.Onboarding.Step > #OnboardingConfig.Steps then
		profile.Onboarding.Done = true
		CurrencyService.add(player, "Crystals", OnboardingConfig.Reward.Crystals, "Onboarding", "tutorial_complete")
	end
	publish(player)
end

function OnboardingService.start()
	DataService.onLoaded(publish)
end

return OnboardingService
