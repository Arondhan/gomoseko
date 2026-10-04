--!strict
-- Панель DPS-замера (вверху по центру): таймер и живой DPS, пока идут 30 секунд, затем итог с наградой.
-- Показывается только во время замера и несколько секунд после него.

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local DpsMeter = {}

local RESULT_SECONDS = 9

local function format(score: number): string
	return string.format("%.1f", score / 10)
end

-- dps = DpsController: события status(Types.DpsStatus)
function DpsMeter.build(parent: Instance, dps: any)
	local panel = Chrome.panel(parent, {
		Name = "DpsMeter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(360, 92),
		Visible = false,
	}, 8)
	local glow = Chrome.glow(panel, Theme.GoldLight, 3)

	local title = Chrome.label(panel, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "DPS TEST",
		FontFace = Theme.Fonts.Title,
		TextSize = 15,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local timeLabel = Chrome.label(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(120, 20),
		Text = "",
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
	})
	local big = Chrome.label(panel, {
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "",
		FontFace = Theme.Fonts.Impact,
		TextSize = 28,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local detail = Chrome.label(panel, {
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextStrokeTransparency = 0.7,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})

	local hideToken = 0
	dps.status.Event:Connect(function(status: any)
		if status.kind == "Running" then
			hideToken += 1
			panel.Visible = true
			title.Text = "DPS TEST — keep hitting!"
			timeLabel.Text = string.format("%.0fs left", math.max(0, (status.duration or 30) - (status.elapsed or 0)))
			big.Text = format(status.dps or 0) .. " DPS"
			detail.Text = string.format("Damage dealt: %d", math.floor(status.total or 0))
		elseif status.kind == "Finished" then
			hideToken += 1
			local mine = hideToken
			panel.Visible = true
			title.Text = "TEST COMPLETE"
			timeLabel.Text = ""
			big.Text = format(status.dps or 0) .. " DPS"
			local best = status.best
			local text = string.format(
				"+%d XP   +%d gold   +%d crystals",
				status.xp or 0,
				status.gold or 0,
				status.crystals or 0
			)
			if status.newBest then
				text = "New daily best!   " .. text
			elseif best then
				text = string.format("Daily best: %s DPS   ", format(best.daily)) .. text
			end
			detail.Text = text
			glow.Transparency = 0
			Theme.tween(glow, 1.5, { Transparency = 1 })
			task.delay(RESULT_SECONDS, function()
				if hideToken == mine then
					panel.Visible = false
				end
			end)
		end
	end)

	return { frame = panel }
end

return DpsMeter
