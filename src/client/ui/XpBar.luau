--!strict
-- Тонкая полоса опыта над панелью колец (как в WoW): фиолетовая заливка, текст «Ур. N · cur / max».
-- Данные — из атрибутов Player "Level", "XP", "XPToNext" (ведёт PlayerStatsService).

local Players = game:GetService("Players")

local StatusBar = require(script.Parent.StatusBar)
local Theme = require(script.Parent.Theme)

local XpBar = {}

function XpBar.build(parent: Instance)
	local player = Players.LocalPlayer

	local holder = Theme.new("Frame", {
		Name = "XpBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -114),
		Size = UDim2.fromOffset(300, 14),
		BackgroundTransparency = 1,
	}, parent)
	local bar = StatusBar.new(holder, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Theme.Xp)

	local function number(name: string, default: number): number
		local value = player:GetAttribute(name)
		return if type(value) == "number" then value else default
	end

	local function refresh()
		local xp, needed = number("XP", 0), number("XPToNext", 100)
		bar.setValue(xp, needed)
		bar.setText(string.format("Lv. %d  ·  %d / %d", number("Level", 1), xp, needed))
	end
	for _, name in { "XP", "XPToNext", "Level" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	return { frame = holder }
end

return XpBar
