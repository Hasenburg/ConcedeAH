local _, ns = ...

-- ====================================
-- Item Default Prices Configuration
-- ====================================
-- Configure default prices for specific items when creating offers
-- Prices are in copper (1 gold = 10000 copper, 1 silver = 100 copper)
-- 
-- Format: [ItemID] = price_in_copper
-- 
-- Examples:
-- [6948] = 10000,  -- Hearthstone = 1 gold
-- [2589] = 50,     -- Linen Cloth = 50 copper
-- [2592] = 150,    -- Wool Cloth = 1 silver 50 copper
-- ====================================

ns.ItemDefaultPrices = {
    -- ==================
    -- Trade Goods - Cloth
    -- ==================
    [2589] = 50,        -- Linen Cloth
    [2592] = 150,       -- Wool Cloth
    [4306] = 400,       -- Silk Cloth
    [4338] = 1000,      -- Mageweave Cloth
    [14047] = 2000,     -- Runecloth
    [14256] = 5000,     -- Felcloth
    
    -- ==================
    -- Trade Goods - Leather
    -- ==================
    [2934] = 50,        -- Ruined Leather Scraps
    [2318] = 100,       -- Light Leather
    [2319] = 200,       -- Medium Leather
    [4234] = 400,       -- Heavy Leather
    [4304] = 800,       -- Thick Leather
    [8170] = 1500,      -- Rugged Leather
    
    -- ==================
    -- Trade Goods - Ore & Bars
    -- ==================
    [2770] = 100,       -- Copper Ore
    [2840] = 200,       -- Copper Bar
    [2771] = 300,       -- Tin Ore
    [3576] = 400,       -- Tin Bar
    [2775] = 500,       -- Silver Ore
    [2842] = 1000,      -- Silver Bar
    [2772] = 500,       -- Iron Ore
    [3575] = 600,       -- Iron Bar
    [3858] = 1500,      -- Mithril Ore
    [3860] = 2000,      -- Mithril Bar
    [10620] = 3000,     -- Thorium Ore
    [12359] = 4000,     -- Thorium Bar
    
    -- ==================
    -- Trade Goods - Herbs
    -- ==================
    [2447] = 50,        -- Peacebloom
    [765] = 50,         -- Silverleaf
    [2449] = 100,       -- Earthroot
    [785] = 150,        -- Mageroyal
    [2450] = 200,       -- Briarthorn
    [2452] = 300,       -- Swiftthistle
    [2453] = 250,       -- Bruiseweed
    [3355] = 400,       -- Wild Steelbloom
    [3356] = 500,       -- Kingsblood
    [3357] = 600,       -- Liferoot
    [3818] = 700,       -- Fadeleaf
    [3819] = 800,       -- Dragon's Teeth
    [3820] = 300,       -- Stranglekelp
    [3821] = 900,       -- Goldthorn
    [4625] = 1000,      -- Firebloom
    [8831] = 1200,      -- Purple Lotus
    [8836] = 1500,      -- Arthas' Tears
    [8838] = 1800,      -- Sungrass
    [8839] = 2000,      -- Blindweed
    [8845] = 2500,      -- Ghost Mushroom
    [8846] = 2200,      -- Gromsblood
    [13463] = 3000,     -- Dreamfoil
    [13464] = 3500,     -- Golden Sansam
    [13465] = 4000,     -- Mountain Silversage
    [13466] = 5000,     -- Plaguebloom
    [13467] = 5500,     -- Icecap
    [13468] = 10000,    -- Black Lotus
    
    -- ==================
    -- Consumables - Potions
    -- ==================
    [118] = 100,        -- Minor Healing Potion
    [858] = 200,        -- Lesser Healing Potion
    [929] = 500,        -- Healing Potion
    [1710] = 1000,      -- Greater Healing Potion
    [3928] = 2000,      -- Superior Healing Potion
    [13446] = 5000,     -- Major Healing Potion
    
    [2455] = 150,       -- Minor Mana Potion
    [3385] = 300,       -- Lesser Mana Potion
    [3827] = 600,       -- Mana Potion
    [6149] = 1200,      -- Greater Mana Potion
    [13443] = 2500,     -- Superior Mana Potion
    [13444] = 5000,     -- Major Mana Potion
    
    -- ==================
    -- Consumables - Elixirs & Flasks
    -- ==================
    [2454] = 200,       -- Elixir of Lion's Strength
    [3390] = 500,       -- Elixir of Lesser Agility
    [8949] = 1000,      -- Elixir of Agility
    [9187] = 2000,      -- Elixir of Greater Agility
    [13447] = 3000,     -- Elixir of the Sages
    [13453] = 3500,     -- Elixir of Brute Force
    [9088] = 5000,      -- Gift of Arthas
    [13452] = 4000,     -- Elixir of the Mongoose
    
    [13510] = 100000,   -- Flask of the Titans
    [13511] = 100000,   -- Flask of Distilled Wisdom
    [13512] = 100000,   -- Flask of Supreme Power
    [13513] = 100000,   -- Flask of Chromatic Resistance
    
    -- ==================
    -- Consumables - Food & Drink
    -- ==================
    [4536] = 100,       -- Shiny Red Apple
    [4540] = 200,       -- Tough Hunk of Bread
    [4541] = 300,       -- Freshly Baked Bread
    [4542] = 500,       -- Moist Cornbread
    [4544] = 800,       -- Mulgore Spice Bread
    [4601] = 1200,      -- Soft Banana Bread
    [8932] = 2000,      -- Alterac Swiss
    [8950] = 2500,      -- Homemade Cherry Pie
    
    -- ==================
    -- Enchanting Materials
    -- ==================
    [10940] = 100,      -- Strange Dust
    [10938] = 500,      -- Lesser Magic Essence
    [10939] = 1000,     -- Greater Magic Essence
    [10978] = 300,      -- Small Glimmering Shard
    [10998] = 500,      -- Lesser Astral Essence
    [11082] = 1000,     -- Greater Astral Essence
    [11083] = 300,      -- Soul Dust
    [11084] = 2000,     -- Large Glimmering Shard
    [11134] = 800,      -- Lesser Mystic Essence
    [11135] = 1600,     -- Greater Mystic Essence
    [11137] = 500,      -- Vision Dust
    [11138] = 3000,     -- Small Glowing Shard
    [11139] = 8000,     -- Large Glowing Shard
    [11174] = 1200,     -- Lesser Nether Essence
    [11175] = 2400,     -- Greater Nether Essence
    [11176] = 800,      -- Dream Dust
    [11177] = 5000,     -- Small Radiant Shard
    [11178] = 15000,    -- Large Radiant Shard
    [14343] = 10000,    -- Small Brilliant Shard
    [14344] = 30000,    -- Large Brilliant Shard
    [16202] = 2000,     -- Lesser Eternal Essence
    [16203] = 4000,     -- Greater Eternal Essence
    [16204] = 1500,     -- Illusion Dust
    
    -- ==================
    -- Gems
    -- ==================
    [774] = 500,        -- Malachite
    [818] = 800,        -- Tigerseye
    [1210] = 2000,      -- Shadowgem
    [1206] = 2500,      -- Moss Agate
    [1705] = 3000,      -- Lesser Moonstone
    [1529] = 5000,      -- Jade
    [3864] = 8000,      -- Citrine
    [7909] = 10000,     -- Aquamarine
    [7910] = 15000,     -- Star Ruby
    [12361] = 20000,    -- Blue Sapphire
    [12364] = 25000,    -- Huge Emerald
    [12799] = 30000,    -- Large Opal
    [12800] = 35000,    -- Azerothian Diamond
    
    -- ==================
    -- Elemental Materials
    -- ==================
    [7067] = 1000,      -- Elemental Earth
    [7068] = 1500,      -- Elemental Fire
    [7069] = 1200,      -- Elemental Air
    [7070] = 1800,      -- Elemental Water
    [7075] = 5000,      -- Core of Earth
    [7076] = 8000,      -- Essence of Earth
    [7077] = 6000,      -- Heart of Fire
    [7078] = 10000,     -- Essence of Fire
    [7079] = 7000,      -- Globe of Water
    [7080] = 12000,     -- Essence of Water
    [7081] = 5500,      -- Breath of Wind
    [7082] = 9000,      -- Essence of Air
    [12803] = 15000,    -- Living Essence
    [12808] = 20000,    -- Essence of Undeath
    
    -- ==================
    -- Raid Materials
    -- ==================
    [17010] = 5000,     -- Fiery Core
    [17011] = 5000,     -- Lava Core
    [17012] = 50000,    -- Core Leather
    [17203] = 100000,   -- Sulfuron Ingot
    [17204] = 200000,   -- Eye of Sulfuras
    
    [19774] = 10000,    -- Souldarite
    [19726] = 50000,    -- Elementium Bar
    
    -- ==================
    -- Special Items
    -- ==================
    [18562] = 500000,   -- Elementium Ore (Black Market item)
    [19019] = 1000000,  -- Thunderfury, Blessed Blade of the Windseeker (Legendary)
    
    -- ==================
    -- Add your custom prices below
    -- ==================
    
}

-- Function to get default price for an item
function ns.GetItemDefaultPrice(itemID)
    if not itemID then return nil end
    return ns.ItemDefaultPrices[itemID]
end

-- Function to set/update default price for an item
function ns.SetItemDefaultPrice(itemID, price)
    if not itemID or not price then return false end
    ns.ItemDefaultPrices[itemID] = price
    return true
end

-- Function to remove default price for an item
function ns.RemoveItemDefaultPrice(itemID)
    if not itemID then return false end
    ns.ItemDefaultPrices[itemID] = nil
    return true
end

-- Initialize slash commands for managing default prices
SLASH_AHDEFAULTPRICE1 = "/ahprice"
SLASH_AHDEFAULTPRICE2 = "/defaultprice"

SlashCmdList["AHDEFAULTPRICE"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end
    
    if #args == 0 then
        print("|cFFFFFF00ConcedeAH Default Prices|r")
        print("Usage:")
        print("  /ahprice set <itemID> <price> - Set default price for an item")
        print("  /ahprice get <itemID> - Get default price for an item")
        print("  /ahprice remove <itemID> - Remove default price for an item")
        print("  /ahprice link - Get price for item on cursor")
        print("  /ahprice setlink <price> - Set price for item on cursor")
        print("Examples:")
        print("  /ahprice set 2589 50 - Set Linen Cloth to 50 copper")
        print("  /ahprice set 2589 1g50s - Set Linen Cloth to 1 gold 50 silver")
        return
    end
    
    local command = args[1]:lower()
    
    if command == "set" then
        local itemID = tonumber(args[2])
        local priceStr = args[3]
        
        if not itemID or not priceStr then
            print("|cFFFF0000Error:|r Invalid parameters. Usage: /ahprice set <itemID> <price>")
            return
        end
        
        -- Parse price (supports formats like "1g50s" or just copper amount)
        local price = 0
        if priceStr:match("g") or priceStr:match("s") or priceStr:match("c") then
            -- Parse gold/silver/copper format
            local gold = tonumber(priceStr:match("(%d+)g")) or 0
            local silver = tonumber(priceStr:match("(%d+)s")) or 0
            local copper = tonumber(priceStr:match("(%d+)c")) or 0
            price = gold * 10000 + silver * 100 + copper
        else
            price = tonumber(priceStr) or 0
        end
        
        if price <= 0 then
            print("|cFFFF0000Error:|r Invalid price")
            return
        end
        
        ns.SetItemDefaultPrice(itemID, price)
        local itemName = GetItemInfo(itemID) or "Unknown Item"
        print(string.format("|cFF00FF00Success:|r Set default price for %s (ID: %d) to %s", 
            itemName, itemID, GetCoinTextureString(price)))
            
    elseif command == "get" then
        local itemID = tonumber(args[2])
        
        if not itemID then
            print("|cFFFF0000Error:|r Invalid item ID")
            return
        end
        
        local price = ns.GetItemDefaultPrice(itemID)
        local itemName = GetItemInfo(itemID) or "Unknown Item"
        
        if price then
            print(string.format("|cFFFFFF00%s (ID: %d):|r Default price is %s", 
                itemName, itemID, GetCoinTextureString(price)))
        else
            print(string.format("|cFFFFFF00%s (ID: %d):|r No default price set", itemName, itemID))
        end
        
    elseif command == "remove" then
        local itemID = tonumber(args[2])
        
        if not itemID then
            print("|cFFFF0000Error:|r Invalid item ID")
            return
        end
        
        local itemName = GetItemInfo(itemID) or "Unknown Item"
        ns.RemoveItemDefaultPrice(itemID)
        print(string.format("|cFF00FF00Success:|r Removed default price for %s (ID: %d)", itemName, itemID))
        
    elseif command == "link" then
        -- Get price for item on cursor
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" then
            local price = ns.GetItemDefaultPrice(itemID)
            local itemName = GetItemInfo(itemID) or "Unknown Item"
            
            if price then
                print(string.format("|cFFFFFF00%s (ID: %d):|r Default price is %s", 
                    itemName, itemID, GetCoinTextureString(price)))
            else
                print(string.format("|cFFFFFF00%s (ID: %d):|r No default price set", itemName, itemID))
            end
        else
            print("|cFFFF0000Error:|r No item on cursor")
        end
        
    elseif command == "setlink" then
        -- Set price for item on cursor
        local priceStr = args[2]
        local infoType, itemID = GetCursorInfo()
        
        if infoType ~= "item" then
            print("|cFFFF0000Error:|r No item on cursor")
            return
        end
        
        if not priceStr then
            print("|cFFFF0000Error:|r No price specified")
            return
        end
        
        -- Parse price
        local price = 0
        if priceStr:match("g") or priceStr:match("s") or priceStr:match("c") then
            local gold = tonumber(priceStr:match("(%d+)g")) or 0
            local silver = tonumber(priceStr:match("(%d+)s")) or 0
            local copper = tonumber(priceStr:match("(%d+)c")) or 0
            price = gold * 10000 + silver * 100 + copper
        else
            price = tonumber(priceStr) or 0
        end
        
        if price <= 0 then
            print("|cFFFF0000Error:|r Invalid price")
            return
        end
        
        ns.SetItemDefaultPrice(itemID, price)
        local itemName = GetItemInfo(itemID) or "Unknown Item"
        print(string.format("|cFF00FF00Success:|r Set default price for %s (ID: %d) to %s", 
            itemName, itemID, GetCoinTextureString(price)))
    else
        print("|cFFFF0000Error:|r Unknown command. Type /ahprice for help")
    end
end