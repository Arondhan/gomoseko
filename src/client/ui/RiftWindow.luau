--!strict
-- Окно «Rift»: описание, состояние текущего забега на сервере, личный рекорд и кнопка Enter / Leave.
-- Телепорт делает сервер (RiftService); окно нужно, чтобы зайти с телефона без прогулки до портала.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestMath = require(Shared:WaitForChild("Rift"):WaitForChild("ChestMath"))
local RiftConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RiftConfig"))

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local RiftWindow = {}

local PHASE_TEXT = {
	Idle = "No one is in the Rift. Be the first!",
	Lobby = "A run is about to start.",
	Wave = "A run is in progress.",
	Intermission = "A run is in progress (between waves).",
	Ending = "The Rift is resetting...",
} :: { [string]: string }

-- deps: { rift = RiftController, notify = (text, color?) -> () }
function RiftWindow.build(parent: Instance, deps: any)
	local rift = deps.rift
	local notify: (string, Color3?) -> () = deps.notify

	local window = Window.new(parent, {
		name = "RiftWindow",
		title = "Rift",
		size = UDim2.fromOffset(500, 660),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	local function text(y: number, height: number, size: number, color: Color3): TextLabel
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

	text(0, 72, Theme.TextSize.Small, Theme.Text).Text =
		"Fight endless waves with your ring skills. Every wave pays Crystals and Essence for summons. A chest every 5 waves, a boss every 10. Wear a ring with a skill to enter; if you fall you keep what you earned."
	local status = text(78, 30, Theme.TextSize.Header, Theme.GoldLight)
	local best = text(110, 28, Theme.TextSize.Header, Theme.Good)

	-- шансы сундуков (из того же конфига, по которому сервер выбирает исход)
	local function oddsLine(title: string, outcomes: { ChestMath.Outcome }): string
		local tenths = ChestMath.tenths(outcomes)
		local parts: { string } = {}
		for i, outcome in outcomes do
			table.insert(parts, string.format("%s %s", outcome.Label, ChestMath.formatTenths(tenths[i])))
		end
		return string.format("%s: %s", title, table.concat(parts, "  ·  "))
	end
	text(144, 100, Theme.TextSize.Small - 1, Theme.Muted).Text = string.format(
		"Chest odds\n%s\n%s\nRing! is a normal Summon roll with luck x1 (same odds as the Odds table). Duplicates give Essence.",
		oddsLine("Rift Chest, waves 5, 15...", RiftConfig.Chests.Normal.Outcomes),
		oddsLine("Titan Chest, boss waves 10, 20...", RiftConfig.Chests.Boss.Outcomes)
	)

	-- недельный топ
	local boardTitle = text(250, 26, Theme.TextSize.Header, Theme.GoldLight)
	boardTitle.Text = "Weekly top"
	local rows: { TextLabel } = {}
	for i = 1, 10 do
		rows[i] = Chrome.label(body, {
			Position = UDim2.fromOffset(0, 278 + (i - 1) * 24),
			Size = UDim2.new(1, 0, 0, 24),
			Text = "",
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	local button = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
	}, body)
	Theme.corner(button, 14)
	local gradient = Theme.gradient(button, 90, Color3.fromRGB(180, 110, 255), Color3.fromRGB(110, 50, 200))
	Chrome.bevel(button, 2, 14, true)
	local buttonLabel = Chrome.label(button, {
		Size = UDim2.fromScale(1, 1),
		Text = "Enter the Rift",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Banner - 8,
		ZIndex = 6,
	})

	local function refresh()
		local info = rift.info()
		if not info then
			return
		end
		local inArena = info.inArena
		status.Text = string.format(
			"%s  Wave %d, %d in arena.",
			PHASE_TEXT[info.state.phase] or "",
			info.state.wave,
			info.state.players
		)
		if info.state.phase == "Idle" then
			status.Text = PHASE_TEXT.Idle
		end
		best.Text = string.format("Your best: wave %d   ·   this week: wave %d", info.best, info.weekBest)
		local days, hours = info.weekEndsIn // 86400, (info.weekEndsIn % 86400) // 3600
		boardTitle.Text = string.format("Weekly top  (resets in %dd %dh)", days, hours)
		for i, row in rows do
			local entry = info.board[i]
			row.Text = if entry then string.format("#%d  %s  —  wave %d", entry.rank, entry.name, entry.score) else ""
			row.TextColor3 = if i == 1 then Theme.GoldLight else Theme.Text
		end
		if #info.board == 0 then
			rows[1].Text = "No runs this week yet. Be the first!"
		end
		buttonLabel.Text = if inArena then "Leave the Rift" else "Enter the Rift"
		gradient.Color = if inArena
			then ColorSequence.new(Color3.fromRGB(255, 110, 90), Color3.fromRGB(200, 40, 40))
			else ColorSequence.new(Color3.fromRGB(180, 110, 255), Color3.fromRGB(110, 50, 200))
	end

	button.MouseButton1Click:Connect(function()
		task.spawn(function()
			local ok, message
			if rift.isInArena() then
				ok, message = rift.leave()
			else
				ok, message = rift.enter()
			end
			notify(message, if ok then Theme.Good else Theme.Danger)
			if ok then
				window.setOpen(false)
			end
			refresh()
		end)
	end)

	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(refresh)
		end
	end)
	task.spawn(function()
		while body.Parent do
			if window.isOpen then
				refresh()
			end
			task.wait(2)
		end
	end)

	return window
end

return RiftWindow
