--!strict
-- Единая точка доступа к ремоутам. Сервер создаёт их в Remotes.init() (ReplicatedStorage.Remotes),
-- клиент получает через Remotes.get(name) (ждёт появления).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

-- имя -> класс. Здесь же документируем направление и формат.
local DEFINITIONS: { [string]: string } = {
	CastSkill = "RemoteFunction", -- клиент -> сервер: (skillId: string, target: Model?) -> CastResult
	SkillVFX = "RemoteEvent", -- сервер -> все клиенты: LightningHop
	InventoryGet = "RemoteFunction", -- клиент -> сервер: () -> InventoryState
	InventoryEquip = "RemoteFunction", -- клиент -> сервер: (itemId: string, slot: number) -> boolean
	InventoryUnequip = "RemoteFunction", -- клиент -> сервер: (slot: number) -> boolean
	InventoryChanged = "RemoteEvent", -- сервер -> клиент: InventoryState
	DamageDealt = "RemoteEvent", -- сервер -> клиент нанёсшего урон: DamageEvent
	GachaGetState = "RemoteFunction", -- клиент -> сервер: () -> GachaState
	GachaRoll = "RemoteFunction", -- клиент -> сервер: (count: number, free: boolean) -> GachaRollResponse
	GachaAnnounce = "RemoteEvent", -- сервер -> все клиенты: GachaAnnounce (редкая находка)
	StoreGetState = "RemoteFunction", -- клиент -> сервер: () -> StoreState
	StoreBuy = "RemoteFunction", -- клиент -> сервер: (key: string) -> (ok: boolean, reason: string?)
	StudioGrant = "RemoteFunction", -- клиент -> сервер: (key: string) -> boolean; работает только в Studio (тест без Robux)
	DpsStatus = "RemoteEvent", -- сервер -> клиент: DpsStatus (идёт замер / замер завершён / недельная награда)
	DpsGetBoards = "RemoteFunction", -- клиент -> сервер: () -> DpsBoardsResponse
	SettingsGet = "RemoteFunction", -- клиент -> сервер: () -> Settings
	SettingsSet = "RemoteFunction", -- клиент -> сервер: (key: string, value: any) -> boolean
	LuckBoostsGet = "RemoteFunction", -- клиент -> сервер: () -> LuckBoosts (AFK-удача + Lucky Hour)
	PlaytimeLuck = "RemoteEvent", -- сервер -> клиент: PlaytimeLuck (шаг AFK-удачи изменился)
	LuckEvent = "RemoteEvent", -- сервер -> все клиенты: LuckEventStatus (Lucky Hour начался/закончился)
	CastCancelled = "RemoteEvent", -- сервер -> клиент кастера: (skillId: string, reason: string) — каст сорван
}

-- Только сервер: создаёт папку и все ремоуты
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() can only be called on the server")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

-- Сервер и клиент: получить ремоут (клиент ждёт, пока сервер его создаст)
function Remotes.get(name: string): Instance
	assert(DEFINITIONS[name], "Unknown remote: " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Remotes
