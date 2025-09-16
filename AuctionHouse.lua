local addonName, ns = ...

local AuctionHouse = LibStub("AceAddon-3.0"):NewAddon("AuctionHouse", "AceComm-3.0", "AceSerializer-3.0")
ns.AuctionHouse = AuctionHouse
local LibDeflate = LibStub("LibDeflate")
local API = ns.AuctionHouseAPI


local COMM_PREFIX = "OFAuctionHouse"
local OF_COMM_PREFIX = "ConcedeAddon"
local T_AUCTION_STATE_REQUEST = "AUCTION_STATE_REQUEST"
local T_AUCTION_STATE = "AUCTION_STATE"

local T_CONFIG_REQUEST = "CONFIG_REQUEST"
local T_CONFIG_CHANGED = "CONFIG_CHANGED"

local T_AUCTION_ADD_OR_UPDATE = "AUCTION_ADD_OR_UPDATE"
local T_AUCTION_SYNCED = "AUCTION_SYNCED"
local T_AUCTION_DELETED = "AUCTION_DELETED"

-- Ratings
local T_RATING_ADD_OR_UPDATE = "RATING_ADD_OR_UPDATE"
local T_RATING_DELETED = "RATING_DELETED"
local T_RATING_SYNCED = "RATING_SYNCED"


-- 1) Add new constants for BLACKLIST in the same style as trades.
local T_BLACKLIST_STATE_REQUEST = "BLACKLIST_STATE_REQUEST"
local T_BLACKLIST_STATE         = "BLACKLIST_STATE"
local T_BLACKLIST_ADD_OR_UPDATE = "BLACKLIST_ADD_OR_UPDATE"
local T_BLACKLIST_DELETED       = "BLACKLIST_DELETED"
local T_BLACKLIST_SYNCED        = "BLACKLIST_SYNCED"
local T_ON_BLACKLIST_STATE_UPDATE = "OnBlacklistStateUpdate"

-- Add them to the ns table so they can be referenced elsewhere
ns.T_BLACKLIST_STATE_REQUEST = T_BLACKLIST_STATE_REQUEST
ns.T_BLACKLIST_STATE = T_BLACKLIST_STATE
ns.T_BLACKLIST_ADD_OR_UPDATE = T_BLACKLIST_ADD_OR_UPDATE
ns.T_BLACKLIST_DELETED = T_BLACKLIST_DELETED
ns.T_BLACKLIST_SYNCED = T_BLACKLIST_SYNCED
ns.T_ON_BLACKLIST_STATE_UPDATE = T_ON_BLACKLIST_STATE_UPDATE

local knownAddonVersions = {}

local ADMIN_USERS = {
    ["Minto-LivingFlame"] = 1,
    ["Concedelabs-LivingFlame"] = 1,
    ["Gbankconcede-LivingFlame"] = 1,
}

-- Constants
local TEST_USERS = {
    -- Debug messages disabled for all users
    -- Add player names here to enable debug messages for specific users
    -- Example: ["Playername"] = "identifier",
}
ns.TEST_USERS = TEST_USERS
local TEST_USERS_RACE = {
    ["Hasenburg"] = "Tauren",
    ["Basenhurg"] = "Orc",
    ["Hasenborg"] = "Undead",
    ["Pencilshaman"] = "Undead",
    ["Hasenburgxx"] = "Troll",
}

ns.COMM_PREFIX = COMM_PREFIX
ns.T_GUILD_ROSTER_CHANGED = "GUILD_ROSTER_CHANGED"

ns.T_CONFIG_REQUEST = T_CONFIG_REQUEST
ns.T_CONFIG_CHANGED = T_CONFIG_CHANGED
ns.T_AUCTION_ADD_OR_UPDATE = T_AUCTION_ADD_OR_UPDATE
ns.T_AUCTION_DELETED = T_AUCTION_DELETED
ns.T_AUCTION_STATE = T_AUCTION_STATE
ns.T_AUCTION_STATE_REQUEST = T_AUCTION_STATE_REQUEST
ns.T_AUCTION_SYNCED = T_AUCTION_SYNCED
ns.T_ON_AUCTION_STATE_UPDATE = "OnAuctionStateUpdate"

-- trades
ns.T_TRADE_ADD_OR_UPDATE = "TRADE_ADD_OR_UPDATE"
ns.T_TRADE_DELETED = "TRADE_DELETED"
ns.T_TRADE_SYNCED = "TRADE_SYNCED"

ns.T_ON_TRADE_STATE_UPDATE = "OnTradeStateUpdate"
ns.T_TRADE_STATE_REQUEST = "TRADE_REQUEST"
ns.T_TRADE_STATE = "TRADE_STATE"

-- trade ratings
ns.T_RATING_ADD_OR_UPDATE = T_RATING_ADD_OR_UPDATE
ns.T_RATING_DELETED = T_RATING_DELETED
ns.T_RATING_SYNCED = T_RATING_SYNCED

ns.T_ON_RATING_STATE_UPDATE = "OnRatingStateUpdate"
ns.T_RATING_STATE_REQUEST = "RATING_STATE_REQUEST"
ns.T_RATING_STATE = "RATING_STATE"


-- version check
ns.T_ADDON_VERSION_REQUEST = "ADDON_VERSION_REQUEST"
ns.T_ADDON_VERSION_RESPONSE = "ADDON_VERSION_RESPONSE"

-- Ranking events
local T_RANKING_UPDATE = "RANKING_UPDATE"
local T_RANKING_STATE_REQUEST = "RANKING_STATE_REQUEST"
local T_RANKING_STATE = "RANKING_STATE"
ns.T_RANKING_UPDATE = T_RANKING_UPDATE
ns.T_RANKING_STATE_REQUEST = T_RANKING_STATE_REQUEST
ns.T_RANKING_STATE = T_RANKING_STATE

local G, W = "GUILD", "WHISPER"

local CHANNEL_WHITELIST = {
    [ns.T_CONFIG_REQUEST] = {[G]=1},
    [ns.T_CONFIG_CHANGED] = {[W]=1},

    [ns.T_AUCTION_STATE_REQUEST] = {[G]=1},
    [ns.T_AUCTION_STATE] = {[W]=1},
    [ns.T_AUCTION_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_AUCTION_DELETED] = {[G]=1},

    [ns.T_TRADE_STATE_REQUEST] = {[G]=1},
    [ns.T_TRADE_STATE] = {[W]=1},
    [ns.T_TRADE_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_TRADE_DELETED] = {[G]=1},

    [ns.T_RATING_STATE_REQUEST] = {[G]=1},
    [ns.T_RATING_STATE] = {[W]=1},
    [ns.T_RATING_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_RATING_DELETED] = {[G]=1},



    [ns.T_ADDON_VERSION_REQUEST] = {[G]=1},
    [ns.T_ADDON_VERSION_RESPONSE] = {[W]=1},


    -- Blacklist
    [ns.T_BLACKLIST_STATE_REQUEST] = {[G] = 1},
    [ns.T_BLACKLIST_STATE]         = {[W] = 1},
    [ns.T_BLACKLIST_ADD_OR_UPDATE] = {[G] = 1},
    [ns.T_BLACKLIST_DELETED]       = {[G] = 1},
    
    -- Ranking
    [T_RANKING_UPDATE]         = {[G] = 1},
    [T_RANKING_STATE_REQUEST]  = {[G] = 1},
    [T_RANKING_STATE]          = {[W] = 1},
    
    -- Player sync
    ["PLAYER_NEEDS_SYNC"]      = {[G] = 1},
}

local function getFullName(name)
    local shortName, realmName = string.split("-", name)
    return shortName .. "-" .. (realmName  or GetRealmName())
end

local function isMessageAllowed(sender, channel, messageType)
    local fullName = getFullName(sender)
    if ADMIN_USERS[fullName] then
        return true
    end
    if not CHANNEL_WHITELIST[messageType] then
        return false
    end
    if not CHANNEL_WHITELIST[messageType][channel] then
        return false
    end
    return true
end

function AuctionHouse:OnInitialize()
    self.addonVersion = GetAddOnMetadata(addonName, "Version")
    knownAddonVersions[self.addonVersion] = true

    ChatUtils_Initialize()

    -- Initialize API
    ns.AuctionHouseAPI:Initialize({
        broadcastAuctionUpdate = function(dataType, payload)
            self:BroadcastAuctionUpdate(dataType, payload)
        end,
        broadcastTradeUpdate = function(dataType, payload)
            self:BroadcastTradeUpdate(dataType, payload)
        end,
        broadcastRatingUpdate = function(dataType, payload)
            self:BroadcastRatingUpdate(dataType, payload)
        end,
        broadcastBlacklistUpdate = function(dataType, payload)
            self:BroadcastBlacklistUpdate(dataType, payload)
        end,
    })
    ns.AuctionHouseAPI:Load()
    self.db = ns.AuctionHouseDB

    -- If needed for test users, show debug UI on load
    if ns.AuctionHouseDB.revision == 0 and TEST_USERS[UnitName("player")] then
        ns.AuctionHouseDB.showDebugUIOnLoad = true
    end


    -- Initialize UI
    ns.TradeAPI:OnInitialize()
    ns.MailboxUI:Initialize()
    ns.AuctionAlertWidget:OnInitialize()
    SettingsUI_Initialize()
    
    -- Initialize Ranking Sync
    if ns.RankingSync then
        ns.RankingSync:Initialize()
    end
    
    -- Initialize Admin Commands
    if ns.InitializeAdminCommands then
        ns.InitializeAdminCommands()
    end

    local age = time() - ns.AuctionHouseDB.lastUpdateAt
    local auctions = ns.AuctionHouseDB.auctions
    local auctionCount = 0
    for _, _ in pairs(auctions) do
        auctionCount = auctionCount + 1
    end
    ns.DebugLog(string.format("[DEBUG] db loaded from persistence. rev: %s, lastUpdateAt: %d (%ds old) with %d auctions",
            ns.AuctionHouseDB.revision, ns.AuctionHouseDB.lastUpdateAt, age, auctionCount))

    AHConfigSaved = ns.GetConfig()

    -- Register comm prefixes
    self:RegisterComm(COMM_PREFIX)
    self:RegisterComm(OF_COMM_PREFIX)

    -- chat commands
    SLASH_GAH1 = "/gah"
    SlashCmdList["GAH"] = function(msg) self:OpenAuctionHouse() end
    
    -- Debug command to check database
    SLASH_GAHDB1 = "/gahdb"
    SlashCmdList["GAHDB"] = function(msg)
        local totalAuctions = 0
        local activeAuctions = 0
        local pendingTradeAuctions = 0
        local pendingLoanAuctions = 0
        local sentCodAuctions = 0
        local sentLoanAuctions = 0
        local completedAuctions = 0
        local otherAuctions = 0
        local nilStatusAuctions = 0
        
        for id, auction in pairs(self.db.auctions) do
            totalAuctions = totalAuctions + 1
            if not auction.status then
                nilStatusAuctions = nilStatusAuctions + 1
            elseif auction.status == ns.AUCTION_STATUS_ACTIVE then
                activeAuctions = activeAuctions + 1
            elseif auction.status == ns.AUCTION_STATUS_PENDING_TRADE then
                pendingTradeAuctions = pendingTradeAuctions + 1
            elseif auction.status == ns.AUCTION_STATUS_PENDING_LOAN then
                pendingLoanAuctions = pendingLoanAuctions + 1
            elseif auction.status == ns.AUCTION_STATUS_SENT_COD then
                sentCodAuctions = sentCodAuctions + 1
            elseif auction.status == ns.AUCTION_STATUS_SENT_LOAN then
                sentLoanAuctions = sentLoanAuctions + 1
            elseif auction.status == ns.AUCTION_STATUS_COMPLETED then
                completedAuctions = completedAuctions + 1
            else
                otherAuctions = otherAuctions + 1
                print("  Unknown status: " .. tostring(auction.status) .. " for auction " .. tostring(id))
            end
        end
        
        print(ChatPrefix() .. " Database contains:")
        print("  Total auctions: " .. totalAuctions)
        print("  Active: " .. activeAuctions)
        print("  Pending Trade: " .. pendingTradeAuctions)
        print("  Pending Loan: " .. pendingLoanAuctions)
        print("  Sent COD: " .. sentCodAuctions) 
        print("  Sent Loan: " .. sentLoanAuctions)
        print("  Completed: " .. completedAuctions)
        print("  Nil status: " .. nilStatusAuctions)
        print("  Other status: " .. otherAuctions)
        print("  DB Revision: " .. (self.db.revision or 0))
    end
    
    -- Manual sync command
    SLASH_GAHSYNC1 = "/gahsync"
    SlashCmdList["GAHSYNC"] = function(msg)
        print(ChatPrefix() .. " Requesting full auction sync from guild...")
        
        -- Reset the received flags to allow re-syncing
        self.receivedAuctionState = false
        self.receivedTradeState = false
        
        -- Reset sync window to allow receiving new data
        self.initAt = GetTime() - 290  -- Set init time to 10 seconds ago to open sync window
        
        -- Broadcast that we need a full sync - same as a new player
        self:BroadcastMessage(self:Serialize({ "PLAYER_NEEDS_SYNC", { 
            player = UnitName("player"),
            revision = 0  -- Force full sync by claiming revision 0
        }}))
        
        -- Also do the regular sync request
        self:RequestLatestState()
        self:RequestLatestTradeState()
    end

    -- Request guild roster update to ensure we have member data
    GuildRoster()
    -- Repeat guild roster update after delay to ensure it's loaded
    C_Timer.After(2, function() GuildRoster() end)
    C_Timer.After(5, function() GuildRoster() end)
    
    -- Start auction expiration and trade trimming
    C_Timer.NewTicker(10, function()
        API:ExpireAuctions()
    end)
    C_Timer.NewTicker(61, function()
        API:TrimTrades()
    end)
    
    -- Periodic sync: Request auction state updates every 10 minutes
    -- This ensures players get auctions that were created while they were offline
    C_Timer.NewTicker(600, function()
        -- Only request if we've been online for at least 5 minutes
        if GetTime() - self.initAt > 300 then
            -- Broadcast that we need updates - triggers full sync from all online players
            self:BroadcastMessage(self:Serialize({ "PLAYER_NEEDS_SYNC", { 
                player = UnitName("player"),
                revision = self.db.revision or 0
            }}))
        end
    end)

    -- Test user functionality removed (streamer/race mapping no longer used)

    self.initAt = time()
    self:RequestLatestConfig()
    self:RequestLatestState()
    self:RequestLatestTradeState()
    self:RequestLatestRatingsState()
    self:RequestLatestBlacklistState()
    self:RequestAddonVersion()
    
    -- Announce that we're a new player who needs auction data
    -- This triggers all online players to send us their auctions
    C_Timer.After(2, function()
        -- Broadcast that we're online and need auction sync
        self:BroadcastMessage(self:Serialize({ "PLAYER_NEEDS_SYNC", { 
            player = UnitName("player"),
            revision = self.db.revision or 0
        }}))
    end)

    if self.db.showDebugUIOnLoad and self.CreateDebugUI then
        self:CreateDebugUI()
        self.debugUI:Show()
    end
    if self.db.openAHOnLoad then
        -- needs a delay to work properly, for whatever reason
        C_Timer.NewTimer(0.5, function()
            OFAuctionFrame_OverrideInitialTab(ns.AUCTION_TAB_BROWSE)
            OFAuctionFrame:Show()
        end)
    end

    self.ignoreSenderCheck = false

    -- Define boolean flags for each state change type
    self.receivedAuctionState = false
    self.receivedTradeState = false
    self.receivedRatingState = false
    self.receivedBlacklistState = false
    
    -- After sync window expires, mark states as received to prevent late responses
    C_Timer.After(300, function()
        self.receivedAuctionState = true
        self.receivedTradeState = true
        self.receivedRatingState = true
        self.receivedBlacklistState = true
    end)
end

function AuctionHouse:BroadcastMessage(message)
    local channel = "GUILD"
    self:SendCommMessage(COMM_PREFIX, message, channel)
    return true
end

function AuctionHouse:SendDm(message, recipient, prio)
    -- Check if recipient already has realm name
    local target
    if string.find(recipient, "-") then
        -- Recipient already has realm, use as-is
        target = recipient
    else
        -- Add current realm to recipient
        target = string.format("%s-%s", recipient, GetRealmName())
    end
    
    self:SendCommMessage(COMM_PREFIX, message, "WHISPER", target, prio)
end

function AuctionHouse:BroadcastAuctionUpdate(dataType, payload)
    self:BroadcastMessage(self:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastTradeUpdate(dataType, payload)
    self:BroadcastMessage(self:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastRatingUpdate(dataType, payload)
    self:BroadcastMessage(self:Serialize({ dataType, payload }))
end


function AuctionHouse:BroadcastBlacklistUpdate(dataType, payload)
    self:BroadcastMessage(self:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastRankingUpdate(dataType, payload)
    self:BroadcastMessage(self:Serialize({ dataType, payload }))
end

function AuctionHouse:IsSyncWindowExpired()
    -- Allow initial state sync within 5 minutes after login to ensure all auctions are received
    -- This gives more time for guild members to respond with their auction data
    return GetTime() - self.initAt > 300
end

local function IsGuildMember(name)
    -- First check our cached guild roster
    if ns.GuildRegister.table[getFullName(name)] then
        return true
    end
    
    -- Check the actual guild roster directly
    local numGuildMembers = GetNumGuildMembers()
    for i = 1, numGuildMembers do
        local memberName = GetGuildRosterInfo(i)
        if memberName then
            -- Extract just the name without realm
            local shortName = string.match(memberName, "([^-]+)")
            if shortName == name then
                return true
            end
        end
    end

    -- might still be guild member if the GuildRegister table didn't finish updating (server delay)
    -- check our hardcoded list for safety
    if ns.GetAvgViewers then
        return ns.GetAvgViewers(name) > 0
    end
    
    return false
end

function AuctionHouse:OnCommReceived(prefix, message, distribution, sender)
    -- Extract sender name without realm if present
    local senderName = sender
    if string.find(sender, "-") then
        senderName = string.match(sender, "([^-]+)")
    end
    
    -- Check whisper messages for guild membership
    -- During sync window (first 5 minutes), be more permissive to handle guild roster delays
    if distribution == W then
        local isGuild = IsGuildMember(senderName)
        
        if not isGuild then
            -- During sync window, allow T_AUCTION_STATE messages even from non-verified guild members
            -- This handles the case where guild roster hasn't loaded yet
            if not self:IsSyncWindowExpired() then
                local success2, data2 = self:Deserialize(message)
                if success2 and data2[1] == T_AUCTION_STATE then
                    -- Allow this message to proceed (guild roster may not be loaded yet)
                else
                    -- Block non-sync whispers
                    return
                end
            else
                -- Block whispers from non-guild members after sync window
                return
            end
        end
    end

    if prefix == OF_COMM_PREFIX then
        ns.HandleOFCommMessage(message, sender, distribution)
        return
    end
    if prefix ~= COMM_PREFIX then
        return
    end

    local success, data = self:Deserialize(message)
    if not success then
        return
    end
    -- Check if sender is self (use senderName without realm)
    if senderName == UnitName("player") and not self.ignoreSenderCheck then
        return
    end

    local dataType = data[1]
    local payload = data[2]

    ns.DebugLog("[DEBUG] recv", dataType, senderName)
    if not isMessageAllowed(senderName, distribution, dataType) then
        ns.DebugLog("[DEBUG] Ignoring message from", senderName, "of type", dataType, "in channel", distribution)
        return
    end

    -- Auction
    if dataType == T_AUCTION_ADD_OR_UPDATE then
        API:UpdateDB(payload)
        API:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = payload.auction, source = payload.source})

    elseif dataType == T_AUCTION_DELETED then
        API:DeleteAuctionInternal(payload, true)
        API:FireEvent(ns.T_AUCTION_DELETED, payload)

    -- Trades
    elseif dataType == ns.T_TRADE_ADD_OR_UPDATE then
        API:UpdateDBTrade({trade = payload.trade})
        API:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {auction = payload.auction, source = payload.source})

    elseif dataType == ns.T_TRADE_DELETED then
        API:DeleteTradeInternal(payload, true)

    -- Ratings
    elseif dataType == ns.T_RATING_ADD_OR_UPDATE then
        API:UpdateDBRating(payload)
        API:FireEvent(ns.T_RATING_ADD_OR_UPDATE, { rating = payload.rating, source = payload.source })

    elseif dataType == ns.T_RATING_DELETE then
        API:DeleteRatingInternal(payload, true)
        API:FireEvent(ns.T_RATING_DELETE, { ratingID = payload.ratingID })


    elseif dataType == T_AUCTION_STATE_REQUEST then
        -- Extract the list of auction IDs and their revisions from the requester
        local responsePayload, auctionCount, deletedCount = self:BuildDeltaState(payload.revision, payload.auctions)

        -- Serialize and compress the response
        local serializeStart = GetTimePreciseSec()
        local serialized = self:Serialize(responsePayload)
        local serializeTime = (GetTimePreciseSec() - serializeStart) * 1000

        local compressStart = GetTimePreciseSec()
        local compressed = LibDeflate:CompressDeflate(serialized)
        local compressTime = (GetTimePreciseSec() - compressStart) * 1000

        ns.DebugLog(string.format("[DEBUG] Sending delta state to %s: %d auctions, %d deleted IDs, rev %d (bytes-compressed: %d, serialize: %.0fms, compress: %.0fms)",
                senderName, auctionCount, deletedCount, self.db.revision,
                #compressed,
                serializeTime, compressTime
        ))

        -- Send the delta state back to the requester
        self:SendDm(self:Serialize({ T_AUCTION_STATE, compressed }), senderName, "BULK")

    elseif dataType == T_AUCTION_STATE then
        -- Allow receiving auction state multiple times during the sync window
        -- This is important when multiple players send their data
        if self:IsSyncWindowExpired() and self.receivedAuctionState then
            ns.DebugLog("ignoring T_AUCTION_STATE - sync window expired")
            return
        end
        -- Don't set receivedAuctionState to true immediately anymore
        -- Allow multiple responses during the sync window

        -- Decompress the payload before processing
        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000
        
        if not decompressed then
            return
        end

        local deserializeStart = GetTimePreciseSec()
        local success, state = self:Deserialize(decompressed)
        local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not success then
            return
        end

        -- Process received auctions regardless of revision during sync window
        -- This is important when multiple players send their data
        local auctionsReceived = 0
        local auctionsUpdated = 0
        local auctionsNew = 0
        local auctionsSkipped = 0
        
        -- Count total auctions in the received state
        for _ in pairs(state.auctions or {}) do
            auctionsReceived = auctionsReceived + 1
        end
        
        -- Always process auctions during the sync window or if sender has higher revision
        if not self:IsSyncWindowExpired() or state.revision > self.db.revision then
            -- Update local auctions with received data
            for id, auction in pairs(state.auctions or {}) do
                local oldAuction = self.db.auctions[id]
                
                -- Only update if we don't have it or the received one is newer
                if not oldAuction then
                    -- Brand new auction, always add it
                    self.db.auctions[id] = auction
                    auctionsNew = auctionsNew + 1
                    API:FireEvent(ns.T_AUCTION_SYNCED, {auction = auction, source = "create"})
                elseif not oldAuction.rev or not auction.rev or auction.rev > oldAuction.rev then
                    -- Update if revision is higher or if revision is missing
                    self.db.auctions[id] = auction
                    auctionsUpdated = auctionsUpdated + 1
                    if oldAuction.status ~= auction.status then
                            -- status change event
                            local source = "status_update"
                            if auction.status == ns.AUCTION_STATUS_PENDING_TRADE then
                                source = "buy"
                            elseif auction.status == ns.AUCTION_STATUS_PENDING_LOAN then
                                source = "buy_loan"
                            end
                            API:FireEvent(ns.T_AUCTION_SYNCED, {auction = auction, source = source})
                        else
                            -- unknown update reason (source)
                            API:FireEvent(ns.T_AUCTION_SYNCED, {auction = auction})
                        end
                else
                    -- Auction was skipped (already have newer version)
                    auctionsSkipped = auctionsSkipped + 1
                    ns.DebugLog(string.format("[DEBUG] Skipped auction %s (old rev: %s, new rev: %s)", 
                        id, tostring(oldAuction and oldAuction.rev), tostring(auction.rev)))
                end
            end

            -- Delete auctions that are no longer valid
            for _, id in ipairs(state.deletedAuctionIds or {}) do
                self.db.auctions[id] = nil
            end

            -- Update revision to the highest one we've seen
            if state.revision > self.db.revision then
                self.db.revision = state.revision
                self.db.lastUpdateAt = state.lastUpdateAt
            end

            API:FireEvent(ns.T_ON_AUCTION_STATE_UPDATE)
            
            ns.DebugLog(string.format("[DEBUG] Processed auction state: %d received, %d new, %d updated, %d deleted, revision %d",
                auctionsReceived, auctionsNew, auctionsUpdated,
                #(state.deletedAuctionIds or {}),
                self.db.revision
            ))
        else
            ns.DebugLog("[DEBUG] Ignoring outdated state update", state.revision, self.db.revision)
        end

    elseif dataType == T_CONFIG_REQUEST then
        if payload.version < AHConfigSaved.version then
            self:SendDm(self:Serialize({ T_CONFIG_CHANGED, AHConfigSaved }), senderName, "BULK")
        end
    elseif dataType == T_CONFIG_CHANGED then
        if payload.version > AHConfigSaved.version then
            AHConfigSaved = payload
        end
    elseif dataType == ns.T_TRADE_STATE_REQUEST then
        local responsePayload, tradeCount, deletedCount = self:BuildTradeDeltaState(payload.revTrades, payload.trades)

        -- serialize and compress
        local serializeStart = GetTimePreciseSec()
        local serialized = self:Serialize(responsePayload)
        local serializeTime = (GetTimePreciseSec() - serializeStart) * 1000

        local compressStart = GetTimePreciseSec()
        local compressed = LibDeflate:CompressDeflate(serialized)
        local compressTime = (GetTimePreciseSec() - compressStart) * 1000

        ns.DebugLog(string.format("[DEBUG] Sending delta trades to %s: %d trades, %d deleted IDs, revTrades %d (compressed bytes: %d, serialize: %.0fms, compress: %.0fms)",
            senderName, tradeCount, deletedCount, self.db.revTrades,
            #compressed, serializeTime, compressTime
        ))

        self:SendDm(self:Serialize({ ns.T_TRADE_STATE, compressed }), senderName, "BULK")

    elseif dataType == ns.T_TRADE_STATE then
        if self:IsSyncWindowExpired() and self.receivedTradeState then
            ns.DebugLog("ignoring T_TRADE_STATE")
            return
        end
        self.receivedTradeState = true

        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        local deserializeStart = GetTimePreciseSec()
        local ok, state = self:Deserialize(decompressed)
        local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not ok then
            return
        end

        -- apply the trade state delta if it is ahead of ours
        if state.revTrades > self.db.revTrades then
            for id, trade in pairs(state.trades or {}) do
                local oldTrade = self.db.trades[id]
                self.db.trades[id] = trade

                if not oldTrade then
                    -- new trade
                    API:FireEvent(ns.T_TRADE_SYNCED, { trade = trade, source = "create" })
                elseif oldTrade.rev == trade.rev then
                    -- same revision, skip
                else
                    -- trade updated
                    API:FireEvent(ns.T_TRADE_SYNCED, { trade = trade })
                end
            end

            for _, id in ipairs(state.deletedTradeIds or {}) do
                self.db.trades[id] = nil
            end

            self.db.revTrades = state.revTrades
            self.db.lastTradeUpdateAt = state.lastTradeUpdateAt

            API:FireEvent(ns.T_ON_TRADE_STATE_UPDATE)

            -- optionally fire a "trade state updated" event
            ns.DebugLog(string.format("[DEBUG] Updated local trade state with %d new/updated trades, %d deleted trades, revTrades %d (compressed bytes: %d, decompress: %.0fms, deserialize: %.0fms)",
                #(state.trades or {}), #(state.deletedTradeIds or {}),
                self.db.revTrades,
                #payload, decompressTime, deserializeTime
            ))
        else
            ns.DebugLog("[DEBUG] Outdated trade state ignored", state.revTrades, self.db.revTrades)
        end


    elseif dataType == ns.T_RATING_STATE_REQUEST then
        local responsePayload, ratingCount, deletedCount = self:BuildRatingsDeltaState(payload.revision, payload.ratings)

        -- Serialize and compress the response
        local serialized = self:Serialize(responsePayload)
        local compressed = LibDeflate:CompressDeflate(serialized)

        ns.DebugLog(string.format("[DEBUG] Sending delta ratings to %s: %d ratings, %d deleted IDs, revision %d (compressed: %db, uncompressed: %db)",
            senderName, ratingCount, deletedCount, self.db.revRatings, #compressed, #serialized))

        -- Send the delta state back to the requester
        self:SendDm(self:Serialize({ ns.T_RATING_STATE, compressed }), senderName, "BULK")

    elseif dataType == ns.T_RATING_STATE then
        if self:IsSyncWindowExpired() and self.receivedRatingState then
            ns.DebugLog("ignoring T_RATING_STATE")
            return
        end
        self.receivedRatingState = true

        -- local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        -- local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        -- local deserializeStart = GetTimePreciseSec()
        local ok, state = self:Deserialize(decompressed)
        -- local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not ok then
            return
        end

        if state.revision > self.db.revRatings then
            -- Update local ratings with received data
            for id, rating in pairs(state.ratings or {}) do
                self.db.ratings[id] = rating
                API:FireEvent(ns.T_RATING_SYNCED, {rating=rating})
            end

            -- Delete ratings that are no longer valid
            for _, id in ipairs(state.deletedRatingIds or {}) do
                self.db.ratings[id] = nil
            end

            self.db.revRatings = state.revision
            self.db.lastRatingUpdateAt = state.lastUpdateAt
            API:FireEvent(ns.T_ON_RATING_STATE_UPDATE)
        end



    -- Ranking events
    elseif dataType == T_RANKING_UPDATE then
        if ns.RankingSync then
            ns.RankingSync:OnRankingUpdate(self:Serialize(data), senderName)
        end
    
    elseif dataType == T_RANKING_STATE_REQUEST then
        if ns.RankingSync then
            ns.RankingSync:OnRankingStateRequest(senderName)
        end
    
    elseif dataType == T_RANKING_STATE then
        if ns.RankingSync then
            ns.RankingSync:OnRankingState(self:Serialize(data), senderName)
        end
    
    elseif dataType == ns.T_ADDON_VERSION_REQUEST then
        knownAddonVersions[payload.version] = true
        local latestVersion = ns.GetLatestVersion(knownAddonVersions)
        if latestVersion ~= payload.version then
            payload = {version=latestVersion}
            if ns.ChangeLog[latestVersion] then
                payload.changeLog = ns.ChangeLog[latestVersion]
            end
            self:SendDm(self:Serialize({ ns.T_ADDON_VERSION_RESPONSE, payload  }), senderName, "BULK")
        end
    elseif dataType == ns.T_ADDON_VERSION_RESPONSE then
        ns.DebugLog("[DEBUG] new addon version available", payload.version)
        knownAddonVersions[payload.version] = true
        if payload.changeLog then
            ns.ChangeLog[payload.version] = payload.changeLog
        end

    elseif dataType == ns.T_BLACKLIST_ADD_OR_UPDATE then
        -- "payload" looks like { playerName = "Alice", rev = 5, namesByType = { review = { "enemy1", "enemy2" } } }
        ns.BlacklistAPI:UpdateDBBlacklist(payload)
        API:FireEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, payload)

    -- deletions are not supported, top-level entries just become empty if everything's been un-blacklisted
    -- elseif dataType == ns.T_BLACKLIST_DELETED then
    --     -- "payload" might be { playerName = "Alice" }
    --     if self.db.blacklists[payload.playerName] ~= nil then
    --         self.db.blacklists[payload.playerName] = nil
    --         if (self.db.revBlacklists or 0) < (payload.rev or 0) then
    --             self.db.revBlacklists = payload.rev
    --             self.db.lastBlacklistUpdateAt = time()
    --         end
    --         API:FireEvent(ns.T_BLACKLIST_DELETED, payload)
    --     end

    elseif dataType == ns.T_BLACKLIST_STATE_REQUEST then
        -- "payload" includes revBlacklists and blacklistEntries with blType
        local responsePayload, blCount, deletedCount =
            self:BuildBlacklistDeltaState(payload.revBlacklists, payload.blacklistEntries)

        -- Serialize and compress the response
        local serializeStart = GetTimePreciseSec()
        local serialized = self:Serialize(responsePayload)
        local serializeTime = (GetTimePreciseSec() - serializeStart) * 1000

        local compressStart = GetTimePreciseSec()
        local compressed = LibDeflate:CompressDeflate(serialized)
        local compressTime = (GetTimePreciseSec() - compressStart) * 1000

        ns.DebugLog(string.format(
            "[DEBUG] Sending delta blacklists to %s: %d changed, %d deleted, revBlacklists %d (bytes: %d, serialize: %.0fms, compress: %.0fms)",
            senderName, blCount, deletedCount, self.db.revBlacklists, #compressed, serializeTime, compressTime
        ))

        self:SendDm(self:Serialize({ ns.T_BLACKLIST_STATE, compressed }), senderName, "BULK")

    elseif dataType == ns.T_BLACKLIST_STATE then
        if self:IsSyncWindowExpired() and self.receivedBlacklistState then
            ns.DebugLog("ignoring T_BLACKLIST_STATE")
            return
        end
        self.receivedBlacklistState = true

        -- "payload" is compressed state with per-type blacklists
        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        local deserializeStart = GetTimePreciseSec()
        local ok, state = self:Deserialize(decompressed)
        local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not ok then
            return
        end

        if state.revBlacklists > (self.db.revBlacklists or 0) then
            -- Update local blacklists
            for user, entry in pairs(state.blacklists or {}) do
                local oldEntry = self.db.blacklists[user]
                self.db.blacklists[user] = entry
                if not oldEntry then
                    API:FireEvent(ns.T_BLACKLIST_SYNCED, { blacklist = entry, source = "create" })
                else
                    API:FireEvent(ns.T_BLACKLIST_SYNCED, { blacklist = entry })
                end
            end
            -- Delete blacklists from local that are no longer in the received state
            for _, user in ipairs(state.deletedBlacklistIds or {}) do
                self.db.blacklists[user] = nil
            end

            -- Bump our local revision
            self.db.revBlacklists = state.revBlacklists
            self.db.lastBlacklistUpdateAt = state.lastBlacklistUpdateAt

            API:FireEvent(ns.T_ON_BLACKLIST_STATE_UPDATE)

            ns.DebugLog(string.format(
                "[DEBUG] Updated local blacklists with %d new/updated, %d deleted, revBlacklists %d (compressed: %d, decompress: %.0fms, deserialize: %.0fms)",
                #(state.blacklists or {}), #(state.deletedBlacklistIds or {}),
                self.db.revBlacklists, #payload, decompressTime, deserializeTime
            ))
        else
            ns.DebugLog("[DEBUG] Outdated blacklist state ignored", state.revBlacklists, self.db.revBlacklists)
        end
        
    elseif dataType == "PLAYER_NEEDS_SYNC" then
        -- A new player logged in and needs auction data
        -- Every online player should send their auction data to help sync
        if payload.player ~= UnitName("player") then
            -- Don't respond to our own sync request
            C_Timer.After(math.random() * 2 + 0.5, function()
                -- Count total auctions in our database
                local totalInDB = 0
                for _ in pairs(self.db.auctions) do
                    totalInDB = totalInDB + 1
                end
                
                -- Add a random 0.5-2.5 second delay to avoid overwhelming the new player
                -- Force send ALL auctions by passing revision 0
                local responsePayload, auctionCount, deletedCount = self:BuildDeltaState(0, {})
                
                if auctionCount > 0 then
                    -- We have auctions to share, send them to the new player
                    local serialized = self:Serialize(responsePayload)
                    local compressed = LibDeflate:CompressDeflate(serialized)
                    
                    -- Send directly to the requesting player
                    self:SendDm(self:Serialize({ T_AUCTION_STATE, compressed }), payload.player, "BULK")
                    
                    ns.DebugLog(string.format("[DEBUG] Sent %d of %d total auctions to new player %s (compressed: %d bytes)", 
                        auctionCount, totalInDB, payload.player, #compressed))
                else
                    ns.DebugLog(string.format("[DEBUG] No auctions to send to %s (total in DB: %d)", 
                        payload.player, totalInDB))
                end
            end)
        end
        
    else
        ns.DebugLog("[DEBUG] unknown event type", dataType)
    end
end

function AuctionHouse:BuildDeltaState(requesterRevision, requesterAuctions)
    local auctionsToSend = {}
    local deletedAuctionIds = {}
    local auctionCount = 0
    local deletionCount = 0

    -- Always send auctions if we have a higher revision or if requester has very low revision (new player)
    if requesterRevision < self.db.revision or requesterRevision == 0 then
        -- Convert requesterAuctions array to lookup table with revisions
        local requesterAuctionLookup = {}
        for _, auctionInfo in ipairs(requesterAuctions or {}) do
            requesterAuctionLookup[auctionInfo.id] = auctionInfo.rev
        end

        -- If requester has revision 0 or very low revision, send ALL active auctions
        if requesterRevision == 0 or (self.db.revision - requesterRevision > 100) then
            -- Send all auctions - the requester is likely a new player or was offline for long
            local totalAuctions = 0
            local skippedAuctions = 0
            for id, auction in pairs(self.db.auctions) do
                totalAuctions = totalAuctions + 1
                -- Send ALL auctions except completed ones and nil status
                -- This includes: ACTIVE, PENDING_TRADE, PENDING_LOAN, SENT_COD, SENT_LOAN
                if auction.status and auction.status ~= ns.AUCTION_STATUS_COMPLETED then
                    auctionsToSend[id] = auction
                    auctionCount = auctionCount + 1
                    ns.DebugLog(string.format("[DEBUG] Including auction %s status=%s", 
                        id, auction.status or "nil"))
                else
                    skippedAuctions = skippedAuctions + 1
                    ns.DebugLog(string.format("[DEBUG] Skipping auction %s status=%s", 
                        id, auction.status or "nil"))
                end
            end
            print(ChatPrefix() .. string.format(" BuildDeltaState: Preparing %d/%d auctions (skipped %d completed)", 
                auctionCount, totalAuctions, skippedAuctions))
            ns.DebugLog(string.format("[DEBUG] BuildDeltaState: Sending ALL auctions - %d active, %d skipped (completed/expired), %d total",
                auctionCount, skippedAuctions, totalAuctions))
        else
            -- Normal delta sync - only send updated auctions
            for id, auction in pairs(self.db.auctions) do
                local requesterRev = requesterAuctionLookup[id]
                if not requesterRev or (auction.rev > requesterRev) then
                    auctionsToSend[id] = auction
                    auctionCount = auctionCount + 1
                end
            end
        end

        -- Find deleted auctions (present in requester but not in current state)
        for id, _ in pairs(requesterAuctionLookup) do
            if not self.db.auctions[id] then
                table.insert(deletedAuctionIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    -- Construct the response payload
    local payload = {
        v = 1,
        auctions = auctionsToSend,
        deletedAuctionIds = deletedAuctionIds,
        revision = self.db.revision,
        lastUpdateAt = self.db.lastUpdateAt,
    }
    
    -- Debug: Count auctions in payload
    local payloadCount = 0
    for _ in pairs(payload.auctions or {}) do
        payloadCount = payloadCount + 1
    end
    
    if payloadCount ~= auctionCount then
        print(ChatPrefix() .. string.format(" WARNING: Payload count mismatch! Expected %d, got %d", 
            auctionCount, payloadCount))
    end
    
    return payload, auctionCount, deletionCount
end

function AuctionHouse:BuildTradeDeltaState(requesterRevision, requesterTrades)
    local tradesToSend = {}
    local deletedTradeIds = {}
    local tradeCount = 0
    local deletionCount = 0

    -- If requester is behind, then we figure out what trades changed or were deleted
    if not requesterRevision or requesterRevision < self.db.revTrades then
        -- Build a lookup table of the requester's trades, keyed by trade id → revision
        local requesterTradeLookup = {}
        for _, tradeInfo in ipairs(requesterTrades or {}) do
            requesterTradeLookup[tradeInfo.id] = tradeInfo.rev
        end

        -- Collect trades that need to be sent because the requester doesn't have them
        for id, trade in pairs(self.db.trades) do
            local requesterRev = requesterTradeLookup[id]
            if not requesterRev or (trade.rev > requesterRev) then
                tradesToSend[id] = trade
                tradeCount = tradeCount + 1
            end
        end

        -- Detect trades the requester has, but we don't (deleted or no longer valid)
        for id, _ in pairs(requesterTradeLookup) do
            if not self.db.trades[id] then
                table.insert(deletedTradeIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    return {
        v = 1,
        trades = tradesToSend,
        deletedTradeIds = deletedTradeIds,
        revTrades = self.db.revTrades or 0,
        lastTradeUpdateAt = self.db.lastTradeUpdateAt,
    }, tradeCount, deletionCount
end

function AuctionHouse:BuildRatingsDeltaState(requesterRevision, requesterRatings)
    local ratingsToSend = {}
    local deletedRatingIds = {}
    local ratingCount = 0
    local deletionCount = 0

    if requesterRevision < self.db.revRatings then
        -- Convert requesterRatings array to lookup table with revisions
        local requesterRatingLookup = {}
        for _, ratingInfo in ipairs(requesterRatings or {}) do
            requesterRatingLookup[ratingInfo.id] = ratingInfo.rev
        end

        -- Find ratings to send (those that requester doesn't have or has older revision)
        for id, rating in pairs(self.db.ratings) do
            local requesterRev = requesterRatingLookup[id]
            if not requesterRev or (rating.rev > requesterRev) then
                ratingsToSend[id] = rating
                ratingCount = ratingCount + 1
            end
        end

        -- Find deleted ratings (present in requester but not in current state)
        for id, _ in pairs(requesterRatingLookup) do
            if not self.db.ratings[id] then
                table.insert(deletedRatingIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    -- Construct the response payload
    return {
        v = 1,
        ratings = ratingsToSend,
        deletedRatingIds = deletedRatingIds,
        revision = self.db.revRatings,
        lastUpdateAt = self.db.lastRatingUpdateAt,
    }, ratingCount, deletionCount
end


function AuctionHouse:BuildBlacklistDeltaState(requesterRevision, requesterBlacklists)
    -- We'll return a table of updated items plus a list of deleted ones.
    local blacklistsToSend = {}
    local deletedBlacklistIds = {}
    local blacklistCount = 0
    local deletionCount = 0

    if requesterRevision < (self.db.revBlacklists or 0) then
        -- Convert the requester's blacklist array into a name->rev lookup with blType
        local requesterBLLookup = {}
        for _, info in ipairs(requesterBlacklists or {}) do
            requesterBLLookup[info.playerName] = info.rev
        end

        -- For each local playerName in blacklists
        for playerName, blacklist in pairs(self.db.blacklists or {}) do
            local requesterRev = requesterBLLookup[playerName]
            if not requesterRev or (blacklist.rev > requesterRev) then
                blacklistsToSend[playerName] = blacklist
                blacklistCount = blacklistCount + 1
            end
        end

        -- Detect blacklists the requester has, but we don't (deleted)
        for playerName, _ in pairs(requesterBLLookup) do
            if not self.db.blacklists[playerName] then
                table.insert(deletedBlacklistIds, playerName)
                deletionCount = deletionCount + 1
            end
        end
    end

    return {
        v = 1,
        blacklists = blacklistsToSend,
        deletedBlacklistIds = deletedBlacklistIds,
        revBlacklists = self.db.revBlacklists or 0,
        lastBlacklistUpdateAt = self.db.lastBlacklistUpdateAt or 0,
    }, blacklistCount, deletionCount
end

function AuctionHouse:RequestLatestConfig()
    self:BroadcastMessage(self:Serialize({ T_CONFIG_REQUEST, { version = AHConfigSaved.version } }))
end


function AuctionHouse:BuildAuctionsTable()
    local auctions = {}
    for id, auction in pairs(self.db.auctions) do
        table.insert(auctions, {id = id, rev = auction.rev})
    end
    return auctions
end

function AuctionHouse:BuildTradesTable()
    local trades = {}
    for id, trade in pairs(self.db.trades) do
        table.insert(trades, { id = id, rev = trade.rev })
    end
    return trades
end

function AuctionHouse:BuildRatingsTable()
    local ratings = {}
    for id, rating in pairs(self.db.ratings) do
        table.insert(ratings, { id = id, rev = rating.rev })
    end
    return ratings
end


function AuctionHouse:BuildBlacklistTable()
    local blacklistEntries = {}
    for playerName, blacklist in pairs(self.db.blacklists or {}) do
        table.insert(blacklistEntries, { playerName = playerName, rev = blacklist.rev })
    end
    return blacklistEntries
end


function AuctionHouse:RequestLatestState()
    local auctions = self:BuildAuctionsTable()
    -- If we have very low revision, request ALL auctions, not just delta
    local revision = self.db.revision
    if revision < 10 then
        -- Signal that we need everything by sending revision 0
        revision = 0
        auctions = {} -- Don't send our auctions if we're new
    end
    local payload = { T_AUCTION_STATE_REQUEST, { revision = revision, auctions = auctions } }
    local msg = self:Serialize(payload)

    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestTradeState()
    local trades = self:BuildTradesTable()
    local payload = { ns.T_TRADE_STATE_REQUEST, { revTrades = self.db.revTrades, trades = trades } }
    local msg = self:Serialize(payload)

    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestRatingsState()
    local ratings = self:BuildRatingsTable()
    local payload = { ns.T_RATING_STATE_REQUEST, { revision = self.db.revRatings, ratings = ratings } }
    local msg = self:Serialize(payload)

    self:BroadcastMessage(msg)
end



function AuctionHouse:RequestLatestBlacklistState()
    local blacklistEntries = self:BuildBlacklistTable()
    local payload = {
        ns.T_BLACKLIST_STATE_REQUEST,
        { revBlacklists = self.db.revBlacklists or 0, blacklistEntries = blacklistEntries }
    }
    local msg = self:Serialize(payload)
    self:BroadcastMessage(msg)
end


SLASH_hasenburgclear1 = "/hasenburgclear"
SlashCmdList["hasenburgclear"] = function(msg)
    HasenburgClearPersistence()
end

function HasenburgClearPersistence()
    ns.AuctionHouseAPI:ClearPersistence()
    print("Persistence cleared")
end

function AuctionHouse:RequestAddonVersion()
    local payload = { ns.T_ADDON_VERSION_REQUEST, { version = self.addonVersion } }
    local msg = self:Serialize(payload)
    self:BroadcastMessage(msg)
end
function AuctionHouse:GetLatestVersion()
    return ns.GetLatestVersion(knownAddonVersions)
end

function AuctionHouse:IsUpdateAvailable()
    local latestVersion = ns.GetLatestVersion(knownAddonVersions)
    return ns.CompareVersions(latestVersion, self.addonVersion) > 0
end

function AuctionHouse:IsImportantUpdateAvailable()
    local latestVersion = ns.GetLatestVersion(knownAddonVersions)
    return ns.CompareVersionsExclPatch(latestVersion, self.addonVersion) > 0
end


function AuctionHouse:OpenAuctionHouse()
    ns.TryExcept(
        function()
            if self:IsImportantUpdateAvailable() and not ns.ShowedUpdateAvailablePopupRecently() then
                ns.ShowUpdateAvailablePopup()
            else
                OFAuctionFrame:Show()
            end
        end,
        function(err)
            ns.DebugLog("[ERROR] Failed to open auction house", err)
            OFAuctionFrame:Show()
        end
    )
end

ns.GameEventHandler:On("PLAYER_REGEN_DISABLED", function()
    -- player entered combat, close the auction house to be safe
    if OFAuctionFrame:IsShown() then
        OFAuctionFrame:Hide()
    else
        OFCloseAuctionStaticPopups()
    end
    StaticPopup_Hide("OF_LEAVE_REVIEW")
    StaticPopup_Hide("OF_UPDATE_AVAILABLE")
    StaticPopup_Hide("OF_BLACKLIST_PLAYER_DIALOG")
    StaticPopup_Hide("OF_DECLINE_ALL")
    StaticPopup_Hide("GAH_MAIL_CANCEL_AUCTION")
end)

-- Function to clean up auctions and trades
function AuctionHouse:CleanupAuctionsAndTrades()
    local me = UnitName("player")

    -- cleanup auctions
    local auctions = API:QueryAuctions(function(auction)
        return auction.owner == me or auction.buyer == me
    end)
    for _, auction in ipairs(auctions) do
        if auction.status == ns.AUCTION_STATUS_SENT_LOAN then
            if auction.owner == me then
                API:MarkLoanComplete(auction.id)
            else
                API:DeclareBankruptcy(auction.id)
            end
        else
            API:DeleteAuctionInternal(auction.id)
        end
    end

    local trades = API:GetMyTrades()
    for _, trade in ipairs(trades) do
        if trade.auction.buyer == me then
            API:SetBuyerDead(trade.id)
        end
        if trade.auction.owner == me then
            API:SetSellerDead(trade.id)
        end
    end
end

ns.GameEventHandler:On("PLAYER_DEAD", function()
    -- Auctions are no longer removed on death
    -- print(ChatPrefix() .. " removing auctions after death")
    -- AuctionHouse:CleanupAuctionsAndTrades()
end)


local function cleanupIfKicked()
    if not IsInGuild() then
        print(ChatPrefix() .. " removing auctions after gkick")
        AuctionHouse:CleanupAuctionsAndTrades()
    end
end

ns.GameEventHandler:On("PLAYER_GUILD_UPDATE", function()
    -- Check guild status after some time, to make sure IsInGuild is accurate
    C_Timer.After(3, cleanupIfKicked)
end)
ns.GameEventHandler:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(10, cleanupIfKicked)
end)
