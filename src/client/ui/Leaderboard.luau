--!strict
-- Окно «Leaderboard» (L): таблицы DPS-арены — Daily / Weekly / All time, до 50 мест, своё место подсвечено.
-- Данные приходят с сервера (DpsController.getBoards); обновляются при открытии и раз в 30 секунд, пока окно открыто.

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Leaderboard = {}

local TABS: { { key: string, title: string } } = {
	{ key = "daily", title = "Daily" },
	{ key = "weekly", title = "Weekly" },
	{ key = "allTime", title = "All time" },
}
local RANK_COLORS = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(215, 220, 232), Color3.fromRGB(214, 146, 90) }

local function format(score: number): string
	return string.format("%.1f", score / 10)
end

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	end
	return string.format("%dh %dm", hours, minutes)
end

-- deps: { dps = DpsController }
function Leaderboard.build(parent: Instance, deps: any)
	local dps = deps.dps
	local player = Players.LocalPlayer

	local window = Window.new(parent, {
		name = "LeaderboardWindow",
		title = "DPS Leaderboard",
		size = UDim2.fromOffset(440, 560),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	local current = "daily"
	local tabButtons: { [string]: TextButton } = {}
	for index, tab in TABS do
		local button = Theme.new("TextButton", {
			Position = UDim2.new((index - 1) / #TABS, if index == 1 then 0 else 3, 0, 0),
			Size = UDim2.new(1 / #TABS, if index == 1 or index == #TABS then -3 else -6, 0, 32),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = tab.title,
			FontFace = Theme.Fonts.Title,
			TextSize = 17,
			TextColor3 = Theme.GoldLight,
			ZIndex = 5,
		}, body)
		Theme.corner(button, 6)
		Theme.gradient(button, 90, Theme.ButtonTop, Theme.ButtonBottom)
		Chrome.bevel(button, 2, 6, true)
		tabButtons[tab.key] = button
	end

	local list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.GoldMid,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body)
	Theme.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, list)

	local footer = Chrome.label(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextColor3 = Theme.Muted,
		TextStrokeTransparency = 0.7,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local response: any = nil

	local function render()
		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		for key, button in tabButtons do
			button.TextColor3 = if key == current then Color3.new(1, 1, 1) else Theme.GoldLight
		end
		if not response then
			return
		end
		local entries = response.boards[current]
		if #entries == 0 then
			Chrome.label(list, {
				Size = UDim2.new(1, 0, 0, 60),
				Text = "No scores yet. Hit a training dummy for 30 seconds!",
				FontFace = Theme.Fonts.Body,
				TextSize = 16,
				TextColor3 = Theme.Muted,
			})
		end
		for index, entry in entries do
			local mine = entry.userId == player.UserId
			local row = Theme.new("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, 30),
				BackgroundColor3 = if mine then Color3.fromRGB(70, 56, 24) else Color3.fromRGB(26, 28, 38),
				BackgroundTransparency = if mine then 0.1 else 0.4,
				BorderSizePixel = 0,
			}, list)
			Theme.corner(row, 5)
			local color = RANK_COLORS[entry.rank] or Theme.Text
			Chrome.label(row, {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(46, 30),
				Text = "#" .. entry.rank,
				TextSize = 16,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			Chrome.label(row, {
				Position = UDim2.fromOffset(56, 0),
				Size = UDim2.new(1, -170, 1, 0),
				Text = entry.name,
				FontFace = Theme.Fonts.Title,
				TextSize = 16,
				TextColor3 = if mine then Theme.GoldLight else color,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			Chrome.label(row, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.fromOffset(100, 30),
				Text = format(entry.score) .. " DPS",
				TextSize = 16,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end

		local best = response.best[current]
		local resets = if current == "daily"
			then "Resets in " .. formatDuration(response.dayEndsIn)
			elseif current == "weekly" then "Resets in "
				.. formatDuration(response.weekEndsIn)
				.. " — top players get crystals"
			else "All-time records"
		local note = if response.source == "memory" then "\nShowing this server only (DataStore unavailable)." else ""
		footer.Text = string.format("Your best: %s DPS   ·   %s%s", format(best), resets, note)
	end

	local function refresh()
		local result = dps.getBoards()
		if result then
			response = result
		end
		render()
	end

	for key, button in tabButtons do
		button.MouseButton1Click:Connect(function()
			current = key
			render()
		end)
	end

	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(function()
				while window.isOpen do
					refresh()
					task.wait(30)
				end
			end)
		end
	end)
	render()

	return window
end

return Leaderboard
