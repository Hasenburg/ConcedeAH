local addonName, ns = ...
local AuctionHouse = ns.AuctionHouse

local TradeAPI = {}
ns.TradeAPI = TradeAPI

function TradeAPI:OnInitialize()
    -- Create event frame
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    -- Register events
    self.eventFrame:RegisterEvent("MAIL_SHOW")
    self.eventFrame:RegisterEvent("MAIL_CLOSED")
    self.eventFrame:RegisterEvent("UI_INFO_MESSAGE") 
    self.eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
    self.eventFrame:RegisterEvent("TRADE_SHOW")
    self.eventFrame:RegisterEvent("TRADE_MONEY_CHANGED")
    self.eventFrame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
    self.eventFrame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
    self.eventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
    
    -- Debug command to check auction statuses
    SLASH_CHECKAUCTIONS1 = "/checkauctions"
    SlashCmdList["CHECKAUCTIONS"] = function()
        local me = UnitName("player")
        local meShort = string.match(me, "^([^-]+)") or me
        local API = ns.AuctionHouseAPI
        print("|cFFFFFF00[Auctions Debug]|r Checking all auctions for " .. me)
        if meShort ~= me then
            print("|cFFFFFF00[Auctions Debug]|r Also checking short name: " .. meShort)
        end
        
        local allAuctions = API:GetAllAuctions()
        local mySellerCount = 0
        local myBuyerCount = 0
        local pendingTradeCount = 0
        
        for _, auction in ipairs(allAuctions) do
            if auction.status == ns.AUCTION_STATUS_PENDING_TRADE then
                pendingTradeCount = pendingTradeCount + 1
            end
            
            -- Check both full name and short name
            local isOwner = (auction.owner == me) or (auction.owner == meShort)
            local isBuyer = (auction.buyer == me) or (auction.buyer == meShort)
            
            if isOwner then
                mySellerCount = mySellerCount + 1
                print("|cFF00FF00[Seller]|r ID: " .. auction.id .. ", Status: " .. (auction.status or "nil") .. ", Buyer: " .. (auction.buyer or "none") .. ", ItemID: " .. (auction.itemID or "nil"))
            elseif isBuyer then
                myBuyerCount = myBuyerCount + 1
                print("|cFF00FFFF[Buyer]|r ID: " .. auction.id .. ", Status: " .. (auction.status or "nil") .. ", Owner: " .. (auction.owner or "none") .. ", ItemID: " .. (auction.itemID or "nil"))
            end
        end
        
        print("|cFFFFFF00[Summary]|r You are seller in " .. mySellerCount .. " auctions, buyer in " .. myBuyerCount .. " auctions")
        print("|cFFFFFF00[Summary]|r Total pending_trade auctions: " .. pendingTradeCount)
        print("|cFFFFFF00[Info]|r Use /testbuy <otherPlayerName> to create a test auction")
    end
    
    -- Debug command to create a test auction and buy it
    SLASH_TESTBUY1 = "/testbuy"
    SlashCmdList["TESTBUY"] = function(targetPlayer)
        if not targetPlayer or targetPlayer == "" then
            print("|cFFFF0000Usage:|r /testbuy <otherPlayerName>")
            print("This will create a test auction as the other player and buy it as you")
            return
        end
        
        local me = UnitName("player")
        local API = ns.AuctionHouseAPI
        
        -- Create a test auction as the target player
        local testAuction = {
            id = "TEST_" .. time(),
            owner = targetPlayer,
            buyer = nil,
            itemID = 2589, -- Linen Cloth
            quantity = 5,
            price = 100, -- 1 silver
            status = ns.AUCTION_STATUS_ACTIVE,
            createdAt = time(),
            rev = 1,
            deliveryType = ns.DELIVERY_TYPE_TRADE
        }
        
        -- Add to database
        API:UpdateDB({auction = testAuction})
        print("|cFF00FF00[Test]|r Created test auction: " .. testAuction.id .. " owned by " .. targetPlayer)
        
        -- Now "buy" it as current player
        testAuction.buyer = me
        testAuction.status = ns.AUCTION_STATUS_PENDING_TRADE
        testAuction.rev = 2
        API:UpdateDB({auction = testAuction})
        
        print("|cFF00FF00[Test]|r You bought the test auction. It's now pending_trade.")
        print("|cFF00FF00[Test]|r Try trading with " .. targetPlayer .. " to test auto-fill")
    end
    
    -- Removed /tm command due to Classic API compatibility issues
    -- The Trade Amount window shows the required amount visually instead

    -- Create a separate frame for secure trade operations
    self.tradeFrame = CreateFrame("Frame")
    self.tradeFrame:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SHOW" then
            local targetName = UnitName("NPC")
            if targetName then
                -- Increased delay to ensure UI is ready
                C_Timer.After(0.8, function()
                    self:TryPrefillTradeWindow(targetName)
                end)
            end
        end
    end)
    self.tradeFrame:RegisterEvent("TRADE_SHOW")
end

local function CreateNewTrade()
    return {
        tradeId = nil,
        playerName = UnitName("player"),
        targetName = nil,
        playerMoney = 0,
        targetMoney = 0,
        playerItems = {},
        targetItems = {},
    }
end

CURRENT_TRADE = nil

local function CurrentTrade()
    if (not CURRENT_TRADE) then
        CURRENT_TRADE = CreateNewTrade()
    end
    return CURRENT_TRADE
end

local function Reset(source)
    ns.DebugLog("[DEBUG] Reset Trade " .. (source or ""))
    CURRENT_TRADE = nil
end

-- this function leaks memory on cache miss because of CreateFrame
--
-- we have to use though, because Item:CreateItemFromItemID doesn't work here (we have a name, not itemID)
-- not called often (on trade when someone puts in a previously unknown item), so should be fine
local function GetItemInfoAsyncWithMemoryLeak(itemName, callback)
    local name = GetItemInfo(itemName)
    if name then
        callback(GetItemInfo(itemName))
    else
        local frame = CreateFrame("FRAME")
        frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        frame:SetScript("OnEvent", function(self, event, ...)
            callback(GetItemInfo(itemName))
            self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        end)
    end
end

local function UpdateItemInfo(id, unit, items)
    local funcInfo = getglobal("GetTrade" .. unit .. "ItemInfo")

    local name, texture, numItems, quality, isUsable, enchantment
    if (unit == "Target") then
        name, texture, numItems, quality, isUsable, enchantment = funcInfo(id)
    else
        name, texture, numItems, quality, enchantment = funcInfo(id)
    end

    if (not name) then
        items[id] = nil
        return
    end

    -- GetTradePlayerItemInfo annoyingly doesn't return the itemID, and there's not obvious way to get the itemID from a trade
    -- in most cases itemID will be available instantly, so race conditions shouldn't be too common
    GetItemInfoAsyncWithMemoryLeak(name, function (_, itemLink)
        local itemID = tonumber(itemLink:match("item:(%d+):"))

        items[id] = {
            itemID = itemID,
            name = name,
            numItems = numItems,
        }
    end)
end

local function UpdateMoney()
    CurrentTrade().playerMoney = GetPlayerTradeMoney()
    CurrentTrade().targetMoney = GetTargetTradeMoney()
end

local function HandleTradeOK()
    local t = CurrentTrade()

    -- Get the items that were traded
    --
    -- both the buyer and seller mark the trade as 'complete',
    -- they always should come to the same conclusion (so conflicting network updates shouldn't arise)
    local playerItems = {}
    local targetItems = {}
    for _, item in pairs(t.playerItems) do
        table.insert(playerItems, {
            itemID = item.itemID,
            count = item.numItems
        })
    end
    for _, item in pairs(t.targetItems) do
        table.insert(targetItems, {
            itemID = item.itemID,
            count = item.numItems
        })
    end

    if #playerItems == 0 and #targetItems == 0 then
        -- insert gold as fake item only if no other items are being traded
        if t.playerMoney then
            table.insert(playerItems, {
                itemID = ns.ITEM_ID_GOLD,
                count = t.playerMoney
            })
        end
        if t.targetMoney then
            table.insert(targetItems, {
                itemID = ns.ITEM_ID_GOLD,
                count = t.targetMoney
            })
        end
    end

    -- Debug prints for items
    for i, item in pairs(t.playerItems) do
        ns.DebugLog("[DEBUG] HandleTradeOK Player Item", i, ":", item.itemID, "x", item.numItems)
    end
    for i, item in pairs(t.targetItems) do
        ns.DebugLog("[DEBUG] HandleTradeOK Target Item", i, ":", item.itemID, "x", item.numItems)
    end
    ns.DebugLog(
        "[DEBUG] HandleTradeOK",
        t.playerName, t.targetName,
        t.playerMoney, t.targetMoney,
        #playerItems, #targetItems
    )

    local function tryMatch(seller, buyer, items, money)
        local success, hadCandidates, err, trade = ns.AuctionHouseAPI:TryCompleteItemTransfer(
            seller,
            buyer,
            items,
            money,
            ns.DELIVERY_TYPE_TRADE
        )

        if success and trade then
            StaticPopup_Show("OF_LEAVE_REVIEW", nil, nil, { tradeID = trade.id })
            return true, nil
        elseif err and hadCandidates then
            local itemInfo = ""
            if playerItems[1] then
                itemInfo = itemInfo .. " (Player: " .. playerItems[1].itemID .. " x" .. playerItems[1].count .. ")"
            end
            if targetItems[1] then
                itemInfo = itemInfo .. " (Target: " .. targetItems[1].itemID .. " x" .. targetItems[1].count .. ")"
            end

            local msg
            if err == "No matching auction found" then
                msg = " Trade didn't match any guild auctions" .. itemInfo
            else
                msg = " Trade didn't match any guild auctions: " .. err .. itemInfo
            end

            return false, msg
        end
        return false
    end

    -- Try first direction (target as seller)
    local success, message1 = tryMatch(t.targetName, t.playerName, targetItems, t.playerMoney or 0)
    local message2

    -- If first attempt failed, try reverse direction
    if not success then
        _, message2 = tryMatch(t.playerName, t.targetName, playerItems, t.targetMoney or 0)
    end

    -- Print message if we got one
    if message1 then
        print(ChatPrefix() .. message1)
    elseif message2 then
        print(ChatPrefix() .. message2)
    end
    Reset("HandleTradeOK")
end

-- Single event handler function
function TradeAPI:OnEvent(event, ...)
    if event == "MAIL_SHOW" then
        -- print("[DEBUG] MAIL_SHOW")

    elseif event == "MAIL_CLOSED" then
        -- print("[DEBUG] MAIL_CLOSED")

    elseif event == "UI_ERROR_MESSAGE" then
        local _, arg2 = ...
        if (arg2 == ERR_TRADE_BAG_FULL or
            arg2 == ERR_TRADE_TARGET_BAG_FULL or
            arg2 == ERR_TRADE_MAX_COUNT_EXCEEDED or
            arg2 == ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED or
            arg2 == ERR_TRADE_TARGET_DEAD or
            arg2 == ERR_TRADE_TOO_FAR) then
            -- print("[DEBUG] Trade failed")
            Reset("trade failed "..arg2)  -- trade failed
        end

    elseif event == "UI_INFO_MESSAGE" then
        local _, arg2 = ...
        if (arg2 == ERR_TRADE_CANCELLED) then
            -- print("[DEBUG] Trade cancelled")
            Reset("trade cancelled")
            -- Hide the trade info frame if it exists
            if TradeAPI.tradeInfoFrame then
                TradeAPI.tradeInfoFrame:Hide()
            end
        elseif (arg2 == ERR_TRADE_COMPLETE) then
            HandleTradeOK()
            -- Hide the trade info frame if it exists
            if TradeAPI.tradeInfoFrame then
                TradeAPI.tradeInfoFrame:Hide()
            end
        end

    elseif event == "TRADE_SHOW" then
        CurrentTrade().targetName = UnitName("NPC")

    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        local arg1 = ...
        UpdateItemInfo(arg1, "Player", CurrentTrade().playerItems)
        ns.DebugLog("[DEBUG] Player ITEM_CHANGED", arg1)

    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        local arg1 = ...
        UpdateItemInfo(arg1, "Target", CurrentTrade().targetItems)
        ns.DebugLog("[DEBUG] Target ITEM_CHANGED", arg1)

    elseif event == "TRADE_MONEY_CHANGED" then
        UpdateMoney()
        -- print("[DEBUG] TRADE_MONEY_CHANGED")

    elseif event == "TRADE_ACCEPT_UPDATE" then
        for i = 1, 7 do
            UpdateItemInfo(i, "Player", CurrentTrade().playerItems)
            UpdateItemInfo(i, "Target", CurrentTrade().targetItems)
        end
        UpdateMoney()
        -- print("[DEBUG] TRADE_ACCEPT_UPDATE")
    end
end

-- Helper function to compare names (handles realm names)
local function namesMatch(name1, name2)
    if not name1 or not name2 then return false end
    
    -- Direct match
    if name1 == name2 then return true end
    
    -- Strip realm names and compare
    local short1 = string.match(name1, "^([^-]+)") or name1
    local short2 = string.match(name2, "^([^-]+)") or name2
    
    return short1 == short2
end

-- findMatchingAuction picks the last-created auction that involves 'me' and targetName
-- we pick the last-created auction so both parties agree on which one should be prefilled
local function findMatchingAuction(myPendingAsSeller, myPendingAsBuyer, targetName)
    local bestMatch = nil
    local isSeller = false

    -- Check if I'm the seller and the partner is the buyer
    for _, auction in ipairs(myPendingAsSeller) do
        if namesMatch(auction.buyer, targetName) then
            if not bestMatch or auction.createdAt > bestMatch.createdAt then
                bestMatch = auction
                isSeller = true
            end
        end
    end

    -- Check if I'm the buyer and the partner is the seller
    for _, auction in ipairs(myPendingAsBuyer) do
        if namesMatch(auction.owner, targetName) then
            if not bestMatch or auction.createdAt > bestMatch.createdAt then
                bestMatch = auction
                isSeller = false
            end
        end
    end

    return bestMatch, isSeller
end

-- Helper function to find ALL stacks of an item with exact quantity
-- Must be defined before use
local function FindAllItemStacksInBags(itemID, quantity)
    local stacks = {}
    
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local count = itemInfo.stackCount
                local link = itemInfo.hyperlink
                local bagItemID = tonumber(link:match("item:(%d+):"))
                
                if bagItemID == itemID and count == quantity then
                    table.insert(stacks, {bag = bag, slot = slot, count = count})
                end
            end
        end
    end
    
    return stacks
end

function TradeAPI:ShowTradeAmountWindow(auctions)
    -- Create or update the trade amount window with itemized list
    C_Timer.After(0.2, function()
        -- Hide old frame if exists
        if TradeAPI.tradeInfoFrame then
            TradeAPI.tradeInfoFrame:Hide()
        end
        
        -- Create new frame
        TradeAPI.tradeInfoFrame = CreateFrame("Frame", "ConcedeAHTradeInfo", TradeFrame)
        
        -- Calculate frame height based on number of items
        local frameHeight = 60 + (#auctions * 18) + 30 -- Header + items + total line
        TradeAPI.tradeInfoFrame:SetSize(250, frameHeight)
        TradeAPI.tradeInfoFrame:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 5, -30)
        
        -- Create background texture
        local bg = TradeAPI.tradeInfoFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.8)
        
        -- Header "Trade Amount"
        TradeAPI.tradeInfoFrame.header = TradeAPI.tradeInfoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        TradeAPI.tradeInfoFrame.header:SetPoint("TOP", 0, -10)
        TradeAPI.tradeInfoFrame.header:SetText("Trade Amount")
        TradeAPI.tradeInfoFrame.header:SetTextColor(1, 1, 0) -- Yellow
        
        -- Item list
        local yOffset = -30
        local totalAmount = 0
        
        for i, auction in ipairs(auctions) do
            local itemLine = TradeAPI.tradeInfoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itemLine:SetPoint("TOPLEFT", 10, yOffset)
            itemLine:SetPoint("TOPRIGHT", -10, yOffset)
            itemLine:SetJustifyH("LEFT")
            
            local itemName, itemLink = ns.GetItemInfo(auction.itemID, auction.quantity)
            local price = (auction.price or 0) + (auction.tip or 0)
            totalAmount = totalAmount + price
            
            if auction.itemID == ns.ITEM_ID_GOLD then
                itemLine:SetText(GetCoinTextureString(auction.quantity or price))
            else
                local qty = auction.quantity or 1
                itemLine:SetText(qty .. "x " .. (itemLink or itemName or "Unknown") .. " - " .. GetCoinTextureString(price))
            end
            
            yOffset = yOffset - 18
        end
        
        -- Separator line
        local separator = TradeAPI.tradeInfoFrame:CreateTexture(nil, "OVERLAY")
        separator:SetPoint("LEFT", 10, yOffset - 5)
        separator:SetPoint("RIGHT", -10, yOffset - 5)
        separator:SetHeight(1)
        separator:SetColorTexture(1, 1, 1, 0.3)
        
        -- Total amount
        local totalLine = TradeAPI.tradeInfoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        totalLine:SetPoint("TOPLEFT", 10, yOffset - 10)
        totalLine:SetPoint("TOPRIGHT", -10, yOffset - 10)
        totalLine:SetJustifyH("LEFT")
        totalLine:SetText("Total: " .. GetCoinTextureString(totalAmount))
        totalLine:SetTextColor(0, 1, 0) -- Green
        
        TradeAPI.tradeInfoFrame:Show()
    end)
end

function TradeAPI:PrefillGold(relevantAuction, totalPrice, targetName, iAmSeller)
    -- Legacy function - convert to new format
    if iAmSeller then
        -- Selling gold
        local auction = {
            itemID = ns.ITEM_ID_GOLD,
            quantity = totalPrice,
            price = 0
        }
        self:PrefillMultipleItems({auction}, targetName)
    else
        -- Buying - show the amount
        local auction = {
            itemID = relevantAuction.itemID,
            quantity = relevantAuction.quantity,
            price = totalPrice
        }
        self:PrefillBuyerGold({auction}, targetName)
    end
end

function TradeAPI:PrefillMultipleItems(auctions, targetName)
    -- I'm the seller: prefill trade with multiple items
    local itemsPlaced = 0
    local maxTradeSlots = 6 -- WoW Classic has 6 trade slots (7th is for non-stackable)
    
    -- Show trade amount window with all items
    self:ShowTradeAmountWindow(auctions)
    
    -- Group auctions by itemID and quantity to find matching stacks
    local stacksNeeded = {}
    for _, auction in ipairs(auctions) do
        if auction.itemID ~= ns.ITEM_ID_GOLD then
            local key = auction.itemID .. "_" .. (auction.quantity or 1)
            if not stacksNeeded[key] then
                stacksNeeded[key] = {
                    itemID = auction.itemID,
                    quantity = auction.quantity or 1,
                    auctions = {}
                }
            end
            table.insert(stacksNeeded[key].auctions, auction)
        end
    end
    
    -- Try to place each stack group in trade
    for _, stackInfo in pairs(stacksNeeded) do
        local itemID = stackInfo.itemID
        local quantity = stackInfo.quantity
        local numStacksNeeded = #stackInfo.auctions
        
        -- Find all matching stacks in bags
        local availableStacks = FindAllItemStacksInBags(itemID, quantity)
        
        if #availableStacks < numStacksNeeded then
            local itemName = select(2, ns.GetItemInfo(itemID)) or "item"
            print(ChatPrefixError() .. " Need " .. numStacksNeeded .. " stack(s) of " .. quantity .. "x " .. itemName .. " but only found " .. #availableStacks)
        end
        
        -- Place as many stacks as possible
        local stacksToPlace = math.min(numStacksNeeded, #availableStacks)
        for i = 1, stacksToPlace do
            if itemsPlaced >= maxTradeSlots then
                print(ChatPrefixError() .. " Trade window full! Could not add all items. Please complete this trade and trade again for remaining items.")
                break
            end
            
            local stack = availableStacks[i]
            C_Container.PickupContainerItem(stack.bag, stack.slot)
            ClickTradeButton(itemsPlaced + 1)
            itemsPlaced = itemsPlaced + 1
            
            local name, itemLink = ns.GetItemInfo(itemID, quantity)
            print(ChatPrefix() .. " Added " .. quantity .. "x " .. (itemLink or name or "item"))
        end
    end
    
    if itemsPlaced > 0 then
        print(ChatPrefix() .. " Added " .. itemsPlaced .. " stack(s) to trade for " .. targetName)
    end
end

function TradeAPI:PrefillBuyerGold(auctions, targetName)
    -- I'm the buyer: show all items I'm buying and the total gold to trade
    
    -- Show trade amount window with all items
    self:ShowTradeAmountWindow(auctions)
    
    -- Calculate total gold needed
    local totalGold = 0
    for _, auction in ipairs(auctions) do
        local price = (auction.price or 0) + (auction.tip or 0)
        totalGold = totalGold + price
    end
    
    -- Check if player has enough gold
    local playerMoney = GetMoney()
    if playerMoney >= totalGold then
        print(ChatPrefix() .. " Trade " .. GetCoinTextureString(totalGold) .. " for " .. #auctions .. " item(s) from " .. targetName)
    else
        print(ChatPrefixError() .. " You need " .. GetCoinTextureString(totalGold) .. " but only have " .. GetCoinTextureString(playerMoney))
    end
end

function TradeAPI:PrefillItem(itemID, quantity, targetName, totalPrice)
    -- Legacy single item function - now calls multiple items with single auction
    local auction = {
        itemID = itemID,
        quantity = quantity,
        price = totalPrice
    }
    self:PrefillMultipleItems({auction}, targetName)
end

-- Keep the original single-item helper function
function TradeAPI:PrefillItemOld(itemID, quantity, targetName, totalPrice)
    -- I'm the owner: prefill trade with the item
    
    -- Show trade amount window for seller (buyer's expected payment)
    if totalPrice and totalPrice > 0 then
        self:ShowTradeAmountWindow({{itemID = itemID, quantity = quantity, price = totalPrice}})
    end
    
    -- Use new helper function to find the item
    local bag, slot, exactMatch = self:FindBestMatchForTrade(itemID, quantity)
    
    if not slot then
        -- Item not found in bags at all
        local itemName = select(2, ns.GetItemInfo(itemID)) or "item"
        print(ChatPrefixError() .. " Item not found: " .. quantity .. "x " .. itemName .. " is not in your bags!")
        return
    end
    
    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
    local stackCount = itemInfo and itemInfo.stackCount or 0
    
    ns.DebugLog("[DEBUG] PrefillItem: Found stack of", stackCount, "need", quantity, "exactMatch:", exactMatch)
    
    if exactMatch then
        -- Exact match found, pick it up and place in trade
        C_Container.PickupContainerItem(bag, slot)
        ClickTradeButton(1)
        
        -- Success message
        local name, itemLink = ns.GetItemInfo(itemID, quantity)
        local itemDescription
        if itemID == ns.ITEM_ID_GOLD then
            itemDescription = name
        else
            itemLink = itemLink or "item"
            itemDescription = quantity .. "x " .. itemLink
        end
        print(ChatPrefix() .. " Auto-filled trade with " .. itemDescription .. " for auction to " .. targetName)
    else
        -- No exact match - show error message
        local itemName = select(2, ns.GetItemInfo(itemID)) or "item"
        
        if stackCount > quantity then
            -- Stack is larger than needed
            print(ChatPrefixError() .. " Wrong stack size: You have a stack of " .. stackCount .. 
                  " but need exactly " .. quantity .. "x " .. itemName .. 
                  ". Please split the stack manually to " .. quantity .. " items.")
        elseif stackCount < quantity then
            -- Stack is smaller than needed (shouldn't happen with our search logic)
            print(ChatPrefixError() .. " Not enough items: You have " .. stackCount .. 
                  " but need " .. quantity .. "x " .. itemName .. ".")
        end
    end
end

function TradeAPI:TryPrefillTradeWindow(targetName)
    if not targetName or targetName == "" then
        return
    end

    local me = UnitName("player")
    -- Strip realm name if present for local comparisons
    local meShort = string.match(me, "^([^-]+)") or me
    
    if me == targetName or meShort == targetName then
        -- Trading with self, exit silently
        return
    end

    local AuctionHouseAPI = ns.AuctionHouseAPI

    -- 1. Gather potential auctions where I'm the seller or the buyer and the status is pending trade
    -- Try both with and without realm name
    local myPendingAsSeller = AuctionHouseAPI:GetAuctionsWithOwnerAndStatus(me, { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN })
    local myPendingAsBuyer  = AuctionHouseAPI:GetAuctionsWithBuyerAndStatus(me, { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN })
    
    -- Also try with short name if different
    if meShort ~= me then
        local shortSeller = AuctionHouseAPI:GetAuctionsWithOwnerAndStatus(meShort, { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN })
        local shortBuyer = AuctionHouseAPI:GetAuctionsWithBuyerAndStatus(meShort, { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN })
        
        -- Merge results
        for _, auction in ipairs(shortSeller) do
            table.insert(myPendingAsSeller, auction)
        end
        for _, auction in ipairs(shortBuyer) do
            table.insert(myPendingAsBuyer, auction)
        end
    end
    
    -- Only show debug if no auctions found
    if #myPendingAsSeller == 0 and #myPendingAsBuyer == 0 then
        print("|cFFFFFF00[Trade]|r No pending auctions found for player " .. me)
        print("|cFFFFFF00[Trade]|r Use /checkauctions to see all your auctions")
    end
    
    -- Debug: Show details of auctions
    for _, auction in ipairs(myPendingAsSeller) do
        ns.DebugLog("[DEBUG] Seller auction: ID =", auction.id, "Status =", auction.status, "Buyer =", auction.buyer)
    end
    for _, auction in ipairs(myPendingAsBuyer) do
        ns.DebugLog("[DEBUG] Buyer auction: ID =", auction.id, "Status =", auction.status, "Owner =", auction.owner)
    end

    local function filterAuctions(auctions)
        local filtered = {}
        for _, auction in ipairs(auctions) do
            -- Filter out mail delivery auctions and death roll (we don't prefill those)
            local deliveryMatch = auction.deliveryType ~= ns.DELIVERY_TYPE_MAIL
            local excluded = auction.deathRoll or auction.duel

            if deliveryMatch and not excluded then
                table.insert(filtered, auction)
            end
        end
        return filtered
    end

    -- Apply filters
    myPendingAsSeller = filterAuctions(myPendingAsSeller)
    myPendingAsBuyer = filterAuctions(myPendingAsBuyer)

    -- 2. Find ALL auctions that match the current trade partner
    local matchingAuctionsAsSeller = {}
    local matchingAuctionsAsBuyer = {}
    
    -- Collect all matching auctions where I'm the seller
    for _, auction in ipairs(myPendingAsSeller) do
        if namesMatch(auction.buyer, targetName) then
            table.insert(matchingAuctionsAsSeller, auction)
        end
    end
    
    -- Collect all matching auctions where I'm the buyer
    for _, auction in ipairs(myPendingAsBuyer) do
        if namesMatch(auction.owner, targetName) then
            table.insert(matchingAuctionsAsBuyer, auction)
        end
    end
    
    -- Determine if we're seller or buyer based on which list has items
    local matchingAuctions = {}
    local isSeller = false
    
    if #matchingAuctionsAsSeller > 0 then
        matchingAuctions = matchingAuctionsAsSeller
        isSeller = true
    elseif #matchingAuctionsAsBuyer > 0 then
        matchingAuctions = matchingAuctionsAsBuyer
        isSeller = false
    else
        -- No matching auctions - exit silently
        return
    end
    
    print(ChatPrefix() .. " Found " .. #matchingAuctions .. " pending auction(s) with " .. targetName)
    
    if isSeller then
        -- I'm the seller - prefill items and show total price expected
        self:PrefillMultipleItems(matchingAuctions, targetName)
    else
        -- I'm the buyer - show all items and total price to pay
        self:PrefillBuyerGold(matchingAuctions, targetName)
    end
end

local function FindItemInBags(itemID, quantity, matchQuantityExact)
    local bestMatch = {
        bag = nil,
        slot = nil,
        count = 0
    }

    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local count = itemInfo.stackCount
                local link = itemInfo.hyperlink
                local bagItemID = tonumber(link:match("item:(%d+):"))

                if bagItemID == itemID then
                    if matchQuantityExact then
                        if count == quantity then
                            return bag, slot
                        end
                    else
                        -- Find the stack that's closest to (but not less than) the desired quantity
                        if count >= quantity and (bestMatch.count == 0 or count < bestMatch.count) then
                            bestMatch.bag = bag
                            bestMatch.slot = slot
                            bestMatch.count = count
                        end
                    end
                end
            end
        end
    end

    return bestMatch.bag, bestMatch.slot
end

function TradeAPI:FindBestMatchForTrade(itemID, quantity)
    -- First try to find an exact quantity match
    local bag, slot = FindItemInBags(itemID, quantity, true)

    if slot then
        -- Exact match found
        return bag, slot, true
    end

    -- Look for any stack large enough
    bag, slot = FindItemInBags(itemID, quantity, false)

    -- Return bag, slot, and false to indicate inexact match
    return bag, slot, false
end
