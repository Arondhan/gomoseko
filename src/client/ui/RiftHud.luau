--!strict
-- HUD забега Rift: крупное «WAVE N», сколько врагов осталось, отсчёт лобби и перерыва, пометки BOSS / CHEST,
-- уведомление о награде за волну и окно итогов, когда игрок выбыл из забега. Данные — RiftController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local RiftHud = {}

-- deps: { rift = RiftController, notify = (text, color?) -> () }
function RiftHud.build(parent: Instance, deps: any)
	local rift = deps.rift
	local notify: (string, Color3?) -> () = deps.notify

	local root = Theme.new("Frame", {
		Name = "RiftHud",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(520, 170),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local title = Chrome.label(root, {
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		FontFace = Theme.Fonts.Banner,
		TextSize = 46,
		TextColor3 = Color3.fromRGB(255, 200, 80),
	})
	local sub = Chrome.label(root, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		TextColor3 = Color3.new(1, 1, 1),
	})
	local tag = Chrome.label(root, {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Header,
		TextColor3 = Theme.Danger,
	})

	-- полоса HP босса
	local bossBar = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(380, 26),
		BackgroundColor3 = Color3.fromRGB(20, 12, 28),
		BorderSizePixel = 0,
		Visible = false,
	}, root)
	Theme.corner(bossBar, 8)
	Chrome.bevel(bossBar, 2, 8, true)
	local bossFill = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 40, 70),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, bossBar)
	Theme.corner(bossFill, 8)
	Theme.gradient(bossFill, 90, Color3.fromRGB(255, 110, 130), Color3.fromRGB(150, 20, 50))
	local bossText = Chrome.label(bossBar, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Small,
		ZIndex = 3,
	})

	local function refresh()
		local state = rift.getState()
		if not (state and rift.isInArena() and state.phase ~= "Idle") then
			root.Visible = false
			return
		end
		root.Visible = true
		if state.phase == "Wave" and state.bossMax > 0 then
			bossBar.Visible = true
			bossFill.Size = UDim2.fromScale(math.clamp(state.bossHealth / state.bossMax, 0, 1), 1)
			bossText.Text = string.format("Rift Titan  %d / %d", state.bossHealth, state.bossMax)
		else
			bossBar.Visible = false
		end
		local countdown = math.ceil(rift.countdown())
		tag.Text = ""
		if state.phase == "Lobby" then
			title.Text = "RIFT"
			sub.Text = string.format("Starting in %d...  (%d in the arena)", countdown, state.players)
			title.TextColor3 = Color3.fromRGB(180, 130, 255)
		elseif state.phase == "Wave" then
			title.Text = "WAVE " .. state.wave
			title.TextColor3 = Color3.fromRGB(255, 200, 80)
			sub.Text = string.format("Enemies left: %d", state.enemiesLeft)
			if state.bossWave then
				tag.Text = "BOSS WAVE!"
			elseif state.chestWave then
				tag.Text = "Chest wave"
				tag.TextColor3 = Theme.GoldLight
			end
			if state.enraged then
				tag.Text = "The Rift is enraged!"
				tag.TextColor3 = Theme.Danger
			elseif state.bossWave then
				tag.TextColor3 = Theme.Danger
			end
		elseif state.phase == "Intermission" then
			title.Text = "WAVE " .. state.wave .. " CLEARED"
			title.TextColor3 = Theme.Good
			sub.Text = string.format("Next wave in %d", countdown)
		else
			title.Text = "RIFT OVER"
			sub.Text = ""
		end
	end
	rift.changed.Event:Connect(refresh)
	game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("InRift"):Connect(refresh)
	task.spawn(function()
		while root.Parent do
			refresh()
			task.wait(0.25)
		end
	end)

	rift.reward.Event:Connect(function(reward: Types.RiftWaveReward)
		notify(
			string.format("Wave %d cleared!  +%d Crystals  +%d Essence", reward.wave, reward.crystals, reward.essence),
			Theme.GoldLight
		)
	end)

	-- сундук: карточка по центру на несколько секунд
	local chest = Chrome.panel(parent, {
		Name = "RiftChest",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(440, 170),
		Visible = false,
		ZIndex = 118,
	}, 16)
	local chestTitle = Chrome.label(chest, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		FontFace = Theme.Fonts.Banner,
		TextSize = 34,
		TextColor3 = Theme.GoldLight,
		ZIndex = 119,
	})
	local chestBody = Chrome.label(chest, {
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 100),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		ZIndex = 119,
	})
	local chestToken = 0
	rift.chest.Event:Connect(function(result: Types.RiftChest)
		chestToken += 1
		local mine = chestToken
		chestTitle.Text = result.title .. "!"
		local lines = { result.label }
		if result.ringName then
			table.insert(
				lines,
				string.format("%s%s", result.ringName, if result.ringIsNew then "  NEW!" else "  (duplicate)")
			)
		end
		local rewards: { string } = {}
		if result.crystals > 0 then
			table.insert(rewards, string.format("+%d Crystals", result.crystals))
		end
		if result.essence > 0 then
			table.insert(rewards, string.format("+%d Essence", result.essence))
		end
		if #rewards > 0 then
			table.insert(lines, table.concat(rewards, "   "))
		end
		chestBody.Text = table.concat(lines, "\n")
		chest.Visible = true
		task.delay(4.5, function()
			if chestToken == mine then
				chest.Visible = false
			end
		end)
	end)

	-- итоги забега
	local results = Chrome.panel(parent, {
		Name = "RiftResults",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 290),
		Visible = false,
		ZIndex = 120,
	}, 16)
	Chrome.label(results, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "RIFT OVER",
		FontFace = Theme.Fonts.Banner,
		TextSize = 38,
		TextColor3 = Theme.Danger,
		ZIndex = 121,
	})
	local body = Chrome.label(results, {
		Position = UDim2.fromOffset(20, 66),
		Size = UDim2.new(1, -40, 0, 140),
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Header,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		ZIndex = 121,
	})
	local close = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(190, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 122,
	}, results)
	Theme.corner(close, 12)
	Theme.gradient(close, 90, Theme.ButtonTop, Theme.ButtonBottom)
	Chrome.bevel(close, 2, 12, true)
	Chrome.label(close, {
		Size = UDim2.fromScale(1, 1),
		Text = "Continue",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		ZIndex = 123,
	})
	close.MouseButton1Click:Connect(function()
		results.Visible = false
	end)
	rift.result.Event:Connect(function(result: Types.RiftResult)
		body.Text = string.format(
			"Waves survived: %d\nBest: %d\nKills: %d\nCrystals: +%d   Essence: +%d",
			result.wave,
			result.best,
			result.kills,
			result.crystals,
			result.essence
		)
		results.Visible = true
	end)

	return { frame = root }
end

return RiftHud
