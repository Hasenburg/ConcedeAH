-- Mock Data Provider for Testing
local addonName, ns = ...

-- Initialize mock functions (always for testing)
local function InitializeMockData()
    
    -- Generate test items
    local testItems = {
        {id = 6948, name = "Hearthstone", quality = 1, level = 1, icon = "Interface\\Icons\\INV_Misc_Hearthstone_01"},
        {id = 2589, name = "Linen Cloth", quality = 1, level = 5, icon = "Interface\\Icons\\INV_Fabric_Linen_01"},
        {id = 2771, name = "Tin Ore", quality = 1, level = 10, icon = "Interface\\Icons\\INV_Ore_Tin_01"},
        {id = 858, name = "Lesser Healing Potion", quality = 1, level = 3, icon = "Interface\\Icons\\INV_Potion_49"},
        {id = 4306, name = "Silk Cloth", quality = 1, level = 20, icon = "Interface\\Icons\\INV_Fabric_Silk_01"},
        {id = 2840, name = "Copper Bar", quality = 1, level = 5, icon = "Interface\\Icons\\INV_Ingot_02"},
        {id = 2318, name = "Light Leather", quality = 1, level = 10, icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03"},
        {id = 774, name = "Malachite", quality = 2, level = 7, icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_03"},
        {id = 818, name = "Tigerseye", quality = 2, level = 15, icon = "Interface\\Icons\\INV_Misc_Gem_Opal_03"},
        {id = 929, name = "Healing Potion", quality = 1, level = 12, icon = "Interface\\Icons\\INV_Potion_51"},
        {id = 3356, name = "Kingsblood", quality = 1, level = 24, icon = "Interface\\Icons\\INV_Misc_Herb_03"},
        {id = 2447, name = "Peacebloom", quality = 1, level = 5, icon = "Interface\\Icons\\INV_Misc_Flower_02"},
        {id = 765, name = "Silverleaf", quality = 1, level = 5, icon = "Interface\\Icons\\INV_Misc_Herb_10"},
        {id = 2449, name = "Earthroot", quality = 1, level = 10, icon = "Interface\\Icons\\INV_Misc_Herb_07"},
        {id = 2450, name = "Briarthorn", quality = 1, level = 15, icon = "Interface\\Icons\\INV_Misc_Root_01"},
        {id = 3820, name = "Stranglekelp", quality = 1, level = 15, icon = "Interface\\Icons\\INV_Misc_Herb_11"},
        {id = 6359, name = "Firefin Snapper", quality = 1, level = 10, icon = "Interface\\Icons\\INV_Misc_Fish_22"},
        {id = 4603, name = "Raw Spotted Yellowtail", quality = 1, level = 25, icon = "Interface\\Icons\\INV_Misc_Fish_01"},
        {id = 2672, name = "Stringy Wolf Meat", quality = 1, level = 5, icon = "Interface\\Icons\\INV_Misc_Food_14"},
        {id = 3173, name = "Bear Meat", quality = 1, level = 15, icon = "Interface\\Icons\\INV_Misc_Food_14"},
        {id = 4234, name = "Heavy Leather", quality = 1, level = 20, icon = "Interface\\Icons\\INV_Misc_LeatherScrap_05"},
        {id = 4304, name = "Thick Leather", quality = 1, level = 30, icon = "Interface\\Icons\\INV_Misc_LeatherScrap_08"},
        {id = 2997, name = "Bolt of Woolen Cloth", quality = 1, level = 15, icon = "Interface\\Icons\\INV_Fabric_Wool_03"},
        {id = 4305, name = "Bolt of Silk Cloth", quality = 1, level = 25, icon = "Interface\\Icons\\INV_Fabric_Silk_03"},
        {id = 5498, name = "Small Lustrous Pearl", quality = 2, level = 15, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_03"},
        {id = 5500, name = "Iridescent Pearl", quality = 2, level = 25, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_02"},
        {id = 3575, name = "Iron Bar", quality = 1, level = 15, icon = "Interface\\Icons\\INV_Ingot_04"},
        {id = 3860, name = "Mithril Bar", quality = 1, level = 30, icon = "Interface\\Icons\\INV_Ingot_06"},
        {id = 2772, name = "Iron Ore", quality = 1, level = 15, icon = "Interface\\Icons\\INV_Ore_Iron_01"},
        {id = 3858, name = "Mithril Ore", quality = 1, level = 30, icon = "Interface\\Icons\\INV_Ore_Mithril_02"},
    }
    
    local playerNames = {"Asmongold", "Esfand", "Staysafe", "TipsOut", "Venruki", 
                         "Payo", "Cdew", "Soda", "Xaryu", "Savix"}
    
    -- Mock GetBrowseAuctions
    ns.GetBrowseAuctions = function(params)
        local auctions = {}
        for i = 1, 50 do
            local item = testItems[((i-1) % #testItems) + 1]
            local auction = {
                id = "mock_" .. i,
                itemID = item.id,
                itemName = item.name,
                itemLink = string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                    item.quality == 2 and "1eff00" or "ffffff", item.id, item.name),
                quality = item.quality,
                level = item.level,
                texture = item.icon,
                owner = playerNames[((i-1) % #playerNames) + 1],
                price = math.random(100, 50000),
                buyoutPrice = math.random(100, 50000),
                quantity = math.random(1, 20),
                count = math.random(1, 20),
                timeLeft = math.random(1, 4),
                isRequest = false
            }
            table.insert(auctions, auction)
        end
        return auctions
    end
    
    -- Mock GetMyActiveAuctions
    ns.GetMyActiveAuctions = function(params)
        local auctions = {}
        for i = 1, 10 do
            local item = testItems[((i-1) % #testItems) + 1]
            local auction = {
                id = "myauction_" .. i,
                itemID = item.id,
                itemName = item.name,
                itemLink = string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                    item.quality == 2 and "1eff00" or "ffffff", item.id, item.name),
                quality = item.quality,
                level = item.level,
                texture = item.icon,
                owner = UnitName("player") or "TestPlayer",
                highBidder = i % 3 == 0 and playerNames[((i-1) % #playerNames) + 1] or nil,
                price = math.random(100, 50000),
                buyoutPrice = math.random(100, 50000),
                quantity = math.random(1, 20),
                count = math.random(1, 20),
                timeLeft = math.random(1, 4),
                status = i % 3 == 0 and "Sold" or "Active",
                isRequest = i % 4 == 0
            }
            table.insert(auctions, auction)
        end
        return auctions
    end
    
    -- Mock GetMyPendingAuctions
    ns.GetMyPendingAuctions = function(params)
        local auctions = {}
        for i = 1, 5 do
            local item = testItems[((i-1) % #testItems) + 1]
            local auction = {
                id = "pending_" .. i,
                itemID = item.id,
                itemName = item.name,
                itemLink = string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                    item.quality == 2 and "1eff00" or "ffffff", item.id, item.name),
                quality = item.quality,
                level = item.level,
                texture = item.icon,
                owner = UnitName("player") or "TestPlayer",
                buyer = playerNames[((i-1) % #playerNames) + 1],
                price = math.random(100, 50000),
                buyoutPrice = math.random(100, 50000),
                quantity = math.random(1, 20),
                count = math.random(1, 20),
                timeLeft = math.random(1, 4),
                status = "Pending",
                isRequest = false
            }
            table.insert(auctions, auction)
        end
        return auctions
    end
    
    -- Mock GetItemInfo
    if not ns.GetItemInfo then
        local itemLookup = {}
        for _, item in ipairs(testItems) do
            itemLookup[item.id] = item
        end
        
        ns.GetItemInfo = function(itemID, quantity)
            local item = itemLookup[itemID]
            if item then
                -- Return format: name, link, quality, level, minLevel, type, subType, stackCount, equipLoc, texture, sellPrice
                return item.name, 
                       string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                           item.quality == 2 and "1eff00" or "ffffff", itemID, item.name),
                       item.quality,
                       item.level,
                       item.level,
                       "Trade Goods",
                       "Trade Goods",
                       20,
                       "",
                       item.icon,
                       100
            end
            -- Try default GetItemInfo if available
            if GetItemInfo then
                return GetItemInfo(itemID)
            end
            return nil
        end
    end
    
    -- Mock GetItemInfoAsync
    if not ns.GetItemInfoAsync then
        ns.GetItemInfoAsync = function(itemID, callback)
            -- Call callback immediately with mock data
            if callback then
                local result = {ns.GetItemInfo(itemID)}
                if result[1] then
                    callback(unpack(result))
                end
            end
        end
    end
    
    -- Mock SortAuctions
    if not ns.SortAuctions then
        ns.SortAuctions = function(auctions, sortParams)
            -- Simple sort by price
            if auctions and #auctions > 0 then
                table.sort(auctions, function(a, b)
                    return (a.price or 0) < (b.price or 0)
                end)
            end
            return auctions
        end
    end
    
    -- Mock IsDefaultBrowseParams
    if not ns.IsDefaultBrowseParams then
        ns.IsDefaultBrowseParams = function(params)
            return params == nil or next(params) == nil
        end
    end
    
    -- Mock BrowseParamsToItemDBArgs
    if not ns.BrowseParamsToItemDBArgs then
        ns.BrowseParamsToItemDBArgs = function(params)
            return params or {}
        end
    end
    
    -- Mock ItemDB
    if not ns.ItemDB then
        ns.ItemDB = {
            Find = function(self, args)
                -- Return empty for now
                return {}
            end
        }
    end
    
    -- Define price types if not defined
    if not ns.PRICE_TYPE_MONEY then
        ns.PRICE_TYPE_MONEY = 1
    end
    if not ns.PRICE_TYPE_TWITCH_RAID then
        ns.PRICE_TYPE_TWITCH_RAID = 2
    end
    
    print("|cFF00FF00Mock Data Provider loaded - Test data is now available|r")
end

-- Initialize mock data if needed
if not ns.GetBrowseAuctions then
    InitializeMockData()
end