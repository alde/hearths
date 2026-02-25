Hearths.UI = {}
local UI = Hearths.UI

function UI:Initialize()
	self.hearthsButton = nil
	self.macroName = "HEARTHS_BTN"
	self.pendingMacroUpdate = nil
	self.triedRefreshInCombat = false
end

function UI:OnPlayerEnteringWorld()
	self.hearthsButton = self:CreateHearthstoneButton()
end

function UI:OnCombatEnd()
	-- Process any macro updates once out of combat
	if self.triedRefreshInCombat then
		self.triedRefreshInCombat = false
		Hearths.App:RefreshSelectedHearthstone()
	end

	if self.pendingMacroUpdate then
		self:UpdateMacro(self.pendingMacroUpdate)
		self.pendingMacroUpdate = nil
	end
end

function UI:OnDataUpdated(event, hearthstonesOptions)
	Hearths.Debug:Log("UI", "Data", "Hearthstone data updated")
end

function UI:OnSelectionChanged(event, selectedHearthstone)
	-- Update macro
	if selectedHearthstone then
		self:UpdateMacro(selectedHearthstone)
		Hearths.Debug:Log("UI", "Macro", "Updating macro:", selectedHearthstone.id, selectedHearthstone.kind)
	end
end

function UI:OnSelectionFailed(event, errorMessage)
	self:ShowErrorMessage(errorMessage or "No hearthstones available")
end

function UI:CreateHearthstoneButton()
	if self.hearthsButton then
		return self.hearthsButton
	end

	local frame = CreateFrame("Button", self.macroName, nil, "SecureActionButtonTemplate")
	frame:SetSize(1, 1)
	frame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
	frame:RegisterForClicks("AnyUp", "AnyDown")
	frame:SetAttribute("useOnKeyDown", false)

	self:ConfigureModifierKeys(frame)

	self:ConfigureKeybinding(frame)

	return frame
end

function UI:ConfigureModifierKeys(frame)
	local hearthstoneIDs = Hearths.App:GetHearthstoneIDs()

	-- Shift + click for Dalaran Hearthstone (if available)
	if PlayerHasToy(hearthstoneIDs.DALARAN) then
		frame:SetAttribute("shift-type1", "toy")
		frame:SetAttribute("shift-toy1", hearthstoneIDs.DALARAN)
	end

	-- Ctrl + click for Garrison Hearthstone (if available)
	if PlayerHasToy(hearthstoneIDs.GARRISON) then
		frame:SetAttribute("ctrl-type1", "toy")
		frame:SetAttribute("ctrl-toy1", hearthstoneIDs.GARRISON)
	end
end

function UI:ConfigureKeybinding(frame)
	if Hearths.db.profile.hearthsKeybinding then
		SetBindingClick(Hearths.db.profile.hearthsKeybinding, frame:GetName())
	end
end

function UI:UpdateKeybinding(oldBinding, newBinding)
	if not self.hearthsButton then return end

	-- Clear old binding
	if oldBinding and oldBinding ~= "" then
		SetBinding(oldBinding)
	end

	-- Set new binding
	if newBinding and newBinding ~= "" then
		---@diagnostic disable-next-line: missing-parameter
		SetBindingClick(newBinding, self.hearthsButton:GetName())
	end
end

-- Main macro update
function UI:UpdateMacro(hearthstone)
	if InCombatLockdown() then
		Hearths.Debug:Log("UI", "Combat", "Combat lockdown active, deferring macro update")
		self.pendingMacroUpdate = hearthstone
		self.triedRefreshInCombat = true
		return
	end

	if not self.hearthsButton then
		Hearths.Debug:Log("UI", "Macro", "No hearthstone button available for macro update")
		return
	end

	self:ClearButtonAttributes()
	self:SetButtonAttributes(hearthstone)
	self:CreateOrUpdateMacroText(hearthstone)
end

-- Clear all action button attributes
function UI:ClearButtonAttributes()
	self.hearthsButton:ClearAttribute("*item1")
	self.hearthsButton:ClearAttribute("*toy1")
	self.hearthsButton:ClearAttribute("*spell1")
end

-- Set button attributes based on selected hearthstone type
function UI:SetButtonAttributes(hearthstone)
	local button = self.hearthsButton
	local itemType = hearthstone.kind
	local id = hearthstone.id

	if itemType == "spell" then
		button:SetAttribute("type1", "spell")
		button:SetAttribute("*spell1", id)
	elseif itemType == "toy" then
		button:SetAttribute("type1", "toy")
		button:SetAttribute("*toy1", id)
	elseif itemType == "item" then
		button:SetAttribute("type1", "item")
		button:SetAttribute("*item1", "item:" .. id)
	else
		Hearths.Debug:Log("UI", "Attributes", "Unknown hearthstone type:", itemType)
	end
end

function UI:CreateOrUpdateMacroText(hearthstone)
	local tooltip = self:GetTooltipForHearthstone(hearthstone)
	local macroText = tooltip .. "\n/click " .. self.hearthsButton:GetName() .. "\n"

	local hasMacro = GetMacroIndexByName(self.macroName)
	if hasMacro > 0 then
		-- Update existing macro
		EditMacro(self.macroName, self.macroName, "INV_MISC_QUESTIONMARK", macroText)
		Hearths.Debug:Log("UI", "Macro", "Updated macro with " .. tostring(hearthstone.id) .. " (" .. hearthstone.kind .. ")")
	else
		-- Create new macro
		CreateMacro(self.macroName, "INV_MISC_QUESTIONMARK", macroText, true)
		Hearths.Debug:Log("UI", "Macro", "Created new macro")
	end
end

function UI:GetTooltipForHearthstone(hearthstone)
	if hearthstone.kind == "spell" then
		return "#showtooltip Astral Recall"
	else
		return "#showtooltip item:" .. hearthstone.id
	end
end

function UI:ShowErrorMessage(message)
	Hearths.Debug:Log("UI", "Error", message)
end
