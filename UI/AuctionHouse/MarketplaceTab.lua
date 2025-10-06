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
    
    -- Debug command to check categories
    SLASH_CHECKCATEGORIES1 = "/checkcategories"
    SlashCmdList["CHECKCATEGORIES"] = function()
        print("|cFF00FF00Categories available:|r")
        for i, cat in ipairs(OFAuctionCategories) do
            local filterInfo = ""
            if cat.filters then
                local classIDs = {}
                for _, filter in ipairs(cat.filters) do
                    table.insert(classIDs, tostring(filter.classID))
                end
                filterInfo = " (ClassIDs: " .. table.concat(classIDs, ", ") .. ")"
            end
            print("  " .. i .. ". " .. (cat.name or "Unknown") .. filterInfo)
        end
    end
    
    -- Debug command to check item classification
    SLASH_CHECKITEM1 = "/checkitem"
    SlashCmdList["CHECKITEM"] = function(msg)
        local itemID = tonumber(msg)
        if not itemID then
            print("Usage: /checkitem <itemID>")
            return
        end
        
        local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice, itemClassID, itemSubClass = GetItemInfo(itemID)
        
        if itemName then
            print("|cFF00FF00Item Info:|r " .. (itemLink or itemName))
            print("  ItemID: " .. itemID)
            print("  ClassID: " .. (itemClassID or "nil"))
            print("  SubClass: " .. (itemSubClass or "nil"))
            print("  Type: " .. (itemType or "nil"))
            print("  SubType: " .. (itemSubType or "nil"))
            
            -- Check which category it should belong to
            local categoryName = "Unknown"
            if itemClassID == 0 then categoryName = "Consumables"
            elseif itemClassID == 1 then categoryName = "Containers"
            elseif itemClassID == 2 then categoryName = "Weapons"
            elseif itemClassID == 3 then categoryName = "Gems"
            elseif itemClassID == 4 then categoryName = "Armor"
            elseif itemClassID == 5 then categoryName = "Reagent"
            elseif itemClassID == 6 then categoryName = "Projectile"
            elseif itemClassID == 7 then categoryName = "Trade Goods"
            elseif itemClassID == 8 then categoryName = "Other (classID 8)"
            elseif itemClassID == 9 then categoryName = "Recipes"
            elseif itemClassID == 10 then categoryName = "Other (Money - obsolete)"
            elseif itemClassID == 11 then categoryName = "Quiver"
            elseif itemClassID == 12 then categoryName = "Quest"
            elseif itemClassID == 13 then categoryName = "Keys"
            elseif itemClassID == 14 then categoryName = "Other (Permanent - obsolete)"
            elseif itemClassID == 15 then categoryName = "Miscellaneous"
            elseif itemClassID == 16 then categoryName = "Glyphs"
            else categoryName = "Other (classID " .. tostring(itemClassID) .. ")"
            end
            
            print("  Should be in category: " .. categoryName)
        else
            print("|cFFFF0000Item not found:|r " .. itemID)
            print("Requesting item data...")
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
end

-- Event frame for item info updates
local marketplaceEventFrame = CreateFrame("Frame")
marketplaceEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
marketplaceEventFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" and success then
        -- When item info is loaded, update the marketplace if it's visible
        if OFAuctionFrameMarketplace and OFAuctionFrameMarketplace:IsVisible() then
            OFAuctionFrameMarketplace_Update()
        end
    end
end)

-- Register for auction updates to refresh marketplace when auctions change
local function updateMarketplaceIfVisible()
    if OFAuctionFrameMarketplace and OFAuctionFrameMarketplace:IsVisible() then
        OFAuctionFrameMarketplace_Update()
    end
end

ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, updateMarketplaceIfVisible)
ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, updateMarketplaceIfVisible)
ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, updateMarketplaceIfVisible)

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
    
    -- Show filter scroll frame and update filters
    if OFBrowseFilterScrollFrame then
        OFBrowseFilterScrollFrame:Show()
    end
    
    -- Initialize filter buttons if needed
    if not OFAuctionFrameBrowse.OFFilterButtons then
        OFAuctionFrameBrowse.OFFilterButtons = {}
        for i = 1, OF_NUM_FILTERS_TO_DISPLAY do
            local button = _G["OFFilterButton" .. i]
            if button then
                OFAuctionFrameBrowse.OFFilterButtons[i] = button
            end
        end
    end
    
    -- Update filters
    if OFAuctionFrameFilters_Update then
        OFAuctionFrameFilters_Update()
    end
    
    -- Load offers - use the browse update which now handles marketplace mode
    OFAuctionFrameBrowse_Update()
    
    -- Request item info for all items to ensure classID data is available
    local allAuctions = ns.AuctionHouseAPI:GetAllAuctions() or {}
    local itemsToLoad = {}
    for _, auction in ipairs(allAuctions) do
        if auction.itemID and auction.itemID > 0 then
            local itemName, _, _, _, _, _, _, _, _, _, _, itemClassID = GetItemInfo(auction.itemID)
            if not itemName or not itemClassID then
                itemsToLoad[auction.itemID] = true
            end
        end
    end
    
    -- Request load for all items that need it
    for itemID, _ in pairs(itemsToLoad) do
        C_Item.RequestLoadItemDataByID(itemID)
    end
    
    -- Schedule a refresh after a short delay to show items once loaded
    if next(itemsToLoad) then
        C_Timer.After(0.5, function()
            if OFAuctionFrameMarketplace and OFAuctionFrameMarketplace:IsVisible() then
                OFAuctionFrameBrowse_Update()
            end
        end)
    end
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
    
    -- Get selected category filter
    local selectedCategory = nil
    local selectedSubCategory = nil
    local selectedSubSubCategory = nil
    
    -- print("|cFFFF00FF[Debug]|r selectedCategoryIndex: " .. tostring(OFAuctionFrameBrowse.selectedCategoryIndex))
    
    if OFAuctionFrameBrowse.selectedCategoryIndex then
        selectedCategory = OFAuctionCategories[OFAuctionFrameBrowse.selectedCategoryIndex]
        -- print("|cFFFF00FF[Debug]|r Category found: " .. tostring(selectedCategory and selectedCategory.name or "nil"))
        -- if selectedCategory then
        --     print("|cFFFF00FF[Debug]|r Category has " .. tostring(selectedCategory.filters and #selectedCategory.filters or 0) .. " filters")
        -- end
        if selectedCategory and OFAuctionFrameBrowse.selectedSubCategoryIndex then
            selectedSubCategory = selectedCategory.subCategories and selectedCategory.subCategories[OFAuctionFrameBrowse.selectedSubCategoryIndex]
            if selectedSubCategory and OFAuctionFrameBrowse.selectedSubSubCategoryIndex then
                selectedSubSubCategory = selectedSubCategory.subCategories and selectedSubCategory.subCategories[OFAuctionFrameBrowse.selectedSubSubCategoryIndex]
            end
        end
    end
    
    -- Filter only offers (not requests) that are active, and apply search/hide filters
    local debugCount = 0
    local now = time()
    for _, auction in ipairs(allAuctions) do
        -- Only show active auctions that haven't expired and are not completed
        if not auction.isRequest and 
           auction.status == ns.AUCTION_STATUS_ACTIVE and 
           auction.status ~= ns.AUCTION_STATUS_COMPLETED and
           auction.status ~= ns.AUCTION_STATUS_PENDING_TRADE and
           auction.status ~= ns.AUCTION_STATUS_PENDING_LOAN and
           auction.status ~= ns.AUCTION_STATUS_SENT_COD and
           auction.status ~= ns.AUCTION_STATUS_SENT_LOAN and
           (not auction.expiresAt or auction.expiresAt > now) then
            debugCount = debugCount + 1
            local shouldShow = true
            
            -- Hide my offers if checkbox is checked
            if hideMyOffers and auction.owner == myName then
                shouldShow = false
            end
            
            -- Apply category filter (skip "All" category which is index 1)
            if shouldShow and selectedCategory and OFAuctionFrameBrowse.selectedCategoryIndex ~= 1 then
                -- if debugCount <= 3 then -- Only debug first 3 items to avoid spam
                --     print("|cFF00FFFF[Debug]|r Applying filter to item: " .. tostring(auction.itemID))
                -- end
                local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice, itemClassID, itemSubClass = nil
                if auction.itemID and auction.itemID > 0 then
                    itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice, itemClassID, itemSubClass = GetItemInfo(auction.itemID)
                    
                    -- Debug output
                    if not itemClassID then
                        -- print("|cFFFF0000[Debug]|r Item " .. auction.itemID .. " has no classID info - trying to fetch...")
                        -- Try to request the item info
                        C_Item.RequestLoadItemDataByID(auction.itemID)
                    -- else
                        -- if debugCount <= 3 then
                        --     print("|cFF00FF00[Debug]|r Item " .. (itemName or "?") .. " (ID:" .. auction.itemID .. ") has classID: " .. itemClassID .. ", subClass: " .. (itemSubClass or "nil"))
                        -- end
                    end
                end
                
                -- Check if item matches selected category
                local matchesFilter = false
                if itemClassID then  -- Only filter if we have classID info
                    if selectedSubSubCategory and selectedSubSubCategory.filters then
                        -- Check sub-sub-category filters
                        for _, filter in ipairs(selectedSubSubCategory.filters) do
                            if filter.classID == itemClassID and (not filter.subClassID or filter.subClassID == itemSubClass) then
                                matchesFilter = true
                                break
                            end
                        end
                    elseif selectedSubCategory and selectedSubCategory.filters then
                        -- Check sub-category filters
                        for _, filter in ipairs(selectedSubCategory.filters) do
                            if filter.classID == itemClassID and (not filter.subClassID or filter.subClassID == itemSubClass) then
                                matchesFilter = true
                                break
                            end
                        end
                    elseif selectedCategory and selectedCategory.filters then
                        -- Check category filters
                        -- if debugCount <= 3 then
                        --     print("|cFFFFFF00[Debug]|r Checking " .. #selectedCategory.filters .. " filters for category: " .. (selectedCategory.name or "?"))
                        -- end
                        for _, filter in ipairs(selectedCategory.filters) do
                            -- if debugCount <= 3 then
                            --     print("|cFFFFFF00[Debug]|r Filter classID: " .. (filter.classID or "nil") .. " vs item classID: " .. itemClassID)
                            -- end
                            if filter.classID == itemClassID and (not filter.subClassID or filter.subClassID == itemSubClass) then
                                matchesFilter = true
                                -- if debugCount <= 3 then
                                --     print("|cFF00FF00[Debug]|r Match found!")
                                -- end
                                break
                            end
                        end
                    end
                else
                    -- If we don't have classID info, hide the item from filtered views
                    -- It will only show in "All" category
                    matchesFilter = false
                end
                
                if not matchesFilter then
                    -- if debugCount <= 3 then
                    --     print("|cFFFF0000[Debug]|r Item filtered out!")
                    -- end
                    shouldShow = false
                -- else
                    -- if debugCount <= 3 then
                    --     print("|cFF00FF00[Debug]|r Item passes filter!")
                    -- end
                end
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
    
    -- Debug: Show how many offers passed the filter
    -- if selectedCategory and OFAuctionFrameBrowse.selectedCategoryIndex ~= 1 then
    --     print("|cFF00FFFF[Debug]|r Filtered offers: " .. numOffers .. " out of " .. #allAuctions .. " total auctions")
    -- end
    
    -- Update scroll frame (use the main browse scroll frame)
    FauxScrollFrame_Update(OFBrowseScrollFrame, numOffers, OF_NUM_BROWSE_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
    
    -- Update offer buttons (reuse OFBrowseButton elements)
    for i = 1, OF_NUM_BROWSE_TO_DISPLAY do
        local button = _G["OFBrowseButton" .. i]
        local index = offset + i
        
        if button and index <= numOffers then
            local offer = offers[index]
            -- print("|cFF00FF00[Debug]|r Showing button " .. i .. " with offer index " .. index .. " (itemID: " .. tostring(offer.itemID) .. ")")
            OFMarketplace_UpdateButton(button, offer, index)
            button:Show()
        elseif button then
            -- print("|cFFFF0000[Debug]|r Hiding button " .. i)
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