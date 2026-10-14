-- Saved settings, LiteMount-style priorities and migration from the old
-- on/off toggles.

Hearths.DB_VERSION = 2

-- Priorities work like LiteMount's:
--   0 Never, 1 Normal, 2 More often, 3 A lot more often, 4 Always.
-- If any usable hearthstone is set to Always, only "Always" ones are rolled.
Hearths.PRIORITY = {
	NEVER = 0,
	NORMAL = 1,
	MORE = 2,
	MOST = 3,
	ALWAYS = 4,
}
Hearths.PRIORITY_MIN = 0
Hearths.PRIORITY_MAX = 4
Hearths.PRIORITY_WEIGHTS = { [1] = 1, [2] = 2, [3] = 6, [4] = 1 }
Hearths.PRIORITY_LABELS = {
	[0] = "Never",
	[1] = "Normal",
	[2] = "More often",
	[3] = "A lot more",
	[4] = "Always",
}
Hearths.PRIORITY_COLORS = {
	[0] = { 0.55, 0.55, 0.55 },
	[1] = { 0.35, 0.70, 1.00 },
	[2] = { 0.30, 0.85, 0.45 },
	[3] = { 1.00, 0.75, 0.20 },
	[4] = { 1.00, 0.45, 0.85 },
}

Hearths.defaults = {
	profile = {
		dbVersion = 0,
		priorities = {},         -- [toyId] = 0..4
		defaultPriority = 1,     -- priority for hearthstones you haven't touched
		includeDefaultHearthstone = false,
		includeAstralRecall = false,
		avoidRepeat = true,
		useNewImmediately = true, -- put a freshly learned hearthstone on the button right away
		hearthsKeybinding = nil,
		debugMode = false,
	},
}

function Hearths:GetPriority(toyId)
	local p = self.db.profile.priorities[toyId]
	if p == nil then
		p = self.db.profile.defaultPriority
	end
	return p
end

function Hearths:SetPriority(toyId, value)
	value = math.max(self.PRIORITY_MIN, math.min(self.PRIORITY_MAX, value))
	self.db.profile.priorities[toyId] = value
	self:SendMessage("HEARTHS_PRIORITIES_CHANGED")
end

function Hearths:SetAllPriorities(ids, value)
	for _, id in ipairs(ids) do
		self.db.profile.priorities[id] = value
	end
	self:SendMessage("HEARTHS_PRIORITIES_CHANGED")
end

-- v1 stored `useAllHearthstoneToys` + `enabledHearthstones` (string keys).
-- When "use all" was off, carry the hand-picked set over as Normal/Never.
function Hearths:MigrateProfile()
	local p = self.db.profile
	if (p.dbVersion or 0) >= self.DB_VERSION then
		return
	end

	if p.useAllHearthstoneToys == false and type(p.enabledHearthstones) == "table" then
		if type(p.availableHearthstones) == "table" then
			for key in pairs(p.availableHearthstones) do
				local id = tonumber(key)
				if id then p.priorities[id] = self.PRIORITY.NEVER end
			end
		end
		for key, enabled in pairs(p.enabledHearthstones) do
			local id = tonumber(key)
			if id then
				p.priorities[id] = enabled and self.PRIORITY.NORMAL or self.PRIORITY.NEVER
			end
		end
	end

	p.useAllHearthstoneToys = nil
	p.enabledHearthstones = nil
	p.availableHearthstones = nil
	p.dbVersion = self.DB_VERSION
end
