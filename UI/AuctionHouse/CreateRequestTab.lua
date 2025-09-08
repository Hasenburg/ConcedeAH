local _, ns = ...

-- Create Request Tab - Create requests

function OFAuctionFrameCreateRequest_OnLoad(self)
    -- Initialize
    self.priceTypeIndex = ns.PRICE_TYPE_MONEY or 1
    self.deliveryTypeIndex = ns.DELIVERY_TYPE_ANY or 1
end

function OFAuctionFrameCreateRequest_OnShow(self)
    OFCreateRequestTitle:SetText("ConcedeAH - Create Request")
    OFAuctionFrameCreateRequest_Update()
    OFCreateRequestNote:SetText(OF_NOTE_PLACEHOLDER)
    OFCreateRequestItemName:SetText("")
end

function OFAuctionFrameCreateRequest_Update()
    -- Update current requests list
    OFCreateRequestCurrentRequests_Update()
end

function OFCreateRequestCurrentRequests_Update()
    local scrollFrame = OFCreateRequestScrollFrame
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Get my current requests
    local requests = ns.GetMyRequests and ns.GetMyRequests() or {}
    local numRequests = #requests
    
    -- Update scroll frame
    FauxScrollFrame_Update(scrollFrame, numRequests, 8, 37)
    
    -- Update request buttons
    for i = 1, 8 do
        local button = _G["OFCreateRequestListButton" .. i]
        local index = offset + i
        
        if index <= numRequests then
            local request = requests[index]
            OFCreateRequestListButton_Update(button, request)
            button:Show()
        else
            button:Hide()
        end
    end
end

function OFCreateRequestListButton_Update(button, request)
    local name = _G[button:GetName() .. "Name"]
    local status = _G[button:GetName() .. "Status"]
    local reward = _G[button:GetName() .. "Reward"]
    
    -- Set request info
    name:SetText(request.itemName or "Unknown Item")
    
    -- Set status
    if status then
        if request.fulfilled then
            status:SetText("Fulfilled by: " .. (request.fulfilledBy or "Unknown"))
            status:SetTextColor(0, 1, 0)
        else
            status:SetText("Open")
            status:SetTextColor(1, 1, 0)
        end
    end
    
    -- Set reward
    if reward and request.reward then
        MoneyFrame_Update(reward:GetName(), request.reward)
    end
    
    button.request = request
end

function OFCreateRequestSearchButton_OnClick()
    -- Open item search dialog
    local searchText = OFCreateRequestItemName:GetText()
    if searchText and searchText ~= "" then
        -- Search for items matching the text
        OFCreateRequestShowSearchResults(searchText)
    end
end

function OFCreateRequestShowSearchResults(searchText)
    -- Create a popup with search results
    local items = {}
    
    -- Search through item database
    for itemID = 1, 50000 do
        local itemName = GetItemInfo(itemID)
        if itemName and string.find(string.lower(itemName), string.lower(searchText)) then
            table.insert(items, {id = itemID, name = itemName})
            if #items >= 20 then break end -- Limit results
        end
    end
    
    -- Display results (simplified - would need proper UI)
    if #items > 0 then
        OFCreateRequestSelectedItem = items[1]
        OFCreateRequestItemName:SetText(items[1].name)
        OFCreateRequestValidate()
    end
end

function OFCreateRequestValidate()
    OFCreateRequestButton:Disable()
    
    local itemName = OFCreateRequestItemName:GetText()
    if not itemName or itemName == "" then return end
    
    local quantity = tonumber(OFCreateRequestQuantity:GetText()) or 0
    if quantity <= 0 then return end
    
    local reward = MoneyInputFrame_GetCopper(OFCreateRequestReward)
    if reward <= 0 then return end
    
    OFCreateRequestButton:Enable()
end

function OFCreateRequestButton_OnClick()
    local itemName = OFCreateRequestItemName:GetText()
    local quantity = tonumber(OFCreateRequestQuantity:GetText()) or 1
    local reward = MoneyInputFrame_GetCopper(OFCreateRequestReward)
    local note = OFCreateRequestNote:GetText()
    
    if note == OF_NOTE_PLACEHOLDER then
        note = ""
    end
    
    -- Create the request
    ns.CreateRequest({
        itemName = itemName,
        itemID = OFCreateRequestSelectedItem and OFCreateRequestSelectedItem.id,
        quantity = quantity,
        reward = reward,
        note = note,
        priceType = OFAuctionFrameCreateRequest.priceTypeIndex,
        deliveryType = OFAuctionFrameCreateRequest.deliveryTypeIndex
    }, function()
        -- Success callback
        OFCreateRequestItemName:SetText("")
        OFCreateRequestQuantity:SetText("1")
        MoneyInputFrame_SetCopper(OFCreateRequestReward, 0)
        OFCreateRequestNote:SetText(OF_NOTE_PLACEHOLDER)
        OFAuctionFrameCreateRequest_Update()
    end)
end

function OFCreateRequestCancelButton_OnClick(self)
    local request = self:GetParent().request
    if not request then return end
    
    -- Cancel the request
    ns.CancelRequest(request.id, function()
        OFAuctionFrameCreateRequest_Update()
    end)
end