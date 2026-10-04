-- Точка входа клиента: UI в стиле WoW (Dragonflight) и запуск контроллеров боя.
-- UI: фреймы игрока и цели (HP/мана), 4 слота для колец внизу по центру, меню (Инвентарь, Магазин) справа внизу.
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
local Fonts = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Fonts"))
task.spawn(Fonts.preload) -- прогрев шрифтов, чтобы текст не «мигал» при первом показе

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local TargetController = require(Controllers:WaitForChild("TargetController"))
local SkillController = require(Controllers:WaitForChild("SkillController"))
local GachaController = require(Controllers:WaitForChild("GachaController"))
local LightningRenderer = require(script.Parent:WaitForChild("VFX"):WaitForChild("LightningRenderer"))
local DamageNumbers = require(script.Parent:WaitForChild("VFX"):WaitForChild("DamageNumbers"))
local TorchFlicker = require(script.Parent:WaitForChild("VFX"):WaitForChild("TorchFlicker"))
local Sfx = require(script.Parent:WaitForChild("VFX"):WaitForChild("Sfx"))
local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sounds"))

local ui = script.Parent:WaitForChild("ui")
local Theme = require(ui:WaitForChild("Theme"))
local RingBar = require(ui:WaitForChild("RingBar"))
local MicroMenu = require(ui:WaitForChild("MicroMenu"))
local Inventory = require(ui:WaitForChild("Inventory"))
local Character = require(ui:WaitForChild("Character"))
local Drag = require(ui:WaitForChild("Drag"))
local Shop = require(ui:WaitForChild("Shop"))
local Summon = require(ui:WaitForChild("Summon"))
local CurrencyBar = require(ui:WaitForChild("CurrencyBar"))
local PlayerFrame = require(ui:WaitForChild("PlayerFrame"))
local TargetFrame = require(ui:WaitForChild("TargetFrame"))
local Tooltip = require(ui:WaitForChild("Tooltip"))
local Notice = require(ui:WaitForChild("Notice"))
local XpBar = require(ui:WaitForChild("XpBar"))
local CastBar = require(ui:WaitForChild("CastBar"))

-- стандартный рюкзак мешает клавишам 1-4, а стандартная полоска здоровья дублирует PlayerFrame
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- Tab теперь выбирает цель
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

PlayerFrame.build(gui)
local targetFrame = TargetFrame.build(gui)
local notice = Notice.build(gui)
XpBar.build(gui)
local castBar = CastBar.build(gui)
local tooltip = Tooltip.build(gui, SkillController.getSkill)

-- перенос кольца ИЗ слота (панель колец или окно персонажа): на другой слот — обмен, в пустоту — снять
local function startSlotDrag(ring: any, fromSlot: number)
	Drag.start(gui, ring, function(slot)
		if slot == nil then
			InventoryController.unequip(fromSlot)
		elseif slot ~= fromSlot then
			InventoryController.equip(ring.Id, slot)
		end
	end)
end

local ringBar = RingBar.build(gui, {
	onDragStart = function(slot)
		local ring = InventoryController.getRingInSlot(slot)
		if ring then
			startSlotDrag(ring, slot)
		end
	end,
	onActivate = SkillController.castSlot, -- ЛКМ по слоту = нажатие его клавиши
	onUnequip = InventoryController.unequip, -- ПКМ по слоту снимает кольцо
	onHover = function(slot)
		local ring = if slot then InventoryController.getRingInSlot(slot) else nil
		if ring then
			tooltip.showRing(ring)
		else
			tooltip.hide()
		end
	end,
})
local menu = MicroMenu.build(gui, tooltip)
CurrencyBar.build(gui, tooltip)

local character = Character.build(gui, {
	controller = InventoryController,
	tooltip = tooltip,
	startDrag = startSlotDrag,
})

-- цели переноса колец: панель колец и окно персонажа
Drag.registerTarget({ getSlotAtPosition = ringBar.getSlotAtPosition, highlight = ringBar.highlightSlot })
Drag.registerTarget({ getSlotAtPosition = character.getSlotAtPosition, highlight = character.highlightSlot })

local summon = Summon.build(gui, { gacha = GachaController, tooltip = tooltip, notify = notice.show })

-- окна и привязка к кнопкам меню
local windows = {
	{ window = character.window, button = menu.character, key = Enum.KeyCode.C },
	{
		window = Inventory.build(gui, { controller = InventoryController, tooltip = tooltip }),
		button = menu.inventory,
		key = Enum.KeyCode.I,
	},
	{ window = summon.window, button = menu.summon, key = Enum.KeyCode.G },
	{
		window = Shop.build(gui, { notify = notice.show, openOdds = summon.openOdds, gacha = GachaController }),
		button = menu.shop,
		key = Enum.KeyCode.B,
	},
}

for _, entry in windows do
	entry.button.click.Event:Connect(entry.window.toggle)
	entry.window.changed.Event:Connect(entry.button.setActive)
end

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

-- кольца из состояния сервера -> иконки в слотах RingBar
InventoryController.changed.Event:Connect(function()
	tooltip.hide()
	for i = 1, ringBar.slotCount do
		local ring = InventoryController.getRingInSlot(i)
		ringBar.setSlot(i, ring)
		character.setSlot(i, ring)
	end
end)

-- оверлей кулдауна на слотах (каждый кадр, только отображение)
RunService.RenderStepped:Connect(function()
	for i = 1, ringBar.slotCount do
		local ring = InventoryController.getRingInSlot(i)
		if ring then
			local remaining, total = SkillController.getCooldown(ring.SkillId)
			ringBar.setCooldown(i, remaining, total)
		else
			ringBar.setCooldown(i, 0, 0)
		end
	end
end)

-- таргет -> фрейм цели
TargetController.changed.Event:Connect(function(model)
	targetFrame.setTarget(model)
end)

-- cast bar следует за событиями скилл-контроллера
SkillController.castStarted.Event:Connect(castBar.start)
-- звук начала каста (заряд молнии) — только у самого кастера
SkillController.castStarted.Event:Connect(function()
	Sfx.play2D(Sounds.id("ArcLightningCharge"), 0.8)
end)
SkillController.castFinished.Event:Connect(castBar.finish)
SkillController.castCancelled.Event:Connect(castBar.cancel)

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
InventoryController.start()
GachaController.start()
TargetController.start(notice.show)
SkillController.start(notice.show, ringBar.press)
LightningRenderer.start()
DamageNumbers.start()
TorchFlicker.start()

local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

UserInputService.InputBegan:Connect(function(input, processed)
	-- Esc закрывает окна даже если его обработал CoreGui
	if input.KeyCode == Enum.KeyCode.Escape then
		for _, entry in windows do
			entry.window.setOpen(false)
		end
		TargetController.clear() -- как в WoW: Esc снимает цель
		return
	end
	if processed then
		return
	end
	for i, key in slotKeys do
		if input.KeyCode == key then
			ringBar.press(i)
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
