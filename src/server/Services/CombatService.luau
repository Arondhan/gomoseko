--!strict
-- Боевая система (сервер): приём каста скилла от игрока, валидация, цепочка прыжков, урон и рассылка визуала.
-- Клиент присылает только "хочу скилл X в цель Y" — всё остальное (кулдаун, мана, дистанция, цели, урон)
-- решает сервер. Клиентам уходят только координаты звеньев молнии для отрисовки (SkillVFX).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ChainSearch = require(Shared:WaitForChild("Combat"):WaitForChild("ChainSearch"))
local Configs = Shared:WaitForChild("Configs")
local CombatConfig = require(Configs:WaitForChild("CombatConfig"))
local ArcLightningConfig = require(Configs:WaitForChild("Skills"):WaitForChild("ArcLightningConfig"))

local Services = script.Parent
local InventoryService = require(Services:WaitForChild("InventoryService"))
local PlayerStatsService = require(Services:WaitForChild("PlayerStatsService"))

local CombatService = {}

-- Реестр скиллов. Новый скилл = конфиг + запись здесь + обработчик (пока универсальная "цепная молния").
local SKILLS: { [string]: Types.SkillConfig } = {
	[ArcLightningConfig.Id] = ArcLightningConfig,
}

local CASTER_HAND_OFFSET = Vector3.new(0, 1, 0) -- откуда стартует первое звено относительно HumanoidRootPart

-- cooldowns[player][skillId] = os.clock(), когда скилл снова доступен
local cooldowns: { [Player]: { [string]: number } } = {}
local vfxRemote: RemoteEvent

local function fail(reason: string): Types.CastResult
	return { ok = false, reason = reason }
end

local function getRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getAliveHumanoid(model: Instance): Humanoid?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Допустимая цель: Model с тегом Enemy, живым Humanoid и HumanoidRootPart; не сам кастер.
local function isValidTarget(model: any, caster: Player): boolean
	if typeof(model) ~= "Instance" or not model:IsA("Model") or model.Parent == nil then
		return false
	end
	if not CollectionService:HasTag(model, CombatConfig.EnemyTag) then
		return false
	end
	local character = caster.Character
	if character and (model == character or model:IsDescendantOf(character)) then
		return false
	end
	return getAliveHumanoid(model) ~= nil and getRoot(model) ~= nil
end

-- Все допустимые цели в мире в формате для ChainSearch
local function collectCandidates(caster: Player): { ChainSearch.Candidate<Model> }
	local list = {}
	for _, instance in CollectionService:GetTagged(CombatConfig.EnemyTag) do
		if isValidTarget(instance, caster) then
			local model = instance :: Model
			local root = getRoot(model)
			if root then
				table.insert(list, { id = model, position = root.Position })
			end
		end
	end
	return list
end

-- Цепочка: бьёт цель, ждёт BounceDelay, ищет ближайшую новую цель в BounceRadius, и так до MaxBounces.
-- Каждая цель поражается не более одного раза за цепочку (множество hit).
local function runChain(player: Player, config: Types.SkillConfig, primary: Model, startPosition: Vector3)
	local hit: { [Model]: boolean } = {}
	local current: Model = primary
	local from = startPosition
	local hopIndex = 0

	while true do
		-- цель могла умереть/исчезнуть, пока мы ждали задержку
		local humanoid = getAliveHumanoid(current)
		local root = getRoot(current)
		if not (humanoid and root and isValidTarget(current, player)) then
			break
		end

		hopIndex += 1
		hit[current] = true
		humanoid:TakeDamage(config.Damage)

		local hop: Types.LightningHop = {
			skillId = config.Id,
			casterUserId = player.UserId,
			hopIndex = hopIndex,
			from = from,
			to = root.Position,
		}
		vfxRemote:FireAllClients(hop)

		if hopIndex > config.MaxBounces then -- hopIndex 1 = первичный удар, остальные = перескоки
			break
		end

		from = root.Position
		task.wait(config.BounceDelay)

		local nextTarget = ChainSearch.findNext(collectCandidates(player), from, config.BounceRadius, hit)
		if not nextTarget then
			break
		end
		current = nextTarget.id
	end
end

local function cast(player: Player, skillId: any, target: any): Types.CastResult
	if type(skillId) ~= "string" then
		return fail("Неверный запрос")
	end
	local config = SKILLS[skillId]
	if not config then
		return fail("Неизвестный скилл")
	end
	if not InventoryService.isSkillEquipped(player, skillId) then
		return fail("Кольцо не надето")
	end

	-- кастер жив
	local character = player.Character
	local casterRoot = character and getRoot(character)
	if not (character and casterRoot and getAliveHumanoid(character)) then
		return fail("Вы не можете сейчас колдовать")
	end

	-- кулдаун
	local now = os.clock()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	if (playerCooldowns[skillId] or 0) > now then
		return fail("Перезарядка")
	end

	-- первичная цель: указанная клиентом (с проверкой дистанции) или ближайший враг в радиусе каста
	local primary: Model
	if target ~= nil then
		if not isValidTarget(target, player) then
			return fail("Неверная цель")
		end
		local targetRoot = getRoot(target :: Model)
		if not targetRoot then
			return fail("Неверная цель")
		end
		if (targetRoot.Position - casterRoot.Position).Magnitude > config.CastRange + CombatConfig.RangeTolerance then
			return fail("Цель слишком далеко")
		end
		primary = target :: Model
	else
		local nearest = ChainSearch.findNext(collectCandidates(player), casterRoot.Position, config.CastRange, {})
		if not nearest then
			return fail("Нет цели")
		end
		primary = nearest.id
	end

	-- мана списывается последней: только за каст, который точно состоится
	if not PlayerStatsService.trySpend(player, config.ManaCost) then
		return fail("Не хватает маны")
	end
	playerCooldowns[skillId] = now + config.Cooldown

	task.spawn(runChain, player, config, primary, casterRoot.Position + CASTER_HAND_OFFSET)
	return { ok = true }
end

function CombatService.start()
	vfxRemote = Remotes.get("SkillVFX") :: RemoteEvent
	local castRemote = Remotes.get("CastSkill") :: RemoteFunction
	castRemote.OnServerInvoke = cast

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return CombatService
