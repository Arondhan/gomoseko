--!strict
-- Чистый алгоритм выбора следующей цели для цепных скиллов. Не использует Roblox-инстансы,
-- поэтому его можно проверять вне Studio. Используется server/Services/CombatService.

local ChainSearch = {}

export type Candidate<T> = { id: T, position: Vector3 }

-- Ближайший к origin кандидат в радиусе radius, которого нет в excluded. nil, если подходящих нет.
function ChainSearch.findNext<T>(
	candidates: { Candidate<T> },
	origin: Vector3,
	radius: number,
	excluded: { [T]: boolean }
): Candidate<T>?
	local best: Candidate<T>? = nil
	local bestDist = radius
	for _, candidate in candidates do
		if not excluded[candidate.id] then
			local dist = (candidate.position - origin).Magnitude
			if dist <= bestDist then
				best = candidate
				bestDist = dist
			end
		end
	end
	return best
end

return ChainSearch
