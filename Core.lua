Hearths = LibStub("AceAddon-3.0"):NewAddon("Hearths", "AceEvent-3.0", "AceConsole-3.0")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")

local Hearthstone = {
	Dalaran = 140192,
	Garrison = 110560,
	Default = 6948,
	AstralRecall = 556,
}

Hearths.scanningTooltip = {}
Hearths.triedRefreshInCombat = false

function Hearths:CreateHearthstoneButton()
	local frame = CreateFrame("Button", "HEARTHS_BTN", nil, "SecureActionButtonTemplate");
	frame:SetSize(1, 1);
	frame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1);
	frame:RegisterForClicks("AnyUp", "AnyDown");
	frame:SetAttribute("useOnKeyDown", false);

	if self.db.profile.hearthsKeybinding then
		SetBindingClick(self.db.profile.hearthsKeybinding, frame:GetName())
	end

	if PlayerHasToy(Hearthstone.Dalaran) then  -- Dalaran Hearthstone
		frame:SetAttribute("shift-type1", "toy")
		frame:SetAttribute("shift-toy1", Hearthstone.Dalaran)
	end
	if PlayerHasToy(Hearthstone.Garrison) then -- Garrison Hearthstone
		frame:SetAttribute("ctrl-type1", "toy")
		frame:SetAttribute("ctrl-toy1", Hearthstone.Garrison)
	end
	return frame
end

function Hearths:OnInitialize()
	HearthsDB = HearthsDB or {}
	if type(HearthsDB.profileKeys) ~= "table" then
		-- Old database from before rewrite - reset it
		HearthsDB = {}
	end

	-- uses the "Default" profile instead of character-specific profiles
	-- https://www.wowace.com/projects/ace3/pages/api/ace-db-3-0
	self.db = LibStub("AceDB-3.0"):New("HearthsDB", self.defaults, true)

	-- registers an options table and adds it to the Blizzard options window
	-- https://www.wowace.com/projects/ace3/pages/api/ace-config-3-0
	AC:RegisterOptionsTable("Hearths_Options", self.options)
	self.optionsFrame = ACD:AddToBlizOptions("Hearths_Options", "Hearths")

	-- adds a child options table, in this case our profiles panel
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	AC:RegisterOptionsTable("Hearths_Profiles", profiles)
	ACD:AddToBlizOptions("Hearths_Profiles", "Profiles", "Hearths")

	self:RegisterChatCommand("hearths", "SlashCommand")
end

function Hearths:OnEnable()
	self:RegisterEvent("NEW_TOY_ADDED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("LOADING_SCREEN_DISABLED")
end

function Hearths:PLAYER_REGEN_ENABLED()
	if self.triedRefreshInCombat then
		self.triedRefreshInCombat = false
		Hearths:RefreshSelectedHearthstone()
	end
end

function Hearths:AreToysLoaded()
	C_Timer.After(1, function()
		if C_ToyBox.GetNumToys() == 0 then
			return Hearths:AreToysLoaded()
		end
		return true
	end)
end

function Hearths:PLAYER_ENTERING_WORLD()
	self.scanningTooltip = CreateFrame("GameTooltip", "HearthsScanningTooltip", UIParent, "GameTooltipTemplate")
	self.scanningTooltip:SetOwner(UIParent, "ANCHOR_NONE") -- Ensures it's hidden

	self.hearthsButton = Hearths:CreateHearthstoneButton()

	if Hearths:AreToysLoaded() then
		if #self.db.profile.availableHearthstones == 0 then
			Hearths:RefreshAvailableHearthstones()
		end
		Hearths:RefreshSelectedHearthstone()
	end
end

function Hearths:LOADING_SCREEN_DISABLED()
	C_Timer.After(1, function()
		Hearths:RefreshAvailableHearthstones()
		Hearths:RefreshSelectedHearthstone()
	end)
end

function Hearths:NEW_TOY_ADDED()
	Hearths:RefreshAvailableHearthstones()
end

function Hearths:IsPlayerShaman()
	local _, playerClass = UnitClass("player")
	return playerClass == "SHAMAN"
end

function Hearths:IsDefaultHearthstoneAvailable()
	return GetItemCount(Hearthstone.Default) > 0
end

function Hearths:ShouldIncludeToy(toyID)
	if not toyID and toyID == 0 then
		return false
	elseif toyID == Hearthstone.Dalaran then
		return false
	elseif toyID == Hearthstone.Garrison then
		return false
	elseif not PlayerHasToy(toyID) then
		return false
	end

	return true
end

function Hearths:GetItemDescription(itemId)
	self.scanningTooltip:ClearLines()
	self.scanningTooltip:SetHyperlink("item:" .. itemId)

	local descriptionText = ""
	local numLines = self.scanningTooltip:NumLines()

	for i = 1, numLines do
		local line = _G["HearthsScanningTooltipTextLeft" .. i]
		if line and line:GetText() then
			local text = line:GetText()
			-- Skip the item name line and focus on description lines
			if i > 1 then -- Skip first line (item name)
				descriptionText = descriptionText .. text .. " "
			end
		end
	end

	self.scanningTooltip:ClearLines()
	return descriptionText
end

function Hearths:GetAvailableHearhstones()
	local hearthstoneToys = {}

	local numToys = C_ToyBox.GetNumToys()
	Hearths:Debug("Scanning " .. numToys .. " toys in toy box...")
	for i = 1, numToys do
		local toyId = C_ToyBox.GetToyFromIndex(i)
		if Hearths:ShouldIncludeToy(toyId) then
			local _, toyName, icon = C_ToyBox.GetToyInfo(toyId)

			-- Get the item description using the GameTooltip method
			local description = Hearths:GetItemDescription(toyId)
			if string.find(description, "Returns you to (.*).") then
				local boundLocation = string.match(description, "Returns you to ([^%.]+).")
				local hearthstoneToy = {
					id = toyId,
					name = toyName,
					icon = icon,
					type = "toy",
					location = boundLocation,
				}
				table.insert(hearthstoneToys, hearthstoneToy)
				Hearths:Debug("Added to candidates: " .. hearthstoneToy.name)
			end
		end
	end

	Hearths:Debug("Found " .. #hearthstoneToys .. " usable hearthstone toys")
	return hearthstoneToys
end

function Hearths:ConvertHearthstoneToys(hearthstoneToys)
	local hearthstoneSettings = {}

	for i, toy in pairs(hearthstoneToys) do
		hearthstoneSettings[tostring(toy.id)] = {
			type = "toggle",
			order = i + 1,
			name = toy.name,
			image = toy.icon,
		}
	end

	return hearthstoneSettings
end

function Hearths:IsOnCooldown(id, kind)
	local duration = 0
	if kind == "spell" then
		_, duration = C_Spell.GetSpellCooldown(id)
	else
		_, duration = C_Item.GetItemCooldown(id)
	end
	if not duration then
		return false
	end
	return duration > 0
end

function Hearths:RefreshSelectedHearthstone()
	if InCombatLockdown() then
		Hearths:Debug("tried refreshing in combat - trying again later")
		self.triedRefreshInCombat = true
		return
	end

	local candidates = self.db.profile.enabledHearthstones
	if self.db.profile.useAllHearthstoneToys then
		candidates = self.db.profile.availableHearthstones
	end

	local count = 0
	local stones = {}
	for toyId, enabled in pairs(candidates) do
		if enabled then
			local row = {}
			row.kind = "toy"
			row.id = toyId

			table.insert(stones, row)
			count = count + 1
		end
	end

	if self.db.profile.includeDefaultHearthstone and Hearths:IsDefaultHearthstoneAvailable() then
		local row = {}
		row.kind = "item"
		row.id = Hearthstone.Default
		table.insert(stones, row)
		count = count + 1
	end

	if self.db.profile.includeAstralRecall and Hearths:IsPlayerShaman() then
		local row = {}
		row.kind = "spell"
		row.id = Hearthstone.AstralRecall
		table.insert(stones, row)
		count = count + 1
	end

	if count == 0 then
		return
	end

	local index = math.random(1, count)
	local randomHearthstone = stones[index]

	Hearths:CreateOrUpdateMacro(randomHearthstone.id, randomHearthstone.kind)
end

function Hearths:CreateOrUpdateMacro(id, kind)
	local tooltip = ""

	-- if player is shaman, and the random selected hearthstone is a toy or item
	-- but on cooldown, check astral recall instead since it's a separate cooldown
	if Hearths:IsPlayerShaman() and self.db.profile.includeAstralRecall then
		if kind ~= "spell" and Hearths:IsOnCooldown(id, kind) and not Hearths:IsOnCooldown(Hearthstone.AstralRecall, "spell") then
			id = Hearthstone.AstralRecall
			kind = "spell"
		end
	end

	if kind == "spell" then
		self.hearthsButton:SetAttribute("type1", "spell")
		self.hearthsButton:ClearAttribute("*item1")
		self.hearthsButton:ClearAttribute("*toy1")
		self.hearthsButton:SetAttribute("*spell1", id)
		tooltip = "#showtooltip Astral Recall"
	elseif kind == "toy" then
		self.hearthsButton:SetAttribute("type1", "toy")
		self.hearthsButton:ClearAttribute("*item1")
		self.hearthsButton:ClearAttribute("*spell1")
		self.hearthsButton:SetAttribute("*toy1", id)
		tooltip = "#showtooltip item:" .. id
	elseif kind == "item" then
		self.hearthsButton:SetAttribute("type1", "item")
		self.hearthsButton:ClearAttribute("*toy1")
		self.hearthsButton:ClearAttribute("*spell1")
		self.hearthsButton:SetAttribute("*item1", "item:" .. id)
		tooltip = "#showtooltip item:" .. id
	end

	local macroText = tooltip .. "\n/click " .. self.hearthsButton:GetName() .. "\n"
	local hasMacro = GetMacroIndexByName("HEARTHS_BTN")
	if hasMacro > 0 then
		EditMacro("HEARTHS_BTN", "HEARTHS_BTN", "INV_MISC_QUESTIONMARK", macroText)
		Hearths:Debug("Updated Macro with " .. tostring(id) .. "(" .. kind .. ")")
	else
		CreateMacro("HEARTHS_BTN", "INV_MISC_QUESTIONMARK", macroText, true)
		Hearths:Debug("Created Macro")
	end
end

function Hearths:RefreshAvailableHearthstones()
	local availableHearthstones = Hearths:ConvertHearthstoneToys(Hearths:GetAvailableHearhstones())

	self.db.profile.availableHearthstones = availableHearthstones
	self.options.args.selectedHearthstones.args = availableHearthstones
end

function Hearths:SlashCommand(input)
	if input == "options" or input == "opts" or input == "" then
		Hearths:RefreshAvailableHearthstones()
		Settings.OpenToCategory(self.optionsFrame.name)
	elseif input == "refresh" then
		Hearths:RefreshAvailableHearthstones()
		Hearths:RefreshSelectedHearthstone()
	end
end

function Hearths:Debug(...)
	if not self.db or not self.db.profile.debugMode then
		return
	end

	-- WoW color codes (using |cFFRRGGBB format)
	local colors = {
		reset = "|r",
		string = "|cFF00FF00",       -- green
		number = "|cFFFFFF00",       -- yellow
		boolean = "|cFFFF00FF",      -- magenta
		['nil'] = "|cFF808080",      -- gray
		['function'] = "|cFF00FFFF", -- cyan
		table = "|cFF4080FF",        -- blue
		userdata = "|cFFFF0000",     -- red
		thread = "|cFFFF8080"        -- light red
	}

	-- Helper to serialize a value based on type
	local function serialize(val, indent, seen)
		indent = indent or 0
		seen = seen or {}
		local val_type = type(val)
		local color = colors[val_type] or colors.reset

		if val_type == "nil" then
			return color .. "nil" .. colors.reset
		elseif val_type == "boolean" then
			return color .. tostring(val) .. colors.reset
		elseif val_type == "number" then
			return color .. tostring(val) .. colors.reset
		elseif val_type == "string" then
			return color .. '"' .. val .. '"' .. colors.reset
		elseif val_type == "function" then
			return color .. "function" .. colors.reset
		elseif val_type == "table" then
			-- Prevent infinite recursion
			if seen[val] then
				return color .. "{circular}" .. colors.reset
			end
			seen[val] = true

			-- Count elements
			local count = 0
			for _ in pairs(val) do count = count + 1 end

			if count == 0 then
				return color .. "{}" .. colors.reset
			end

			-- For small tables, show inline
			if count <= 3 then
				local parts = {}
				for k, v in pairs(val) do
					local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
					table.insert(parts, key_str .. "=" .. serialize(v, indent, seen))
				end
				return color .. "{" .. table.concat(parts, ", ") .. "}" .. colors.reset
			end

			-- For larger tables, show condensed
			return color .. "{...}" .. colors.reset
		elseif val_type == "userdata" then
			return color .. "userdata" .. colors.reset
		else
			return colors.reset .. tostring(val) .. colors.reset
		end
	end

	-- Process all arguments
	local args = { ... }
	local output = {}

	for i, arg in ipairs(args) do
		table.insert(output, serialize(arg))
	end

	-- Use WoW's print function
	print("|cFFFF8040[Hearths]|r " .. table.concat(output, " "))
end
