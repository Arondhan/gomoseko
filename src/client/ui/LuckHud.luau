--!strict
-- Две плашки удачи: «AFK Luck: +0.2x (next +0.1x in 06:12)» рядом с валютами и баннер «LUCKY HOUR» вверху экрана
-- на время события. Данные — LuckController (сервер считает, клиент только показывает).

local TweenService = game:GetService("TweenService")

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local LuckHud = {}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- deps: { luck = LuckController, tooltip = Tooltip, notify = (text, color?) -> () }
function LuckHud.build(parent: Instance, deps: any)
	local luck = deps.luck
	local tooltip = deps.tooltip
	local notify: (string, Color3?) -> () = deps.notify

	-- AFK Luck: строка под валютами слева внизу (текст с обводкой, без панели)
	local afk = Chrome.label(parent, {
		Name = "AfkLuck",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.fromOffset(360, 28),
		Text = "AFK Luck: +0.0x",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
		Active = true,
	})
	local afkLabel = afk

	local function refreshAfk()
		local playtime = luck.getPlaytime()
		if not playtime then
			afkLabel.Text = "AFK Luck: ..."
			return
		end
		local nextIn = luck.playtimeNextIn()
		if nextIn then
			afkLabel.Text = string.format(
				"AFK Luck: +%.1fx  (+%.1fx in %s)",
				playtime.bonus,
				playtime.stepBonus,
				formatTime(nextIn)
			)
		else
			afkLabel.Text = string.format("AFK Luck: +%.1fx (MAX)", playtime.bonus)
		end
	end
	afk.MouseEnter:Connect(function()
		local playtime = luck.getPlaytime()
		local lines = {
			"Stay on the server to raise your luck.",
			"Every 10 minutes of continuous play adds a bonus to your luck.",
			"Leaving the server resets it.",
		}
		if playtime then
			table.insert(lines, string.format("Now: +%.1fx   Max: +%.1fx", playtime.bonus, playtime.maxBonus))
		end
		tooltip.show("AFK Playtime Luck", nil, lines, Theme.Good)
	end)
	afk.MouseLeave:Connect(function()
		tooltip.hide()
	end)

	-- Lucky Hour: таймер справа сверху («LUCKY HOUR IN 03:12»), во время события — зелёный «ON»
	local banner = Chrome.label(parent, {
		Name = "LuckyHour",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 10),
		Size = UDim2.fromOffset(420, 40),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		TextColor3 = Color3.fromRGB(110, 190, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
	})
	local bannerLabel = banner
	local pulse = Theme.new("UIScale", { Scale = 1 }, banner)
	task.spawn(function()
		while banner.Parent do
			TweenService:Create(pulse, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Scale = 1.05 }):Play()
			task.wait(0.8)
			TweenService:Create(pulse, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
			task.wait(0.8)
		end
	end)

	local function refreshEvent()
		local current = luck.getEvent()
		if not current then
			banner.Visible = false
			return
		end
		banner.Visible = true
		if current.active then
			banner.TextColor3 = Theme.Good
			bannerLabel.Text = string.format(
				"%s! +%.1fx  %s",
				string.upper(current.name),
				current.percent / 100,
				formatTime(current.remaining)
			)
		else
			banner.TextColor3 = Color3.fromRGB(110, 190, 255)
			bannerLabel.Text = string.format("%s IN %s", string.upper(current.name), formatTime(current.remaining))
		end
	end

	luck.eventChanged.Event:Connect(function(status: any)
		if status.active then
			notify(
				string.format(
					"%s has started! +%.1fx luck for %s",
					status.name,
					status.percent / 100,
					formatTime(status.endsIn)
				),
				Theme.GoldLight
			)
		end
	end)
	luck.changed.Event:Connect(function()
		refreshAfk()
		refreshEvent()
	end)
	task.spawn(function()
		while afk.Parent do
			refreshAfk()
			refreshEvent()
			task.wait(1)
		end
	end)
	refreshAfk()

	return { afk = afk, banner = banner }
end

return LuckHud
