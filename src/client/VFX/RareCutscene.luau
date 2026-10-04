--!strict
-- Кинематографичный ролл редкого кольца (только клиент, только визуал — результат ролла уже решил сервер):
--   1) управление игрока блокируется на 2–3 секунды (PlayerModule:GetControls():Disable());
--   2) камера плавно наезжает на персонажа с эффектного ракурса (TweenService на CFrameValue);
--   3) лёгкая тряска экрана (затухающий оффсет камеры, отключается в настройках);
--   4) освещение мира приглушается (ColorCorrectionEffect), в момент удара — яркая вспышка;
--   5) звук раската грома и вибрация геймпада.
-- Всё возвращается назад в любом случае: смерть/сброс персонажа, пропуск (Space / тап / кнопка геймпада), ошибка.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))

local VFX = script.Parent
local Sfx = require(VFX:WaitForChild("Sfx"))
local Haptics = require(VFX:WaitForChild("Haptics"))

local RareCutscene = {}

export type Options = {
	color: Color3, -- цвет качества кольца (вспышка, оттенок)
	rank: number, -- 1..7 (Common..Divine): сила эффектов
	shake: boolean, -- тряска экрана включена
}

-- Параметры по рангу: длительность (сек), амплитуда тряски (studs), глубина затемнения, угол обзора в конце
local STYLES: { [number]: { duration: number, shake: number, dim: number, fov: number } } = {
	[4] = { duration = 2.2, shake = 0.12, dim = 0.18, fov = 58 },
	[5] = { duration = 2.6, shake = 0.2, dim = 0.25, fov = 54 },
	[6] = { duration = 3.0, shake = 0.3, dim = 0.32, fov = 50 },
	[7] = { duration = 3.2, shake = 0.38, dim = 0.4, fov = 46 },
}

local playing = false

local function getControls(): any?
	local localPlayer = Players.LocalPlayer
	local scripts = localPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, result = pcall(function()
		return (require(module) :: any):GetControls()
	end)
	return if ok then result else nil
end

function RareCutscene.isPlaying(): boolean
	return playing
end

-- Проигрывает катсцену и возвращается, когда она закончилась (yield). Возвращает false, если не запустилась.
function RareCutscene.play(options: Options): boolean
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if playing or not camera or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	playing = true

	local style = STYLES[math.clamp(options.rank, 4, 7)]
	local duration = style.duration
	local head = (character :: Model):FindFirstChild("Head")
	local focus = (if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 2, 0))
		+ Vector3.new(0, 0.4, 0)

	-- 1) блокировка управления
	local controls = getControls()
	if controls then
		pcall(function()
			controls:Disable()
		end)
	end

	-- 2) камера: стартовая точка — где камера сейчас, финальная — напротив лица, чуть снизу (героический ракурс)
	local startCFrame = camera.CFrame
	local startFov = camera.FieldOfView
	local look = root.CFrame.LookVector
	local endPosition = focus + look * 7 + Vector3.new(0, -1.2, 0)
	local endCFrame = CFrame.lookAt(endPosition, focus)
	local midPosition = focus + (root.CFrame.RightVector * 6 + look * 11 + Vector3.new(0, 3, 0))
	local midCFrame = CFrame.lookAt(midPosition, focus)

	camera.CameraType = Enum.CameraType.Scriptable
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = startCFrame
	local fovValue = Instance.new("NumberValue")
	fovValue.Value = startFov

	-- 4) затемнение мира
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "RareCutsceneCC"
	correction.Parent = Lighting

	local finished = false
	local skipRequested = false
	local startedAt = os.clock()
	local connections: { RBXScriptConnection } = {}
	local shakeAmplitude = 0.0
	local shakeUntil = 0.0

	local function cleanup()
		if finished then
			return
		end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		pcall(function()
			RunService:UnbindFromRenderStep("RareCutscene")
		end)
		correction:Destroy()
		cframeValue:Destroy()
		fovValue:Destroy()
		if camera.Parent then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = startFov
		end
		if controls then
			pcall(function()
				controls:Enable()
			end)
		end
		Haptics.pulse(0, 0)
		playing = false
	end

	-- 3) камера каждый кадр = значение твина + тряска (после стандартной камеры Roblox)
	RunService:BindToRenderStep("RareCutscene", Enum.RenderPriority.Camera.Value + 1, function()
		if finished then
			return
		end
		local cf = cframeValue.Value
		local now = os.clock()
		if options.shake and now < shakeUntil then
			local falloff = (shakeUntil - now) / math.max(0.01, duration * 0.45)
			local a = shakeAmplitude * math.clamp(falloff, 0, 1)
			cf = cf
				* CFrame.new((math.random() - 0.5) * 2 * a, (math.random() - 0.5) * 2 * a, 0)
				* CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * 2 * a * 2))
		end
		camera.CFrame = cf
		camera.FieldOfView = fovValue.Value
	end)

	-- пропуск: Space, тап, A на геймпаде (не раньше чем через 0.7 с, чтобы случайное нажатие не съело эффект)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if os.clock() - startedAt < 0.7 then
				return
			end
			if
				input.KeyCode == Enum.KeyCode.Space
				or input.KeyCode == Enum.KeyCode.ButtonA
				or input.UserInputType == Enum.UserInputType.Touch
			then
				skipRequested = true
			end
		end)
	)
	-- смерть или исчезновение персонажа обрывают катсцену
	table.insert(
		connections,
		humanoid.Died:Connect(function()
			skipRequested = true
		end)
	)

	local ok = pcall(function()
		local approachTime = duration * 0.62
		local hitTime = duration - approachTime
		-- наезд: сначала дугой через боковую точку, затем к лицу
		local approach = TweenInfo.new(approachTime * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		TweenService:Create(cframeValue, approach, { Value = midCFrame }):Play()
		TweenService:Create(
			correction,
			TweenInfo.new(approachTime, Enum.EasingStyle.Sine),
			{ Brightness = -style.dim, Saturation = -0.5, Contrast = 0.12 }
		):Play()
		task.wait(approachTime * 0.5)
		if not skipRequested then
			TweenService:Create(
				cframeValue,
				TweenInfo.new(approachTime * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Value = endCFrame }
			):Play()
			TweenService:Create(
				fovValue,
				TweenInfo.new(approachTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Value = style.fov }
			):Play()
			Haptics.pulse(0.15, approachTime)
			task.wait(approachTime * 0.5)
		end

		-- удар: гром, вспышка цветом качества, тряска
		if not skipRequested then
			Sfx.play2D(Sounds.id("ThunderBoom"), 1, 0)
			Haptics.pulse(0.9, 0.35)
			shakeAmplitude = style.shake
			shakeUntil = os.clock() + hitTime * 0.9
			correction.TintColor = Color3.new(1, 1, 1):Lerp(options.color, 0.55)
			correction.Brightness = 0.45
			correction.Saturation = 0.2
			TweenService:Create(
				correction,
				TweenInfo.new(hitTime * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }
			):Play()
			local waited = 0.0
			while waited < hitTime and not skipRequested do
				waited += task.wait(0.05)
			end
		end
	end)
	if not ok then
		warn("[RareCutscene] error during cutscene, restoring camera")
	end

	cleanup()
	return ok
end

return RareCutscene
