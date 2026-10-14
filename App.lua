Hearths.App = {}
local App = Hearths.App

local HEARTHSTONE_IDS = {
	DALARAN = 140192,
	GARRISON = 110560,
	DEFAULT = 6948,
	ASTRAL_RECALL = 556,
}

-- Toys that match hearthstone tooltip patterns but aren't actual hearthstones
local FAKE_HEARTHSTONE_IDS = {
	[95567] = true, -- Kirin Tor Beacon
	[95568] = true, -- Sunreaver Beacon
}

local HEARTHSTONE_TOOLTIP_TEXT = "Speak to an Innkeeper in a different place to change your home location."
local LOGIN_LOAD_DELAY_SECONDS = 3

function App:Initialize()
	self.scanningTooltip = nil
	self.isScanning = false
	self.owned = {}      -- [toyId] = { id, name, icon, known = catalogue entry or nil }
	self.ownedCount = 0
end

function App:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
	if not self.scanningTooltip then
		-- Hidden tooltip used to spot hearthstone toys that aren't in the catalogue yet
		self.scanningTooltip = CreateFrame("GameTooltip", "HearthsScanningTooltip", UIParent, "GameTooltipTemplate")
		self.scanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end

	if isInitialLogin or isReloadingUi then
		-- Cold login/reload: toy box data may not be ready yet, so wait
		-- briefly and just restore whatever the macro already has instead
		-- of rerolling.
		C_Timer.After(LOGIN_LOAD_DELAY_SECONDS, function()
			self:RefreshAvailableHearthstones()
			self:LoadCurrentHearthstone()
		end)
	else
		-- Any other loading screen during play (zoning, portals, hearth use,
		-- etc.) - rescan and roll a new hearthstone so the macro rotates.
		self:RefreshAvailableHearthstones()
		self:RefreshSelectedHearthstone()
	end
end

function App:OnNewToyAdded(itemId, isRetry)
	self:RefreshAvailableHearthstones()

	itemId = tonumber(itemId)
	if not (itemId and Hearths.db.profile.useNewImmediately) then
		return
	end
	-- Only for hearthstones we can actually use and haven't set to Never
	local info = self.owned[itemId]
	if not info then
		-- The toy box can lag the event by a moment; look again once
		if not isRetry then
			C_Timer.After(1, function() self:OnNewToyAdded(itemId, true) end)
		end
		return
	end
	if not self:MeetsRestrictions(itemId) then
		return
	end
	if Hearths:GetPriority(itemId) <= Hearths.PRIORITY.NEVER then
		return
	end

	Hearths:SendMessage("HEARTHS_SELECTION_CHANGED", { id = itemId, kind = "toy" })
	Hearths:Print("New hearthstone! |cffffffff" .. (info.name or itemId) .. "|r is on your Hearths button.")
end

function App:LoadCurrentHearthstone()
	local currentHearthstone = Hearths.UI:GetCurrentHearthstone()
	if currentHearthstone and self:IsCandidate(currentHearthstone) then
		Hearths:SendMessage("HEARTHS_SELECTION_CHANGED", currentHearthstone)
		return
	end

	self:RefreshSelectedHearthstone()
end

---------------------------------------------------------------------------
-- Collection scanning
---------------------------------------------------------------------------

function App:RefreshAvailableHearthstones()
	if self.isScanning then
		Hearths.Debug:Log("App", "Scanning", "Already scanning, skipping duplicate request")
		return
	end
	self.isScanning = true

	local owned = {}
	local count = 0

	-- 1) Everything we know about: cheap PlayerHasToy checks
	for _, entry in ipairs(Hearths.Data.HEARTHSTONES) do
		if PlayerHasToy(entry.id) then
			local _, toyName, icon = C_ToyBox.GetToyInfo(entry.id)
			owned[entry.id] = { id = entry.id, name = toyName or entry.name, icon = icon, known = entry }
			count = count + 1
		end
	end

	-- 2) Anything else in the toy box whose tooltip reads like a hearthstone
	--    (new toys that aren't in Data.lua yet)
	local numToys = C_ToyBox.GetNumToys()
	for i = 1, numToys do
		local toyId = C_ToyBox.GetToyFromIndex(i)
		if toyId and toyId > 0 and not owned[toyId] and not Hearths.Data:Get(toyId)
			and not FAKE_HEARTHSTONE_IDS[toyId]
			and toyId ~= HEARTHSTONE_IDS.DALARAN and toyId ~= HEARTHSTONE_IDS.GARRISON
			and PlayerHasToy(toyId) then
			local description = self:GetItemDescription(toyId)
			if string.find(description, HEARTHSTONE_TOOLTIP_TEXT, 1, true) then
				local _, toyName, icon = C_ToyBox.GetToyInfo(toyId)
				owned[toyId] = { id = toyId, name = toyName or ("Toy " .. toyId), icon = icon }
				count = count + 1
				Hearths.Debug:Log("App", "Detection", "Uncatalogued hearthstone: " .. tostring(toyName) .. " (" .. toyId .. ")")
			end
		end
	end

	self.owned = owned
	self.ownedCount = count
	self:BuildSpellMap()
	self.isScanning = false

	Hearths:SendMessage("HEARTHS_DATA_UPDATED")
	Hearths.Debug:Log("App", "Hearthstones", "Found " .. count .. " hearthstone toys")
end

-- Full collection for the Collection page: catalogue + uncatalogued owned toys.
-- Each row: { id, name, icon, owned, usable, reason, priority, entry }
function App:GetCollection()
	local rows = {}

	for _, entry in ipairs(Hearths.Data.HEARTHSTONES) do
		local ownedInfo = self.owned[entry.id]
		local usable, reason = self:MeetsRestrictions(entry.id)
		rows[#rows + 1] = {
			id = entry.id,
			name = (ownedInfo and ownedInfo.name) or C_Item.GetItemNameByID(entry.id) or entry.name,
			icon = (ownedInfo and ownedInfo.icon) or C_Item.GetItemIconByID(entry.id),
			owned = ownedInfo ~= nil,
			usable = usable,
			reason = reason,
			priority = Hearths:GetPriority(entry.id),
			entry = entry,
		}
	end

	for id, info in pairs(self.owned) do
		if not info.known then
			rows[#rows + 1] = {
				id = id,
				name = info.name,
				icon = info.icon,
				owned = true,
				usable = true,
				priority = Hearths:GetPriority(id),
			}
		end
	end

	return rows
end

function App:GetCollectionCounts()
	return self.ownedCount, #Hearths.Data.HEARTHSTONES + (self.ownedCount - self:CountKnownOwned())
end

function App:CountKnownOwned()
	local n = 0
	for _, info in pairs(self.owned) do
		if info.known then n = n + 1 end
	end
	return n
end

---------------------------------------------------------------------------
-- Selection
---------------------------------------------------------------------------

-- Weighted candidate list (toys with priority > 0 that we can use), plus
-- the default Hearthstone item if enabled.
function App:GetEnabledHearthstones()
	local stones = {}
	local anyAlways = false

	for id in pairs(self.owned) do
		local p = Hearths:GetPriority(id)
		if p > Hearths.PRIORITY.NEVER and self:MeetsRestrictions(id) then
			stones[#stones + 1] = { id = id, kind = "toy", priority = p }
			if p == Hearths.PRIORITY.ALWAYS then anyAlways = true end
		end
	end

	if Hearths.db.profile.includeDefaultHearthstone and self:IsDefaultHearthstoneAvailable() then
		stones[#stones + 1] = { id = HEARTHSTONE_IDS.DEFAULT, kind = "item", priority = Hearths.PRIORITY.NORMAL }
	end

	-- "Always" wins: only roll among the Always hearthstones
	if anyAlways then
		local always = {}
		for _, s in ipairs(stones) do
			if s.priority == Hearths.PRIORITY.ALWAYS then always[#always + 1] = s end
		end
		stones = always
	end

	table.sort(stones, function(a, b) return a.id < b.id end)
	return stones
end

function App:IsCandidate(hearthstone)
	if hearthstone.kind == "spell" then
		return self:IsPlayerShaman() and Hearths.db.profile.includeAstralRecall
	end
	for _, s in ipairs(self:GetEnabledHearthstones()) do
		if s.id == hearthstone.id then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Usage tracking (bad-luck protection)
---------------------------------------------------------------------------

function App:GetUsage(id)
	return Hearths.db.char.usage[id] or 0
end

function App:ResetUsage()
	wipe(Hearths.db.char.usage)
	Hearths:SendMessage("HEARTHS_PRIORITIES_CHANGED")
end

-- Map the teleport spell each hearthstone casts back to the hearthstone, so a
-- successful cast (from our button OR the toy box) counts as a use.
function App:BuildSpellMap()
	local map = {}
	local function add(id)
		local _, spellId = C_Item.GetItemSpell(id)
		if spellId then map[spellId] = id end
	end
	for id in pairs(self.owned) do add(id) end
	add(HEARTHSTONE_IDS.DEFAULT)
	map[HEARTHSTONE_IDS.ASTRAL_RECALL] = HEARTHSTONE_IDS.ASTRAL_RECALL
	self.spellToStone = map
end

function App:OnSpellcastSucceeded(unit, spellId)
	if unit ~= "player" or not spellId then return end
	if issecretvalue and issecretvalue(spellId) then return end
	if not self.spellToStone then self:BuildSpellMap() end
	local id = self.spellToStone[spellId]
	if not id then return end
	local usage = Hearths.db.char.usage
	usage[id] = (usage[id] or 0) + 1
	Hearths.Debug:Log("App", "Usage", tostring(id) .. " used " .. usage[id] .. "x")
	Hearths:SendMessage("HEARTHS_PRIORITIES_CHANGED")
end

-- Multiplier from bad-luck protection: (most + 1) / (uses + 1), capped.
-- Everything used equally -> 1x for all, so it only ever evens things out.
function App:GetLessUsedBoost(id, mostUsed)
	if not Hearths.db.profile.favorLessUsed then return 1 end
	local boost = (mostUsed + 1) / (self:GetUsage(id) + 1)
	return math.min(Hearths.MAX_LESS_USED_BOOST, boost)
end

function App:GetWeight(stone, mostUsed)
	local base = Hearths.PRIORITY_WEIGHTS[stone.priority] or 0
	return base * self:GetLessUsedBoost(stone.id, mostUsed)
end

function App:WeightedPick(list)
	local mostUsed = 0
	for _, s in ipairs(list) do
		mostUsed = math.max(mostUsed, self:GetUsage(s.id))
	end

	local weights, total = {}, 0
	for i, s in ipairs(list) do
		weights[i] = self:GetWeight(s, mostUsed)
		total = total + weights[i]
	end
	if total <= 0 then return list[math.random(1, #list)] end

	local cutoff = math.random() * total
	local t = 0
	for i, s in ipairs(list) do
		t = t + weights[i]
		if t > cutoff then return s end
	end
	return list[#list]
end

-- manual = true when the player asked for it (Re-roll button), so we say what happened
function App:RefreshSelectedHearthstone(manual)
	local candidates = self:GetEnabledHearthstones()
	Hearths.Debug:Log("App", "Candidates", "Number of enabled hearthstones: " .. tostring(#candidates))

	local offCooldown = {}
	for _, hearthstone in ipairs(candidates) do
		if not self:IsOnCooldown(hearthstone.id, hearthstone.kind) then
			offCooldown[#offCooldown + 1] = hearthstone
		end
	end

	-- Don't show the same one twice in a row if there's a choice
	if Hearths.db.profile.avoidRepeat and #offCooldown > 1 then
		local current = Hearths.UI:GetCurrentHearthstone()
		if current then
			for i, s in ipairs(offCooldown) do
				if s.id == current.id then
					table.remove(offCooldown, i)
					break
				end
			end
		end
	end

	-- Shaman: use Astral Recall if everything else is on cooldown
	if #offCooldown == 0 and self:IsPlayerShaman() and Hearths.db.profile.includeAstralRecall then
		if not self:IsOnCooldown(HEARTHSTONE_IDS.ASTRAL_RECALL, "spell") then
			offCooldown[1] = { id = HEARTHSTONE_IDS.ASTRAL_RECALL, kind = "spell" }
		end
	end

	-- Hearthstone toys share one cooldown, so right after hearthing they're
	-- ALL on cooldown. Keep rotating anyway instead of freezing the macro.
	local pool = offCooldown
	if #pool == 0 then
		pool = {}
		local current = Hearths.db.profile.avoidRepeat and #candidates > 1 and Hearths.UI:GetCurrentHearthstone()
		for _, s in ipairs(candidates) do
			if not (current and s.id == current.id) then
				pool[#pool + 1] = s
			end
		end
	end

	if #pool == 0 then
		Hearths.Debug:Log("App", "Selection", "No hearthstones enabled")
		Hearths:SendMessage("HEARTHS_SELECTION_FAILED", "No hearthstones enabled - check the Collection page")
		if manual then
			Hearths:Print("Nothing to roll - every hearthstone is set to Never (see /hearths collection).")
		end
		return nil
	end

	local selected = self:WeightedPick(pool)
	Hearths:SendMessage("HEARTHS_SELECTION_CHANGED", selected)
	if manual then
		Hearths:Print("Next up: |cffffffff" .. self:GetDisplayName(selected) .. "|r")
	end
	return selected
end

function App:GetDisplayName(stone)
	if stone.kind == "spell" then
		return C_Spell.GetSpellName(stone.id) or "Astral Recall"
	elseif stone.kind == "toy" then
		local _, name = C_ToyBox.GetToyInfo(stone.id)
		if name then return name end
	end
	local entry = Hearths.Data:Get(stone.id)
	return C_Item.GetItemNameByID(stone.id) or (entry and entry.name) or tostring(stone.id)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function App:GetItemDescription(itemId)
	if not self.scanningTooltip then
		return ""
	end

	self.scanningTooltip:ClearLines()
	self.scanningTooltip:SetHyperlink("item:" .. itemId)

	local parts = {}
	for i = 2, self.scanningTooltip:NumLines() do
		local line = _G["HearthsScanningTooltipTextLeft" .. i]
		local text = line and line:GetText()
		if text then parts[#parts + 1] = text end
	end

	self.scanningTooltip:ClearLines()
	return table.concat(parts, " ")
end

function App:IsOnCooldown(id, kind)
	local duration
	if kind == "spell" then
		local info = C_Spell.GetSpellCooldown(id)
		duration = type(info) == "table" and info.duration or info
	else
		local _
		_, duration = C_Item.GetItemCooldown(id)
	end
	-- Midnight can hand back secret values in restricted contexts; comparing
	-- one would error, so treat it as "not on cooldown".
	if issecretvalue and issecretvalue(duration) then
		return false
	end
	-- GCD shows up as a short cooldown; ignore anything under 2s
	return (duration or 0) > 2
end

-- Returns usable, reasonIfNot
function App:MeetsRestrictions(toyId)
	local entry = Hearths.Data:Get(toyId)
	local restrict = entry and entry.restrict
	if not restrict then
		return true
	end

	if restrict.race then
		local _, raceFile = UnitRace("player")
		if not restrict.race[raceFile] then
			return false, "Wrong race for this character"
		end
	end

	if restrict.covenant then
		local active = C_Covenants and C_Covenants.GetActiveCovenantID and C_Covenants.GetActiveCovenantID() or 0
		if active ~= restrict.covenant then
			return false, "Needs this character pledged to the covenant"
		end
	end

	return true
end

function App:IsPlayerShaman()
	local _, playerClass = UnitClass("player")
	return playerClass == "SHAMAN"
end

-- Check if default hearthstone item is available (don't include if deleted)
function App:IsDefaultHearthstoneAvailable()
	return C_Item.GetItemCount(HEARTHSTONE_IDS.DEFAULT, false, false, false, false) > 0
end

function App:GetHearthstoneIDs()
	return HEARTHSTONE_IDS
end
