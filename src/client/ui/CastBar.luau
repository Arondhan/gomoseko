--!strict
-- Полоса каста по центру внизу (как в WoW): название скилла, золотая заливка с искрой на конце, таймер.
-- start(name, duration) запускает заполнение; finish() — успешное завершение, cancel(reason) — срыв (красная).

local RunService = game:GetService("RunService")

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local CastBar = {}

local CAST_COLOR = Color3.fromRGB(255, 196, 40)
local FINISH_COLOR = Color3.fromRGB(80, 220, 90)

function CastBar.build(parent: Instance)
	local root = Chrome.panel(parent, {
		Name = "CastBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(300, 24),
		BackgroundTransparency = 0,
		Visible = false,
	}, 6)
	local group = Theme.new("UIScale", { Scale = 1 }, root)

	local clip = Theme.new("Frame", {
		Name = "Clip",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2,
	}, root)
	Theme.corner(clip, 4)

	local fill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, clip)
	local fillGradient = Theme.new("UIGradient", {
		Rotation = 90,
		Color = Theme.shade(CAST_COLOR),
	}, fill)

	-- искра на конце заполнения
	local spark = Theme.new("Frame", {
		Name = "Spark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 10, 1, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, clip)
	Theme.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, spark)

	local nameLabel = Chrome.label(root, {
		Name = "SkillName",
		Size = UDim2.fromScale(1, 1),
		TextSize = 15,
		FontFace = Theme.Fonts.Title,
		ZIndex = 5,
	})
	local timeLabel = Chrome.label(root, {
		Name = "Time",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(40, 24),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	})

	local token = 0 -- номер текущего каста: устаревшие таймеры/твины не трогают новый каст
	local connection: RBXScriptConnection? = nil

	local function stopLoop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	local function setFillColor(color: Color3)
		fillGradient.Color = Theme.shade(color)
	end

	local function hideLater(mine: number)
		task.delay(0.35, function()
			if token == mine then
				root.Visible = false
			end
		end)
	end

	local bar = {}

	function bar.start(skillName: string, duration: number)
		if duration <= 0 then
			return
		end
		token += 1
		stopLoop()
		setFillColor(CAST_COLOR)
		nameLabel.Text = skillName
		fill.Size = UDim2.fromScale(0, 1)
		spark.Visible = true
		root.Visible = true
		group.Scale = 1

		local startedAt = os.clock()
		connection = RunService.RenderStepped:Connect(function()
			local progress = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			fill.Size = UDim2.fromScale(progress, 1)
			spark.Position = UDim2.fromScale(progress, 0.5)
			timeLabel.Text = string.format("%.1f", math.max(0, duration - (os.clock() - startedAt)))
		end)
	end

	function bar.finish()
		if not root.Visible then
			return
		end
		stopLoop()
		local mine = token
		fill.Size = UDim2.fromScale(1, 1)
		spark.Visible = false
		timeLabel.Text = ""
		setFillColor(FINISH_COLOR)
		hideLater(mine)
	end

	function bar.cancel(reason: string?)
		if not root.Visible then
			return
		end
		stopLoop()
		local mine = token
		spark.Visible = false
		timeLabel.Text = ""
		setFillColor(Theme.Danger)
		nameLabel.Text = reason or "Interrupted"
		hideLater(mine)
	end

	return { frame = root, start = bar.start, finish = bar.finish, cancel = bar.cancel }
end

return CastBar
