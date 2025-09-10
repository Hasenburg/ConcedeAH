local _, ns = ...

local AuctionHouse = ns.AuctionHouse

-- Initialize ranking sync module
local RankingSync = {}
ns.RankingSync = RankingSync

function RankingSync:Initialize()
    -- Store reference to AuctionHouse
    self.AuctionHouse = ns.AuctionHouse
    
    print("|cFF00FF00[Ranking Sync]|r Initialized - Will sync in 5 seconds")
    
    -- First broadcast our own data, then request from others
    C_Timer.After(5, function()
        -- Broadcast our data first
        self:BroadcastFullRankingState()
        
        -- Then request data from others after a short delay
        C_Timer.After(2, function()
            self:RequestRankingState()
        end)
    end)
end

function RankingSync:BroadcastRankingReset()
    if not self.AuctionHouse then return end
    if not ns.IsAdmin or not ns.IsAdmin() then return end
    
    local payload = {
        action = "reset",
        weekStartTime = time(),
        admin = UnitName("player")
    }
    
    self.AuctionHouse:BroadcastRankingUpdate(ns.T_RANKING_UPDATE, payload)
    print("|cFF00FF00[Admin Ranking Sync]|r Broadcasting ranking reset to guild")
end

function RankingSync:BroadcastRankingUpdate(contributor, type, points)
    if not self.AuctionHouse then 
        print("|cFFFF0000[Ranking Sync ERROR]|r AuctionHouse not available!")
        return 
    end
    
    local payload = {
        contributor = contributor,
        type = type,  -- "seller" or "buyer"
        points = points,
        weekStartTime = OFRankingData.weekStartTime,
        timestamp = time()
    }
    
    -- Use the AuctionHouse broadcast system
    self.AuctionHouse:BroadcastRankingUpdate(ns.T_RANKING_UPDATE, payload)
    
    print("|cFF00FF00[Ranking Sync]|r Broadcasting update: " .. contributor .. " = " .. points .. " " .. type .. " points (week: " .. OFRankingData.weekStartTime .. ")")
end

function RankingSync:OnRankingUpdate(message, sender)
    local success, data = self.AuctionHouse:Deserialize(message)
    if not success then 
        print("|cFFFF0000[Ranking Sync ERROR]|r Failed to deserialize message from " .. sender)
        return 
    end
    
    local _, payload = unpack(data)
    if not payload then 
        print("|cFFFF0000[Ranking Sync ERROR]|r Invalid payload from " .. sender)
        return 
    end
    
    -- Check if this is a reset command from admin
    if payload.action == "reset" then
        print("|cFFFF0000[Admin Ranking Sync]|r Received ranking reset from admin: " .. (payload.admin or "unknown"))
        OFRankingData = {
            currentWeek = {sellers = {}, buyers = {}},
            historicalWeeks = {},
            allTime = {sellers = {}, buyers = {}},
            weekStartTime = payload.weekStartTime or time()
        }
        -- Update UI if visible
        if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
            OFAuctionFrameRanking_UpdateList()
        end
        return
    end
    
    if not payload.contributor then 
        print("|cFFFF0000[Ranking Sync ERROR]|r Missing contributor in payload from " .. sender)
        return 
    end
    
    local pointType = payload.type or "seller"  -- Default to seller for compatibility
    print("|cFF00FFFF[Ranking Sync]|r Received update from " .. sender .. ": " .. payload.contributor .. " = " .. payload.points .. " " .. pointType .. " points (week: " .. payload.weekStartTime .. ")")
    
    -- Initialize if needed
    if not OFRankingData then
        OFRankingData = {
            currentWeek = {sellers = {}, buyers = {}},
            historicalWeeks = {},
            allTime = {sellers = {}, buyers = {}},
            weekStartTime = 0
        }
    end
    
    -- Ensure structure exists
    if not OFRankingData.currentWeek.sellers then
        OFRankingData.currentWeek = {sellers = {}, buyers = {}}
    end
    if not OFRankingData.allTime.sellers then
        OFRankingData.allTime = {sellers = {}, buyers = {}}
    end
    
    -- Check week reset first
    OFAuctionFrameRanking_CheckWeekReset()
    
    -- Check if this is for the current week
    if payload.weekStartTime == OFRankingData.weekStartTime then
        -- Update current week data based on type
        local dataTable = pointType == "buyer" and OFRankingData.currentWeek.buyers or OFRankingData.currentWeek.sellers
        local allTimeTable = pointType == "buyer" and OFRankingData.allTime.buyers or OFRankingData.allTime.sellers
        
        local currentPoints = dataTable[payload.contributor] or 0
        if payload.points > currentPoints then
            local difference = payload.points - currentPoints
            dataTable[payload.contributor] = payload.points
            
            -- Update all time
            allTimeTable[payload.contributor] = (allTimeTable[payload.contributor] or 0) + difference
            
            print("|cFF00FFFF[Ranking Sync]|r Updated " .. payload.contributor .. " to " .. payload.points .. " " .. pointType .. " points this week, " .. allTimeTable[payload.contributor] .. " total")
            
            -- Update UI if visible
            if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
                OFAuctionFrameRanking_UpdateList()
            end
        else
            print("|cFFFFFF00[Ranking Sync]|r Ignoring update - already have " .. currentPoints .. " " .. pointType .. " points for " .. payload.contributor)
        end
    else
        print("|cFFFFFF00[Ranking Sync]|r Ignoring update - different week (current: " .. OFRankingData.weekStartTime .. ", received: " .. payload.weekStartTime .. ")")
    end
end

function RankingSync:RequestRankingState()
    if not self.AuctionHouse then return end
    
    print("|cFFFFFF00[Ranking Sync]|r Requesting ranking state from guild...")
    self.AuctionHouse:BroadcastRankingUpdate(ns.T_RANKING_STATE_REQUEST, {})
end

function RankingSync:BroadcastFullRankingState()
    if not self.AuctionHouse then return end
    
    -- Initialize if needed
    OFAuctionFrameRanking_InitializeData()
    
    -- Count data
    local sellerCount = 0
    local buyerCount = 0
    for _ in pairs(OFRankingData.currentWeek.sellers or {}) do
        sellerCount = sellerCount + 1
    end
    for _ in pairs(OFRankingData.currentWeek.buyers or {}) do
        buyerCount = buyerCount + 1
    end
    
    if sellerCount == 0 and buyerCount == 0 then
        print("|cFFFFFF00[Ranking Sync]|r No ranking data to broadcast")
        return
    end
    
    -- Broadcast each seller individually
    for contributor, points in pairs(OFRankingData.currentWeek.sellers or {}) do
        local payload = {
            contributor = contributor,
            type = "seller",
            points = points,
            weekStartTime = OFRankingData.weekStartTime,
            timestamp = time()
        }
        self.AuctionHouse:BroadcastRankingUpdate(ns.T_RANKING_UPDATE, payload)
    end
    
    -- Broadcast each buyer individually
    for contributor, points in pairs(OFRankingData.currentWeek.buyers or {}) do
        local payload = {
            contributor = contributor,
            type = "buyer",
            points = points,
            weekStartTime = OFRankingData.weekStartTime,
            timestamp = time()
        }
        self.AuctionHouse:BroadcastRankingUpdate(ns.T_RANKING_UPDATE, payload)
    end
    
    print(string.format("|cFF00FF00[Ranking Sync]|r Broadcasted full ranking state: %d sellers, %d buyers", 
        sellerCount, buyerCount))
end

function RankingSync:OnRankingStateRequest(sender)
    if not self.AuctionHouse then 
        print("|cFFFF0000[Ranking Sync]|r Cannot send state - AuctionHouse not available")
        return 
    end
    
    -- Initialize if needed
    if not OFRankingData then
        OFRankingData = {
            currentWeek = {sellers = {}, buyers = {}},
            historicalWeeks = {},
            allTime = {sellers = {}, buyers = {}},
            weekStartTime = 0
        }
    end
    
    -- Count how much data we have
    local sellerCount = 0
    local buyerCount = 0
    for _ in pairs(OFRankingData.currentWeek.sellers or {}) do
        sellerCount = sellerCount + 1
    end
    for _ in pairs(OFRankingData.currentWeek.buyers or {}) do
        buyerCount = buyerCount + 1
    end
    
    -- Send our current ranking data to the requester
    local payload = {
        currentWeek = OFRankingData.currentWeek,
        allTime = OFRankingData.allTime,
        weekStartTime = OFRankingData.weekStartTime
    }
    
    print(string.format("|cFFFFFF00[Ranking Sync]|r Sending ranking state to %s (%d sellers, %d buyers)", 
        sender, sellerCount, buyerCount))
    self.AuctionHouse:SendDm(self.AuctionHouse:Serialize({ns.T_RANKING_STATE, payload}), sender)
end

function RankingSync:OnRankingState(message, sender)
    local success, data = self.AuctionHouse:Deserialize(message)
    if not success then return end
    
    local _, payload = unpack(data)
    if not payload then return end
    
    -- Count received data
    local receivedSellers = 0
    local receivedBuyers = 0
    if payload.currentWeek then
        if payload.currentWeek.sellers then
            for _ in pairs(payload.currentWeek.sellers) do
                receivedSellers = receivedSellers + 1
            end
        end
        if payload.currentWeek.buyers then
            for _ in pairs(payload.currentWeek.buyers) do
                receivedBuyers = receivedBuyers + 1
            end
        end
    end
    
    print(string.format("|cFF00FF00[Ranking Sync]|r Received ranking state from %s (%d sellers, %d buyers)", 
        sender, receivedSellers, receivedBuyers))
    
    -- Initialize if needed
    if not OFRankingData then
        OFRankingData = {
            currentWeek = {sellers = {}, buyers = {}},
            historicalWeeks = {},
            allTime = {sellers = {}, buyers = {}},
            weekStartTime = 0
        }
    end
    
    -- Ensure structure exists
    if not OFRankingData.currentWeek.sellers then
        OFRankingData.currentWeek = {sellers = {}, buyers = {}}
    end
    if not OFRankingData.allTime.sellers then
        OFRankingData.allTime = {sellers = {}, buyers = {}}
    end
    
    -- Merge the received data
    if payload.weekStartTime == OFRankingData.weekStartTime then
        -- Same week, merge current week data
        -- Handle both old and new data formats
        if payload.currentWeek then
            if payload.currentWeek.sellers then
                -- New format with sellers/buyers
                for contributor, points in pairs(payload.currentWeek.sellers or {}) do
                    local currentPoints = OFRankingData.currentWeek.sellers[contributor] or 0
                    if points > currentPoints then
                        OFRankingData.currentWeek.sellers[contributor] = points
                    end
                end
                for contributor, points in pairs(payload.currentWeek.buyers or {}) do
                    local currentPoints = OFRankingData.currentWeek.buyers[contributor] or 0
                    if points > currentPoints then
                        OFRankingData.currentWeek.buyers[contributor] = points
                    end
                end
            else
                -- Old format - add to sellers
                for contributor, points in pairs(payload.currentWeek) do
                    local currentPoints = OFRankingData.currentWeek.sellers[contributor] or 0
                    if points > currentPoints then
                        OFRankingData.currentWeek.sellers[contributor] = points
                    end
                end
            end
        end
    end
    
    -- Always merge all-time data (take the maximum)
    if payload.allTime then
        if payload.allTime.sellers then
            -- New format
            for contributor, points in pairs(payload.allTime.sellers or {}) do
                local currentPoints = OFRankingData.allTime.sellers[contributor] or 0
                if points > currentPoints then
                    OFRankingData.allTime.sellers[contributor] = points
                end
            end
            for contributor, points in pairs(payload.allTime.buyers or {}) do
                local currentPoints = OFRankingData.allTime.buyers[contributor] or 0
                if points > currentPoints then
                    OFRankingData.allTime.buyers[contributor] = points
                end
            end
        else
            -- Old format - add to sellers
            for contributor, points in pairs(payload.allTime) do
                local currentPoints = OFRankingData.allTime.sellers[contributor] or 0
                if points > currentPoints then
                    OFRankingData.allTime.sellers[contributor] = points
                end
            end
        end
    end
    
    -- Count final data after merge
    local finalSellers = 0
    local finalBuyers = 0
    for _ in pairs(OFRankingData.currentWeek.sellers or {}) do
        finalSellers = finalSellers + 1
    end
    for _ in pairs(OFRankingData.currentWeek.buyers or {}) do
        finalBuyers = finalBuyers + 1
    end
    
    print(string.format("|cFF00FF00[Ranking Sync]|r Ranking data merged successfully. Now have %d sellers, %d buyers", 
        finalSellers, finalBuyers))
    
    -- Update UI if visible
    if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
        OFAuctionFrameRanking_UpdateList()
    end
end