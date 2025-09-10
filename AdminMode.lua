local _, ns = ...

-- Admin configuration
local ADMIN_CHARACTERS = {
    ["Basenburg"] = true,
}

-- Check if current player is admin
function ns.IsAdmin()
    local playerName = UnitName("player")
    return ADMIN_CHARACTERS[playerName] == true
end

-- Admin commands initialization
function ns.InitializeAdminCommands()
    if not ns.IsAdmin() then return end
    
    -- Register admin slash commands
    SLASH_RANKINGRESET1 = "/rankingreset"
    SLASH_RANKINGSET1 = "/rankingset"
    SLASH_AUCTIONDELETE1 = "/auctiondel"
    SLASH_RANKINGBROADCAST1 = "/rankingbroadcast"
    
    -- Reset all rankings
    SlashCmdList["RANKINGRESET"] = function(msg)
        if not ns.IsAdmin() then 
            print("|cFFFF0000[Admin]|r You don't have permission to use this command.")
            return
        end
        
        if msg == "confirm" then
            OFRankingData = {
                currentWeek = {sellers = {}, buyers = {}},
                historicalWeeks = {},
                allTime = {sellers = {}, buyers = {}},
                weekStartTime = time()
            }
            print("|cFF00FF00[Admin]|r Rankings have been reset!")
            
            -- Broadcast the reset to other players
            if ns.RankingSync then
                ns.RankingSync:BroadcastRankingReset()
            end
            
            -- Update UI if visible
            if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
                OFAuctionFrameRanking_UpdateList()
            end
        else
            print("|cFFFFFF00[Admin]|r Type '/rankingreset confirm' to reset all rankings.")
        end
    end
    
    -- Set ranking points for a player
    SlashCmdList["RANKINGSET"] = function(msg)
        if not ns.IsAdmin() then 
            print("|cFFFF0000[Admin]|r You don't have permission to use this command.")
            return
        end
        
        local player, salesStr, purchasesStr = strsplit(" ", msg)
        local sales = tonumber(salesStr) or 0
        local purchases = tonumber(purchasesStr) or 0
        
        if not player then
            print("|cFFFFFF00[Admin]|r Usage: /rankingset PlayerName SalesPoints [PurchasePoints]")
            print("|cFFFFFF00[Admin]|r Example: /rankingset Bob 10 5")
            return
        end
        
        -- Initialize data structure properly
        if not OFRankingData then
            OFRankingData = {
                currentWeek = {sellers = {}, buyers = {}},
                historicalWeeks = {},
                allTime = {sellers = {}, buyers = {}},
                weekStartTime = time()
            }
        end
        
        -- Ensure structure exists
        if not OFRankingData.currentWeek.sellers then
            OFRankingData.currentWeek = {sellers = {}, buyers = {}}
        end
        if not OFRankingData.allTime.sellers then
            OFRankingData.allTime = {sellers = {}, buyers = {}}
        end
        
        -- Set the points
        OFRankingData.currentWeek.sellers[player] = sales
        OFRankingData.currentWeek.buyers[player] = purchases
        OFRankingData.allTime.sellers[player] = sales
        OFRankingData.allTime.buyers[player] = purchases
        
        print(string.format("|cFF00FF00[Admin]|r Set %s to %d sales, %d purchases", player, sales, purchases))
        
        -- Broadcast the updates
        if ns.RankingSync then
            ns.RankingSync:BroadcastRankingUpdate(player, "seller", sales)
            if purchases > 0 then
                ns.RankingSync:BroadcastRankingUpdate(player, "buyer", purchases)
            end
        end
        
        -- Update UI if visible
        if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
            OFAuctionFrameRanking_UpdateList()
        end
    end
    
    -- Delete an auction by ID
    SlashCmdList["AUCTIONDELETE"] = function(msg)
        if not ns.IsAdmin() then 
            print("|cFFFF0000[Admin]|r You don't have permission to use this command.")
            return
        end
        
        if not msg or msg == "" then
            print("|cFFFFFF00[Admin]|r Usage: /auctiondel <auctionID>")
            return
        end
        
        local success, error = ns.AuctionHouseAPI:DeleteAuction(msg)
        if success then
            print("|cFF00FF00[Admin]|r Auction " .. msg .. " deleted successfully.")
        else
            print("|cFFFF0000[Admin]|r Failed to delete auction: " .. (error or "unknown error"))
        end
    end
    
    -- Force broadcast current rankings to guild
    SlashCmdList["RANKINGBROADCAST"] = function()
        if not ns.IsAdmin() then 
            print("|cFFFF0000[Admin]|r You don't have permission to use this command.")
            return
        end
        
        if not OFRankingData then
            print("|cFFFF0000[Admin]|r No ranking data to broadcast.")
            return
        end
        
        print("|cFF00FF00[Admin]|r Broadcasting current rankings to guild...")
        
        -- Broadcast each player's points
        for player, points in pairs(OFRankingData.currentWeek or {}) do
            if ns.RankingSync then
                ns.RankingSync:BroadcastRankingUpdate(player, points)
            end
        end
        
        print("|cFF00FF00[Admin]|r Broadcast complete.")
    end
    
    print("|cFF00FF00[Admin Mode]|r Activated for " .. UnitName("player"))
    print("|cFF00FF00[Admin Commands]|r")
    print("  /rankingreset - Reset all rankings")
    print("  /rankingset <player> <points> - Set player points")
    print("  /rankingbroadcast - Force broadcast rankings")
    print("  /auctiondel <id> - Delete an auction")
end

-- Add delete button to auction browse frames for admins
function ns.AddAdminDeleteButton(button, auctionID)
    if not ns.IsAdmin() then return end
    
    if not button.adminDeleteButton then
        local deleteBtn = CreateFrame("Button", nil, button)
        deleteBtn:SetSize(20, 20)
        deleteBtn:SetPoint("RIGHT", button, "RIGHT", 25, 0)
        deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        deleteBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
        
        deleteBtn:SetScript("OnClick", function()
            if IsShiftKeyDown() then
                local currentAuctionID = deleteBtn.auctionID
                local success, error = ns.AuctionHouseAPI:DeleteAuction(currentAuctionID)
                if success then
                    print("|cFF00FF00[Admin]|r Deleted auction: " .. currentAuctionID)
                    -- Force refresh the marketplace
                    C_Timer.After(0.1, function()
                        if OFAuctionFrameMarketplace and OFAuctionFrameMarketplace:IsShown() then
                            OFMarketplace_Search()
                        else
                            OFAuctionFrameBrowse_Search()
                        end
                    end)
                else
                    print("|cFFFF0000[Admin]|r Failed to delete: " .. (error or "unknown"))
                end
            else
                print("|cFFFFFF00[Admin]|r Shift-click to delete auction: " .. deleteBtn.auctionID)
            end
        end)
        
        deleteBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Admin: Delete Auction", 1, 0, 0)
            GameTooltip:AddLine("Shift-click to delete this auction", 1, 1, 1)
            GameTooltip:Show()
        end)
        
        deleteBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        button.adminDeleteButton = deleteBtn
    end
    
    button.adminDeleteButton.auctionID = auctionID
    button.adminDeleteButton:Show()
end