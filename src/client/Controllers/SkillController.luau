--!strict
-- Клиентский контроллер скиллов: ввод (слот кольца / быстрая клавиша), захват цели, запрос на сервер,
-- локальный таймер кулдауна. Тяжёлого здесь нет: все проверки по-настоящему делает CombatService,
-- локальные (кулдаун/мана/дистанция) нужны только для мгновенного отклика и сообщений игроку.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ArcLightningConfig =
	require(Shared:WaitForChild("Configs"):WaitForChild("Skills"):WaitForChild("ArcLightningConfig"))

local Controllers = script.Parent
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local TargetController = require(Controllers:WaitForChild("TargetController"))

local SkillController = {}

-- события для cast bar: Fire(skillName, castTime) / Fire() / Fire(reason)
SkillController.castStarted = Instance.new("BindableEvent")
SkillController.castFinished = Instance.new("BindableEvent")
SkillController.castCancelled = Instance.new("BindableEvent")

local CAST_FINISH_GRACE = 0.2 -- запас на сетевую задержку: сервер может сорвать каст чуть позже таймера

-- Реестр скиллов на клиенте (те же конфиги, что и на сервере)
local SKILLS: { [string]: Types.SkillConfig } = {
	[ArcLightningConfig.Id] = ArcLightningConfig,
}

local localPlayer = Players.LocalPlayer
local cooldownEnds: { [string]: number } = {} -- skillId -> os.clock() окончания кулдауна
local pending = false -- запрос на сервер в полёте
local castEndsAt = 0 -- до какого момента идёт каст (os.clock)
local castToken = 0 -- номер каста: устаревшие таймеры игнорируются
local onError: (string) -> () = function() end

function SkillController.getSkill(skillId: string): Types.SkillConfig?
	return SKILLS[skillId]
end

-- Остаток кулдауна и его полная длительность (для оверлея на слоте)
function SkillController.getCooldown(skillId: string): (number, number)
	local skill = SKILLS[skillId]
	local remaining = math.max(0, (cooldownEnds[skillId] or 0) - os.clock())
	return remaining, if skill then skill.Cooldown else 0
end

local function myRoot(): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Применить скилл кольца из слота. target == nil -> сервер сам выберет ближайшего врага.
function SkillController.castSlot(slot: number)
	local ring = InventoryController.getRingInSlot(slot)
	if not ring then
		return
	end
	local skill = SKILLS[ring.SkillId]
	if not skill or pending then
		return
	end

	if os.clock() < castEndsAt then
		onError("Вы уже колдуете")
		return
	end
	if SkillController.getCooldown(skill.Id) > 0 then
		onError("Перезарядка")
		return
	end
	local mana = localPlayer:GetAttribute("Mana")
	if type(mana) == "number" and mana < skill.ManaCost then
		onError("Не хватает маны")
		return
	end

	local target = TargetController.getTarget()
	if target then
		local root, targetRoot = myRoot(), target:FindFirstChild("HumanoidRootPart")
		if root and targetRoot and targetRoot:IsA("BasePart") then
			if (targetRoot.Position - root.Position).Magnitude > skill.CastRange then
				onError("Цель слишком далеко")
				return
			end
		end
	end

	pending = true
	local remote = Remotes.get("CastSkill") :: RemoteFunction
	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer(skill.Id, target)
		end)
		pending = false
		local response = result :: Types.CastResult?
		if ok and response and response.ok then
			cooldownEnds[skill.Id] = os.clock() + skill.Cooldown
			local castTime = response.castTime or 0
			if castTime > 0 then
				castToken += 1
				local mine = castToken
				castEndsAt = os.clock() + castTime
				SkillController.castStarted:Fire(skill.Name, castTime)
				task.delay(castTime + CAST_FINISH_GRACE, function()
					if castToken == mine then
						SkillController.castFinished:Fire()
					end
				end)
			end
		else
			onError(if response and response.reason then response.reason else "Не удалось применить")
		end
	end)
end

-- errorCallback получает текст отказа (его показывает ui/Notice);
-- keyCastCallback (необязательно) вызывается, когда каст запущен быстрой клавишей (например, для анимации слота)
function SkillController.start(errorCallback: (string) -> (), keyCastCallback: ((slot: number) -> ())?)
	onError = errorCallback

	-- сервер сорвал каст (цель пропала/умерла, кастер погиб): возвращаем кулдаун, гасим cast bar, показываем причину
	local cancelRemote = Remotes.get("CastCancelled") :: RemoteEvent
	cancelRemote.OnClientEvent:Connect(function(skillId: string, reason: string)
		if type(skillId) ~= "string" or type(reason) ~= "string" then
			return
		end
		castToken += 1
		castEndsAt = 0
		cooldownEnds[skillId] = nil
		SkillController.castCancelled:Fire(reason)
		onError(reason)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		for _, skill in SKILLS do
			if skill.DefaultKey == input.KeyCode then
				local slot = InventoryController.getSlotForSkill(skill.Id)
				if slot then
					if keyCastCallback then
						keyCastCallback(slot)
					end
					SkillController.castSlot(slot)
				end
			end
		end
	end)
end

return SkillController
