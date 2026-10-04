--!strict
-- Проигрывание звуковых эффектов: общая SoundGroup "SFX" (громкость в Config.Audio), лёгкая случайная высота тона,
-- лимит одновременных звуков. Пустой ID — тишина без ошибок.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}

local MAX_ACTIVE = 16
local active = 0
local group: SoundGroup? = nil

local function getGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = Instance.new("SoundGroup")
	g.Name = "SFX"
	g.Volume = Config.Audio.SfxVolume
	g.Parent = SoundService
	group = g
	return g
end

local function play(soundId: string, parent: Instance, volume: number, pitchJitter: number, rollOff: number?)
	if soundId == "" or active >= MAX_ACTIVE then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.SoundGroup = getGroup()
	if pitchJitter > 0 then
		local pitch = Instance.new("PitchShiftSoundEffect")
		pitch.Octave = 1 + (math.random() * 2 - 1) * pitchJitter
		pitch.Parent = sound
	end
	if rollOff then
		sound.RollOffMaxDistance = rollOff
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
	end
	sound.Parent = parent
	active += 1
	sound.Ended:Once(function()
		active -= 1
		sound:Destroy()
	end)
	sound:Play()
	-- страховка: если Ended не придёт (звук не загрузился), всё равно освобождаем место
	task.delay(8, function()
		if sound.Parent then
			active -= 1
			sound:Destroy()
		end
	end)
end

-- Глобальный (2D) звук, например каст у самого игрока
function Sfx.play2D(soundId: string, volume: number?, pitchJitter: number?)
	play(soundId, SoundService, volume or 1, pitchJitter or 0.06, nil)
end

-- Позиционный (3D) звук: parent — деталь или Attachment в мире (например, точка попадания молнии)
function Sfx.play3D(soundId: string, parent: Instance, volume: number?, pitchJitter: number?, rollOff: number?)
	play(soundId, parent, volume or 1, pitchJitter or 0.08, rollOff or 150)
end

return Sfx
