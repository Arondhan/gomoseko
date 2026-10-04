-- Фабрика окон в стиле WoW: заголовок, кнопка X, перетаскивание, анимация открытия/закрытия.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Window = {}

local topZ = 1 -- общий счётчик, чтобы активное окно было поверх

function Window.new(parent: Instance, config: { name: string, title: string, size: UDim2, position: UDim2 })
	local frame = Theme.new("CanvasGroup", {
		Name = config.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = config.position,
		Size = config.size,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		GroupTransparency = 1,
	}, parent)
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.Gold, 2)
	local scale = Theme.new("UIScale", { Name = "Scale", Scale = 0.94 }, frame)

	local bar = Theme.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Header,
		BorderSizePixel = 0,
	}, frame)
	Theme.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Gold,
		BorderSizePixel = 0,
	}, bar)
	Theme.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = config.title,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = Theme.Text,
	}, bar)
	local close = Theme.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Inset,
		BorderSizePixel = 0,
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Theme.Text,
	}, bar)
	Theme.corner(close, 5)
	Theme.stroke(close, Theme.GoldDim, 1)

	local body = Theme.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 37),
		Size = UDim2.new(1, 0, 1, -37),
		BackgroundTransparency = 1,
	}, frame)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
	}, body)

	local window = { frame = frame, body = body, isOpen = false, changed = Instance.new("BindableEvent") }

	local function bringToFront()
		topZ += 1
		frame.ZIndex = topZ
	end

	function window.setOpen(open: boolean)
		if window.isOpen == open then
			return
		end
		window.isOpen = open
		window.changed:Fire(open)
		if open then
			bringToFront()
			frame.Visible = true
			scale.Scale = 0.94
			Theme.tween(frame, 0.15, { GroupTransparency = 0 })
			Theme.tween(scale, 0.15, { Scale = 1 })
		else
			Theme.tween(frame, 0.12, { GroupTransparency = 1 })
			Theme.tween(scale, 0.12, { Scale = 0.96 })
			task.delay(0.12, function()
				if not window.isOpen then
					frame.Visible = false
				end
			end)
		end
	end

	function window.toggle()
		window.setOpen(not window.isOpen)
	end

	close.MouseButton1Click:Connect(function()
		window.setOpen(false)
	end)

	-- перетаскивание за заголовок
	local dragging = false
	local dragStart: Vector3
	local startPos: UDim2
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			bringToFront()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - dragStart
			frame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return window
end

return Window
