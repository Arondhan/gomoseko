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

export type RingDef = {
	Id: string,
	Name: string,
	Description: string,
	SkillId: string,
	Color: Color3,
	Rarity: string,
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

-- Ответ сервера на запрос каста
export type CastResult = {
	ok: boolean,
	reason: string?,
}

return {}
