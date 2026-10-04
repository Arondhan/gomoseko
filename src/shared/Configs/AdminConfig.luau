--!strict
-- Доступ к админ-меню (F2 или плитка «Admin»). Проверка делается на сервере (AdminService) при каждом действии.
-- В Studio меню доступно всегда (AllowStudio); на живом сервере — владельцу игры (если место принадлежит
-- пользователю) и тем, чей UserId вписан сюда. Свой UserId смотрите на странице профиля Roblox (число в адресе).

local AdminConfig = {
	Enabled = true, -- false выключает админ-меню совсем (рекомендуется для релиза без тестов)
	AllowStudio = true,
	AllowOwner = true,
	UserIds = {} :: { number }, -- например { 123456789 }
}

return AdminConfig
