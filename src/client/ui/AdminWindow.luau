--!strict
-- Окно «Admin» (F2 / плитка Admin): выдача колец, валюты и уровень, тестовый режим боя, спавн врагов, события
-- удачи. Это только кнопки — каждое действие отправляется на сервер (AdminAction), который заново проверяет, что
-- игрок админ, и валидирует параметры. Окно строится клиентом только если AdminGet вернул admin = true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaMath = require(Shared:WaitForChild("Gacha"):WaitForChild("GachaMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local AdminWindow = {}

local CELL_W, CELL_H, GAP = 150, 42, 8

-- deps: { notify = (text, color?) -> () }
function AdminWindow.build(parent: Instance, deps: any)
	local notify: (string, Color3?) -> () = deps.notify
	local actRemote = Remotes.get("AdminAction") :: RemoteFunction
	local getRemote = Remotes.get("AdminGet") :: RemoteFunction

	local window = Window.new(parent, {
		name = "AdminWindow",
		title = "Admin",
		size = UDim2.fromOffset(540, 620),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})

	local scroll = Theme.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.GoldMid,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window.body)
	Theme.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }, scroll)
	Theme.new("UIPadding", { PaddingRight = UDim.new(0, 10) }, scroll)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- отправка действия на сервер; ответ показываем уведомлением
	local flagLabels: { [string]: { label: TextLabel, title: string } } = {}
	local function refreshFlags()
		local ok, result = pcall(function()
			return getRemote:InvokeServer()
		end)
		if ok and type(result) == "table" and type(result.flags) == "table" then
			for name, entry in flagLabels do
				entry.label.Text = entry.title .. (if result.flags[name] then ": ON" else ": OFF")
			end
		end
	end
	local function run(action: string, a: any?, b: any?)
		task.spawn(function()
			local ok, success, message = pcall(function()
				return actRemote:InvokeServer(action, a, b)
			end)
			if not ok then
				notify("Admin: connection problem", Theme.Danger)
				return
			end
			notify(tostring(message), if success then Theme.Good else Theme.Danger)
			refreshFlags()
		end)
	end

	local function heading(text: string)
		Chrome.label(scroll, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 30),
			Text = text,
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Title,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local function makeButton(
		container: Instance,
		text: string,
		width: number?,
		height: number?
	): (TextButton, TextLabel)
		local button = Theme.new("TextButton", {
			Size = UDim2.fromOffset(width or CELL_W, height or CELL_H),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 5,
		}, container)
		Theme.corner(button, 10)
		Theme.gradient(button, 90, Theme.ButtonTop, Theme.ButtonBottom)
		Chrome.bevel(button, 2, 10, true)
		local label = Chrome.label(button, {
			Size = UDim2.fromScale(1, 1),
			Text = text,
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Color3.new(1, 1, 1),
			TextWrapped = true,
			ZIndex = 6,
		})
		return button, label
	end

	-- сетка кнопок: { text, action, a, b, flag }
	local function grid(entries: { { text: string, action: string, a: any?, b: any?, flag: string? } })
		local columns = 3
		local rows = math.ceil(#entries / columns)
		local holder = Theme.new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, rows * (CELL_H + GAP) - GAP),
			BackgroundTransparency = 1,
		}, scroll)
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL_W, CELL_H),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, holder)
		for index, entry in entries do
			local button, label = makeButton(holder, entry.text)
			button.LayoutOrder = index
			if entry.flag then
				flagLabels[entry.flag] = { label = label, title = entry.text }
			end
			button.MouseButton1Click:Connect(function()
				run(entry.action, entry.a, entry.b)
			end)
		end
	end

	-- кольца: общие кнопки и список «название · 1 in N · Give»
	heading("Rings")
	grid({
		{ text = "Give ALL rings", action = "GiveAllRings" },
		{ text = "Reset rings", action = "ResetRings" },
	})
	local sorted = table.clone(RingsConfig.List)
	table.sort(sorted, function(a, b)
		return a.OneIn < b.OneIn
	end)
	for _, ring in sorted do
		local row = Theme.new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
		}, scroll)
		Chrome.label(row, {
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = ring.Name,
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Quality[ring.Quality] or Theme.Quality.Common,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Chrome.label(row, {
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.3, 0, 1, 0),
			Text = GachaMath.formatOneIn(ring.OneIn),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small - 1,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local give = makeButton(row, "Give", 86, 32)
		give.AnchorPoint = Vector2.new(1, 0.5)
		give.Position = UDim2.new(1, 0, 0.5, 0)
		give.MouseButton1Click:Connect(function()
			run("GiveRing", ring.Id)
		end)
	end

	heading("Currency")
	grid({
		{ text = "+1,000 Crystals", action = "AddCurrency", a = "Crystals", b = 1000 },
		{ text = "+100,000 Crystals", action = "AddCurrency", a = "Crystals", b = 100000 },
		{ text = "+10,000 Gold", action = "AddCurrency", a = "Gold", b = 10000 },
		{ text = "+1,000,000 Gold", action = "AddCurrency", a = "Gold", b = 1000000 },
		{ text = "+1,000 Essence", action = "AddCurrency", a = "Essence", b = 1000 },
		{ text = "+100,000 Essence", action = "AddCurrency", a = "Essence", b = 100000 },
	})

	heading("Level")
	grid({
		{ text = "Level 1", action = "SetLevel", a = 1 },
		{ text = "Level 10", action = "SetLevel", a = 10 },
		{ text = "Level 25", action = "SetLevel", a = 25 },
		{ text = "Level 50", action = "SetLevel", a = 50 },
	})

	heading("Combat test")
	grid({
		{ text = "Infinite mana", action = "ToggleFlag", a = "InfiniteMana", flag = "InfiniteMana" },
		{ text = "No cooldown", action = "ToggleFlag", a = "NoCooldown", flag = "NoCooldown" },
		{ text = "Refill mana", action = "RefillMana" },
		{ text = "Reset cooldowns", action = "ResetCooldowns" },
	})

	heading("Enemies")
	grid({
		{ text = "Dummy x1", action = "Spawn", a = "Dummy", b = 1 },
		{ text = "Dummy x5", action = "Spawn", a = "Dummy", b = 5 },
		{ text = "Clear all", action = "ClearEnemies" },
		{ text = "Mover x1", action = "Spawn", a = "Mover", b = 1 },
		{ text = "Mover x5", action = "Spawn", a = "Mover", b = 5 },
	})

	heading("Luck and events")
	grid({
		{ text = "Lucky Hour 5 min", action = "LuckyHour", a = 300 },
		{ text = "End Lucky Hour", action = "LuckyHour", a = 0 },
		{ text = "AFK +10 min", action = "AfkLuck", a = 600 },
		{ text = "AFK MAX", action = "AfkLuck", a = 6000 },
	})

	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(refreshFlags)
		end
	end)
	task.spawn(refreshFlags)

	return window
end

return AdminWindow
