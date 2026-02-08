Hearths = LibStub("AceAddon-3.0"):NewAddon("Hearths", "AceEvent-3.0", "AceConsole-3.0")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")

function Hearths:OnInitialize()
	-- Handle database migration from old version
	HearthsDB = HearthsDB or {}
	if type(HearthsDB.profileKeys) ~= "table" then
		-- Old database from before rewrite - reset it
		HearthsDB = {}
	end

	-- Initialize database with defaults (defined in Options.lua)
	self.db = LibStub("AceDB-3.0"):New("HearthsDB", self.defaults, true)

	self.App:Initialize()
	self.UI:Initialize()

	AC:RegisterOptionsTable("Hearths_Options", self.options)
	self.optionsFrame = ACD:AddToBlizOptions("Hearths_Options", "Hearths")

	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	AC:RegisterOptionsTable("Hearths_Profiles", profiles)
	ACD:AddToBlizOptions("Hearths_Profiles", "Profiles", "Hearths")

	-- Module Messages Handlers
	self:RegisterMessage("HEARTHS_DATA_UPDATED", function(_, ...)
		self.UI:OnDataUpdated("HEARTHS_DATA_UPDATED", ...)
		ACD:ConfigTableChanged(nil, "Hearths_Options")
	end)
	self:RegisterMessage("HEARTHS_SELECTION_CHANGED", function(_, ...)
		self.UI:OnSelectionChanged("HEARTHS_SELECTION_CHANGED", ...)
	end)
	self:RegisterMessage("HEARTHS_SELECTION_FAILED", function(_, ...)
		self.UI:OnSelectionFailed("HEARTHS_SELECTION_FAILED", ...)
	end)

	-- Register slash command
	self:RegisterChatCommand("hearths", "SlashCommand")
end

function Hearths:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		self.App:OnPlayerEnteringWorld()
		self.UI:OnPlayerEnteringWorld()
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		self.UI:OnCombatEnd()
	end)
	self:RegisterEvent("NEW_TOY_ADDED", function()
		self.App:OnNewToyAdded()
	end)
	self:RegisterEvent("LOADING_SCREEN_DISABLED", function()
		self.App:OnLoadingScreenDisabled()
	end)
end

-- Slash command handler
function Hearths:SlashCommand(input)
	local args = { strsplit(" ", input:lower()) }
	local command = args[1] or ""

	if command == "" or command == "options" or command == "opts" then
		self.App:RefreshAvailableHearthstones()
		Settings.OpenToCategory(self.optionsFrame.name)
	elseif command == "list" then
		self:PrintHearthstoneList()
	elseif command == "refresh" then
		self.App:RefreshAvailableHearthstones()
		self.App:RefreshSelectedHearthstone()
	elseif command == "debug" then
		-- Handle debug subcommands
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

-- Print enabled hearthstones (for debugging)
function Hearths:PrintHearthstoneList()
	local availCount = 0
	for _ in pairs(self.db.profile.availableHearthstones) do availCount = availCount + 1 end
	self:Print("|cFFFF8040[Hearths]|r Available in DB: " .. availCount .. ", Toys in box: " .. C_ToyBox.GetNumToys() .. ", Use all: " .. tostring(self.db.profile.useAllHearthstoneToys))

	local stones = self.App:GetEnabledHearthstones()
	self:Print("|cFFFF8040[Hearths - Enabled Hearthstones]|r (" .. #stones .. " total)")
	for _, stone in ipairs(stones) do
		local name
		if stone.kind == "spell" then
			name = C_Spell.GetSpellName(stone.id) or tostring(stone.id)
		elseif stone.kind == "toy" then
			local _, toyName = C_ToyBox.GetToyInfo(stone.id)
			name = toyName or tostring(stone.id)
		else
			name = C_Item.GetItemNameByID(stone.id) or tostring(stone.id)
		end
		self:Print("  " .. stone.kind .. ": " .. name .. " (" .. tostring(stone.id) .. ")")
	end
end

function Hearths:PrintHelp()
	local help = {
		"|cFFFF8040[Hearths Commands]|r",
		"/hearths - Open settings panel",
		"/hearths list - Show enabled hearthstones",
		"/hearths refresh - Update macro selection",
		"/hearths debug <cmd> - Debug commands (use 'debug help' for details)",
	}

	for _, line in ipairs(help) do
		self:Print(line)
	end
end

function Hearths:PrintDebugHelp()
	local help = {
		"|cFFFF8040[Hearths Debug Commands]|r",
		"/hearths debug on|off - Enable/disable debug logging",
	}

	for _, line in ipairs(help) do
		self:Print(line)
	end
end
