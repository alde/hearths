-- Hearths Addon - Random Hearthstone Rotation
local addonName, addon = ...
local frame = nil
local cooldownFrame = nil
local currentHearthstone = nil
local hearthstoneToys = {}
local pendingRotation = false
local lastCooldownCheck = 0

-- Initialize SavedVariables
local function InitializeSavedVars()
    HearthsDB = HearthsDB or {}
    HearthsDB.position = HearthsDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    HearthsDB.debug = HearthsDB.debug or false
end

-- Debug print function
local function DebugPrint(msg)
    if HearthsDB and HearthsDB.debug then
        print("|cFF888888[Hearths Debug]|r " .. msg)
    end
end

-- Function to get cooldown information for different types
local function GetCooldownInfo(hearthstone)
    local startTime, duration = 0, 0

    if hearthstone.type == "toy" then
        startTime, duration = GetItemCooldown(hearthstone.id)
    elseif hearthstone.type == "item" then
        startTime, duration = GetItemCooldown(hearthstone.id)
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
    -- Scan for hearthstones first
    ScanHearthstoneToys()

    if #hearthstoneToys == 0 then
        DebugPrint("No hearthstone toys found!")
        return
    end

    -- Pick an available hearthstone for the button (same logic as rotation)
    local availableHearthstones = {}
    DebugPrint("Initial cooldown check for all hearthstones:")
    for _, hearthstone in ipairs(hearthstoneToys) do
        local onCooldown = IsOnCooldown(hearthstone)
        local remaining = GetRemainingCooldown(hearthstone)
        DebugPrint("  " .. hearthstone.name .. ": " .. (onCooldown and ("on cooldown (" .. math.floor(remaining) .. "s)") or "available"))
        if not onCooldown then
            table.insert(availableHearthstones, hearthstone)
        end
    end

    -- If no hearthstones are available, find the one with shortest cooldown
    if #availableHearthstones == 0 then
        DebugPrint("All hearthstones on cooldown at startup, finding shortest cooldown")
        local shortestCooldown = nil
        local shortestTime = math.huge

        for _, hearthstone in ipairs(hearthstoneToys) do
            local remaining = GetRemainingCooldown(hearthstone)
            if remaining < shortestTime then
                shortestTime = remaining
                shortestCooldown = hearthstone
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

    frame = CreateFrame("Button", "HearthsButton", UIParent, "SecureActionButtonTemplate")
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
    UpdateButtonForHearthstone(currentHearthstone)

    -- Custom tooltip with modifier information
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(currentHearthstone.name, 1, 1, 1, 1)
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
                -- Cooldown text removed - game already displays this
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
end

-- Function to set up a new random hearthstone for the existing button
function SetupRandomHearthstone()
    if not frame or #hearthstoneToys == 0 then
        return
    end

    -- Filter out hearthstones that are on cooldown
    local availableHearthstones = {}
    DebugPrint("Checking cooldowns for all hearthstones:")
    for _, hearthstone in ipairs(hearthstoneToys) do
        local onCooldown = IsOnCooldown(hearthstone)
        local remaining = GetRemainingCooldown(hearthstone)
        DebugPrint("  " .. hearthstone.name .. ": " .. (onCooldown and ("on cooldown (" .. math.floor(remaining) .. "s)") or "available"))
        if not onCooldown then
            table.insert(availableHearthstones, hearthstone)
        end
    end

    -- If no hearthstones are available, find the one with shortest cooldown
    if #availableHearthstones == 0 then
        DebugPrint("All hearthstones on cooldown, finding shortest cooldown")
        local shortestCooldown = nil
        local shortestTime = math.huge

        for _, hearthstone in ipairs(hearthstoneToys) do
            local remaining = GetRemainingCooldown(hearthstone)
            if remaining < shortestTime then
                shortestTime = remaining
                shortestCooldown = hearthstone
            end
        end

        if shortestCooldown then
            currentHearthstone = shortestCooldown
            DebugPrint("Selected hearthstone with shortest cooldown: " .. currentHearthstone.name .. " (" .. math.floor(shortestTime) .. "s remaining)")
        end
    else
        -- Pick a random hearthstone from available ones
        local randomIndex = math.random(1, #availableHearthstones)
        currentHearthstone = availableHearthstones[randomIndex]
        DebugPrint("Selected available hearthstone: " .. currentHearthstone.name)
    end

    -- Update the button for the new hearthstone
    UpdateButtonForHearthstone(currentHearthstone)

    DebugPrint("Switched to: " .. currentHearthstone.name .. " (ID: " .. currentHearthstone.id .. ")")
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

    -- Dalaran Hearthstone is available via Shift-click but not in regular rotation

    -- Garrison Hearthstone is available via Ctrl-click but not in regular rotation

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

-- Initialize the addon
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        InitializeSavedVars()
        C_Timer.After(1, function()
            CreateHearthstoneButton()
        end)
    elseif (event == "LOADING_SCREEN_DISABLED" or event == "UNIT_SPELLCAST_STOP") and pendingRotation then
        -- Loading screen ended, delay rotation to ensure cooldowns are updated
        C_Timer.After(2.0, function()
            if pendingRotation then
                SetupRandomHearthstone()
                pendingRotation = false
                DebugPrint("Loading screen ended, rotated hearthstone")
            end
        end)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" and arg1 == "player" and pendingRotation then
        -- Hearthstone cast was interrupted
        pendingRotation = false
        DebugPrint("Hearthstone interrupted, not rotating")
    end
end)

-- Slash command for debug control
SLASH_HEARTHS1 = "/hearths"
SLASH_HEARTHS2 = "/hearth"
SlashCmdList["HEARTHS"] = function(msg)
    local args = {strsplit(" ", msg)}
    local command = args[1] or ""

    if command == "debug" then
        local setting = args[2] or ""
        if setting == "on" then
            HearthsDB.debug = true
            print("|cFF00FF00[Hearths]|r Debug logging enabled")
        elseif setting == "off" then
            HearthsDB.debug = false
            print("|cFF00FF00[Hearths]|r Debug logging disabled")
        else
            local status = HearthsDB.debug and "enabled" or "disabled"
            print("|cFF00FF00[Hearths]|r Debug logging is currently " .. status)
            print("  Usage: /hearths debug on|off")
        end
    elseif command == "reset" then
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER")
            HearthsDB.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
            print("|cFF00FF00[Hearths]|r Button position reset to center")
        end
    else
        print("|cFF00FF00[Hearths]|r Commands:")
        print("  /hearths debug on|off - Toggle debug logging")
        print("  /hearths reset - Reset button position to center")
        print("  Hold Alt and drag to move the button")
    end
end
