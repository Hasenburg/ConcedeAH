local _, ns = ...

-- Open Tab - Shows all open offers and requests

function OFAuctionFrameOpen_OnLoad(self)
    -- Set up sort parameters
    currentSortParams = currentSortParams or {}
    currentSortParams["open"] = {
        sortColumn = "time",
        reverseSort = true,
        params = {}
    }
end

function OFAuctionFrameOpen_OnShow(self)
    OFOpenTitle:SetText("OnlyFangs AH - Open Orders")
    OFAuctionFrameOpen_Update()
end

function OFAuctionFrameOpen_Update()
    local scrollFrame = OFOpenScrollFrame
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Get all open offers and requests
    local myOffers = ns.GetMyActiveAuctions and ns.GetMyActiveAuctions({}) or {}
    local myRequests = ns.GetMyRequests and ns.GetMyRequests() or {}
    
    -- Combine and filter only open items
    local openItems = {}
    
    -- Add open offers
    for _, offer in ipairs(myOffers) do
        if not offer.buyer then
            offer.type = "OFFER"
            table.insert(openItems, offer)
        end
    end
    
    -- Add open requests
    for _, request in ipairs(myRequests) do
        if not request.fulfilled then
            request.type = "REQUEST"
            table.insert(openItems, request)
        end
    end
    
    local numItems = #openItems
    
    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, numItems, OF_NUM_BIDS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
    
    -- Update buttons
    for i = 1, OF_NUM_BIDS_TO_DISPLAY do
        local button = _G["OFOpenButton" .. i]
        local index = offset + i
        
        if index <= numItems then
            local item = openItems[index]
            OFOpen_UpdateButton(button, item)
            button:Show()
        else
            button:Hide()
        end
    end
    
    -- Update counts
    OFOpenOffersCount:SetText("Open Offers: " .. #myOffers)
    OFOpenRequestsCount:SetText("Open Requests: " .. #myRequests)
end

function OFOpen_UpdateButton(button, item)
    local name = _G[button:GetName() .. "Name"]
    local typeText = _G[button:GetName() .. "Type"]
    local status = _G[button:GetName() .. "Status"]
    local time = _G[button:GetName() .. "Time"]
    local action = _G[button:GetName() .. "Action"]
    
    -- Set item name
    if item.itemID then
        local itemName, _, quality = GetItemInfo(item.itemID)
        if itemName then
            name:SetText(itemName)
            local r, g, b = GetItemQualityColor(quality or 1)
            name:SetTextColor(r, g, b)
        end
    else
        name:SetText(item.itemName or "Unknown Item")
    end
    
    -- Set type
    if typeText then
        if item.type == "OFFER" then
            typeText:SetText("[Offer]")
            typeText:SetTextColor(0, 1, 0)
        else
            typeText:SetText("[Request]")
            typeText:SetTextColor(1, 1, 0)
        end
    end
    
    -- Set status
    if status then
        local timeLeft = item.timeLeft or 0
        if timeLeft > 3600 then
            status:SetText(string.format("%dh left", timeLeft / 3600))
            status:SetTextColor(0, 1, 0)
        elseif timeLeft > 60 then
            status:SetText(string.format("%dm left", timeLeft / 60))
            status:SetTextColor(1, 1, 0)
        else
            status:SetText("Expiring soon")
            status:SetTextColor(1, 0, 0)
        end
    end
    
    -- Set time created
    if time and item.createdTime then
        local elapsed = GetServerTime() - item.createdTime
        if elapsed < 3600 then
            time:SetText(string.format("%dm ago", elapsed / 60))
        elseif elapsed < 86400 then
            time:SetText(string.format("%dh ago", elapsed / 3600))
        else
            time:SetText(string.format("%dd ago", elapsed / 86400))
        end
    end
    
    -- Set action button
    if action then
        action:SetText("Cancel")
        action:Show()
    end
    
    button.item = item
end

function OFOpenButton_OnClick(self)
    local item = self.item
    if not item then return end
    
    -- Select item
    OFAuctionFrame.selectedOpenItem = item
    
    -- Enable action buttons
    if item.type == "OFFER" then
        OFOpenEditButton:Enable()
    end
    OFOpenCancelButton:Enable()
end

function OFOpenCancelButton_OnClick()
    local item = OFAuctionFrame.selectedOpenItem
    if not item then return end
    
    local confirmText = item.type == "OFFER" and "Cancel this offer?" or "Cancel this request?"
    
    StaticPopup_Show("OF_CONFIRM_CANCEL_OPEN", confirmText, nil, {
        item = item,
        callback = function()
            if item.type == "OFFER" then
                ns.CancelOffer(item.id, function()
                    OFAuctionFrameOpen_Update()
                end)
            else
                ns.CancelRequest(item.id, function()
                    OFAuctionFrameOpen_Update()
                end)
            end
        end
    })
end

function OFOpenEditButton_OnClick()
    local item = OFAuctionFrame.selectedOpenItem
    if not item or item.type ~= "OFFER" then return end
    
    -- Switch to Create Offer tab with this item selected for editing
    OFAuctionFrameSwitchTab(TAB_CREATE_OFFER)
    -- TODO: Pre-fill the Create Offer tab with this item's details
end