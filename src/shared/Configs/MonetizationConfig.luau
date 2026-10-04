--!strict
-- Продукты за Robux. Id = 0 — «не настроено»: создайте Developer Product / Game Pass в Creator Hub и впишите ID.
-- Developer Products — расходуемые (пачки кристаллов, зелья удачи). Game Passes — постоянные.
--
-- ВАЖНО (политика Roblox «Paid Random Items»): всё, что даёт случайные предметы за Robux или за купленную за Robux
-- валюту (кристаллы), и всё, что меняет шансы (зелья, LuckyCharm), обязано показывать числовые шансы ДО покупки.
-- В интерфейсе это окно Summon → «Odds / Details»; описания ниже с числами показываются в Store.

local MonetizationConfig = {}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	Kind: "Crystals" | "LuckPotion",
	Crystals: number?,
	LuckPercent: number?, -- +% к удаче на время действия
	DurationSeconds: number?,
}

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	LuckPercent: number?, -- постоянный +% к удаче
}

MonetizationConfig.Products = {
	{
		Key = "Crystals_S",
		Id = 0,
		Name = "Handful of Crystals",
		Description = "100 Summon Crystals (10 summons).",
		Kind = "Crystals",
		Crystals = 100,
	},
	{
		Key = "Crystals_M",
		Id = 0,
		Name = "Pouch of Crystals",
		Description = "550 Summon Crystals (55 summons, +10% bonus).",
		Kind = "Crystals",
		Crystals = 550,
	},
	{
		Key = "Crystals_L",
		Id = 0,
		Name = "Chest of Crystals",
		Description = "1200 Summon Crystals (120 summons, +20% bonus).",
		Kind = "Crystals",
		Crystals = 1200,
	},
	{
		Key = "LuckPotion_I",
		Id = 0,
		Name = "Luck Potion I",
		Description = "+100% Luck for 15 minutes: doubles the chance of finding every ring except the most common one (exact numbers: Summon → Odds).",
		Kind = "LuckPotion",
		LuckPercent = 100,
		DurationSeconds = 900,
	},
	{
		Key = "LuckPotion_II",
		Id = 0,
		Name = "Luck Potion II",
		Description = "+300% Luck for 15 minutes: quadruples the chance of finding every ring except the most common one (exact numbers: Summon → Odds).",
		Kind = "LuckPotion",
		LuckPercent = 300,
		DurationSeconds = 900,
	},
} :: { Product }

MonetizationConfig.Passes = {
	{
		Key = "AutoRoll",
		Id = 0,
		Name = "Auto Roll",
		Description = "Unlocks automatic summoning in the Summon window (stops on Epic or better).",
	},
	{
		Key = "FastRoll",
		Id = 0,
		Name = "Fast Roll",
		Description = "Summon twice as fast.",
	},
	{
		Key = "LuckyCharm",
		Id = 0,
		Name = "Lucky Charm",
		Description = "+25% Luck, permanently: raises the chance of finding every ring except the most common one by 25% (exact numbers: Summon → Odds).",
		LuckPercent = 25,
	},
} :: { Pass }

MonetizationConfig.ProductsByKey = {} :: { [string]: Product }
for _, product in MonetizationConfig.Products do
	MonetizationConfig.ProductsByKey[product.Key] = product
end

MonetizationConfig.PassesByKey = {} :: { [string]: Pass }
for _, pass in MonetizationConfig.Passes do
	MonetizationConfig.PassesByKey[pass.Key] = pass
end

return MonetizationConfig
