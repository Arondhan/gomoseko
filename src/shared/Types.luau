--!strict
-- Общие типы для боевой системы / инвентаря колец. Только типы — кода здесь нет.

export type SkillConfig = {
	Id: string,
	Name: string,
	CastRange: number,
	Damage: number,
	MaxBounces: number,
	BounceRadius: number,
	BounceDelay: number,
	Cooldown: number,
	ManaCost: number,
	CastTime: number, -- время каста, сек (0 = мгновенно, cast bar скрыт)
	DefaultKey: Enum.KeyCode?,
	Color: Color3,
	CoreColor: Color3,
	Width: number,
	CoreWidth: number,
	ZigzagSegments: number,
	ZigzagAmplitude: number,
	FadeTime: number,
	SoundId: string,
	SoundVolume: number,
}

export type Quality = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Divine"

-- Пассивные бонусы кольца (суммируются по надетым кольцам, см. server/Services/StatsService)
export type RingStats = {
	DamagePct: number?, -- +% к урону скиллов
	MaxMana: number?,
	ManaRegen: number?, -- +ед. маны в секунду
	CooldownReductionPct: number?, -- -% к перезарядке скиллов
	CastRange: number?, -- +studs к дальности каста
	LuckPct: number?, -- +% к удаче призыва
}

export type RingDef = {
	Id: string,
	Name: string,
	Description: string,
	SkillId: string?, -- скилл, который даёт кольцо (nil — кольцо только с пассивными бонусами)
	Color: Color3,
	Quality: Quality,
	OneIn: number, -- базовый шанс выпадения в Gacha: «1 из N» (при удаче ×1)
	Stats: RingStats,
	Image: string?, -- необязательно: "rbxassetid://..." заменяет процедурную иконку
}

-- Состояние инвентаря игрока: список предметов и надетые кольца по слотам 1..N.
-- equipped — плотный массив длиной RingSlotCount, пустой слот = "" (так массив безопасно ходит через ремоуты).
export type InventoryState = {
	items: { string },
	equipped: { string },
}

-- Одно звено цепной молнии (сервер -> все клиенты, только для визуала)
export type LightningHop = {
	skillId: string,
	casterUserId: number,
	hopIndex: number,
	from: Vector3,
	to: Vector3,
}

-- Ответ сервера на запрос каста (castTime — сколько секунд длится каст, для cast bar)
export type CastResult = {
	ok: boolean,
	reason: string?,
	castTime: number?,
	cooldown: number?, -- фактическая перезарядка с учётом бонусов колец (для таймера на клиенте)
}

-- Нанесённый урон (сервер -> клиент кастера, для плавающих цифр)
export type DamageEvent = {
	skillId: string,
	position: Vector3,
	amount: number,
}

-- Gacha: результат одного призыва
export type RollResult = {
	ringId: string,
	quality: Quality,
	oneIn: number,
	isNew: boolean, -- кольца не было в инвентаре
	essence: number, -- Ring Essence за дубликат (0, если кольцо новое)
}

-- Строка таблицы шансов (проценты в виде строк: сумма всех исходов ровно 100 %)
export type OddsRing = {
	ringId: string,
	name: string,
	oneIn: number, -- базовая редкость кольца (при удаче ×1)
	percent: string, -- фактический шанс в процентах при текущей удаче, «0.000002»
	effective: string, -- он же в виде «1 in 50,000,000»
}

export type OddsGroup = {
	quality: Quality,
	percent: string,
	rings: { OddsRing },
}

export type LuckSource = { name: string, percent: number }

export type GachaState = {
	crystals: number,
	essence: number,
	rollCost: number,
	multiCount: number,
	luck: number, -- итоговый множитель удачи
	luckSources: { LuckSource },
	odds: { OddsGroup },
	freeRollIn: number, -- секунд до бесплатного ролла (0 — доступен)
	paidRestricted: boolean, -- платные призывы недоступны в регионе игрока (политика Roblox)
	passes: { [string]: boolean },
	rolls: number,
}

-- AFK Playtime Luck (сервер -> клиент). Времена — относительные секунды на момент отправки.
export type PlaytimeLuck = {
	steps: number,
	percent: number, -- бонус к удаче в процентах
	bonus: number, -- в «иксах»: 0.2 = +0.2x
	maxBonus: number, -- максимум (1.0 = +1.0x)
	stepBonus: number, -- сколько даёт один шаг (0.1)
	nextIn: number?, -- секунд до следующего шага (nil — максимум)
}

-- Lucky Hour (сервер -> клиент)
export type LuckEventStatus = {
	name: string,
	active: boolean,
	endsIn: number, -- секунд до конца (если активно)
	startsIn: number, -- секунд до начала следующего (если не активно)
	percent: number, -- бонус к удаче в процентах
}

export type LuckBoosts = { playtime: PlaytimeLuck, event: LuckEventStatus }

-- Index (книга колец)
export type IndexMilestone = {
	percent: number,
	crystals: number,
	essence: number,
	need: number, -- сколько колец нужно для вехи
	reached: boolean,
	claimed: boolean,
}

export type IndexState = {
	discovered: { string }, -- id найденных колец
	total: number,
	milestones: { IndexMilestone },
}

export type IndexClaimResponse = { ok: boolean, reason: string?, state: IndexState? }

export type GachaRollResponse = {
	ok: boolean,
	reason: string?,
	results: { RollResult }?,
	state: GachaState?,
}

export type GachaAnnounce = {
	playerName: string,
	ringId: string,
	oneIn: number,
}

-- Магазин (Robux): строка продукта или геймпасса
export type StoreItem = {
	key: string,
	id: number, -- 0 = не настроен в Creator Hub
	name: string,
	description: string,
	kind: "Crystals" | "LuckPotion" | "Pass",
	isPass: boolean,
	owned: boolean, -- для геймпассов
}

export type StoreState = {
	items: { StoreItem },
	restricted: boolean, -- платные случайные предметы запрещены в регионе игрока: платные товары скрыты
	studio: boolean, -- Studio: доступны тестовые гранты без Robux
}

-- Настройки игрока (хранятся в профиле)
export type Settings = {
	SfxVolume: number, -- 0..1
	LowQuality: boolean?, -- nil = автоопределение (телефон -> true)
	Cinematic: boolean?, -- катсцены редких находок (nil = включено)
	Shake: boolean?, -- тряска экрана (nil = включено)
	SkipAnim: boolean?, -- быстрый ролл без анимации (nil = выключено)
	Haptics: boolean?, -- вибрация (nil = включено)
}

-- DPS-арена
export type DpsEntry = { rank: number, userId: number, name: string, score: number } -- score = DPS × 10

export type DpsBoards = { daily: { DpsEntry }, weekly: { DpsEntry }, allTime: { DpsEntry } }

export type DpsBest = { daily: number, weekly: number, allTime: number }

export type DpsBoardsResponse = {
	boards: DpsBoards,
	best: DpsBest, -- личные рекорды игрока (DPS × 10)
	source: string, -- "datastore" или "memory" (если DataStore недоступен)
	updated: number, -- unix-время последнего обновления таблиц
	dayEndsIn: number, -- секунд до конца дня (UTC)
	weekEndsIn: number, -- секунд до конца недели (UTC)
}

export type DpsStatus = {
	kind: "Running" | "Finished" | "WeeklyReward",
	elapsed: number?,
	duration: number?,
	total: number?,
	dps: number?, -- DPS × 10
	best: DpsBest?,
	newBest: boolean?, -- новый личный рекорд за день
	xp: number?,
	gold: number?,
	crystals: number?,
	rank: number?, -- для WeeklyReward: место прошлой недели
}

return {}
