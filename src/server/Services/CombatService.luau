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
local AoeSearch = require(Shared:WaitForChild("Combat"):WaitForChild("AoeSearch"))
local ChainSearch = require(Shared:WaitForChild("Combat"):WaitForChild("ChainSearch"))
local Configs = Shared:WaitForChild("Configs")
local CombatConfig = require(Configs:WaitForChild("CombatConfig"))
local Skills = Configs:WaitForChild("Skills")
local ArcLightningConfig = require(Skills:WaitForChild("ArcLightningConfig"))
local FireballConfig = require(Skills:WaitForChild("FireballConfig"))
local MeteorConfig = require(Skills:WaitForChild("MeteorConfig"))

local Services = script.Parent
local InventoryService = require(Services:WaitForChild("InventoryService"))
local PlayerStatsService = require(Services:WaitForChild("PlayerStatsService"))
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DpsService = require(Services:WaitForChild("DpsService"))
local OnboardingService = require(Services:WaitForChild("OnboardingService"))
local StatsService = require(Services:WaitForChild("StatsService"))

local CombatService = {}

-- Реестр скиллов. Новый скилл = конфиг (с полем Kind) + запись здесь; поведение задаёт обработчик HANDLERS[Kind].
local SKILLS: { [string]: Types.SkillConfig } = {
	[ArcLightningConfig.Id] = ArcLightningConfig,
	[FireballConfig.Id] = FireballConfig,
	[MeteorConfig.Id] = MeteorConfig,
}

local CASTER_HAND_OFFSET = Vector3.new(0, 1, 0) -- откуда стартует первое звено относительно HumanoidRootPart
local DAMAGE_NUMBER_OFFSET = Vector3.new(0, 3, 0) -- где над целью появляется цифра урона
local METEOR_GROUND_OFFSET = 2.5 -- от центра HumanoidRootPart до земли под ногами

-- cooldowns[player][skillId] = os.clock(), когда скилл снова доступен
local cooldowns: { [Player]: { [string]: number } } = {}
local casting: { [Player]: boolean } = {} -- игрок сейчас читает каст (CastTime > 0)
local vfxRemote: RemoteEvent
local damageRemote: RemoteEvent
local cancelRemote: RemoteEvent
local effectRemote: RemoteEvent

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

-- Урон одной цели от скилла игрока: бонусы колец (DamagePct), манекены не умирают (урон идёт в DPS-замер),
-- цифра урона — только тому, кто бьёт, убийство даёт опыт и награды. Общая часть всех видов скиллов.
local function applyDamage(player: Player, config: Types.SkillConfig, model: Model)
	local humanoid = getAliveHumanoid(model)
	local root = getRoot(model)
	if not (humanoid and root) then
		return
	end
	local damage = config.Damage * (1 + StatsService.get(player).DamagePct / 100)
	if model:GetAttribute("Immortal") == true then
		DpsService.recordHit(player, damage)
	else
		humanoid:TakeDamage(damage)
	end
	local damageEvent: Types.DamageEvent = {
		skillId = config.Id,
		position = root.Position + DAMAGE_NUMBER_OFFSET,
		amount = damage,
	}
	damageRemote:FireClient(player, damageEvent)
	if humanoid.Health <= 0 then
		PlayerStatsService.addXp(player, CombatConfig.Progression.XpPerKill)
		CurrencyService.rewardKill(player)
	end
end

-- Chain: бьёт цель, ждёт BounceDelay, ищет ближайшую новую цель в BounceRadius, и так до MaxBounces.
-- Каждая цель поражается не более одного раза за цепочку (множество hit).
local function runChain(player: Player, config: Types.SkillConfig, primary: Model, startPosition: Vector3)
	local maxBounces = config.MaxBounces or 0
	local bounceRadius = config.BounceRadius or 0
	local bounceDelay = config.BounceDelay or 0.17
	local hit: { [Model]: boolean } = {}
	local current: Model = primary
	local from = startPosition
	local hopIndex = 0

	while true do
		-- цель могла умереть/исчезнуть, пока мы ждали задержку
		local root = getRoot(current)
		if not (getAliveHumanoid(current) and root and isValidTarget(current, player)) then
			break
		end

		hopIndex += 1
		hit[current] = true
		applyDamage(player, config, current)

		local hop: Types.LightningHop = {
			skillId = config.Id,
			casterUserId = player.UserId,
			hopIndex = hopIndex,
			from = from,
			to = root.Position,
		}
		vfxRemote:FireAllClients(hop)

		if hopIndex > maxBounces then -- hopIndex 1 = первичный удар, остальные = перескоки
			break
		end

		from = root.Position
		task.wait(bounceDelay)

		local nextTarget = ChainSearch.findNext(collectCandidates(player), from, bounceRadius, hit)
		if not nextTarget then
			break
		end
		current = nextTarget.id
	end
end

-- Площадной удар: все допустимые цели в радиусе radius от center получают урон скилла
local function strikeArea(player: Player, config: Types.SkillConfig, center: Vector3, radius: number)
	for _, candidate in AoeSearch.within(collectCandidates(player), center, radius) do
		applyDamage(player, config, candidate.id)
	end
end

-- Projectile (Fireball): шар летит к точке, где цель была при выстреле, и взрывается; бьёт всех в ExplosionRadius
local function runProjectile(player: Player, config: Types.SkillConfig, primary: Model, startPosition: Vector3)
	local root = getRoot(primary)
	if not root then
		return
	end
	local radius = config.ExplosionRadius or 8
	local target = root.Position
	local duration = AoeSearch.flightTime((target - startPosition).Magnitude, config.ProjectileSpeed or 60)
	local effect: Types.SkillEffect = {
		skillId = config.Id,
		kind = config.Kind,
		casterUserId = player.UserId,
		from = startPosition,
		to = target,
		radius = radius,
		duration = duration,
	}
	effectRemote:FireAllClients(effect)
	task.wait(duration)
	strikeArea(player, config, target, radius)
end

-- Meteor: метка на земле под целью, через Delay с неба падает метеор; бьёт круг Radius вокруг метки
-- (цель, успевшая уйти из круга, не пострадает)
local function runMeteor(player: Player, config: Types.SkillConfig, primary: Model, _startPosition: Vector3)
	local root = getRoot(primary)
	if not root then
		return
	end
	local radius = config.Radius or 15
	local delay = config.Delay or 1.2
	local ground = root.Position - Vector3.new(0, METEOR_GROUND_OFFSET, 0)
	local effect: Types.SkillEffect = {
		skillId = config.Id,
		kind = config.Kind,
		casterUserId = player.UserId,
		from = ground + Vector3.new(0, config.FallHeight or 90, 0),
		to = ground,
		radius = radius,
		duration = delay,
	}
	effectRemote:FireAllClients(effect)
	task.wait(delay)
	strikeArea(player, config, ground, radius)
end

local HANDLERS: { [Types.SkillKind]: (Player, Types.SkillConfig, Model, Vector3) -> () } = {
	Chain = runChain,
	Projectile = runProjectile,
	Meteor = runMeteor,
}

local function runSkill(player: Player, config: Types.SkillConfig, primary: Model, startPosition: Vector3)
	HANDLERS[config.Kind](player, config, primary, startPosition)
end

local function cast(player: Player, skillId: any, target: any): Types.CastResult
	if type(skillId) ~= "string" then
		return fail("Invalid request")
	end
	local config = SKILLS[skillId]
	if not config then
		return fail("Unknown skill")
	end
	-- эффективные значения с учётом бонусов надетых колец
	local bonuses = StatsService.get(player)
	local castRange = config.CastRange + bonuses.CastRange
	local cooldown = config.Cooldown * (1 - bonuses.CooldownReductionPct / 100)
	if not InventoryService.isSkillEquipped(player, skillId) then
		return fail("Ring not equipped")
	end

	if casting[player] then
		return fail("You are already casting")
	end

	-- кастер жив
	local character = player.Character
	local casterRoot = character and getRoot(character)
	if not (character and casterRoot and getAliveHumanoid(character)) then
		return fail("You cannot cast right now")
	end

	-- кулдаун
	local now = os.clock()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	if (playerCooldowns[skillId] or 0) > now then
		return fail("On cooldown")
	end

	-- первичная цель: указанная клиентом (с проверкой дистанции) или ближайший враг в радиусе каста
	local primary: Model
	if target ~= nil then
		if not isValidTarget(target, player) then
			return fail("Invalid target")
		end
		local targetRoot = getRoot(target :: Model)
		if not targetRoot then
			return fail("Invalid target")
		end
		if (targetRoot.Position - casterRoot.Position).Magnitude > castRange + CombatConfig.RangeTolerance then
			return fail("Target is too far")
		end
		primary = target :: Model
	else
		local nearest = ChainSearch.findNext(collectCandidates(player), casterRoot.Position, castRange, {})
		if not nearest then
			return fail("No target")
		end
		primary = nearest.id
	end

	-- мана списывается последней: только за каст, который точно состоится
	if not PlayerStatsService.trySpend(player, config.ManaCost) then
		return fail("Not enough mana")
	end
	playerCooldowns[skillId] = now + cooldown

	-- мгновенный каст — сразу цепочка
	if config.CastTime <= 0 then
		task.spawn(runSkill, player, config, primary, casterRoot.Position + CASTER_HAND_OFFSET)
		OnboardingService.notify(player, "CastSpell")
		return { ok = true, castTime = 0, cooldown = cooldown }
	end

	-- каст с задержкой: после CastTime цель и кастер проверяются заново, при срыве возвращаем ману и кулдаун
	casting[player] = true
	task.delay(config.CastTime, function()
		casting[player] = nil
		local currentCharacter = player.Character
		local root = currentCharacter and getRoot(currentCharacter)
		local primaryRoot = getRoot(primary)
		local reason: string? = nil
		if not (currentCharacter and root and getAliveHumanoid(currentCharacter)) then
			reason = "Cast interrupted"
		elseif not (isValidTarget(primary, player) and primaryRoot) then
			reason = "Target lost"
		elseif (primaryRoot.Position - root.Position).Magnitude > castRange + CombatConfig.RangeTolerance then
			reason = "Target is too far"
		end
		if reason then
			PlayerStatsService.refund(player, config.ManaCost)
			if cooldowns[player] then
				cooldowns[player][skillId] = nil
			end
			cancelRemote:FireClient(player, skillId, reason)
			return
		end
		runSkill(player, config, primary, (root :: BasePart).Position + CASTER_HAND_OFFSET)
	end)
	OnboardingService.notify(player, "CastSpell")
	return { ok = true, castTime = config.CastTime, cooldown = cooldown }
end

function CombatService.start()
	vfxRemote = Remotes.get("SkillVFX") :: RemoteEvent
	damageRemote = Remotes.get("DamageDealt") :: RemoteEvent
	cancelRemote = Remotes.get("CastCancelled") :: RemoteEvent
	effectRemote = Remotes.get("SkillEffect") :: RemoteEvent
	local castRemote = Remotes.get("CastSkill") :: RemoteFunction
	castRemote.OnServerInvoke = cast

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		casting[player] = nil
	end)
end

return CombatService
