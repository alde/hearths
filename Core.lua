Hearths = LibStub("AceAddon-3.0"):NewAddon("Hearths", "AceEvent-3.0", "AceConsole-3.0")

function Hearths:OnInitialize()
	-- Handle database migration from old version
	HearthsDB = HearthsDB or {}
	if type(HearthsDB.profileKeys) ~= "table" then
		-- Old database from before rewrite - reset it
		HearthsDB = {}
	end

	-- Initialize database with defaults (defined in Options.lua)
	self.db = LibStub("AceDB-3.0"):New("HearthsDB", self.defaults, true)
	self:MigrateProfile()

	local function OnProfileChanged()
		self:MigrateProfile()
		self.App:RefreshSelectedHearthstone()
		self.Settings:OnProfileChanged()
	end
	self.db.RegisterCallback(self, "OnProfileChanged", OnProfileChanged)
	self.db.RegisterCallback(self, "OnProfileCopied", OnProfileChanged)
	self.db.RegisterCallback(self, "OnProfileReset", OnProfileChanged)

	self.App:Initialize()
	self.UI:Initialize()

	-- Module Messages Handlers
	self:RegisterMessage("HEARTHS_DATA_UPDATED", function()
		self.UI:OnDataUpdated()
		self.Settings:Refresh()
	end)
	self:RegisterMessage("HEARTHS_PRIORITIES_CHANGED", function()
		self.Settings:Refresh()
	end)
	self:RegisterMessage("HEARTHS_SELECTION_CHANGED", function(_, ...)
		self.UI:OnSelectionChanged("HEARTHS_SELECTION_CHANGED", ...)
	end)
	self:RegisterMessage("HEARTHS_SELECTION_FAILED", function(_, ...)
		self.UI:OnSelectionFailed("HEARTHS_SELECTION_FAILED", ...)
	end)

	self:RegisterChatCommand("hearths", "SlashCommand")
end

function Hearths:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
		self.UI:OnPlayerEnteringWorld()
		self.App:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		self.UI:OnCombatEnd()
	end)
	self:RegisterEvent("NEW_TOY_ADDED", function(_, itemId)
		self.App:OnNewToyAdded(itemId)
	end)
	-- Covenant swaps change which covenant hearthstones are usable
	self:RegisterEvent("COVENANT_CHOSEN", function()
		self.App:RefreshSelectedHearthstone()
		self.Settings:Refresh()
	end)
end

function Hearths:SlashCommand(input)
	local args = { strsplit(" ", (input or ""):lower()) }
	local command = args[1] or ""

	if command == "" or command == "options" or command == "opts" or command == "config" then
		self.App:RefreshAvailableHearthstones()
		self.Settings:Toggle()
	elseif command == "collection" or command == "c" then
		self.App:RefreshAvailableHearthstones()
		self.Settings:OpenCollection("all")
	elseif command == "missing" or command == "m" then
		self.App:RefreshAvailableHearthstones()
		self:PrintMissing()
		self.Settings:OpenCollection("missing")
	elseif command == "list" then
		self:PrintHearthstoneList()
	elseif command == "refresh" or command == "reroll" then
		self.App:RefreshAvailableHearthstones()
		self.App:RefreshSelectedHearthstone(true)
	elseif command == "debug" then
		local debugCmd = args[2] or ""
		if debugCmd == "on" or debugCmd == "enable" then
			self.db.profile.debugMode = true
			self:Print("Debug logging enabled")
		elseif debugCmd == "off" or debugCmd == "disable" then
			self.db.profile.debugMode = false
			self:Print("Debug logging disabled")
		else
			self:PrintDebugHelp()
		end
	else
		self:PrintHelp()
	end
end

-- Print the current rotation with priorities
function Hearths:PrintHearthstoneList()
	local stones = self.App:GetEnabledHearthstones()
	self:Print(string.format("|cFFFF8040Rotation|r (%d of %d collected)", #stones, self.App.ownedCount))
	for _, stone in ipairs(stones) do
		local name
		if stone.kind == "toy" then
			local _, toyName = C_ToyBox.GetToyInfo(stone.id)
			name = toyName or tostring(stone.id)
		else
			name = C_Item.GetItemNameByID(stone.id) or tostring(stone.id)
		end
		self:Print(string.format("  %s  |cff999999(%s)|r", name, self.PRIORITY_LABELS[stone.priority] or "?"))
	end
end

-- Print missing hearthstones you can still get, grouped
function Hearths:PrintMissing()
	local groups = { available = {}, seasonal = {}, shop = {} }
	for _, data in ipairs(self.App:GetCollection()) do
		if not data.owned and data.entry and groups[data.entry.status] then
			table.insert(groups[data.entry.status], data)
		end
	end

	local have, total = self.App:GetCollectionCounts()
	self:Print(string.format("|cFFFF8040Collected %d / %d hearthstones|r", have, total))
	for _, def in ipairs({ { "available", "Obtainable now" }, { "seasonal", "Seasonal" }, { "shop", "Shop" } }) do
		local list = groups[def[1]]
		if #list > 0 then
			table.sort(list, function(a, b) return a.name < b.name end)
			self:Print("|cff59b3ff" .. def[2] .. "|r")
			for _, data in ipairs(list) do
				self:Print("  |cffffffff" .. data.name .. "|r - " .. data.entry.source)
			end
		end
	end
end

function Hearths:PrintHelp()
	local help = {
		"|cFFFF8040[Hearths Commands]|r",
		"/hearths - Open settings",
		"/hearths collection - Browse all hearthstones and set priorities",
		"/hearths missing - List hearthstones you're missing and how to get them",
		"/hearths list - Show the current rotation",
		"/hearths refresh - Rescan and re-roll",
		"/hearths debug on|off - Toggle debug logging",
	}
	for _, line in ipairs(help) do
		self:Print(line)
	end
end

function Hearths:PrintDebugHelp()
	self:Print("|cFFFF8040[Hearths Debug Commands]|r")
	self:Print("/hearths debug on|off - Enable/disable debug logging")
end
