local _, ns = ...

-- Pending Tab - Shows bought items awaiting fulfillment and accepted requests

function OFAuctionFramePending_OnLoad(self)
    -- Set up sort parameters
    currentSortParams = currentSortParams or {}
    currentSortParams["pending"] = {
        sortColumn = "time",
        reverseSort = true,
        params = {}
    }
    
    -- Register events
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    self:RegisterEvent("BAG_UPDATE")
end

function OFAuctionFramePending_OnShow(self)
    OFPendingTitle:SetText("OnlyFangs AH - Pending Fulfillment")
    OFAuctionFramePending_Update()
end

function OFAuctionFramePending_OnEvent(self, event, ...)
    if event == "MAIL_INBOX_UPDATE" or event == "BAG_UPDATE" then
        if self:IsVisible() then
            OFAuctionFramePending_Update()
        end
    end
end

function OFAuctionFramePending_Update()
    local scrollFrame = OFPendingScrollFrame
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Get pending items
    local pendingItems = {}
    
    -- Get bought items awaiting delivery
    local myPendingAuctions = ns.GetMyPendingAuctions and ns.GetMyPendingAuctions({}) or {}
    for _, auction in ipairs(myPendingAuctions) do
        auction.type = "BOUGHT"
        table.insert(pendingItems, auction)
    end
    
    -- Get accepted requests awaiting fulfillment
    local acceptedRequests = ns.GetAcceptedRequests and ns.GetAcceptedRequests() or {}
    for _, request in ipairs(acceptedRequests) do
        request.type = "ACCEPTED_REQUEST"
        table.insert(pendingItems, request)
    end
    
    -- Get items I need to deliver (sold items)
    local soldItems = ns.GetMySoldItems and ns.GetMySoldItems() or {}
    for _, item in ipairs(soldItems) do
        item.type = "SOLD"
        table.insert(pendingItems, item)
    end
    
    local numItems = #pendingItems
    
    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, numItems, OF_NUM_BIDS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
    
    -- Update buttons
    for i = 1, OF_NUM_BIDS_TO_DISPLAY do
        local button = _G["OFPendingButton" .. i]
        local index = offset + i
        
        if index <= numItems then
            local item = pendingItems[index]
            OFPending_UpdateButton(button, item)
            button:Show()
        else
            button:Hide()
        end
    end
    
    -- Update summary
    OFPendingBoughtCount:SetText("Items to receive: " .. #myPendingAuctions)
    OFPendingSoldCount:SetText("Items to deliver: " .. #soldItems)
end

function OFPending_UpdateButton(button, item)
    local name = _G[button:GetName() .. "Name"]
    local typeText = _G[button:GetName() .. "Type"]
    local status = _G[button:GetName() .. "Status"]
    local partner = _G[button:GetName() .. "Partner"]
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
    
    -- Set type and status
    if typeText then
        if item.type == "BOUGHT" then
            typeText:SetText("[Awaiting Delivery]")
            typeText:SetTextColor(1, 1, 0)
            partner:SetText("From: " .. (item.seller or "Unknown"))
        elseif item.type == "SOLD" then
            typeText:SetText("[Need to Deliver]")
            typeText:SetTextColor(0, 1, 1)
            partner:SetText("To: " .. (item.buyer or "Unknown"))
        elseif item.type == "ACCEPTED_REQUEST" then
            typeText:SetText("[Request to Fulfill]")
            typeText:SetTextColor(1, 0.5, 0)
            partner:SetText("For: " .. (item.requester or "Unknown"))
        end
    end
    
    -- Set delivery status
    if status then
        if item.deliveryType == ns.DELIVERY_TYPE_MAIL then
            if item.mailSent then
                status:SetText("Mail sent")
                status:SetTextColor(0, 1, 0)
            else
                status:SetText("Mail pending")
                status:SetTextColor(1, 1, 0)
            end
        elseif item.deliveryType == ns.DELIVERY_TYPE_TRADE then
            if item.traded then
                status:SetText("Traded")
                status:SetTextColor(0, 1, 0)
            else
                status:SetText("Trade pending")
                status:SetTextColor(1, 1, 0)
            end
        else
            status:SetText("Any delivery")
            status:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    -- Set action button
    if action then
        if item.type == "SOLD" then
            action:SetText("Send Mail")
            action:Show()
        elseif item.type == "BOUGHT" then
            action:SetText("Track")
            action:Show()
        elseif item.type == "ACCEPTED_REQUEST" then
            action:SetText("Fulfill")
            action:Show()
        else
            action:Hide()
        end
    end
    
    button.item = item
end

function OFPendingButton_OnClick(self)
    local item = self.item
    if not item then return end
    
    -- Select item
    OFAuctionFrame.selectedPendingItem = item
    
    -- Show appropriate actions
    if item.type == "SOLD" then
        OFPendingSendMailButton:Enable()
        OFPendingWhisperButton:Enable()
    elseif item.type == "BOUGHT" then
        OFPendingWhisperButton:Enable()
        OFPendingReviewButton:Enable()
    elseif item.type == "ACCEPTED_REQUEST" then
        OFPendingFulfillButton:Enable()
        OFPendingWhisperButton:Enable()
    end
end

function OFPendingSendMailButton_OnClick()
    local item = OFAuctionFrame.selectedPendingItem
    if not item or item.type ~= "SOLD" then return end
    
    -- Open mail with item pre-filled
    if not MailFrame:IsVisible() then
        MailFrame:Show()
    end
    
    SendMailNameEditBox:SetText(item.buyer)
    SendMailSubjectEditBox:SetText("OnlyFangs AH: " .. (item.itemName or "Your item"))
    
    -- Auto-attach the item if possible
    -- This would require finding the item in bags and attaching it
end

function OFPendingWhisperButton_OnClick()
    local item = OFAuctionFrame.selectedPendingItem
    if not item then return end
    
    local targetName
    if item.type == "SOLD" then
        targetName = item.buyer
    elseif item.type == "BOUGHT" then
        targetName = item.seller
    elseif item.type == "ACCEPTED_REQUEST" then
        targetName = item.requester
    end
    
    if targetName then
        ChatFrame_SendTell(targetName)
    end
end

function OFPendingReviewButton_OnClick()
    local item = OFAuctionFrame.selectedPendingItem
    if not item or item.type ~= "BOUGHT" then return end
    
    -- Open review dialog
    ns.ShowReviewDialog(item, function(rating, comment)
        ns.SubmitReview(item.id, rating, comment, function()
            OFAuctionFramePending_Update()
        end)
    end)
end

function OFPendingFulfillButton_OnClick()
    local item = OFAuctionFrame.selectedPendingItem
    if not item or item.type ~= "ACCEPTED_REQUEST" then return end
    
    -- Check if player has the item
    local hasItem = false
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemID = GetContainerItemID(bag, slot)
            if itemID == item.itemID then
                hasItem = true
                -- Fulfill the request
                ns.FulfillAcceptedRequest(item.id, bag, slot, function()
                    OFAuctionFramePending_Update()
                end)
                break
            end
        end
        if hasItem then break end
    end
    
    if not hasItem then
        UIErrorsFrame:AddMessage("You don't have the requested item", 1.0, 0.1, 0.1, 1.0)
    end
end