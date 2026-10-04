--!strict
-- Покупки за Robux: Developer Products (кристаллы, зелья удачи) и Game Passes (AutoRoll, FastRoll, LuckyCharm).
-- Здесь единственный MarketplaceService.ProcessReceipt. Также — проверка региона по политике Roblox
-- «Paid Random Items» (PolicyService): там, где платные случайные предметы запрещены, платные призывы и товары отключаются.
--
-- До создания продуктов/пассов в Creator Hub и ввода их ID (Configs/MonetizationConfig) покупки недоступны;
-- в Studio работает «Test Grant» (StudioGrant) для проверки без Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MonetizationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("MonetizationConfig"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local restricted: { [Player]: boolean } = {}
local policyLoaded: { [Player]: boolean } = {}

---------------------------------------------------------------------------
-- Политика: платные случайные предметы
---------------------------------------------------------------------------
local function loadPolicy(player: Player)
	for attempt = 1, 3 do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			restricted[player] = info.ArePaidRandomItemsRestricted == true
			policyLoaded[player] = true
			return
		end
		task.wait(attempt)
	end
	-- не удалось узнать: в живой игре действуем осторожно (считаем регион ограниченным), в Studio — нет
	restricted[player] = not RunService:IsStudio()
	policyLoaded[player] = true
	warn(
		"[Monetization] PolicyService unavailable for "
			.. player.Name
			.. ", restricted = "
			.. tostring(restricted[player])
	)
end

-- true — игроку нельзя пользоваться платными генераторами случайных предметов (Robux и валюта за Robux)
function MonetizationService.isPaidRandomRestricted(player: Player): boolean
	local deadline = os.clock() + 15
	while not policyLoaded[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return restricted[player] == true
end

---------------------------------------------------------------------------
-- Геймпассы
---------------------------------------------------------------------------
function MonetizationService.owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

local function refreshPasses(player: Player)
	local set = owned[player]
	if not set then
		return
	end
	for _, pass in MonetizationConfig.Passes do
		if pass.Id ~= 0 and not set[pass.Key] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				set[pass.Key] = true
			end
		end
	end
end

---------------------------------------------------------------------------
-- Выдача покупок (общая для настоящих покупок и Studio-гранта)
---------------------------------------------------------------------------
local function grantProduct(player: Player, profile: DataService.Profile, product: MonetizationConfig.Product)
	if product.Kind == "Crystals" then
		CurrencyService.add(player, "Crystals", product.Crystals or 0)
	elseif product.Kind == "LuckPotion" then
		local now = os.time()
		local boosts = profile.Boosts
		local active = boosts.LuckUntil > now
		local percent = product.LuckPercent or 0
		boosts.LuckPercent = if active then math.max(boosts.LuckPercent, percent) else percent
		boosts.LuckUntil = (if active then boosts.LuckUntil else now) + (product.DurationSeconds or 0)
	end
end

local function productById(productId: number): MonetizationConfig.Product?
	for _, product in MonetizationConfig.Products do
		if product.Id ~= 0 and product.Id == productId then
			return product
		end
	end
	return nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if profile.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- уже выдано (повторная доставка квитанции)
	end
	local product = productById(info.ProductId)
	if not product then
		warn("[Monetization] unknown ProductId " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- без сохранения данных настоящую покупку подтверждать нельзя: она пропала бы при выходе
	if not DataService.isPersistent(player) then
		warn("[Monetization] profile is not persistent (DataStore unavailable): purchase deferred")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grantProduct(player, profile, product)
	profile.Receipts[purchaseId] = true
	if not DataService.save(player, false) then
		-- в памяти уже выдано и записано в Receipts: повторная доставка вернёт PurchaseGranted без двойной выдачи,
		-- а автосохранение запишет данные на диск
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------------
-- Магазин: состояние и покупка
---------------------------------------------------------------------------
local function buildState(player: Player): Types.StoreState
	local items: { Types.StoreItem } = {}
	for _, product in MonetizationConfig.Products do
		table.insert(items, {
			key = product.Key,
			id = product.Id,
			name = product.Name,
			description = product.Description,
			kind = product.Kind,
			isPass = false,
			owned = false,
		})
	end
	for _, pass in MonetizationConfig.Passes do
		table.insert(items, {
			key = pass.Key,
			id = pass.Id,
			name = pass.Name,
			description = pass.Description,
			kind = "Pass",
			isPass = true,
			owned = MonetizationService.owns(player, pass.Key),
		})
	end
	return {
		items = items,
		restricted = MonetizationService.isPaidRandomRestricted(player),
		studio = RunService:IsStudio(),
	}
end

local function buy(player: Player, key: any): (boolean, string?)
	if type(key) ~= "string" then
		return false, "Invalid request"
	end
	if MonetizationService.isPaidRandomRestricted(player) then
		return false, "Not available in your region"
	end
	local product = MonetizationConfig.ProductsByKey[key]
	local pass = MonetizationConfig.PassesByKey[key]
	if product then
		if product.Id == 0 then
			return false, "Not set up yet"
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
		return true, nil
	elseif pass then
		if pass.Id == 0 then
			return false, "Not set up yet"
		end
		if MonetizationService.owns(player, pass.Key) then
			return false, "You already own this"
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return true, nil
	end
	return false, "Unknown item"
end

-- Только Studio: выдать покупку без Robux (для проверки интерфейса и экономики)
local function studioGrant(player: Player, key: any): boolean
	if not RunService:IsStudio() or type(key) ~= "string" then
		return false
	end
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local product = MonetizationConfig.ProductsByKey[key]
	local pass = MonetizationConfig.PassesByKey[key]
	if product then
		grantProduct(player, profile, product)
		return true
	elseif pass and owned[player] then
		owned[player][pass.Key] = true
		return true
	end
	return false
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	local stateRemote = Remotes.get("StoreGetState") :: RemoteFunction
	local buyRemote = Remotes.get("StoreBuy") :: RemoteFunction
	local grantRemote = Remotes.get("StudioGrant") :: RemoteFunction
	stateRemote.OnServerInvoke = buildState
	buyRemote.OnServerInvoke = buy
	grantRemote.OnServerInvoke = studioGrant

	local function onPlayerAdded(player: Player)
		owned[player] = {}
		task.spawn(loadPolicy, player)
		task.spawn(refreshPasses, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		restricted[player] = nil
		policyLoaded[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			for _, pass in MonetizationConfig.Passes do
				if pass.Id == passId and owned[player] then
					owned[player][pass.Key] = true
				end
			end
		end
	)
end

return MonetizationService
