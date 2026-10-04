--!strict
-- Бейдж уровня «Lv N» и кнопка ▲ улучшения на кольце (ячейка сетки или слот в окне Rings). ▲ зелёная, если хватает
-- Essence и Gold на следующий уровень, серая — если нет; на максимальном уровне скрыта. Тап по ▲ просит сервер
-- улучшить кольцо (InventoryController.upgrade), тап по самому кольцу работает как раньше (надеть/снять).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PowerConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PowerConfig"))
local PowerMath = require(Shared:WaitForChild("Combat"):WaitForChild("PowerMath"))

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local RingBadges = {}

local AFFORD = Color3.fromRGB(70, 200, 90)
local BROKE = Color3.fromRGB(110, 118, 140)

local localPlayer = Players.LocalPlayer

local function balance(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- ring — определение кольца; controller — InventoryController; notify(text, color?) — сообщение игроку.
-- Возвращает { update = () -> (), destroy = () -> () }: пересчитать бейдж и цвет ▲ / убрать их с кольца.
function RingBadges.add(parent: GuiObject, ring: any, controller: any, notify: (string, Color3?) -> ())
	local z = parent.ZIndex + 10
	local badge = Chrome.label(parent, {
		Name = "LevelBadge",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 3, 1, -1),
		Size = UDim2.fromOffset(40, 18),
		Text = "",
		TextSize = Theme.TextSize.Small - 2,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = z,
	})
	local button = Theme.new("TextButton", {
		Name = "UpgradeButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = BROKE,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "▲",
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		ZIndex = z + 1,
	}, parent)
	Theme.corner(button, 6)
	Chrome.bevel(button, 1, 6, true)

	local api: { update: () -> (), destroy: () -> () } = {} :: any
	function api.update()
		local level = controller.getLevel(ring.Id)
		badge.Text = "Lv " .. level
		local essence, gold =
			PowerMath.upgradeCost(PowerConfig.QualityMultiplier[ring.Quality] or 1, level, PowerConfig.Rings)
		if essence and gold then
			button.Visible = true
			button.BackgroundColor3 = if balance("Essence") >= essence and balance("Gold") >= gold
				then AFFORD
				else BROKE
		else
			button.Visible = false -- максимальный уровень
		end
	end

	button.MouseButton1Click:Connect(function()
		task.spawn(function()
			local ok, message = controller.upgrade(ring.Id)
			notify(message, if ok then Theme.Good else Theme.Danger)
		end)
	end)
	function api.destroy()
		badge:Destroy()
		button:Destroy()
	end

	api.update()
	return api
end

return RingBadges
