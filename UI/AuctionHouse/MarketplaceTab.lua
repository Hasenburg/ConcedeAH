local _, ns = ...

-- Marketplace Tab - Shows all offered items (like Guild Orders but without requests)

function OFAuctionFrameMarketplace_OnLoad(self)
    self.page = 0
    self.isSearch = nil
    self.canQuery = 1
    
    -- Set up sort parameters
    currentSortParams = currentSortParams or {}
    currentSortParams["marketplace"] = {
        sortColumn = "quality",
        reverseSort = false,
        params = {}
    }
end

function OFAuctionFrameMarketplace_OnShow(self)
    -- Update title
    OFMarketplaceTitle:SetText("ConcedeAH - Marketplace")
    
    -- Load offers
    OFAuctionFrameMarketplace_Update()
end

function OFAuctionFrameMarketplace_Update()
    local offset = FauxScrollFrame_GetOffset(OFMarketplaceScrollFrame) or 0
    
    -- Get all offers (not requests)
    local offers = ns.GetAllOffers and ns.GetAllOffers() or {}
    local numOffers = #offers
    
    -- Update scroll frame
    FauxScrollFrame_Update(OFMarketplaceScrollFrame, numOffers, OF_NUM_BROWSE_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
    
    -- Update offer buttons
    for i = 1, OF_NUM_BROWSE_TO_DISPLAY do
        local button = _G["OFMarketplaceButton" .. i]
        local index = offset + i
        
        if index <= numOffers then
            local offer = offers[index]
            OFMarketplace_UpdateButton(button, offer, index)
            button:Show()
        else
            button:Hide()
        end
    end
end

function OFMarketplace_UpdateButton(button, offer, index)
    -- Update button with offer information
    local name = _G[button:GetName() .. "Name"]
    local texture = _G[button:GetName() .. "ItemIconTexture"]
    local count = _G[button:GetName() .. "ItemCount"]
    local moneyFrame = _G[button:GetName() .. "MoneyFrame"]
    local buyoutMoneyFrame = _G[button:GetName() .. "BuyoutMoneyFrame"]
    
    -- Set item info
    if offer.itemID then
        local itemName, _, quality, level, _, _, _, _, _, itemTexture = GetItemInfo(offer.itemID)
        if itemName then
            name:SetText(itemName)
            texture:SetTexture(itemTexture)
            
            -- Set quality color
            local r, g, b = GetItemQualityColor(quality or 1)
            name:SetTextColor(r, g, b)
            
            -- Set count
            if offer.quantity and offer.quantity > 1 then
                count:SetText(offer.quantity)
                count:Show()
            else
                count:Hide()
            end
            
            -- Set price
            if moneyFrame then
                MoneyFrame_Update(moneyFrame:GetName(), offer.price or 0)
            end
        end
    end
    
    button.offer = offer
end

function OFMarketplaceButton_OnClick(self)
    local offer = self.offer
    if not offer then return end
    
    -- Handle offer selection
    OFAuctionFrame.selectedOffer = offer
    
    -- Show buy/fulfill options
    OFMarketplaceFulfillButton:Enable()
end

function OFMarketplaceFulfillButton_OnClick()
    local offer = OFAuctionFrame.selectedOffer
    if not offer then return end
    
    -- Process offer fulfillment
    ns.AuctionBuyConfirmPrompt:Show(offer, false,
        function() 
            -- Success callback
            OFAuctionFrameSwitchTab(TAB_PENDING)
        end,
        function(error) 
            -- Error callback
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0)
        end
    )
end

function OFMarketplace_Search()
    -- Implement search functionality
    local searchText = OFMarketplaceSearchBox:GetText()
    if searchText and searchText ~= "" then
        -- Filter offers by search text
        OFAuctionFrameMarketplace_Update()
    end
end