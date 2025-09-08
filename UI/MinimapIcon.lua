local addonName, ns = ...

-- Ensure LibStub is available
if not LibStub then
    print("ConcedeAH: LibStub not found, minimap button cannot be created")
    return
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then 
    print("ConcedeAH: LibDataBroker not found, minimap button cannot be created")
    return 
end

local plugin = ldb:NewDataObject(addonName, {
    type = "data source",
    text = "Concede",
    icon = "Interface\\AddOns\\"..addonName.."\\Media\\icon_of_64px.png",
})

function plugin.OnClick(self, button)
    if button == "LeftButton" then
        if OFAuctionFrame:IsShown() then
            OFAuctionFrame:Hide()
        else
           ns.AuctionHouse:OpenAuctionHouse()
        end
    end
end

local function wrapColor(text, color)
    return "|cff"..color..text.."|r"
end

function plugin.OnTooltipShow(tt)
    tt:AddLine("ConcedeAH")
    local grey = "808080"
    local me = UnitName("player")

    local pendingAuctions = ns.GetMyPendingAuctions({})
    local pendingReviewCount = ns.AuctionHouseAPI:GetPendingReviewCount()
    local ratingAvg, ratingCount = ns.AuctionHouseAPI:GetAverageRatingForUser(me)
    local ratingText = string.format("%.1f stars", ratingAvg)
    if ratingCount == 0 then
        ratingText = "N/A"
    end

    tt:AddLine(wrapColor("Left-click: ", grey) .. "Open Guild AH")
    tt:AddLine(wrapColor("Pending Orders: ", grey) .. #pendingAuctions)
    tt:AddLine(wrapColor("Pending Reviews: ", grey) .. pendingReviewCount)
    tt:AddLine(wrapColor("Review Rating: ", grey) .. ratingText)
    tt:AddLine(wrapColor("Addon version: ", grey) .. GetAddOnMetadata(addonName, "Version"))
end

-- Initialize minimap icon with saved position
local minimapIconDefaults = {
    hide = false,
    minimapPos = 220,
    radius = 80,
}

local function InitializeMinimapIcon()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then 
        print("ConcedeAH: LibDBIcon not found, minimap button disabled")
        return false
    end
    
    -- Initialize saved variables for minimap icon position
    if not PlayerPrefsSaved then
        PlayerPrefsSaved = {}
    end
    if not PlayerPrefsSaved.minimapIcon then
        PlayerPrefsSaved.minimapIcon = {}
        for k, v in pairs(minimapIconDefaults) do
            PlayerPrefsSaved.minimapIcon[k] = v
        end
    end
    
    -- Register the minimap icon
    icon:Register(addonName, plugin, PlayerPrefsSaved.minimapIcon)
    
    -- Show icon if not hidden
    if not PlayerPrefsSaved.minimapIcon.hide then
        icon:Show(addonName)
    else
        icon:Hide(addonName)
    end
    
    return true
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
        if event == "ADDON_LOADED" and ... ~= addonName then
            return
        end
        
        -- Try to initialize after a short delay to ensure all libraries are loaded
        C_Timer.After(0.5, function()
            if InitializeMinimapIcon() then
                print("ConcedeAH: Minimap button ready. Click to open AH. Use /ofah minimap to toggle visibility.")
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end)
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")

-- Add slash command to toggle minimap icon
SLASH_OFAHMINIMAP1 = "/ofahminimap"
SLASH_OFAHMINIMAP2 = "/ofah"
SlashCmdList["OFAHMINIMAP"] = function(msg)
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then 
        print("ConcedeAH: Minimap icon library not available")
        return 
    end
    
    -- Ensure SavedVariables exist
    if not PlayerPrefsSaved then
        PlayerPrefsSaved = {}
    end
    if not PlayerPrefsSaved.minimapIcon then
        PlayerPrefsSaved.minimapIcon = {}
        for k, v in pairs(minimapIconDefaults) do
            PlayerPrefsSaved.minimapIcon[k] = v
        end
        -- Try to register if not already done
        icon:Register(addonName, plugin, PlayerPrefsSaved.minimapIcon)
    end
    
    if msg == "minimap" or msg == "minimap toggle" then
        if PlayerPrefsSaved.minimapIcon.hide then
            PlayerPrefsSaved.minimapIcon.hide = false
            icon:Show(addonName)
            print("ConcedeAH: Minimap button shown")
        else
            PlayerPrefsSaved.minimapIcon.hide = true
            icon:Hide(addonName)
            print("ConcedeAH: Minimap button hidden")
        end
    elseif msg == "minimap show" then
        PlayerPrefsSaved.minimapIcon.hide = false
        icon:Show(addonName)
        print("ConcedeAH: Minimap button shown")
    elseif msg == "minimap hide" then
        PlayerPrefsSaved.minimapIcon.hide = true
        icon:Hide(addonName)
        print("ConcedeAH: Minimap button hidden")
    elseif msg == "help" then
        print("ConcedeAH Commands:")
        print("  /ofah - Open/close auction house")
        print("  /ofah minimap - Toggle minimap button")
        print("  /ofah minimap show - Show minimap button")
        print("  /ofah minimap hide - Hide minimap button")
    else
        -- Open/close the auction house window
        if OFAuctionFrame and OFAuctionFrame:IsShown() then
            OFAuctionFrame:Hide()
        elseif ns.AuctionHouse then
            ns.AuctionHouse:OpenAuctionHouse()
        else
            print("ConcedeAH: Auction house not available yet")
        end
    end
end
