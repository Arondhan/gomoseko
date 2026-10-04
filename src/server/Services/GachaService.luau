--!strict
-- Призыв колец (Gacha в стиле RNG-игр): сервер сам бросает кубики, списывает кристаллы и выдаёт кольца.
-- Шансы считает shared/Gacha/GachaMath; та же функция строит таблицу шансов, которую видит игрок ДО покупки.
-- Политика Roblox «Paid Random Items»: для регионов с ограничением платные призывы и платная удача отключены,
-- остаётся бесплатный ролл (без платной удачи).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GachaMath = require(Shared:WaitForChild("Gacha"):WaitForChild("GachaMath"))
local Configs = Shared:WaitForChild("Configs")
local GachaConfig = require(Configs:WaitForChild("GachaConfig"))
local MonetizationConfig = require(Configs:WaitForChild("MonetizationConfig"))
local RingsConfig = require(Configs:WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local OnboardingService = require(Services:WaitForChild("OnboardingService"))
local StatsService = require(Services:WaitForChild("StatsService"))

local GachaService = {}

local RECENT_LIMIT = 20
-- порядок показа в таблице шансов: от самых редких к самым частым
local QUALITY_ORDER: { Types.Quality } = { "Divine", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

local rng = Random.new()
local lastRollAt: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}
local announceRemote: RemoteEvent

-- пул для GachaMath
local pool: { GachaMath.Entry } = {}
for _, ring in RingsConfig.List do
	table.insert(pool, { id = ring.Id, oneIn = ring.OneIn })
end

local function fail(reason: string): Types.GachaRollResponse
	return { ok = false, reason = reason }
end

-- Удача игрока: 1 + (бонусы колец [+ платные источники]) / 100. includePaid = false — для бесплатного ролла.
local function computeLuck(player: Player, includePaid: boolean): (number, { Types.LuckSource })
	local sources: { Types.LuckSource } = {}
	local total = 0
	local ringLuck = StatsService.get(player).LuckPct
	if ringLuck > 0 then
		table.insert(sources, { name = "Equipped rings", percent = ringLuck })
		total += ringLuck
	end
	if includePaid and not MonetizationService.isPaidRandomRestricted(player) then
		local profile = DataService.get(player)
		if profile and profile.Boosts.LuckUntil > os.time() and profile.Boosts.LuckPercent > 0 then
			table.insert(sources, { name = "Luck Potion", percent = profile.Boosts.LuckPercent })
			total += profile.Boosts.LuckPercent
		end
		local charm = MonetizationConfig.PassesByKey.LuckyCharm
		if charm and MonetizationService.owns(player, charm.Key) and (charm.LuckPercent or 0) > 0 then
			table.insert(sources, { name = "Lucky Charm", percent = charm.LuckPercent or 0 })
			total += charm.LuckPercent or 0
		end
	end
	return math.min(GachaConfig.Luck.Max, 1 + total / 100), sources
end

-- Таблица шансов (проценты строками, сумма ровно 100 %) при данной удаче, сгруппированная по качеству
local function buildOdds(luck: number): { Types.OddsGroup }
	local units = GachaMath.units(pool, luck)
	local probs = GachaMath.probabilities(pool, luck)
	local groups: { Types.OddsGroup } = {}
	for _, quality in QUALITY_ORDER do
		local rings: { Types.OddsRing } = {}
		local groupUnits = 0
		for _, ring in RingsConfig.List do
			if ring.Quality == quality then
				groupUnits += units[ring.Id]
				table.insert(rings, {
					ringId = ring.Id,
					name = ring.Name,
					oneIn = ring.OneIn,
					percent = GachaMath.formatUnits(units[ring.Id]),
					effective = GachaMath.formatEffective(probs[ring.Id]),
				})
			end
		end
		if #rings > 0 then
			table.sort(rings, function(a, b)
				return a.oneIn > b.oneIn
			end)
			table.insert(
				groups,
				{ quality = quality :: Types.Quality, percent = GachaMath.formatUnits(groupUnits), rings = rings }
			)
		end
	end
	return groups
end

local function buildState(player: Player): Types.GachaState?
	local profile = DataService.waitForProfile(player, 30)
	if not profile then
		return nil
	end
	local restricted = MonetizationService.isPaidRandomRestricted(player)
	local luck, sources = computeLuck(player, true)
	local passes: { [string]: boolean } = {}
	for _, pass in MonetizationConfig.Passes do
		passes[pass.Key] = MonetizationService.owns(player, pass.Key)
	end
	return {
		crystals = CurrencyService.get(player, "Crystals"),
		essence = CurrencyService.get(player, "Essence"),
		rollCost = GachaConfig.RollCost,
		multiCount = GachaConfig.MultiCount,
		luck = luck,
		luckSources = sources,
		odds = buildOdds(luck),
		freeRollIn = math.max(0, profile.Gacha.LastFreeRoll + GachaConfig.FreeRollCooldown - os.time()),
		paidRestricted = restricted,
		passes = passes,
		rolls = profile.Gacha.Rolls,
	}
end

local function roll(player: Player, count: any, free: any): Types.GachaRollResponse
	if type(count) ~= "number" or (count ~= 1 and count ~= GachaConfig.MultiCount) or type(free) ~= "boolean" then
		return fail("Invalid request")
	end
	local profile = DataService.get(player)
	if not profile then
		return fail("Your data is still loading")
	end
	if busy[player] then
		return fail("Please wait")
	end

	-- анти-спам
	local pause = if MonetizationService.owns(player, "FastRoll")
		then GachaConfig.FastRollCooldown
		else GachaConfig.RollCooldown
	local now = os.clock()
	if lastRollAt[player] and now - lastRollAt[player] < pause then
		return fail("Please wait")
	end
	lastRollAt[player] = now
	busy[player] = true

	local luck: number
	if free then
		if count ~= 1 then
			busy[player] = nil
			return fail("The free roll is a single summon")
		end
		if profile.Gacha.LastFreeRoll + GachaConfig.FreeRollCooldown > os.time() then
			busy[player] = nil
			return fail("The free roll is not ready yet")
		end
		luck = computeLuck(player, false)
		profile.Gacha.LastFreeRoll = os.time()
	else
		if MonetizationService.isPaidRandomRestricted(player) then
			busy[player] = nil
			return fail("Paid summons are not available in your region")
		end
		if not CurrencyService.trySpend(player, "Crystals", GachaConfig.RollCost * count, "Shop", "ring_summon") then
			busy[player] = nil
			return fail("Not enough Summon Crystals")
		end
		luck = computeLuck(player, true)
	end

	local results: { Types.RollResult } = {}
	local saveSoon = false
	for _ = 1, count do
		local ringId = GachaMath.roll(pool, luck, rng :: any)
		local ring = RingsConfig.Rings[ringId]
		local isNew = InventoryService.grantRing(player, ringId)
		local essence = 0
		if not isNew then
			essence = GachaConfig.Essence[ring.Quality] or 0
			CurrencyService.add(player, "Essence", essence, "Gameplay", "duplicate_ring")
		end
		table.insert(
			results,
			{ ringId = ringId, quality = ring.Quality, oneIn = ring.OneIn, isNew = isNew, essence = essence }
		)

		table.insert(profile.Gacha.Recent, { ringId = ringId, t = os.time() })
		if #profile.Gacha.Recent > RECENT_LIMIT then
			table.remove(profile.Gacha.Recent, 1)
		end
		if ring.OneIn >= GachaConfig.Announce.MinOneIn then
			saveSoon = true
			local announce: Types.GachaAnnounce =
				{ playerName = player.DisplayName, ringId = ringId, oneIn = ring.OneIn }
			announceRemote:FireAllClients(announce)
		end
	end
	profile.Gacha.Rolls += count
	if saveSoon then
		task.spawn(DataService.save, player, false) -- редкую находку не теряем при сбое сервера
	end

	busy[player] = nil
	OnboardingService.notify(player, "Summon")
	return { ok = true, results = results, state = buildState(player) }
end

function GachaService.start()
	announceRemote = Remotes.get("GachaAnnounce") :: RemoteEvent
	local stateRemote = Remotes.get("GachaGetState") :: RemoteFunction
	local rollRemote = Remotes.get("GachaRoll") :: RemoteFunction
	stateRemote.OnServerInvoke = buildState
	rollRemote.OnServerInvoke = roll

	Players.PlayerRemoving:Connect(function(player)
		lastRollAt[player] = nil
		busy[player] = nil
	end)
end

return GachaService
