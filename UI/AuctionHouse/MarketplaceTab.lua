local _, ns = ...

-- Marketplace Tab - Shows all offered items (like Guild Orders but without requests)

function OFAuctionFrameMarketplace_OnLoad(self)
    self.page = 0
    self.isSearch = nil
    self.canQuery = 1
    self.searchText = ""
    self.hideMyOffers = false
    
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
    
    -- Show the Hide My Offers checkbox
    if OFMarketplaceHideMyOffersCheckbox then
        OFMarketplaceHideMyOffersCheckbox:Show()
        OFMarketplaceHideMyOffersCheckbox:SetChecked(self.hideMyOffers or false)
    end
    if OFMarketplaceHideMyOffersLabel then
        OFMarketplaceHideMyOffersLabel:Show()
    end
    
    -- Make sure search box is visible and functional
    if OFBrowseName then
        OFBrowseName:Show()
        -- Hook the text changed event if not already done
        if not self.searchHooked then
            OFBrowseName:HookScript("OnTextChanged", function()
                OFMarketplace_Search()
            end)
            self.searchHooked = true
        end
        -- Get current search text
        OFMarketplace_Search()
    end
    
    -- Show the scroll frame
    if OFBrowseScrollFrame then
        OFBrowseScrollFrame:Show()
    end
    
    -- Load offers
    OFAuctionFrameMarketplace_Update()
end

function OFAuctionFrameMarketplace_OnHide(self)
    -- Hide the checkbox when tab is hidden
    if OFMarketplaceHideMyOffersCheckbox then
        OFMarketplaceHideMyOffersCheckbox:Hide()
    end
    if OFMarketplaceHideMyOffersLabel then
        OFMarketplaceHideMyOffersLabel:Hide()
    end
end

function OFAuctionFrameMarketplace_Update()
    -- Use the main browse scroll frame
    local offset = FauxScrollFrame_GetOffset(OFBrowseScrollFrame) or 0
    
    -- Get all offers from API
    local allAuctions = ns.AuctionHouseAPI:GetAllAuctions() or {}
    local offers = {}
    local searchText = OFAuctionFrameMarketplace.searchText or ""
    local hideMyOffers = OFAuctionFrameMarketplace.hideMyOffers or false
    local myName = UnitName("player")
    
    -- Filter only offers (not requests) and apply search/hide filters
    for _, auction in ipairs(allAuctions) do
        if not auction.isRequest then
            local shouldShow = true
            
            -- Hide my offers if checkbox is checked
            if hideMyOffers and auction.owner == myName then
                shouldShow = false
            end
            
            -- Apply search filter
            if shouldShow and searchText ~= "" then
                local itemName = ""
                if auction.itemID and auction.itemID > 0 then
                    itemName = GetItemInfo(auction.itemID) or ""
                elseif auction.itemName then
                    itemName = auction.itemName
                end
                
                -- Check if search text matches item name or owner
                if not (string.find(string.lower(itemName), string.lower(searchText), 1, true) or
                        string.find(string.lower(auction.owner or ""), string.lower(searchText), 1, true)) then
                    shouldShow = false
                end
            end
            
            if shouldShow then
                table.insert(offers, auction)
            end
        end
    end
    
    local numOffers = #offers
    
    -- Update scroll frame (use the main browse scroll frame)
    FauxScrollFrame_Update(OFBrowseScrollFrame, numOffers, OF_NUM_BROWSE_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
    
    -- Update offer buttons (reuse OFBrowseButton elements)
    for i = 1, OF_NUM_BROWSE_TO_DISPLAY do
        local button = _G["OFBrowseButton" .. i]
        local index = offset + i
        
        if button and index <= numOffers then
            local offer = offers[index]
            OFMarketplace_UpdateButton(button, offer, index)
            button:Show()
        elseif button then
            button:Hide()
        end
    end
end

function OFMarketplace_UpdateButton(button, offer, index)
    if not button then return end
    
    -- Update button with offer information
    local buttonName = button:GetName()
    local name = _G[buttonName .. "Name"]
    local texture = _G[buttonName .. "ItemIconTexture"]
    local count = _G[buttonName .. "ItemCount"]
    local moneyFrame = _G[buttonName .. "MoneyFrame"]
    local buyoutMoneyFrame = _G[buttonName .. "BuyoutMoneyFrame"]
    
    -- Set item info
    if offer.itemID and offer.itemID > 0 then
        local itemName, _, quality, level, _, _, _, _, _, itemTexture = GetItemInfo(offer.itemID)
        if itemName then
            name:SetText(itemName)
            texture:SetTexture(itemTexture)
        else
            -- Fallback to stored name if item not in cache
            name:SetText(offer.itemName or "Unknown")
            texture:SetTexture("Interface\Icons\INV_Misc_QuestionMark")
        end
    elseif offer.itemName then
        -- Special items without itemID
        name:SetText(offer.itemName)
        texture:SetTexture(offer.texture or "Interface\Icons\INV_Misc_QuestionMark")
    end
    
    -- Set quality color
    local quality = 1
    if offer.itemID and offer.itemID > 0 then
        local _, _, itemQuality = GetItemInfo(offer.itemID)
        quality = itemQuality or 1
    end
    local r, g, b = GetItemQualityColor(quality)
    if name then
        name:SetTextColor(r, g, b)
    end
    
    -- Set count
    if count then
        if offer.quantity and offer.quantity > 1 then
            count:SetText(offer.quantity)
            count:Show()
        else
            count:Hide()
        end
    end
    
    -- Set price
    if moneyFrame then
        MoneyFrame_Update(moneyFrame:GetName(), offer.price or 0)
    end
    
    button.offer = offer
end

function OFMarketplace_OnButtonClick(self)
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
    -- Update search text from the main browse name field
    local searchBox = _G["OFBrowseName"]
    if searchBox then
        local searchText = searchBox:GetText() or ""
        -- Ignore placeholder text
        if searchText == OF_BROWSE_SEARCH_PLACEHOLDER then
            searchText = ""
        end
        OFAuctionFrameMarketplace.searchText = searchText
    end
    OFAuctionFrameMarketplace_Update()
end

function OFMarketplace_OnSearchTextChanged(self)
    -- Called when search text changes in OFBrowseName
    OFMarketplace_Search()
end

function OFMarketplace_ToggleHideMyOffers()
    -- Toggle hide my offers setting
    OFAuctionFrameMarketplace.hideMyOffers = not OFAuctionFrameMarketplace.hideMyOffers
    OFAuctionFrameMarketplace_Update()
end