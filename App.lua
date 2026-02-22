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

local RETRY_DELAY_SECONDS = 1
local MAX_RETRY_ATTEMPTS = 10

function App:Initialize()
	self.scanningTooltip = nil
	self.isScanning = false
	self.retryAttempts = 0

	if Hearths.db.profile.debugMode then
		Hearths.Debug.settings.enabled = true
	end
end

function App:OnPlayerEnteringWorld()
	-- Initialize hidden scanning tooltip for item description parsing
	self.scanningTooltip = CreateFrame("GameTooltip", "HearthsScanningTooltip", UIParent, "GameTooltipTemplate")
	self.scanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")

	self:InitializeWithRetry()
end

function App:OnNewToyAdded()
	self:RefreshAvailableHearthstones()
end

function App:OnLoadingScreenDisabled()
	-- Delay for toy box data to be ready
	C_Timer.After(RETRY_DELAY_SECONDS, function()
		self:RefreshAvailableHearthstones()
		self:RefreshSelectedHearthstone()
	end)
end

function App:InitializeWithRetry()
	if C_ToyBox.GetNumToys() == 0 then
		self.retryAttempts = self.retryAttempts + 1
		if self.retryAttempts <= MAX_RETRY_ATTEMPTS then
			Hearths.Debug:Log("App", "ToyBox", "Toy box not loaded yet, retrying... (" .. self.retryAttempts .. "/" .. MAX_RETRY_ATTEMPTS .. ")")
			C_Timer.After(RETRY_DELAY_SECONDS, function() self:InitializeWithRetry() end)
			return
		else
			Hearths.Debug:Log("App", "ToyBox", "Toy box failed to load after " .. MAX_RETRY_ATTEMPTS .. " attempts")
			return
		end
	end

	-- Toy box is ready
	self:RefreshAvailableHearthstones()
	self:RefreshSelectedHearthstone()
end

function App:RefreshAvailableHearthstones()
	if self.isScanning then
		Hearths.Debug:Log("App", "Scanning", "Already scanning, skipping duplicate request")
		return
	end

	self.isScanning = true
	local availableHearthstones = Hearths:ConvertHearthstonesToOptions(self:GetAvailableHearthstones())

	Hearths.db.profile.availableHearthstones = availableHearthstones
	Hearths.options.args.selectedHearthstones.args = availableHearthstones

	Hearths:SendMessage("HEARTHS_DATA_UPDATED", availableHearthstones)

	self.isScanning = false
	Hearths.Debug:Log("App", "Hearthstones", "Refreshed available hearthstones")
end

function App:RefreshSelectedHearthstone()
	local candidates = self:GetEnabledHearthstones()
	local availableCandidates = {}

	for _, hearthstone in pairs(candidates) do
		if not self:IsOnCooldown(hearthstone.id, hearthstone.kind) then
			table.insert(availableCandidates, hearthstone)
		end
	end

	-- Shaman: use Astral Recall if everything else is on cooldown
	if #availableCandidates == 0 and self:IsPlayerShaman() and Hearths.db.profile.includeAstralRecall then
		local astralRecall = { id = HEARTHSTONE_IDS.ASTRAL_RECALL, kind = "spell" }
		if not self:IsOnCooldown(astralRecall.id, astralRecall.kind) then
			table.insert(availableCandidates, astralRecall)
		end
	end

	if #availableCandidates == 0 then
		Hearths.Debug:Log("App", "Selection", "No hearthstones available or all on cooldown")
		Hearths:SendMessage("HEARTHS_SELECTION_FAILED", "No hearthstones available or all on cooldown")
		return nil
	end

	-- Select random hearthstone from available candidates
	local randomIndex = math.random(1, #availableCandidates)
	local selectedHearthstone = availableCandidates[randomIndex]

	-- Apply Shaman special case
	selectedHearthstone = self:ApplyShamanCooldownLogic(selectedHearthstone)

	-- Notify UI layer of selection change
	Hearths:SendMessage("HEARTHS_SELECTION_CHANGED", selectedHearthstone)
	return selectedHearthstone
end

-- Shaman special case
function App:ApplyShamanCooldownLogic(hearthstone)
	if not self:IsPlayerShaman() or not Hearths.db.profile.includeAstralRecall then
		return hearthstone
	end

	-- If selected hearthstone is on cooldown but Astral Recall isn't, switch to Astral Recall
	if hearthstone.kind ~= "spell" and self:IsOnCooldown(hearthstone.id, hearthstone.kind) then
		if not self:IsOnCooldown(HEARTHSTONE_IDS.ASTRAL_RECALL, "spell") then
			Hearths.Debug:Log("App", "Cooldown", "Switching to Astral Recall due to cooldown")
			return { id = HEARTHSTONE_IDS.ASTRAL_RECALL, kind = "spell" }
		end
	end

	return hearthstone
end

-- Get list of enabled hearthstones
function App:GetEnabledHearthstones()
	local stones = {}

	-- Get toy hearthstones
	local candidates = Hearths.db.profile.enabledHearthstones
	if Hearths.db.profile.useAllHearthstoneToys then
		candidates = Hearths.db.profile.availableHearthstones
	end

	-- Add enabled toy hearthstones
	for toyId, enabled in pairs(candidates) do
		if enabled then
			table.insert(stones, { id = tonumber(toyId), kind = "toy" })
		end
	end

	-- Add default hearthstone if available and enabled
	if Hearths.db.profile.includeDefaultHearthstone and self:IsDefaultHearthstoneAvailable() then
		table.insert(stones, { id = HEARTHSTONE_IDS.DEFAULT, kind = "item" })
	end

	-- Add Astral Recall if player is a Shaman and enabled
	if Hearths.db.profile.includeAstralRecall and self:IsPlayerShaman() then
		table.insert(stones, { id = HEARTHSTONE_IDS.ASTRAL_RECALL, kind = "spell" })
	end

	return stones
end

-- Scan toy box for all available hearthstone toys
function App:GetAvailableHearthstones()
	local hearthstoneToys = {}

	local numToys = C_ToyBox.GetNumToys()
	Hearths.Debug:Log("App", "ToyBox", "Scanning " .. numToys .. " toys in toy box...")

	for i = 1, numToys do
		local toyId = C_ToyBox.GetToyFromIndex(i)
		if self:ShouldIncludeToy(toyId) then
			local _, toyName, icon = C_ToyBox.GetToyInfo(toyId)

			-- Get item description by scanning the tooltip
			local description = self:GetItemDescription(toyId)
			local hasHearthstoneDescription = string.match(description, "Returns you to ([^%.]+)")
			if hasHearthstoneDescription then
				local hearthstoneToy = {
					id = toyId,
					name = toyName,
					icon = icon,
					type = "toy",
				}
				table.insert(hearthstoneToys, hearthstoneToy)
				Hearths.Debug:Log("App", "Detection", "Added to candidates: " .. hearthstoneToy.name)
			end
		end
	end

	Hearths.Debug:Log("App", "Detection", "Found " .. #hearthstoneToys .. " usable hearthstone toys")
	return hearthstoneToys
end

-- Determine if a toy should be included in hearthstone selection
function App:ShouldIncludeToy(toyID)
	if not toyID or toyID == 0 then
		return false
	elseif toyID == HEARTHSTONE_IDS.DALARAN then
		return false -- Not part of randomizer
	elseif toyID == HEARTHSTONE_IDS.GARRISON then
		return false -- Not part of randomizer
	elseif FAKE_HEARTHSTONE_IDS[toyID] then
		return false
	elseif not PlayerHasToy(toyID) then
		return false
	end

	return true
end

-- Extract item description
function App:GetItemDescription(itemId)
	if not self.scanningTooltip then
		return ""
	end

	self.scanningTooltip:ClearLines()
	self.scanningTooltip:SetHyperlink("item:" .. itemId)

	local descriptionText = ""
	local numLines = self.scanningTooltip:NumLines()

	for i = 1, numLines do
		local line = _G["HearthsScanningTooltipTextLeft" .. i]
		if line and line:GetText() then
			local text = line:GetText()
			-- Skip first line (name) and just get the description
			if i > 1 then
				descriptionText = descriptionText .. text .. " "
			end
		end
	end

	self.scanningTooltip:ClearLines()
	return descriptionText
end

-- Check if an item or spell is on cooldown
function App:IsOnCooldown(id, kind)
	local duration = 0
	if kind == "spell" then
		local spellInfo = C_Spell.GetSpellCooldown(id)
		if not spellInfo then
			return false
		end
		_, duration = spellInfo
	else
		_, duration = C_Item.GetItemCooldown(id)
	end
	if not duration then
		return false
	end
	return duration > 0
end

-- Is the Player a Shaman
function App:IsPlayerShaman()
	local _, playerClass = UnitClass("player")
	return playerClass == "SHAMAN"
end

-- Check if default hearthstone item is available (don't include if deleted)
function App:IsDefaultHearthstoneAvailable()
	return C_Item.GetItemCount(HEARTHSTONE_IDS.DEFAULT, false, false, false, false) > 0
end

-- Hearthstone constants accessor
function App:GetHearthstoneIDs()
	return HEARTHSTONE_IDS
end
