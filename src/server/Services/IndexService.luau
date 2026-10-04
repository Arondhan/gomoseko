--!strict
-- Index (книга колец): какие кольца игрок уже находил и награды за вехи (25 / 50 / 100 %).
-- «Найдено» = кольцо есть в профиле (кольца не пропадают), поэтому отдельного списка не храним; в профиле лежат
-- только полученные награды (Index.Claimed). Награда выдаётся один раз, проверки — на сервере.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local IndexMath = require(Shared:WaitForChild("Gacha"):WaitForChild("IndexMath"))
local Configs = Shared:WaitForChild("Configs")
local GachaConfig = require(Configs:WaitForChild("GachaConfig"))
local RingsConfig = require(Configs:WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))

local IndexService = {}

local function buildState(player: Player): Types.IndexState?
	local profile = DataService.waitForProfile(player, 30)
	if not profile then
		return nil
	end
	local discovered: { string } = {}
	for _, ringId in profile.Rings do
		if RingsConfig.Rings[ringId] then
			table.insert(discovered, ringId)
		end
	end
	local total = #RingsConfig.List
	local milestones: { Types.IndexMilestone } = {}
	for _, milestone in GachaConfig.Index.Milestones do
		table.insert(milestones, {
			percent = milestone.Percent,
			crystals = milestone.Crystals,
			essence = milestone.Essence,
			need = IndexMath.ringsNeeded(total, milestone.Percent),
			reached = IndexMath.reached(#discovered, total, milestone.Percent),
			claimed = profile.Index.Claimed[tostring(milestone.Percent)] == true,
		})
	end
	return { discovered = discovered, total = total, milestones = milestones }
end

local function claim(player: Player, percent: any): Types.IndexClaimResponse
	local profile = DataService.get(player)
	if not profile or type(percent) ~= "number" then
		return { ok = false, reason = "Invalid request" }
	end
	local state = buildState(player)
	if not state then
		return { ok = false, reason = "Your data is still loading" }
	end
	for _, milestone in state.milestones do
		if milestone.percent == percent then
			if not milestone.reached then
				return { ok = false, reason = "Not reached yet", state = state }
			end
			if milestone.claimed then
				return { ok = false, reason = "Already claimed", state = state }
			end
			profile.Index.Claimed[tostring(percent)] = true -- сначала отмечаем, потом выдаём: двойной вызов невозможен
			if milestone.crystals > 0 then
				CurrencyService.add(player, "Crystals", milestone.crystals, "Gameplay", "index_reward")
			end
			if milestone.essence > 0 then
				CurrencyService.add(player, "Essence", milestone.essence, "Gameplay", "index_reward")
			end
			task.spawn(DataService.save, player, false)
			return { ok = true, state = buildState(player) }
		end
	end
	return { ok = false, reason = "Unknown reward", state = state }
end

function IndexService.start()
	local getRemote = Remotes.get("IndexGet") :: RemoteFunction
	local claimRemote = Remotes.get("IndexClaim") :: RemoteFunction
	getRemote.OnServerInvoke = buildState
	claimRemote.OnServerInvoke = claim
end

return IndexService
