--!strict
-- Чистая математика «часиков» кулдауна (как в WoW: тёмная область сжимается по часовой стрелке от 12 часов).
-- Правая и левая половинки закрашиваются полуплоскостью-градиентом; здесь считаем, что куда ставить.

local CooldownMath = {}

-- Доля оставшегося кулдауна 0..1
function CooldownMath.fraction(remaining: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp(remaining / total, 0, 1)
end

-- Угол «стрелки» в градусах по часовой от 12 часов: 0 — кулдаун только начался, 360 — закончился.
-- Тёмная область — сектор от стрелки по часовой до 12 часов.
function CooldownMath.hand(remaining: number, total: number): number
	return (1 - CooldownMath.fraction(remaining, total)) * 360
end

export type Sweep = {
	rightDark: boolean, -- правая половинка закрашена градиентом (иначе чистая)
	rightRotation: number, -- Rotation градиента правой половинки
	leftDark: boolean, -- левая половинка закрашена градиентом (иначе полностью тёмная)
	leftRotation: number,
}

-- Состояние двух половинок для угла стрелки.
-- Правая половинка: пока стрелка в ней (0..180) — полуплоскость с Rotation = hand, дальше — чистая.
-- Левая половинка: пока стрелка в правой — полностью тёмная, потом — полуплоскость с Rotation = hand.
function CooldownMath.sweep(remaining: number, total: number): Sweep
	local hand = CooldownMath.hand(remaining, total)
	return {
		rightDark = hand < 180,
		rightRotation = hand,
		leftDark = hand >= 180,
		leftRotation = hand,
	}
end

return CooldownMath
