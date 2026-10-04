--!strict
-- Чистая проверка доступа к админ-меню (без Roblox API — проверяется в CLI). Вызывается только на сервере.

local AdminAccess = {}

export type Config = {
	Enabled: boolean,
	AllowStudio: boolean,
	AllowOwner: boolean,
	UserIds: { number },
}

-- userId — кто спрашивает; isStudio — игра запущена в Studio; creatorId/creatorIsUser — владелец места
function AdminAccess.isAllowed(
	userId: number,
	config: Config,
	isStudio: boolean,
	creatorId: number,
	creatorIsUser: boolean
): boolean
	if not config.Enabled then
		return false
	end
	if config.AllowStudio and isStudio then
		return true
	end
	if config.AllowOwner and creatorIsUser and userId == creatorId and creatorId > 0 then
		return true
	end
	return table.find(config.UserIds, userId) ~= nil
end

return AdminAccess
