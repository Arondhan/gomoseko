-- Точка входа клиента: мультяшный UI (толстый шрифт, яркие плитки меню слева) и запуск контроллеров боя.
-- UI: фреймы игрока и цели (HP/мана), 4 слота для колец внизу по центру, меню-плитки слева, валюты слева внизу.
-- Контроллеры: инвентарь колец, таргет, скиллы; VFX: отрисовка молнии.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local RingsConfig = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Configs")
		:WaitForChild("Rings")
		:WaitForChild("RingsConfig")
)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local Fonts = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Fonts"))
task.spawn(Fonts.preload) -- прогрев шрифтов, чтобы текст не «мигал» при первом показе

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local TargetController = require(Controllers:WaitForChild("TargetController"))
local SkillController = require(Controllers:WaitForChild("SkillController"))
local GachaController = require(Controllers:WaitForChild("GachaController"))
local SettingsController = require(Controllers:WaitForChild("SettingsController"))
local DpsController = require(Controllers:WaitForChild("DpsController"))
local LuckController = require(Controllers:WaitForChild("LuckController"))
local RiftController = require(Controllers:WaitForChild("RiftController"))
local IndexController = require(Controllers:WaitForChild("IndexController"))
local GachaConfig = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("GachaConfig")
)
local LightningRenderer = require(script.Parent:WaitForChild("VFX"):WaitForChild("LightningRenderer"))
local DamageNumbers = require(script.Parent:WaitForChild("VFX"):WaitForChild("DamageNumbers"))
local TorchFlicker = require(script.Parent:WaitForChild("VFX"):WaitForChild("TorchFlicker"))
local SkillEffects = require(script.Parent:WaitForChild("VFX"):WaitForChild("SkillEffects"))
local TitleGradient = require(script.Parent:WaitForChild("VFX"):WaitForChild("TitleGradient"))
local Sfx = require(script.Parent:WaitForChild("VFX"):WaitForChild("Sfx"))
local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sounds"))

local ui = script.Parent:WaitForChild("ui")
local Theme = require(ui:WaitForChild("Theme"))
local RingsWindow = require(ui:WaitForChild("RingsWindow"))
local SkillPad = require(ui:WaitForChild("SkillPad"))
local AdminWindow = require(ui:WaitForChild("AdminWindow"))
local RiftHud = require(ui:WaitForChild("RiftHud"))
local RiftTelegraph = require(script.Parent:WaitForChild("VFX"):WaitForChild("RiftTelegraph"))
local RiftWindow = require(ui:WaitForChild("RiftWindow"))
local SideMenu = require(ui:WaitForChild("SideMenu"))
local BoostWindow = require(ui:WaitForChild("BoostWindow"))
local Drag = require(ui:WaitForChild("Drag"))
local Shop = require(ui:WaitForChild("Shop"))
local Summon = require(ui:WaitForChild("Summon"))
local CurrencyBar = require(ui:WaitForChild("CurrencyBar"))
local LuckHud = require(ui:WaitForChild("LuckHud"))
local IndexWindow = require(ui:WaitForChild("IndexWindow"))
local SettingsWindow = require(ui:WaitForChild("SettingsWindow"))
local DpsMeter = require(ui:WaitForChild("DpsMeter"))
local Leaderboard = require(ui:WaitForChild("Leaderboard"))
local OnboardingTracker = require(ui:WaitForChild("OnboardingTracker"))
local PlayerFrame = require(ui:WaitForChild("PlayerFrame"))
local Tooltip = require(ui:WaitForChild("Tooltip"))
local Notice = require(ui:WaitForChild("Notice"))
local XpBar = require(ui:WaitForChild("XpBar"))

-- стандартный рюкзак мешает клавишам 1-4, а стандартная полоска здоровья дублирует PlayerFrame
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("HubUI")
if old then
	old:Destroy()
end

local gui = Theme.new("ScreenGui", {
	Name = "HubUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 10,
}, playerGui)

-- масштаб интерфейса: на маленьких экранах (телефон) уменьшаем, на больших (1080p и выше) увеличиваем — шрифты читаемы
local uiScale = Theme.new("UIScale", { Scale = 1 }, gui)
local function updateScale()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 1080
	uiScale.Scale = math.clamp(height / 800, 0.6, 1.4)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
local isPhone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

PlayerFrame.build(gui)
local notice = Notice.build(gui)
XpBar.build(gui)
local tooltip = Tooltip.build(gui, SkillController.getSkill)

-- перенос кольца ИЗ слота окна Rings: на другой слот — обмен, в пустоту — снять
local function startSlotDrag(ring: any, fromSlot: number)
	Drag.start(gui, ring, function(slot)
		if slot == nil then
			InventoryController.unequip(fromSlot)
		elseif slot ~= fromSlot then
			InventoryController.equip(ring.Id, slot)
		end
	end)
end

-- слоты с кольцами, дающими скилл, по порядку: первый — большая кнопка Attack, остальные — малые кнопки
local function skillSlots(): { number }
	local list: { number } = {}
	for slot = 1, 4 do
		local ring = InventoryController.getRingInSlot(slot)
		if ring and ring.SkillId then
			table.insert(list, slot)
		end
	end
	return list
end

local pad = SkillPad.build(gui, {
	tooltip = tooltip,
	onPress = function(index: number)
		local slot = skillSlots()[index]
		if slot then
			SkillController.castSlot(slot)
		elseif index == 1 then
			notice.show("Wear a ring with a skill: open Rings", Theme.Warn)
		end
	end,
})

-- анимация нажатия кнопки, соответствующей слоту (каст клавишей)
local function pressSlot(slot: number)
	pad.press(table.find(skillSlots(), slot))
end
local menu = SideMenu.build(gui, tooltip)
local currencyBar = CurrencyBar.build(gui, tooltip)
local luckHud = LuckHud.build(gui, { luck = LuckController, tooltip = tooltip, notify = notice.show })

-- на телефоне слева внизу стик, справа внизу кнопка прыжка Roblox: меню уменьшаем, валюты и удачу переносим вверх вправо
if isPhone then
	Theme.new("UIScale", { Scale = 0.8 }, menu.frame)
	menu.frame.Position = UDim2.fromOffset(16, 160)
	currencyBar.frame.AnchorPoint = Vector2.new(1, 0)
	currencyBar.frame.Position = UDim2.new(1, -8, 0, 54)
	luckHud.afk.AnchorPoint = Vector2.new(1, 0)
	luckHud.afk.Position = UDim2.new(1, -8, 0, 178)
	luckHud.afk.TextXAlignment = Enum.TextXAlignment.Right
	pad.frame.Position = UDim2.new(1, -190, 1, -40) -- левее кнопки прыжка Roblox
end
OnboardingTracker.build(gui, function()
	notice.show("Tutorial complete! Crystals added.", Theme.GoldLight)
end)

local rings = RingsWindow.build(gui, {
	controller = InventoryController,
	tooltip = tooltip,
	startDrag = startSlotDrag,
})

-- цель переноса колец: слоты окна Rings
Drag.registerTarget({ getSlotAtPosition = rings.getSlotAtPosition, highlight = rings.highlightSlot })

local summon = Summon.build(gui, {
	gacha = GachaController,
	tooltip = tooltip,
	notify = notice.show,
	settings = SettingsController,
})

-- окна и привязка к кнопкам меню
local indexMilestones: { number } = {}
for _, milestone in GachaConfig.Index.Milestones do
	table.insert(indexMilestones, milestone.Percent)
end
local shopWindow = Shop.build(gui, { notify = notice.show, openOdds = summon.openOdds, gacha = GachaController })
local boostWindow = BoostWindow.build(gui, {
	gacha = GachaController,
	luck = LuckController,
	openStore = function()
		shopWindow.setOpen(true)
	end,
})
local windows = {
	{ window = rings.window, button = menu.rings, key = Enum.KeyCode.C },
	{ window = rings.window, key = Enum.KeyCode.I },
	{
		window = IndexWindow.build(gui, {
			index = IndexController,
			tooltip = tooltip,
			notify = notice.show,
			milestones = indexMilestones,
		}),
		button = menu.index,
		key = Enum.KeyCode.N,
	},
	{ window = summon.window, button = menu.summon, key = Enum.KeyCode.G },
	{ window = Leaderboard.build(gui, { dps = DpsController }), button = menu.ranks, key = Enum.KeyCode.L },
	{
		window = SettingsWindow.build(gui, { settings = SettingsController }),
		button = menu.settings,
		key = Enum.KeyCode.O,
	},
	{ window = shopWindow, button = menu.shop, key = Enum.KeyCode.B },
	{
		window = RiftWindow.build(gui, { rift = RiftController, notify = notice.show }),
		button = menu.rift,
		key = Enum.KeyCode.T,
	},
	{ window = boostWindow, button = menu.boost, key = Enum.KeyCode.V },
}

for _, entry in windows do
	if entry.button then
		entry.button.click.Event:Connect(entry.window.toggle)
		entry.window.changed.Event:Connect(entry.button.setActive)
	end
end

-- админ-меню: сервер говорит, админ ли игрок; окно строится только для админов (все действия проверяются на сервере)
task.spawn(function()
	local ok, result = pcall(function()
		return (Remotes.get("AdminGet") :: RemoteFunction):InvokeServer()
	end)
	if not (ok and type(result) == "table" and result.admin == true) then
		return
	end
	local adminWindow = AdminWindow.build(gui, { notify = notice.show })
	menu.admin.frame.Visible = true
	menu.admin.click.Event:Connect(adminWindow.toggle)
	adminWindow.changed.Event:Connect(menu.admin.setActive)
	table.insert(windows, { window = adminWindow, button = menu.admin, key = Enum.KeyCode.F2 })
end)

-- красные точки: есть бесплатный ролл / можно забрать награду Index
local function refreshPings()
	local gachaState = GachaController.getState()
	menu.summon.setPing(gachaState ~= nil and GachaController.freeRollIn() <= 0)
	local indexState = IndexController.getState()
	local claimable = false
	if indexState then
		for _, milestone in indexState.milestones do
			if milestone.reached and not milestone.claimed then
				claimable = true
			end
		end
	end
	menu.index.setPing(claimable)
end
IndexController.changed.Event:Connect(refreshPings)
GachaController.stateChanged.Event:Connect(refreshPings)
task.spawn(function()
	while true do
		refreshPings()
		task.wait(5)
	end
end)

-- DPS-арена: панель замера и недельная награда
DpsMeter.build(gui, DpsController)
DpsController.status.Event:Connect(function(status)
	if status.kind == "WeeklyReward" then
		notice.show(
			string.format("Weekly DPS reward: rank #%d  +%d crystals!", status.rank or 0, status.crystals or 0),
			Theme.GoldLight
		)
	end
end)

-- редкая находка любого игрока -> объявление всем
GachaController.announced.Event:Connect(function(info)
	local ring = RingsConfig.Rings[info.ringId]
	if ring then
		notice.show(
			string.format("%s found the %s (1 in %s)!", info.playerName, ring.Name, tostring(info.oneIn)),
			Theme.Quality[ring.Quality]
		)
	end
end)

-- кольца из состояния сервера -> слоты окна Rings и кнопки скиллов
InventoryController.changed.Event:Connect(function()
	task.spawn(IndexController.refresh) -- возможно, найдено новое кольцо
	tooltip.hide()
	for i = 1, rings.slotCount do
		rings.setSlot(i, InventoryController.getRingInSlot(i))
	end
	local entries: { { ring: any, slot: number }? } = {}
	for _, slot in skillSlots() do
		table.insert(entries, { ring = InventoryController.getRingInSlot(slot), slot = slot })
	end
	pad.setSkills(entries)
end)

-- кулдауны на кнопках скиллов (каждый кадр, только отображение)
RunService.RenderStepped:Connect(function()
	local slots = skillSlots()
	for index = 1, pad.count do
		local ring = if slots[index] then InventoryController.getRingInSlot(slots[index]) else nil
		if ring and ring.SkillId then
			local remaining, total = SkillController.getCooldown(ring.SkillId)
			pad.setCooldown(index, remaining, total)
		else
			pad.setCooldown(index, 0, 0)
		end
	end
end)

-- звук начала каста (заряд молнии) — только у самого кастера
SkillController.castStarted.Event:Connect(function(skillName: string)
	local sound = if skillName == "Arc Lightning" then "ArcLightningCharge" else "FireballCast"
	Sfx.play2D(Sounds.id(sound), 0.8)
end)

-- «ding» при повышении уровня (атрибут Level растёт на сервере)
local lastLevel = localPlayer:GetAttribute("Level")
localPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	local level = localPlayer:GetAttribute("Level")
	if type(level) == "number" and type(lastLevel) == "number" and level > lastLevel then
		notice.show("Level Up: " .. level .. "!", Theme.GoldLight)
	end
	lastLevel = level
end)

-- запуск контроллеров (они ждут ремоуты, которые создаёт server/Main)
DpsController.start()
SettingsController.start()
InventoryController.start()
GachaController.start()
LuckController.start()
RiftController.start()
RiftTelegraph.start()
RiftController.weekly.Event:Connect(function(weekly)
	notice.show(
		string.format("Weekly Rift reward: rank #%d  +%d crystals!", weekly.rank, weekly.crystals),
		Theme.GoldLight
	)
end)
RiftHud.build(gui, { rift = RiftController, notify = notice.show })
-- вход в Rift через портал: отказ сервера (нет кольца со скиллом и т.п.) приходит атрибутом
localPlayer:GetAttributeChangedSignal("RiftMessage"):Connect(function()
	local value = localPlayer:GetAttribute("RiftMessage")
	if type(value) == "string" then
		notice.show((string.split(value, "|"))[1], Theme.Danger)
	end
end)
IndexController.start()
TargetController.start()
SkillController.start(notice.show, pressSlot)
LightningRenderer.start()
SkillEffects.start()
DamageNumbers.start()
TorchFlicker.start()
TitleGradient.start()

local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

UserInputService.InputBegan:Connect(function(input, processed)
	-- Esc закрывает окна даже если его обработал CoreGui
	if input.KeyCode == Enum.KeyCode.Escape then
		for _, entry in windows do
			entry.window.setOpen(false)
		end
		TargetController.clear() -- Esc снимает цель
		return
	end
	if processed then
		return
	end
	for i, key in slotKeys do
		if input.KeyCode == key then
			pressSlot(i)
			SkillController.castSlot(i)
			return
		end
	end
	for _, entry in windows do
		if input.KeyCode == entry.key then
			entry.window.toggle()
			return
		end
	end
end)
