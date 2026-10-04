--!strict
-- Окно «Boost»: всё про удачу в одном месте — текущий множитель и из чего он состоит, AFK-удача (растёт за время
-- на сервере), Lucky Hour (таймер) и кнопка в магазин за зельями удачи. Данные — GachaController и LuckController.

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local BoostWindow = {}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- deps: { gacha = GachaController, luck = LuckController, openStore = () -> () }
function BoostWindow.build(parent: Instance, deps: any)
	local gacha = deps.gacha
	local luck = deps.luck

	local window = Window.new(parent, {
		name = "BoostWindow",
		title = "Boosts",
		size = UDim2.fromOffset(440, 440),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	local function line(y: number, height: number, size: number, color: Color3): TextLabel
		return Chrome.label(body, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			Text = "",
			FontFace = Theme.Fonts.Title,
			TextSize = size,
			TextColor3 = color,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end

	local luckTitle = line(0, 34, Theme.TextSize.Title, Theme.Good)
	local luckSources = line(36, 84, Theme.TextSize.Small, Theme.Text)
	local afkTitle = line(126, 30, Theme.TextSize.Header, Theme.GoldLight)
	local afkInfo = line(156, 44, Theme.TextSize.Small, Theme.Muted)
	local eventTitle = line(210, 30, Theme.TextSize.Header, Theme.GoldLight)
	local eventInfo = line(240, 44, Theme.TextSize.Small, Theme.Muted)

	local store = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
	}, body)
	Theme.corner(store, 12)
	Theme.gradient(store, 90, Color3.fromRGB(255, 100, 90), Color3.fromRGB(200, 40, 40))
	Chrome.bevel(store, 2, 12, true)
	Chrome.label(store, {
		Size = UDim2.fromScale(1, 1),
		Text = "Buy Luck Potions",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
	})
	store.MouseButton1Click:Connect(function()
		window.setOpen(false)
		deps.openStore()
	end)

	local function refresh()
		local state = gacha.getState()
		if state then
			luckTitle.Text = string.format("Your Luck: ×%.2f", state.luck)
			local lines: { string } = {}
			for _, source in state.luckSources do
				table.insert(lines, string.format("%s: +%g%%", source.name, source.percent))
			end
			if #lines == 0 then
				table.insert(lines, "No luck bonuses yet")
			end
			luckSources.Text = table.concat(lines, "\n")
		else
			luckTitle.Text = "Your Luck"
		end

		local playtime = luck.getPlaytime()
		if playtime then
			afkTitle.Text = string.format("AFK Luck: +%.1fx", playtime.bonus)
			local nextIn = luck.playtimeNextIn()
			afkInfo.Text = if nextIn
				then string.format(
					"Stay on the server: +%.1fx more in %s (max +%.1fx). Leaving resets it.",
					playtime.stepBonus,
					formatTime(nextIn),
					playtime.maxBonus
				)
				else "Maximum reached! Leaving the server resets it."
		else
			afkTitle.Text = "AFK Luck"
			afkInfo.Text = "Loading..."
		end

		local current = luck.getEvent()
		if current and current.active then
			eventTitle.Text = string.format("%s is ON!  %s", current.name, formatTime(current.remaining))
			eventInfo.Text = string.format("+%.1fx luck for everyone right now. Summon now!", current.percent / 100)
		elseif current then
			eventTitle.Text = string.format("%s in %s", current.name, formatTime(current.remaining))
			eventInfo.Text =
				string.format("+%.1fx luck for everyone, a few minutes every half hour.", current.percent / 100)
		else
			eventTitle.Text = "Lucky Hour"
			eventInfo.Text = "Loading..."
		end
	end

	gacha.stateChanged.Event:Connect(refresh)
	luck.changed.Event:Connect(refresh)
	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(gacha.refresh)
			refresh()
		end
	end)
	task.spawn(function()
		while body.Parent do
			if window.isOpen then
				refresh()
			end
			task.wait(1)
		end
	end)
	refresh()

	return window
end

return BoostWindow
