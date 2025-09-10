local _, ns = ...

local OF_MAX_BAG_ITEMS_DISPLAYED = 20
local OF_BAGITEM_HEIGHT = 28

local bagItemsCache = {}
local selectedBagItem = nil

function OFGetBagItems()
    local items = {}
    
    -- Classic Era uses C_Container API
    for bag = 0, 4 do
        local numSlots = 0
        
        -- Try C_Container API first (Classic Era)
        if C_Container and C_Container.GetContainerNumSlots then
            numSlots = C_Container.GetContainerNumSlots(bag)
        else
            -- Fallback: assume standard bag sizes
            if bag == 0 then
                numSlots = 16  -- Backpack always has 16 slots
            else
                numSlots = 0  -- Don't assume other bags exist
            end
        end
        
        if numSlots > 0 then
            for slot = 1, numSlots do
                local itemInfo = nil
                local texture, itemCount, locked, quality, itemLink, itemID
                local name = "Item"
                
                -- Try new C_Container API
                if C_Container and C_Container.GetContainerItemInfo then
                    itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                    if itemInfo then
                        texture = itemInfo.iconFileID
                        itemCount = itemInfo.stackCount
                        quality = itemInfo.quality
                        locked = itemInfo.isLocked
                        
                        -- Get item link
                        if C_Container.GetContainerItemLink then
                            itemLink = C_Container.GetContainerItemLink(bag, slot)
                        end
                    end
                end
                
                if texture then
                    -- Check if item is bound (soulbound)
                    local isBound = false
                    
                    -- Use C_Container API to check if item is bound
                    if C_Container and C_Container.GetContainerItemInfo then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and info.isBound then
                            isBound = true
                        end
                    end
                    
                    -- Also check via tooltip scanning for additional bound checks
                    if not isBound and itemLink then
                        -- Create hidden tooltip for scanning
                        local tooltipName = "OFBagScanTooltip"
                        local tooltip = _G[tooltipName] or CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
                        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                        tooltip:ClearLines()
                        
                        -- Set the item to tooltip
                        if C_Container and C_Container.GetContainerItemID then
                            tooltip:SetBagItem(bag, slot)
                        else
                            tooltip:SetBagItem(bag, slot)
                        end
                        
                        -- Scan tooltip text for binding status
                        for i = 1, tooltip:NumLines() do
                            local text = _G[tooltipName.."TextLeft"..i]
                            if text then
                                local lineText = text:GetText()
                                if lineText and (string.find(lineText, ITEM_SOULBOUND) or 
                                               string.find(lineText, "Soulbound") or
                                               string.find(lineText, "Seelengebunden") or
                                               string.find(lineText, ITEM_BIND_ON_PICKUP) or
                                               string.find(lineText, "Binds when picked up")) then
                                    isBound = true
                                    break
                                end
                            end
                        end
                        
                        tooltip:Hide()
                    end
                    
                    -- Only add non-bound items (tradeable items)
                    if not isBound then
                        -- Extract info from itemLink if available
                        if itemLink then
                            -- Extract item ID from link
                            itemID = tonumber(string.match(itemLink, "item:(%d+)")) or 0
                            
                            -- Extract name from link
                            local linkName = string.match(itemLink, "%[(.+)%]")
                            if linkName then
                                name = linkName
                            end
                            
                            -- Try to get better info if available
                            if itemID > 0 and GetItemInfo then
                                local betterName = GetItemInfo(itemID)
                                if betterName then
                                    name = betterName
                                end
                            end
                        end
                        
                        table.insert(items, {
                            bag = bag,
                            slot = slot,
                            itemID = itemID or 0,
                            name = name,
                            texture = texture,
                            count = itemCount or 1,
                            quality = quality or 1,
                            itemLink = itemLink
                        })
                    end
                end
            end
        end
    end
    
    -- Sort items by quality (descending), then by name
    table.sort(items, function(a, b)
        if a.quality ~= b.quality then
            return a.quality > b.quality
        end
        return (a.name or "") < (b.name or "")
    end)
    
    return items
end

function OFBagItemsFrame_OnLoad(self)
    self.items = {}
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
end

function OFBagItemsFrame_OnEvent(self, event, ...)
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        OFBagItemsFrame_Update()
    end
end

function OFBagItemsFrame_OnShow()
    OFBagItemsFrame_Update()
end

function OFBagItemButton_OnClick(self)
    local item = self.item
    if not item then return end
    
    -- Pick up the item from bag and place it in auction slot
    ClearCursor()
    
    -- Use the appropriate API for picking up the item
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(item.bag, item.slot)
    else
        PickupContainerItem(item.bag, item.slot)
    end
    
    -- Place the item in the auction slot
    if OFAuctionsItemButton then
        ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
    end
    
    ClearCursor()
    
    -- Set the stack size fields for Create Offer tab
    if OFAuctionsStackSizeEntry then
        -- Set stack size to the total count of items
        OFAuctionsStackSizeEntry:SetText(tostring(item.count or 1))
        OFAuctionsStackSizeEntry:Show()
    end
    if OFAuctionsNumStacksEntry then
        -- Default to 1 stack
        OFAuctionsNumStacksEntry:SetText("1")
        OFAuctionsNumStacksEntry:Show()
    end
    
    -- Update selection
    selectedBagItem = item
    OFBagItemsFrame_Update()
    
    -- Set default price if configured for this item
    if item.itemID and ns.GetItemDefaultPrice then
        local defaultPrice = ns.GetItemDefaultPrice(item.itemID)
        if defaultPrice and defaultPrice > 0 then
            -- Set the price in the appropriate money frame
            if OFBuyoutPrice then
                -- For Auctions tab
                MoneyInputFrame_SetCopper(OFBuyoutPrice, defaultPrice)
            end
            if OFCreateOfferBuyoutPrice then
                -- For Create Offer tab
                MoneyInputFrame_SetCopper(OFCreateOfferBuyoutPrice, defaultPrice)
            end
        end
    end
end

function OFBagItemButton_OnEnter(self)
    if not self.item then return end
    
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(self.item.bag, self.item.slot)
    GameTooltip:Show()
end

function OFBagItemButton_OnLeave(self)
    GameTooltip:Hide()
end

function OFBagItemsFrame_Update()
    if not OFBagItemsScrollFrame then 
        return 
    end
    
    if not OFBagItemsFrame or not OFBagItemsFrame:IsVisible() then
        return
    end
    
    local scrollFrame = OFBagItemsScrollFrame
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Get all tradable items from bags
    bagItemsCache = OFGetBagItems()
    local numItems = #bagItemsCache
    
    -- Always show all 20 buttons
    for i = 1, 20 do
        local button = _G["OFBagItemButton" .. i]
        if button then
            button:Show()
            
            -- Get child elements
            local slot = _G[button:GetName() .. "Slot"]
            local border = _G[button:GetName() .. "Border"]
            local icon = _G[button:GetName() .. "IconTexture"]
            local count = _G[button:GetName() .. "Count"]
            
            local itemIndex = offset + i
            if itemIndex <= numItems then
                -- We have an item for this slot
                local item = bagItemsCache[itemIndex]
                button.item = item
                
                -- Always show slot background
                if slot then 
                    slot:Show() 
                end
                
                -- Show border with quality color
                if border then 
                    border:Show()
                    local r, g, b = GetItemQualityColor(item.quality or 1)
                    border:SetVertexColor(r, g, b)
                end
                
                -- Set and show icon - texture IDs need to be converted to paths
                if icon and item.texture then
                    -- In Classic Era, textures are numeric IDs that need GetSpellTexture or similar
                    if type(item.texture) == "number" then
                        -- Use SetToFileData for numeric texture IDs
                        icon:SetTexture(item.texture)
                    else
                        icon:SetTexture(item.texture)
                    end
                    icon:Show()
                elseif icon then
                    -- No texture, use question mark
                    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    icon:Show()
                end
                
                -- Show count if > 1
                if count then
                    if item.count and item.count > 1 then
                        count:SetText(item.count)
                        count:Show()
                    else
                        count:Hide()
                    end
                end
            else
                -- Empty slot
                button.item = nil
                
                -- Hide slot background for empty slots
                if slot then 
                    slot:Hide() 
                end
                
                -- Hide border for empty slots
                if border then 
                    border:Hide()
                end
                
                -- Hide icon and count
                if icon then 
                    icon:Hide() 
                end
                if count then 
                    count:Hide() 
                end
            end
        end
    end
    
    -- Update scroll frame to show items properly
    FauxScrollFrame_Update(scrollFrame, numItems, OF_MAX_BAG_ITEMS_DISPLAYED, OF_BAGITEM_HEIGHT)
end

-- Make it globally accessible
_G["OFBagItemsFrame_Update"] = OFBagItemsFrame_Update