local _, ns = ...

-- Create Offer Tab - Create offers with list of current offers on right side

function OFAuctionFrameCreateOffer_OnLoad(self)
    -- Initialize
    self.priceTypeIndex = ns.PRICE_TYPE_MONEY or 1
    self.deliveryTypeIndex = ns.DELIVERY_TYPE_ANY or 1
    
    -- Register events
    self:RegisterEvent("NEW_AUCTION_UPDATE")
    self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
end

function OFAuctionFrameCreateOffer_OnShow(self)
    OFCreateOfferTitle:SetText("ConcedeAH - Create Offer")
    OFAuctionFrameCreateOffer_Update()
    OFCreateOfferNote:SetText(OF_NOTE_PLACEHOLDER)
end

function OFAuctionFrameCreateOffer_Update()
    -- Update bag items using the standard frame
    if OFBagItemsFrame then
        OFBagItemsFrame_Update()
    end
    
    -- Update right side - current offers
    OFCreateOfferCurrentOffers_Update()
end

-- These functions are no longer needed as we use OFBagItemsFrame
-- Kept for reference but commented out
--[[
function OFCreateOfferBagItems_Update()
    local scrollFrame = OFCreateOfferBagScrollFrame
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Get all tradable items from bags
    local items = OFGetBagItems()
    local numItems = #items
    
    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, numItems, 8, 40)
    
    -- Update item buttons
    for i = 1, 8 do
        local button = _G["OFCreateOfferBagButton" .. i]
        local index = offset + i
        
        if index <= numItems then
            local item = items[index]
            OFCreateOfferBagButton_Update(button, item)
            button:Show()
        else
            button:Hide()
        end
    end
end

function OFCreateOfferBagButton_Update(button, item)
    local icon = _G[button:GetName() .. "IconTexture"]
    local name = _G[button:GetName() .. "Name"]
    local count = _G[button:GetName() .. "Count"]
    
    icon:SetTexture(item.texture)
    name:SetText(item.name)
    
    local r, g, b = GetItemQualityColor(item.quality)
    name:SetTextColor(r, g, b)
    
    if item.count > 1 then
        count:SetText(item.count)
        count:Show()
    else
        count:Hide()
    end
    
    button.item = item
end
--]]

function OFCreateOfferCurrentOffers_Update()
    local scrollFrame = OFCreateOfferOffersScrollFrame
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Get my current offers
    local offers = ns.GetMyActiveAuctions and ns.GetMyActiveAuctions({}) or {}
    local numOffers = #offers
    
    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, numOffers, 6, 37)
    
    -- Update offer buttons
    for i = 1, 6 do
        local button = _G["OFCreateOfferListButton" .. i]
        local index = offset + i
        
        if index <= numOffers then
            local offer = offers[index]
            OFCreateOfferListButton_Update(button, offer)
            button:Show()
        else
            button:Hide()
        end
    end
end

function OFCreateOfferListButton_Update(button, offer)
    local name = _G[button:GetName() .. "Name"]
    local status = _G[button:GetName() .. "Status"]
    local buyout = _G[button:GetName() .. "Buyout"]
    
    -- Set offer info
    if offer.itemID then
        local itemName, _, quality = GetItemInfo(offer.itemID)
        if itemName then
            name:SetText(itemName)
            local r, g, b = GetItemQualityColor(quality or 1)
            name:SetTextColor(r, g, b)
        end
    end
    
    -- Set status
    if status then
        if offer.buyer then
            status:SetText("Sold to: " .. offer.buyer)
            status:SetTextColor(0, 1, 0)
        else
            status:SetText("Active")
            status:SetTextColor(1, 1, 0)
        end
    end
    
    -- Set buyout price
    if buyout and offer.price then
        MoneyFrame_Update(buyout:GetName(), offer.price)
    end
    
    button.offer = offer
end

-- This function is no longer needed as we use OFBagItemButton_OnClick from BagItemsList.lua
--[[
function OFCreateOfferBagButton_OnClick(self)
    local item = self.item
    if not item then return end
    
    -- Pick up item and place in offer slot
    ClearCursor()
    PickupContainerItem(item.bag, item.slot)
    ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
    ClearCursor()
    
    -- Set quantity fields if they exist
    if OFAuctionsStackSizeEntry then
        OFAuctionsStackSizeEntry:SetText(tostring(item.count))
        OFAuctionsStackSizeEntry:Show()
    end
    if OFAuctionsNumStacksEntry then
        OFAuctionsNumStacksEntry:SetText("1")
        OFAuctionsNumStacksEntry:Show()
    end
    
    OFCreateOfferValidate()
end
--]]

function OFCreateOfferValidate()
    OFCreateOfferButton:Disable()
    
    local name = GetAuctionSellItemInfo and GetAuctionSellItemInfo()
    if not name then return end
    
    local buyout = MoneyInputFrame_GetCopper(OFCreateOfferBuyoutPrice)
    if buyout <= 0 then return end
    
    OFCreateOfferButton:Enable()
end

function OFCreateOfferButton_OnClick()
    local name, texture, count, quality, canUse, price, _, stackCount, totalCount, itemID = GetAuctionSellItemInfo and GetAuctionSellItemInfo()
    if not name then return end
    
    local buyout = MoneyInputFrame_GetCopper(OFCreateOfferBuyoutPrice)
    local note = OFCreateOfferNote:GetText()
    if note == OF_NOTE_PLACEHOLDER then
        note = ""
    end
    
    -- Create the offer
    ns.CreateOffer({
        itemID = itemID,
        itemName = name,
        texture = texture,
        quantity = count,
        price = buyout,
        note = note,
        priceType = OFAuctionFrameCreateOffer.priceTypeIndex,
        deliveryType = OFAuctionFrameCreateOffer.deliveryTypeIndex
    }, function()
        -- Success callback
        OFCreateOfferNote:SetText(OF_NOTE_PLACEHOLDER)
        ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
        ClearCursor()
        OFAuctionFrameCreateOffer_Update()
    end)
end