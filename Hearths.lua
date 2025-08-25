-- Hearths Addon - Random Hearthstone Rotation
local addonName, addon = ...
local frame = nil
local cooldownFrame = nil
local currentHearthstone = nil
local hearthstoneToys = {}
local pendingRotation = false
local lastCooldownCheck = 0
local buttonVisible = true
local mouseoverVisible = false

-- Debug print function
local function DebugPrint(msg)
    if HearthsDB and HearthsDB.debug then
        print("|cFF888888[Hearths Debug]|r " .. msg)
    end
end

-- Initialize SavedVariables
local function InitializeSavedVars()
    local wasNew = HearthsDB == nil
    HearthsDB = HearthsDB or {}
    HearthsDB.position = HearthsDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    HearthsDB.debug = HearthsDB.debug or false
    if HearthsDB.useAllHearthstones == nil then
        HearthsDB.useAllHearthstones = true
    end
    HearthsDB.enabledHearthstones = HearthsDB.enabledHearthstones or {}
    HearthsDB.visibilityMode = HearthsDB.visibilityMode or "always"

    if wasNew then
        DebugPrint("SavedVariables initialized for first time - useAllHearthstones: " .. tostring(HearthsDB.useAllHearthstones))
    else
        DebugPrint("SavedVariables loaded - useAllHearthstones: " .. tostring(HearthsDB.useAllHearthstones) .. ", enabledHearthstones count: " .. tostring(#HearthsDB.enabledHearthstones))
    end
end


-- Function to update button visibility based on current mode
local function UpdateButtonVisibility()
    if not frame then
        return
    end

    local mode = HearthsDB.visibilityMode
    local shouldShow = false

    if mode == "always" then
        shouldShow = true
    elseif mode == "never" then
        shouldShow = false
    elseif mode == "mouseover" then
        shouldShow = mouseoverVisible
    else
        -- Default to always visible for unknown modes
        shouldShow = true
    end

    -- Only show if we have a current hearthstone
    if shouldShow and not currentHearthstone then
        shouldShow = false
    end

    -- Always keep frame shown for mouse events
    frame:Show()
    frame:SetAlpha(0)

    -- Handle always visible mode
    if mode == "always" then
        frame:Show()
        frame:SetAlpha(1)
        return
    end

    if mode == "mouseover" then
        frame:Show()
        -- TODO: fade in and out
        frame:SetAlpha(mouseoverVisible and 1 or 0)
    end

    if mode == "never" then
        frame:Hide()
        return
    end
end


-- Function to check if a hearthstone is enabled for rotation
local function IsHearthstoneEnabled(hearthstone)
    if HearthsDB.useAllHearthstones then
        return true
    end
    return HearthsDB.enabledHearthstones[hearthstone.id] == true
end

-- Function to get cooldown information for different types
local function GetCooldownInfo(hearthstone)
    local startTime, duration = 0, 0

    if hearthstone.type == "toy" then
        startTime, duration = C_Item.GetItemCooldown(hearthstone.id)
    elseif hearthstone.type == "item" then
        startTime, duration = C_Item.GetItemCooldown(hearthstone.id)
    elseif hearthstone.type == "spell" then
        local cooldownInfo = C_Spell.GetSpellCooldown(hearthstone.id)
        if cooldownInfo then
            startTime, duration = cooldownInfo.startTime, cooldownInfo.duration
        end
    end

    return startTime, duration
end

-- Function to check if hearthstone is on cooldown
local function IsOnCooldown(hearthstone)
    local startTime, duration = GetCooldownInfo(hearthstone)
    if duration <= 0 then
        return false -- No cooldown active
    end
    local remaining = (startTime + duration) - GetTime()
    return remaining > 0.1 -- Add small buffer to avoid precision issues
end

-- Function to get remaining cooldown time
local function GetRemainingCooldown(hearthstone)
    local startTime, duration = GetCooldownInfo(hearthstone)
    if duration > 0 then
        local remaining = (startTime + duration) - GetTime()
        return math.max(0, remaining)
    end
    return 0
end

-- Function to validate that initialization was successful
local function ValidateInitialization()
    -- Check if any hearthstones were found
    if #hearthstoneToys == 0 then
        DebugPrint("Validation failed: No hearthstones found")
        return false
    end

    -- Check if at least one hearthstone is enabled
    local hasEnabledHearthstone = false
    for _, hearthstone in ipairs(hearthstoneToys) do
        if IsHearthstoneEnabled(hearthstone) then
            hasEnabledHearthstone = true
            break
        end
    end

    if not hasEnabledHearthstone then
        DebugPrint("Validation failed: No enabled hearthstones found")
        return false
    end

    DebugPrint("Validation passed: " .. #hearthstoneToys .. " hearthstones found, at least one enabled")
    return true
end

-- Function to update button attributes for a specific hearthstone
local function UpdateButtonForHearthstone(hearthstone)
    -- Set up modifier keys for Dalaran and Garrison hearthstones
    if PlayerHasToy(140192) then -- Dalaran Hearthstone
        frame:SetAttribute("shift-type1", "toy")
        frame:SetAttribute("shift-toy1", 140192)
    end
    if PlayerHasToy(110560) then -- Garrison Hearthstone
        frame:SetAttribute("ctrl-type1", "toy")
        frame:SetAttribute("ctrl-toy1", 110560)
    end

    -- Set up the button based on hearthstone type
    if hearthstone.type == "toy" then
        local _, toyName, toyTexture = C_ToyBox.GetToyInfo(hearthstone.id)
        frame:SetNormalTexture(toyTexture or hearthstone.icon)
        frame:SetAttribute("type1", "toy")
        frame:SetAttribute("*toy1", hearthstone.id)
    elseif hearthstone.type == "item" then
        frame:SetNormalTexture(hearthstone.icon)
        frame:SetAttribute("type1", "item")
        frame:SetAttribute("*item1", "item:" .. hearthstone.id)
    elseif hearthstone.type == "spell" then
        frame:SetNormalTexture(hearthstone.icon)
        frame:SetAttribute("type1", "spell")
        frame:SetAttribute("*spell1", hearthstone.id)
    end
end

-- Create a working hearthstone button using the pattern that works
local function CreateHearthstoneButton()
    -- Note: ScanHearthstoneToys() should be called before this function
    if #hearthstoneToys == 0 then
        DebugPrint("No hearthstone toys found!")
        return
    end

    -- Pick an available hearthstone for the button (same logic as rotation)
    local availableHearthstones = {}
    DebugPrint("Initial cooldown check for all hearthstones:")
    for _, hearthstone in ipairs(hearthstoneToys) do
        local onCooldown = IsOnCooldown(hearthstone)
        local enabled = IsHearthstoneEnabled(hearthstone)
        local remaining = GetRemainingCooldown(hearthstone)
        DebugPrint("  " .. hearthstone.name .. ": " .. (onCooldown and ("on cooldown (" .. math.floor(remaining) .. "s)") or "available") .. (enabled and "" or " (disabled)"))
        if not onCooldown and enabled then
            table.insert(availableHearthstones, hearthstone)
        end
    end

    -- If no hearthstones are available, find the enabled one with shortest cooldown
    if #availableHearthstones == 0 then
        DebugPrint("All enabled hearthstones on cooldown at startup, finding shortest cooldown")
        local shortestCooldown = nil
        local shortestTime = math.huge

        for _, hearthstone in ipairs(hearthstoneToys) do
            if IsHearthstoneEnabled(hearthstone) then
                local remaining = GetRemainingCooldown(hearthstone)
                if remaining < shortestTime then
                    shortestTime = remaining
                    shortestCooldown = hearthstone
                end
            end
        end

        if shortestCooldown then
            currentHearthstone = shortestCooldown
            DebugPrint("Selected hearthstone with shortest cooldown at startup: " .. currentHearthstone.name .. " (" .. math.floor(shortestTime) .. "s remaining)")
        end
    else
        -- Pick a random hearthstone from available ones
        local randomIndex = math.random(1, #availableHearthstones)
        currentHearthstone = availableHearthstones[randomIndex]
        DebugPrint("Selected available hearthstone at startup: " .. currentHearthstone.name)
    end

    frame = CreateFrame("Button", "Hearths", UIParent, "SecureActionButtonTemplate")
    frame:SetSize(41, 41)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Create cooldown overlay
    cooldownFrame = CreateFrame("Cooldown", "HearthsCooldown", frame, "CooldownFrameTemplate")
    cooldownFrame:SetAllPoints(frame)
    cooldownFrame:SetDrawBling(false)


    -- Set up the button for the current hearthstone
    if currentHearthstone then
        UpdateButtonForHearthstone(currentHearthstone)
        DebugPrint("Button configured for: " .. currentHearthstone.name)
    else
        DebugPrint("ERROR: No hearthstone selected, cannot configure button")
        return
    end

    -- Custom tooltip with modifier information
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if currentHearthstone then
            GameTooltip:AddLine(currentHearthstone.name, 1, 1, 1, 1)
        else
            GameTooltip:AddLine("Hearths (No hearthstone selected)", 1, 0.5, 0.5, 1)
        end
        GameTooltip:AddLine(" ")
        if PlayerHasToy(140192) then
            GameTooltip:AddLine("Shift-click: Dalaran Hearthstone", 0.7, 0.7, 1, 1)
        end
        if PlayerHasToy(110560) then
            GameTooltip:AddLine("Ctrl-click: Garrison Hearthstone", 0.7, 0.7, 1, 1)
        end
        GameTooltip:AddLine("Alt-drag: Move button", 0.7, 0.7, 0.7, 1)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame:RegisterForClicks("AnyDown")

    -- Handle dragging to move the button
    frame:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        HearthsDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)

    -- Check for modifier keys before click to prevent rotation
    frame:SetScript("PreClick", function(self, button)
        if button == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
            -- This is a normal click, prepare for rotation
            pendingRotation = true
            DebugPrint("Clicked: " .. currentHearthstone.name .. " (pending rotation)")
        elseif button == "LeftButton" and IsShiftKeyDown() then
            -- Shift-click for Dalaran
            pendingRotation = false
            DebugPrint("Shift-clicked: Dalaran Hearthstone (no rotation)")
        elseif button == "LeftButton" and IsControlKeyDown() then
            -- Ctrl-click for Garrison
            pendingRotation = false
            DebugPrint("Ctrl-clicked: Garrison Hearthstone (no rotation)")
        else
            -- Other modifier click
            pendingRotation = false
            DebugPrint("Modifier click detected, no rotation")
        end
    end)

    -- Update cooldown display (throttled to 1 second intervals)
    frame:SetScript("OnUpdate", function(self, elapsed)
        lastCooldownCheck = lastCooldownCheck + elapsed

        if lastCooldownCheck >= 1.0 and currentHearthstone then
            lastCooldownCheck = 0
            local startTime, duration = GetCooldownInfo(currentHearthstone)
            if duration > 0 then
                cooldownFrame:SetCooldown(startTime, duration)
            else
                cooldownFrame:Clear()
            end
        end
    end)

    -- Restore saved position
    if HearthsDB.position then
        frame:ClearAllPoints()
        frame:SetPoint(HearthsDB.position.point, UIParent, HearthsDB.position.relativePoint, HearthsDB.position.x, HearthsDB.position.y)
    end

    DebugPrint("Created button for: " .. currentHearthstone.name .. " (ID: " .. currentHearthstone.id .. ")")

    -- Apply visibility settings
    UpdateButtonVisibility()

    -- Mouseover detection using direct button events
    local mouseoverTimer = nil

    -- Store original handlers
    local originalOnEnter = frame:GetScript("OnEnter")
    local originalOnLeave = frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function(self)
        if HearthsDB.visibilityMode == "mouseover" then
            -- Cancel any pending hide timer
            if mouseoverTimer then
                mouseoverTimer:Cancel()
                mouseoverTimer = nil
            end

            DebugPrint("Mouse entered button area")
            mouseoverVisible = true
            UpdateButtonVisibility()
        end

        -- Call original OnEnter for tooltip
        if originalOnEnter then
            originalOnEnter(self)
        end
    end)

    frame:SetScript("OnLeave", function(self)
        if HearthsDB.visibilityMode == "mouseover" then
            -- Add delay before hiding to prevent flickering
            if mouseoverTimer then
                mouseoverTimer:Cancel()
            end
            mouseoverTimer = C_Timer.NewTimer(0.3, function()
                if HearthsDB.visibilityMode == "mouseover" then
                    DebugPrint("Mouse left button area (delayed)")
                    mouseoverVisible = false
                    UpdateButtonVisibility()
                end
                mouseoverTimer = nil
            end)
        end

        -- Call original OnLeave for tooltip
        if originalOnLeave then
            originalOnLeave(self)
        end
    end)

end


-- Create a hidden tooltip for scanning item descriptions
local scanningTooltip = CreateFrame("GameTooltip", "HearthsScanningTooltip", UIParent, "GameTooltipTemplate")
scanningTooltip:SetOwner(UIParent, "ANCHOR_NONE") -- Ensures it's hidden

-- Function to get item description using GameTooltip
local function GetItemDescription(itemID)
    scanningTooltip:ClearLines()
    scanningTooltip:SetHyperlink("item:" .. itemID)

    local descriptionText = ""
    local numLines = scanningTooltip:NumLines()

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

    scanningTooltip:ClearLines()
    return descriptionText
end

-- Scan for hearthstone toys the player owns
function ScanHearthstoneToys()
    DebugPrint("Starting hearthstone scan...")
    hearthstoneToys = {}

    -- Add the default hearthstone
    local defaultHearthstone = {
        id = 6948,
        name = "Hearthstone",
        icon = "Interface\\Icons\\INV_Misc_Rune_01",
        type = "item"
    }
    table.insert(hearthstoneToys, defaultHearthstone)
    DebugPrint("Added to rotation: " .. defaultHearthstone.name)

    -- Add Astral Recall if player is a Shaman
    local _, playerClass = UnitClass("player")
    if playerClass == "SHAMAN" then
        local astralRecall = {
            id = 556, -- Astral Recall spell ID
            name = "Astral Recall",
            icon = "Interface\\Icons\\Spell_Nature_AstralRecal",
            type = "spell"
        }
        table.insert(hearthstoneToys, astralRecall)
        DebugPrint("Added to rotation: " .. astralRecall.name)
    end

    -- Scan toy box for hearthstone toys
    local numToys = C_ToyBox.GetNumFilteredToys()
    DebugPrint("Scanning " .. numToys .. " toys in toy box...")
    for i = 1, numToys do
        local toyID = C_ToyBox.GetToyFromIndex(i)
        if toyID and toyID > 0 and C_ToyBox.IsToyUsable(toyID) then
            local itemID, toyName, icon = C_ToyBox.GetToyInfo(toyID)

            if toyName and type(toyName) == "string" then
                -- Get the item description using the GameTooltip method
                local description = GetItemDescription(toyID)

                -- Check for multiple hearthstone description patterns
                local isHearthstone = false
                if string.find(description, "Speak to an Innkeeper in a different place to change your home location") then
                    isHearthstone = true
                elseif string.find(description, "Return to your home location") then
                    isHearthstone = true
                elseif string.find(description, "Return to your hearth") then
                    isHearthstone = true
                elseif string.find(description, "Return to your inn") then
                    isHearthstone = true
                elseif string.find(description, "Return to your home") then
                    isHearthstone = true
                elseif string.find(description, "Use: Return to your home") then
                    isHearthstone = true
                elseif string.find(description, "Use: Return to your hearth") then
                    isHearthstone = true
                end

                if isHearthstone then
                    local hearthstoneToy = {
                        id = toyID,
                        name = toyName,
                        icon = icon,
                        type = "toy"
                    }
                    table.insert(hearthstoneToys, hearthstoneToy)
                    DebugPrint("Added to rotation: " .. hearthstoneToy.name)
                end
            end
        end
    end

    DebugPrint("Found " .. #hearthstoneToys .. " usable hearthstones")
end

-- Create options panel with custom frame and proper icons
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "HearthsOptionsPanel", UIParent)
    panel.name = "Hearths"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Hearths Options")

    -- Debug Mode checkbox
    local debugCheckbox = CreateFrame("CheckButton", "HearthsDebugCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    debugCheckbox.Text:SetText("Enable Debug Logging")
    debugCheckbox:SetScript("OnClick", function(self)
        HearthsDB.debug = self:GetChecked()
        local status = self:GetChecked() and "enabled" or "disabled"
        print("|cFF00FF00[Hearths]|r Debug logging " .. status)
    end)

    -- Visibility Mode Section
    local visibilityHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibilityHeader:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -20)
    visibilityHeader:SetText("Button Visibility:")

    -- Visibility Mode Dropdown
    local visibilityDropdown = CreateFrame("Frame", "HearthsVisibilityDropdown", panel, "UIDropDownMenuTemplate")
    visibilityDropdown:SetPoint("TOPLEFT", visibilityHeader, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(visibilityDropdown, 150)
    UIDropDownMenu_SetText(visibilityDropdown, "Always Visible")

    local function VisibilityDropdown_OnClick(self)
        HearthsDB.visibilityMode = self.value
        UIDropDownMenu_SetText(visibilityDropdown, self:GetText())
        DebugPrint("Visibility mode changed to: " .. self.value)
        UpdateButtonVisibility()
        CloseDropDownMenus()
    end

    local function VisibilityDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "Always Visible"
        info.value = "always"
        info.func = VisibilityDropdown_OnClick
        info.checked = HearthsDB.visibilityMode == "always"
        UIDropDownMenu_AddButton(info)

        info.text = "Never Visible"
        info.value = "never"
        info.func = VisibilityDropdown_OnClick
        info.checked = HearthsDB.visibilityMode == "never"
        UIDropDownMenu_AddButton(info)


        info.text = "Show on Mouseover"
        info.value = "mouseover"
        info.func = VisibilityDropdown_OnClick
        info.checked = HearthsDB.visibilityMode == "mouseover"
        UIDropDownMenu_AddButton(info)
    end

    UIDropDownMenu_Initialize(visibilityDropdown, VisibilityDropdown_Initialize)

    -- Keybinding Information Section
    local keybindHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keybindHeader:SetPoint("TOPLEFT", visibilityDropdown, "BOTTOMLEFT", 15, -20)
    keybindHeader:SetText("Keybindings:")

    -- Create keybind text frame (will be updated dynamically)
    local keybindCurrent = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    keybindCurrent:SetPoint("TOPLEFT", keybindHeader, "BOTTOMLEFT", 0, -3)
    keybindCurrent:SetText("• Current binding: Loading...")
    keybindCurrent:SetTextColor(0.8, 0.8, 0.8)

    -- Store reference for dynamic updates
    panel.keybindCurrent = keybindCurrent

    -- Update keybinding text whenever the panel is shown
    panel:SetScript("OnShow", function()
        if panel.keybindCurrent then
            local currentKeybind = GetBindingKey("CLICK Hearths:LeftButton")
            if currentKeybind then
                panel.keybindCurrent:SetText("• Current binding: Random " .. currentKeybind .. ", Dalaran: Shift+" .. currentKeybind .. ", Garrison: Ctrl+" .. currentKeybind)
                panel.keybindCurrent:SetTextColor(0.5, 1, 0.5)
            else
                panel.keybindCurrent:SetText("• Current binding: None - Configure in Interface > Key Bindings > Hearths")
                panel.keybindCurrent:SetTextColor(0.8, 0.8, 0.8)
            end
        end
    end)

       -- Use All Hearthstones checkbox
    local useAllCheckbox = CreateFrame("CheckButton", "HearthsUseAllCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    useAllCheckbox:SetPoint("TOPLEFT", keybindCurrent, "BOTTOMLEFT", 0, -10)
    useAllCheckbox.Text:SetText("Use All Hearthstones")
    useAllCheckbox:SetScript("OnClick", function(self)
        HearthsDB.useAllHearthstones = self:GetChecked()
        if HearthsDB.useAllHearthstones then
            DebugPrint("Enabled all hearthstones for rotation")
            -- Enable and check all individual checkboxes
            for _, checkbox in pairs(panel.hearthstoneCheckboxes or {}) do
                checkbox:SetChecked(true)
                checkbox:SetEnabled(false)
            end
        else
            DebugPrint("Switched to custom hearthstone selection")
            -- Enable individual checkboxes and set them based on saved state
            for _, checkbox in pairs(panel.hearthstoneCheckboxes or {}) do
                checkbox:SetEnabled(true)
                checkbox:SetChecked(HearthsDB.enabledHearthstones[checkbox.hearthstoneId] == true)
            end
        end

        -- If current hearthstone is no longer enabled, find a new one
        if currentHearthstone and not IsHearthstoneEnabled(currentHearthstone) then
            SetupRandomHearthstone()
        end
    end)

    -- Header for individual selections
    local customHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customHeader:SetPoint("TOPLEFT", useAllCheckbox, "BOTTOMLEFT", 0, -15)
    customHeader:SetText("Individual Hearthstone Selection:")

    -- Container for individual hearthstone checkboxes
    panel.hearthstoneCheckboxes = {}

    -- Create scrollable frame for hearthstone list
    local scrollFrame = CreateFrame("ScrollFrame", "HearthsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", customHeader, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 20)
    scrollFrame:SetSize(400, 200)

    local scrollChild = CreateFrame("Frame", "HearthsScrollChild", scrollFrame)
    scrollChild:SetSize(380, 1) -- Height will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)

    local function RefreshHearthstoneList()
        -- Always scan for hearthstones to ensure the list is up to date
        ScanHearthstoneToys()
        DebugPrint("RefreshHearthstoneList: Found " .. #hearthstoneToys .. " hearthstones after scan")

        -- Debug: list all hearthstones found
        for i, hearthstone in ipairs(hearthstoneToys) do
            DebugPrint("  " .. i .. ": " .. hearthstone.name .. " (ID: " .. hearthstone.id .. ")")
        end

        -- Safeguard: If no hearthstones found, ensure at least the default one exists
        if #hearthstoneToys == 0 then
            DebugPrint("No hearthstones found in scan, adding default hearthstone")
            local defaultHearthstone = {
                id = 6948,
                name = "Hearthstone",
                icon = "Interface\\Icons\\INV_Misc_Rune_01",
                type = "item"
            }
            table.insert(hearthstoneToys, defaultHearthstone)
        end

        -- Clear existing checkboxes
        for _, checkbox in pairs(panel.hearthstoneCheckboxes) do
            checkbox:Hide()
            checkbox:SetParent(nil)
        end
        panel.hearthstoneCheckboxes = {}

        -- If switching to custom mode for the first time, initialize all as enabled
        if not HearthsDB.useAllHearthstones and not next(HearthsDB.enabledHearthstones) then
            for _, hearthstone in ipairs(hearthstoneToys) do
                HearthsDB.enabledHearthstones[hearthstone.id] = true
            end
        end

        -- Create checkboxes for each hearthstone in scroll child
        local yOffset = -10
        for i, hearthstone in ipairs(hearthstoneToys) do
            -- Create a container frame for the checkbox + icon
            local container = CreateFrame("Frame", "HearthsContainer" .. i, scrollChild)
            container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
            container:SetSize(350, 25)

            -- Create icon
            local icon = container:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", container, "LEFT", 0, 0)
            icon:SetTexture(hearthstone.icon)

            -- Create checkbox
            local checkbox = CreateFrame("CheckButton", "HearthsCheckbox" .. i, container, "InterfaceOptionsCheckButtonTemplate")
            checkbox:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            checkbox.Text:SetText(hearthstone.name)
            checkbox.hearthstoneId = hearthstone.id

            checkbox:SetScript("OnClick", function(self)
                if not HearthsDB.useAllHearthstones then
                    HearthsDB.enabledHearthstones[hearthstone.id] = self:GetChecked()
                    local status = self:GetChecked() and "enabled" or "disabled"
                    DebugPrint(hearthstone.name .. " " .. status)

                    -- Check if all are now enabled
                    local allEnabled = true
                    for _, h in ipairs(hearthstoneToys) do
                        if not HearthsDB.enabledHearthstones[h.id] then
                            allEnabled = false
                            break
                        end
                    end
                    if allEnabled then
                        HearthsDB.useAllHearthstones = true
                        useAllCheckbox:SetChecked(true)
                        for _, cb in pairs(panel.hearthstoneCheckboxes) do
                            cb:SetChecked(true)
                            cb:SetEnabled(false)
                        end
                        DebugPrint("All hearthstones enabled, switched back to 'Use All' mode")
                    end

                    -- Handle hearthstone enable/disable changes
                    if self:GetChecked() then
                        -- Hearthstone was enabled - if no current hearthstone or button is hidden, set up a new one
                        if not currentHearthstone or (frame and not frame:IsShown()) then
                            SetupRandomHearthstone()
                        end
                    else
                        -- Hearthstone was disabled - if it was the current one, find a new one
                        if currentHearthstone and hearthstone.id == currentHearthstone.id then
                            SetupRandomHearthstone()
                        end
                    end
                end
            end)

            panel.hearthstoneCheckboxes[i] = checkbox
            yOffset = yOffset - 30
        end

        -- Set scroll child height based on content
        scrollChild:SetHeight(math.max(200, #hearthstoneToys * 30 + 20))

        -- Set initial states
        debugCheckbox:SetChecked(HearthsDB.debug)
        useAllCheckbox:SetChecked(HearthsDB.useAllHearthstones)

        -- Set visibility dropdown text
        local visibilityTexts = {
            always = "Always Visible",
            never = "Never Visible",
            mouseover = "Show on Mouseover"
        }
        UIDropDownMenu_SetText(visibilityDropdown, visibilityTexts[HearthsDB.visibilityMode] or "Always Visible")

        for _, checkbox in pairs(panel.hearthstoneCheckboxes) do
            if HearthsDB.useAllHearthstones then
                checkbox:SetChecked(true)
                checkbox:SetEnabled(false)
            else
                checkbox:SetChecked(HearthsDB.enabledHearthstones[checkbox.hearthstoneId] == true)
                checkbox:SetEnabled(true)
            end
        end
    end

    panel.RefreshHearthstoneList = RefreshHearthstoneList

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    panel.category = category

    return panel
end

-- Retry mechanism for initialization
local initializationRetries = 0
local maxRetries = 3

local function AttemptInitialization()
    initializationRetries = initializationRetries + 1
    DebugPrint("Initialization attempt " .. initializationRetries .. "/" .. maxRetries)

    -- Scan for hearthstones first
    ScanHearthstoneToys()

    -- Validate that we have usable hearthstones
    if ValidateInitialization() then
        DebugPrint("Initialization successful, creating button")
        CreateHearthstoneButton()
        if not optionsPanel then
            optionsPanel = CreateOptionsPanel()
            -- Refresh the hearthstone list after scanning
            if optionsPanel.RefreshHearthstoneList then
                optionsPanel.RefreshHearthstoneList()
            end
        end
    else
        if initializationRetries < maxRetries then
            DebugPrint("Initialization failed, retrying in 3 seconds...")
            C_Timer.After(3, AttemptInitialization)
        else
            DebugPrint("Initialization failed after " .. maxRetries .. " attempts. Toy box or SavedVariables may not be ready.")
        end
    end
end

-- Function to set up a new random hearthstone for the existing button
function SetupRandomHearthstone()
    if not frame or #hearthstoneToys == 0 then
        return
    end

    local availableHearthstones = {}
    local shortestCooldownHearthstones = {}
    local shortestTime = math.huge

    DebugPrint("Checking cooldowns for all hearthstones:")
    for _, hearthstone in ipairs(hearthstoneToys) do
        local onCooldown = IsOnCooldown(hearthstone)
        local enabled = IsHearthstoneEnabled(hearthstone)
        local remaining = GetRemainingCooldown(hearthstone)
        DebugPrint("  " .. hearthstone.name .. ": " .. (onCooldown and ("on cooldown (" .. math.floor(remaining) .. "s)") or "available") .. (enabled and "" or " (disabled)"))

        if enabled then
            -- 1. Check if any are off cooldown
            if not onCooldown then
                table.insert(availableHearthstones, hearthstone)
            else
                -- 2. Track shortest cooldown times
                if remaining < shortestTime then
                    shortestTime = remaining
                    shortestCooldownHearthstones = {hearthstone}
                elseif remaining == shortestTime then
                    table.insert(shortestCooldownHearthstones, hearthstone)
                end
            end
        end
    end

    -- 1. If any are off cooldown, pick one randomly
    if #availableHearthstones > 0 then
        local randomIndex = math.random(1, #availableHearthstones)
        currentHearthstone = availableHearthstones[randomIndex]
        DebugPrint("Selected available hearthstone: " .. currentHearthstone.name)
    -- 2. If not, pick randomly from those with shortest cooldown
    elseif #shortestCooldownHearthstones > 0 then
        local randomIndex = math.random(1, #shortestCooldownHearthstones)
        currentHearthstone = shortestCooldownHearthstones[randomIndex]
        DebugPrint("Selected hearthstone with shortest cooldown: " .. currentHearthstone.name .. " (" .. math.floor(shortestTime) .. "s remaining)")
    else
        -- No enabled hearthstones found at all
        currentHearthstone = nil
        DebugPrint("No enabled hearthstones found, hiding button")
    end

    -- Update the button for the new hearthstone or hide it if none selected
    if currentHearthstone then
        UpdateButtonForHearthstone(currentHearthstone)
        UpdateButtonVisibility()
    else
        -- Hide the button when no hearthstones are enabled
        frame:Hide()
        DebugPrint("Button hidden - no enabled hearthstones")
    end

    if currentHearthstone then
        DebugPrint("Switched to: " .. currentHearthstone.name .. " (ID: " .. currentHearthstone.id .. ")")
    end
end

-- Initialize the addon
local eventFrame = CreateFrame("Frame")
local optionsPanel = nil
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leaving combat
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        DebugPrint("Addon loaded, initializing SavedVariables")
        InitializeSavedVars()
        C_Timer.After(1, AttemptInitialization)
    elseif (event == "LOADING_SCREEN_DISABLED" or event == "UNIT_SPELLCAST_STOP") and pendingRotation then
        -- Loading screen ended, delay rotation to ensure cooldowns are updated
        -- But only if not in combat
        C_Timer.After(2.0, function()
            if pendingRotation and not UnitAffectingCombat("player") then
                SetupRandomHearthstone()
                pendingRotation = false
                DebugPrint("Loading screen ended, rotated hearthstone")
            elseif pendingRotation and UnitAffectingCombat("player") then
                DebugPrint("Skipping rotation - player in combat")
                -- Keep pendingRotation true so it will rotate when combat ends
            end
        end)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" and arg1 == "player" and pendingRotation then
        -- Hearthstone cast was interrupted
        pendingRotation = false
        DebugPrint("Hearthstone interrupted, not rotating")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat - handle pending rotation when combat ends
        if pendingRotation then
            SetupRandomHearthstone()
            pendingRotation = false
            DebugPrint("Combat ended, rotated hearthstone")
        end
    end
end)

-- Slash command to open settings
SLASH_HEARTHS1 = "/hearths"
SlashCmdList["HEARTHS"] = function(msg)
    if not optionsPanel then
        optionsPanel = CreateOptionsPanel()
    end
    -- Always refresh the hearthstone list when opening options
    if optionsPanel.RefreshHearthstoneList then
        optionsPanel.RefreshHearthstoneList()
    end
    Settings.OpenToCategory(optionsPanel.category:GetID())
end
