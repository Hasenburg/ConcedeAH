local addonName, ns = ...

OF_AH_ADDON_NAME = addonName

-- keep last item sent to auction & it's price

-- To experiment with different "20x" label strings, use:
-- /script AUCTION_PRICE_STACK_SIZE_LABEL = "%dx"

local FILTER_ALL_INDEX = -1;

OF_LAST_ITEM_AUCTIONED = "";
OF_LAST_ITEM_COUNT = 0;
OF_LAST_ITEM_BUYOUT = 0;

OF_NOTE_PLACEHOLDER = "Leave a note..."

OF_BROWSE_SEARCH_PLACEHOLDER = "Search or wishlist"

local TAB_MARKETPLACE = 1
local TAB_CREATE_OFFER = 2
local TAB_PENDING = 3
local TAB_CREATE_REQUEST = 4 -- removed, keeping for compatibility
local TAB_OPEN = 5 -- removed, keeping for compatibility
ns.AUCTION_TAB_MARKETPLACE = TAB_MARKETPLACE
ns.AUCTION_TAB_CREATE_OFFER = TAB_CREATE_OFFER
ns.AUCTION_TAB_PENDING = TAB_PENDING
ns.AUCTION_TAB_CREATE_REQUEST = TAB_CREATE_REQUEST -- removed
ns.AUCTION_TAB_OPEN = TAB_OPEN -- removed

local BROWSE_PARAM_INDEX_PAGE = 5;
local PRICE_TYPE_UNIT = 1;
local PRICE_TYPE_STACK = 2;

local activeTooltipPriceTooltipFrame
local activeTooltipAuctionFrameItem
local allowLoans = false
local roleplay = false
local deathRoll = false
local duel = false
local currentSortParams = {}
local browseResultCache
local browseSortDirty = true
local auctionSellItemInfo

local selectedAuctionItems = {
    list = nil,
    bidder = nil,
    owner = nil,
}


local function pack(...)
    local table = {}
    for i = 1, select('#', ...) do
        table[i] = select(i, ...)
    end
    return table
end

local function OFGetAuctionSellItemInfo()
    if auctionSellItemInfo == nil then
        return nil
    end
    return unpack(auctionSellItemInfo)
end

function OFGetCurrentSortParams(type)
    return currentSortParams[type].params
end

local function OFGetSelectedAuctionItem(type)
    return selectedAuctionItems[type]
end

local function OFSetSelectedAuctionItem(type, auction)
    selectedAuctionItems[type] = auction
end


function OFAllowLoansCheckButton_OnClick(button)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    allowLoans = not allowLoans
    if allowLoans then
        roleplay = false
        duel = false
        deathRoll = false
        local priceType = OFAuctionFrameAuctions.priceTypeIndex
        if priceType ~= ns.PRICE_TYPE_MONEY then
            OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
            OFPriceTypeDropdown:GenerateMenu()
        end
    end
    OFUpdateAuctionSellItem()
end

function OFRoleplayCheckButton_OnClick(button)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    roleplay = not roleplay
    if roleplay then
        duel = false
        deathRoll = false
        allowLoans = false
    end
    OFUpdateAuctionSellItem()
end

function OFDeathRollCheckButton_OnClick(button)
    deathRoll = not deathRoll
    if deathRoll then
        duel = false
        roleplay = false
        allowLoans = false
    end
    OFSpecialFlagCheckButton_OnClick()
    OFUpdateAuctionSellItem()
end

function OFDuelCheckButton_OnClick(button)
    duel = not duel
    if duel then
        deathRoll = false
        roleplay = false
        allowLoans = false
    end
    OFSpecialFlagCheckButton_OnClick()
    OFUpdateAuctionSellItem()
end

function OFSpecialFlagCheckButton_OnClick()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if deathRoll or duel then
        local priceType = OFAuctionFrameAuctions.priceTypeIndex
        if priceType == ns.PRICE_TYPE_TWITCH_RAID then
            OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
            OFPriceTypeDropdown:GenerateMenu()
        end
        local deliveryType = OFAuctionFrameAuctions.deliveryTypeIndex
        if deliveryType ~= ns.DELIVERY_TYPE_TRADE then
            OFSetupDeliveryDropdown(OFAuctionFrameAuctions, ns.DELIVERY_TYPE_TRADE)
            OFDeliveryDropdown:GenerateMenu()
        end
    end
end

local function GetAuctionSortColumn(sortTable)
	local existingSortColumn, existingSortReverse = currentSortParams[sortTable].column, currentSortParams[sortTable].desc

	-- The "bid" column can now be configured to sort by per-unit bid price ("unitbid"),
	-- per-unit buyout price ("unitprice"), or total buyout price ("totalbuyout") instead of
	-- always sorting by total bid price ("bid"). Map these new sort options to the "bid" column.
	if (existingSortColumn == "totalbuyout" or existingSortColumn == "unitbid" or existingSortColumn == "unitprice") then
		existingSortColumn = "bid";
	end

	return existingSortColumn, existingSortReverse
end


local function GetBuyoutPrice()
	local buyoutPrice = MoneyInputFrame_GetCopper(OFBuyoutPrice);
	return buyoutPrice;
end


function OFBrowseFulfillButton_OnClick(button)
    ns.AuctionBuyConfirmPrompt:Show(OFAuctionFrame.auction, false,
            function() OFAuctionFrameSwitchTab(TAB_PENDING) end,
            function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
            function() button:Enable() end
    )
end

-- Loan button removed
-- function OFBrowseLoanButton_OnClick(button)
--     ns.AuctionBuyConfirmPrompt:Show(OFAuctionFrame.auction, true,
--         function() OFAuctionFrameSwitchTab(TAB_PENDING) end,
--         function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
--         function() button:Enable() end
--     )
-- end

function OFBrowseBuyoutButton_OnClick(button)
    if OFAuctionFrame.auction.deathRoll then
        StaticPopup_Show("OF_BUY_AUCTION_DEATH_ROLL")
    elseif OFAuctionFrame.auction.duel then
        StaticPopup_Show("OF_BUY_AUCTION_DUEL")
    elseif OFAuctionFrame.auction.itemID == ns.ITEM_ID_GOLD then
        StaticPopup_Show("OF_BUY_AUCTION_GOLD")
    else
        ns.AuctionBuyConfirmPrompt:Show(OFAuctionFrame.auction, false,
            function() OFAuctionFrameSwitchTab(TAB_PENDING) end,
            function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
            function() button:Enable() end
        )
    end
end

function OFBidWhisperButton_OnClick()
    local auction = OFAuctionFrame.auction
    local name = UnitName("player") == auction.owner and auction.buyer or auction.owner
    ChatFrame_SendTell(name)
end

function OFBidInviteButton_OnClick()
    local auction = OFAuctionFrame.auction
    local name = UnitName("player") == auction.owner and auction.buyer or auction.owner
    InviteUnit(name)
end

StaticPopupDialogs["OF_CANCEL_AUCTION_PENDING"] = {
    text = "Are you sure you want to cancel this auction?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local success, error = ns.AuctionHouseAPI:CancelAuction(OFAuctionFrame.auction.id)
        if success then
            OFAuctionFrameBid_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnCancel = function(self)
        OFBidCancelAuctionButton:Enable()
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_CANCEL_AUCTION_ACTIVE"] = {
    text = "Are you sure you want to cancel this auction?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local success, error = ns.AuctionHouseAPI:CancelAuction(OFAuctionFrame.auction.id)
        if success then
            OFAuctionFrameAuctions_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnCancel = function(self)
        OFAuctionsCancelAuctionButton:Enable();
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

local function CreateSpecialModifierBuyConfirmPrompt(text)
    return {
        text = text,
        button1 = YES,
        button2 = NO,
        OnAccept = function(self)
            local _, err = ns.AuctionHouseAPI:RequestBuyAuction(OFAuctionFrame.auction.id, 0)
            if err == nil then
                OFAuctionFrameBrowse_Update()
            else
                UIErrorsFrame:AddMessage(err, 1.0, 0.1, 0.1, 1.0)
            end
        end,
        OnShow = function(self)
            MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price)
        end,
        OnCancel = function(self)
            OFBrowseBuyoutButton:Enable()
        end,
        hasMoneyFrame = 1,
        showAlert = 1,
        timeout = 0,
        exclusive = 1,
        hideOnEscape = 1
    }
end

StaticPopupDialogs["OF_BUY_AUCTION_DEATH_ROLL"] = CreateSpecialModifierBuyConfirmPrompt("Are you sure you want to accept a death roll for this auction?")

StaticPopupDialogs["OF_BUY_AUCTION_DUEL"] = CreateSpecialModifierBuyConfirmPrompt("Are you sure you want to accept a duel for this auction?")

StaticPopupDialogs["OF_BUY_AUCTION_GOLD"] = {
    text = "Are you sure you want to buy this auction?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local _, err = ns.AuctionHouseAPI:RequestBuyAuction(OFAuctionFrame.auction.id, 0)
        if err == nil then
            OFAuctionFrameBrowse_Update()
        else
            UIErrorsFrame:AddMessage(err, 1.0, 0.1, 0.1, 1.0)
        end
    end,
    OnCancel = function(self)
        OFBrowseBuyoutButton:Enable()
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
}

StaticPopupDialogs["OF_DECLINE_ALL"] = {
	text = "Are you sure you want to unlist all your pending orders?",
    button1 = YES,
    button2 = NO,
	OnAccept = function()
		-- Cancel each auction
        local allAuctions = ns.AuctionHouseAPI:GetMySellPendingAuctions()
		for _, auction in pairs(allAuctions) do
			ns.AuctionHouseAPI:CancelAuction(auction.id)
		end
	end,
    showAlert = 1,
	timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["OF_FORGIVE_LOAN"] = {
    text = "Mark loan complete? This will complete the trade.",
    button1 = "Mark Loan Complete",
    button2 = "Cancel",
    OnAccept = function(self)
        local error = ns.AuctionHouseAPI:MarkLoanComplete(OFAuctionFrame.auction.id)
        if error == nil then
            OFAuctionFrameBid_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price);
    end,
    OnCancel = function(self)
        OFBidForgiveLoanButton:Enable();
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_DECLARE_BANKRUPTCY"] = {
    text = "Declare Bankruptcy? This will complete the trade without fulfilling your end of the deal.",
    button1 = "Declare Bankruptcy",
    button2 = "Cancel",
    OnAccept = function(self)
        local error = ns.AuctionHouseAPI:DeclareBankruptcy(OFAuctionFrame.auction.id)
        if error == nil then
            PlaySoundFile("Interface\\AddOns\\"..addonName.."\\Media\\bankruptcy.mp3", "Master")
            OFAuctionFrameBid_Update()
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price)
    end,
    OnCancel = function(self)
        OFBidForgiveLoanButton:Enable()
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_MARK_AUCTION_COMPLETE"] = {
    text = "Mark auction complete? This will complete the trade.",
    button1 = "Mark Auction Complete",
    button2 = "Cancel",
    OnAccept = function(self)
        local auction, trade, error = ns.AuctionHouseAPI:CompleteAuction(OFAuctionFrame.auction.id)
        if error == nil then
            OFAuctionFrameBid_Update()
            if auction then
                StaticPopup_Show("OF_LEAVE_REVIEW", nil, nil, { tradeID = trade.id });
            end
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        if OFAuctionFrame.auction.priceType == ns.PRICE_TYPE_MONEY then
            MoneyFrame_Update(self.moneyFrame, OFAuctionFrame.auction.price)
        else
            self.moneyFrame:Hide()
        end
    end,
    OnCancel = function(self)
        OFBidForgiveLoanButton:Enable()
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

StaticPopupDialogs["OF_FULFILL_AUCTION"] = {
    text = "Are you sure you want to fulfill this wishlist request?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local success, error = ns.AuctionHouseAPI:RequestFulfillAuction(OFAuctionFrame.auction.id)
        if success then
            OFAuctionFrameSwitchTab(TAB_PENDING)
        else
            UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        end
    end,
    OnShow = function(self)
        local auction = OFAuctionFrame.auction
        if auction.priceType == ns.PRICE_TYPE_MONEY then
            MoneyFrame_Update(self.moneyFrame, auction.price)
        else
            self.moneyFrame:Hide()
        end
        ns.GetItemInfoAsync(auction.itemID, function(...)
            local item = ns.ItemInfoToTable(...)
            local itemName
            if auction.itemID == ns.ITEM_ID_GOLD then
                itemName = ns.GetMoneyString(auction.quantity)
            else
                itemName = item.name
                if auction.quantity > 1 then
                    itemName = itemName .. " x" .. auction.quantity
                end
            end
            local name = ns.GetDisplayName(auction.owner)
            self.text:SetText(string.format("Are you sure you want to fulfill the wishlist request of %s for %s?", name, itemName))
        end)
    end,
    OnCancel = function(self)
        OFBrowseFulfillButton:Enable();
    end,
    hasMoneyFrame = 1,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1
};

function OFUpdateAuctionSellItem()
    OFRoleplayCheckButton:SetChecked(roleplay)
    OFAllowLoansCheckButton:SetChecked(allowLoans)
    OFDeathRollCheckButton:SetChecked(deathRoll)
    OFDuelCheckButton:SetChecked(duel)


    local priceType = OFAuctionFrameAuctions.priceTypeIndex
    if priceType == ns.PRICE_TYPE_MONEY then
        OFBuyoutPrice:Show()
        OFTwitchRaidViewerAmount:Hide()
    elseif priceType == ns.PRICE_TYPE_TWITCH_RAID then
        OFBuyoutPrice:Hide()
        OFTwitchRaidViewerAmount:Show()
    else
        OFBuyoutPrice:Hide()
        OFTwitchRaidViewerAmount:Hide()
    end
    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = OFGetAuctionSellItemInfo()
    local isGold = itemID == ns.ITEM_ID_GOLD
    if isGold then
        OFBuyoutPrice:Hide()
    end

    if (texture) then
        OFAuctionsItemButton:SetNormalTexture(texture)
    else
        OFAuctionsItemButton:ClearNormalTexture()
    end

    OFAuctionsItemButton.stackCount = stackCount
    OFAuctionsItemButton.totalCount = totalCount
    OFAuctionsItemButton.pricePerUnit = pricePerUnit
    OFAuctionsItemButtonName:SetText(name or "")
    OFAuctionsItemButtonCount:SetText(count or "")
    if ((count == nil or count > 1) and not isGold) then
        OFAuctionsItemButtonCount:Show()
    else
        OFAuctionsItemButtonCount:Hide()
    end
    OFAuctionsFrameAuctions_ValidateAuction()
end

local function LockCheckButton(button, value)
    button:Disable()
    button:SetChecked(value)
    _G[button:GetName().."Text"]:SetTextColor(0.5, 0.5, 0.5)
end

local function UnlockCheckButton(button)
    button:Enable()
    _G[button:GetName().."Text"]:SetTextColor(1, 1, 1)
end

local function OnMoneySelected(self)
    local copper = MoneyInputFrame_GetCopper(self.moneyInputFrame)
    local myMoney = GetMoney()
    if myMoney < copper then
        PlayVocalErrorSoundID(40)
        UIErrorsFrame:AddMessage(ERR_NOT_ENOUGH_MONEY, 1.0, 0.1, 0.1, 1.0)
        return
    end
    local name, _, quality, _, _, _, _, stackCount, _, texture = ns.GetGoldItemInfo(copper)
    name = ITEM_QUALITY_COLORS[quality].hex..name.."|r"
    -- name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID
    auctionSellItemInfo = pack(name, texture, copper, quality, true, copper, 1, stackCount, myMoney, ns.ITEM_ID_GOLD)
    OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
    OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
    allowLoans = false
    LockCheckButton(OFAllowLoansCheckButton, false)
    OFUpdateAuctionSellItem()
end

function OFSelectEnchantForAuction(itemID)
    local name, _, quality, _, _, _, _, stackCount, _, texture = ns.GetSpellItemInfo(itemID)
    name = ITEM_QUALITY_COLORS[quality].hex..name.."|r"
    auctionSellItemInfo = pack(name, texture, 1, quality, true, 1, 1, stackCount, 1, itemID)
    UnlockCheckButton(OFAllowLoansCheckButton)
    OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
    OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
    OFUpdateAuctionSellItem()
end

StaticPopupDialogs["OF_SELECT_AUCTION_MONEY"] = {
    text = "Select the amount for the auction",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self)
        OnMoneySelected(self)
    end,
    OnHide = function(self)
        MoneyInputFrame_ResetMoney(self.moneyInputFrame)
    end,
    EditBoxOnEnterPressed = function(self)
        OnMoneySelected(self)
    end,
    hasMoneyInputFrame = 1,
    timeout = 0,
    hideOnEscape = 1
};

--local original = ContainerFrameItemButton_OnClick
--function ContainerFrameItemButton_OnClick(self, button, ...)
--    if button == "RightButton" and OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
--        local bagIdx, slotIdx = self:GetParent():GetID(), self:GetID()
--        C_Container.PickupContainerItem(bagIdx, slotIdx);
--        OFAuctionSellItemButton_OnClick(AuctionsItemButton, "LeftButton")
--    else
--        return original(self, button, ...)
--    end
--end


function OFAuctionFrame_OnLoad (self)
    tinsert(UISpecialFrames, "OFAuctionFrame")

	-- Tab Handling code
	PanelTemplates_SetNumTabs(self, 3);
	PanelTemplates_SetTab(self, 1);

	-- Set focus rules
	OFBrowseFilterScrollFrame.ScrollBar.scrollStep = OF_BROWSE_FILTER_HEIGHT;

	-- Init search dot count
	OFAuctionFrameBrowse.dotCount = 0;
	OFAuctionFrameBrowse.isSearchingThrottle = 0;

	OFAuctionFrameBrowse.page = 0;
	FauxScrollFrame_SetOffset(OFBrowseScrollFrame,0);

	OFAuctionFrameBid.page = 0;
	FauxScrollFrame_SetOffset(OFBidScrollFrame,0);
	GetBidderAuctionItems(OFAuctionFrameBid.page);

	OFAuctionFrameAuctions.page = 0;
	FauxScrollFrame_SetOffset(OFAuctionsScrollFrame,0);

	MoneyFrame_SetMaxDisplayWidth(OFAuctionFrameMoneyFrame, 160);

	-- Reset button removed - no longer needed
	-- if GetClassicExpansionLevel() == LE_EXPANSION_CLASSIC then
	-- 	OFBrowseResetButton:SetSize(97, 22);
	-- 	OFBrowseResetButton:SetPoint("TOPLEFT", 37, -79);
	-- end
end

function OFAuctionFrame_Show()
	if ( OFAuctionFrame:IsShown() ) then
		OFAuctionFrameBrowse_Update();
		OFAuctionFrameBid_Update();
		OFAuctionFrameAuctions_Update();
	else
		ShowUIPanel(OFAuctionFrame);

		OFAuctionFrameBrowse.page = 0;
		FauxScrollFrame_SetOffset(OFBrowseScrollFrame,0);

		OFAuctionFrameBid.page = 0;
		FauxScrollFrame_SetOffset(OFBidScrollFrame,0);
		GetBidderAuctionItems(OFAuctionFrameBid.page);

		OFAuctionFrameAuctions.page = 0;
		FauxScrollFrame_SetOffset(OFAuctionsScrollFrame,0);

		OFBrowsePrevPageButton.isEnabled = false;
		OFBrowseNextPageButton.isEnabled = false;
		OFBrowsePrevPageButton:Disable();
		OFBrowseNextPageButton:Disable();
		
		if ( not OFAuctionFrame:IsShown() ) then
			CloseAuctionHouse();
		end
	end
end

function OFAuctionFrame_Hide()
	HideUIPanel(OFAuctionFrame);
end

local initialTab = TAB_MARKETPLACE
function OFAuctionFrame_OverrideInitialTab(tab)
    initialTab = tab
end

function AuctionFrame_UpdatePortrait()
    -- if ns.IsAtheneBlocked() then
    --     SetPortraitTexture(OFAuctionPortraitTexture, "player");
    -- else
    OFAuctionPortraitTexture:SetTexture("Interface\\AddOns\\"..addonName.."\\Media\\icon_of_400px.png")
    -- end
end

function OFAuctionFrame_OnShow (self)
    -- Set initial tab to Marketplace
    if not initialTab or initialTab == TAB_BROWSE then
        initialTab = TAB_MARKETPLACE
    end
    OFAuctionFrameSwitchTab(initialTab)
    initialTab = TAB_MARKETPLACE

    AuctionFrame_UpdatePortrait()
	OFBrowseNoResultsText:SetText(BROWSE_SEARCH_TEXT);
	PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN);

	SetUpSideDressUpFrame(self, 840, 1020, "TOPLEFT", "TOPRIGHT", -2, -28);
end

function OFAuctionFrameTab_OnClick(self, button, down)
    local index = self:GetID();
    OFAuctionFrameSwitchTab(index)
end


local function AssignReviewTextures(includingLeftBorder)
    local basepath = "Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-review-"

    if includingLeftBorder then
        OFAuctionFrameBotLeft:SetTexture(basepath .. "botleft")
        OFAuctionFrameTopLeft:SetTexture(basepath .. "topleft")
    else
        OFAuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft")
        OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopLeft")
    end
    OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top")
    OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight")
    OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot")
    OFAuctionFrameBotRight:SetTexture(basepath .. "botright")
end

local function AssignCreateOrderTextures()
    local basepath = "Interface\\AddOns\\"..addonName.."\\Media\\auctionframe-auction-"

    OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopLeft");
    OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
    OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
    OFAuctionFrameBotLeft:SetTexture(basepath .. "botleft.png");
    OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
    OFAuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotRight");
end


function OFAuctionFrameSwitchTab(index)
	PanelTemplates_SetTab(OFAuctionFrame, index)
	
	-- Hide all frames
	OFAuctionFrameAuctions:Hide()
	OFAuctionFrameBrowse:Hide()
	OFAuctionFrameBid:Hide()
	if OFAuctionFrameSettings then OFAuctionFrameSettings:Hide() end
	if OFAuctionFrameMarketplace then OFAuctionFrameMarketplace:Hide() end
	if OFAuctionFrameCreateOffer then OFAuctionFrameCreateOffer:Hide() end
	if OFAuctionFrameCreateRequest then OFAuctionFrameCreateRequest:Hide() end
	if OFAuctionFrameOpen then OFAuctionFrameOpen:Hide() end
	if OFAuctionFramePending then OFAuctionFramePending:Hide() end
    
    SetAuctionsTabShowing(false)

	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)

	-- Reset all filters first
	OFAuctionFrameBrowse.showOnlyOffers = false
	OFAuctionFrameAuctions.isRequestMode = false
	OFAuctionFrameBid.showOpenOnly = false
	OFAuctionFrameBid.showPendingOnly = false
	
	-- Clear browse parameters when switching tabs
	prevBrowseParams = nil
	browseResultCache = nil
	
	-- Reset category selection
	OFAuctionFrameBrowse.selectedCategoryIndex = nil
	OFAuctionFrameBrowse.selectedSubCategoryIndex = nil
	OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil
	OF_OPEN_FILTER_LIST = {}
	
	if ( index == TAB_MARKETPLACE ) then
		-- Use existing Browse frame for Marketplace (offers only)
		OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopLeft");
		OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Top");
		OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopRight");
		OFAuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-BotLeft");
		OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
		OFAuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight");
		OFAuctionFrameBrowse.showOnlyOffers = true  -- Filter to show only offers
		OFAuctionFrameBrowse:Show();
		OFAuctionFrame.type = "list";
		-- Set "Seller" for Marketplace tab
		if OFBrowseHighBidderSort then
			OFBrowseHighBidderSort:SetText("Seller")
			-- Keep Seller column at fixed width
			OFBrowseHighBidderSort:SetWidth(117)
		end
		-- Show Price column but make it narrower
		if OFBrowseCurrentBidSort then
			OFBrowseCurrentBidSort:Show()
		end
		-- Hide bag items frame
		if OFBagItemsFrame then
			OFBagItemsFrame:Hide()
		end
		-- Update browse frame
		OFAuctionFrameBrowse_Update()
	elseif ( index == TAB_CREATE_OFFER ) then
		-- Use existing Auctions frame for Create Offer
        AssignCreateOrderTextures()
		OFAuctionFrameAuctions:Show();
		-- Show Price column header again
		if OFBrowseCurrentBidSort then
			OFBrowseCurrentBidSort:Show()
		end
		SetAuctionsTabShowing(true);
		-- Show bag items for Create Offer
		if OFBagItemsFrame then
			OFBagItemsFrame:Show()
			OFBagItemsFrame_Update()
		end
		-- Update auctions frame
		OFAuctionFrameAuctions_Update()
	-- elseif ( index == TAB_CREATE_REQUEST ) then -- removed tab
	-- elseif ( index == TAB_OPEN ) then -- removed tab
    elseif ( index == TAB_PENDING ) then
		-- Show pending fulfillments
        OFAuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopLeft");
        OFAuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
        OFAuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
        OFAuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft");
        OFAuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
		OFAuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight");
		OFAuctionFrameBid.showPendingOnly = true
		OFAuctionFrameBid:Show();
		OFAuctionFrame.type = "pending";
		-- Hide bag items frame
		if OFBagItemsFrame then
			OFBagItemsFrame:Hide()
		end
		-- Update bid frame
		OFAuctionFrameBid_Update()
	else
        AssignReviewTextures(true)
        OFAuctionFrameSettings:Show()
        OFAuctionFrame.type = "settings"
    end
end

-- Browse tab functions

function OFAuctionFrameBrowse_OnLoad(self)
    -- Initialize filter buttons array if not exists
    if not self.OFFilterButtons then
        self.OFFilterButtons = {}
        for i = 1, OF_NUM_FILTERS_TO_DISPLAY do
            local button = _G["OFFilterButton" .. i]
            if button then
                self.OFFilterButtons[i] = button
            end
        end
    end
    
    -- set default sort
    OFAuctionFrame_SetSort("list", "quality", true)

    local markDirty = function()
        browseResultCache = nil
    end
    local function markDirtyAndUpdate()
        markDirty()
        if OFAuctionFrame:IsShown() and OFAuctionFrameBrowse:IsShown() then
            OFAuctionFrameBrowse_Update()
        end
    end
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, function()
        markDirtyAndUpdate()
    end)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, markDirty)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, markDirty)

    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, markDirtyAndUpdate)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_DELETED, markDirtyAndUpdate)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_BLACKLIST_STATE_UPDATE, markDirtyAndUpdate)

	self.qualityIndex = FILTER_ALL_INDEX;
end



function OFAuctionFrameBrowse_UpdateArrows()
	OFSortButton_UpdateArrow(OFBrowseQualitySort, "list", "quality")
	OFSortButton_UpdateArrow(OFBrowseTypeSort, "list", "type")
    OFSortButton_UpdateArrow(OFBrowseLevelSort, "list", "level")
    OFSortButton_UpdateArrow(OFBrowseDeliverySort, "list", "delivery")
	OFSortButton_UpdateArrow(OFBrowseHighBidderSort, "list", "seller")
    OFSortButton_UpdateArrow(OFBrowseRatingSort, "list", "rating")
	OFSortButton_UpdateArrow(OFBrowseCurrentBidSort, "list", "bid")
end


function OFRequestItemButton_OnClick(button)
    ns.AuctionWishlistConfirmPrompt:Show(
        button:GetParent().itemID,
        nil,
        function(error) UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0) end,
        nil
    )
end

function OFSelectSpecialItemButton_OnClick(button)
    if button:GetParent().isEnchantEntry then
        ns.ShowAuctionSelectEnchantPrompt()
    else
        StaticPopup_Show("OF_SELECT_AUCTION_MONEY")
    end
end

function OFBrowseButton_OnClick(button)
	assert(button);
	
	OFSetSelectedAuctionItem("list", button.auction)
	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameBrowse_Update()
end

function OFAuctionFrameBrowse_Reset(self)
	OFBrowseName:SetText(OF_BROWSE_SEARCH_PLACEHOLDER)
	OFBrowseMinLevel:SetText("")
	OFBrowseMaxLevel:SetText("")
    OFOnlineOnlyCheckButton:SetChecked(false)
    OFAuctionsOnlyCheckButton:SetChecked(false)

	-- reset the filters
	OF_OPEN_FILTER_LIST = {}
	OFAuctionFrameBrowse.selectedCategoryIndex = nil
	OFAuctionFrameBrowse.selectedSubCategoryIndex = nil
	OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil

	OFAuctionFrameFilters_Update()
    OFAuctionFrameBrowse_Search()
    OFAuctionFrameBrowse_Update()
	self:Disable()
end

-- Reset button removed - function no longer needed
-- function OFBrowseResetButton_OnUpdate(self, elapsed)
--     local search = OFBrowseName:GetText()
-- 	if ( (search == "" or search == OF_BROWSE_SEARCH_PLACEHOLDER) and (OFBrowseMinLevel:GetText() == "") and (OFBrowseMaxLevel:GetText() == "") and
--          (not OFOnlineOnlyCheckButton:GetChecked()) and
-- 	     (not OFAuctionFrameBrowse.selectedCategoryIndex))
-- 	then
-- 		self:Disable()
-- 	else
-- 		self:Enable()
-- 	end
-- end

function OFAuctionFrame_SetSort(sortTable, sortColumn, oppositeOrder)
    local template = OFAuctionSort[sortTable.."_"..sortColumn]
    local sortParams = {}
	-- set the columns
	for index, row in pairs(template) do
		-- Browsing by the "bid" column will sort by whatever price sorrting option the user selected
		-- instead of always sorting by "bid" (total bid price)
		local sort = row.column;
        local reverse
		if (oppositeOrder) then
            reverse = not row.reverse
		else
            reverse = row.reverse
		end
        table.insert(sortParams, { column = sort, reverse = reverse })
	end
    currentSortParams[sortTable] = {
        column = sortColumn,
        desc = oppositeOrder,
        params = sortParams,
    }
    if sortTable == "list" then
        browseSortDirty = true
    end
end

function OFAuctionFrame_OnClickSortColumn(sortTable, sortColumn)
	-- change the sort as appropriate
	local existingSortColumn, existingSortReverse = GetAuctionSortColumn(sortTable)
	local oppositeOrder = false
	if (existingSortColumn and (existingSortColumn == sortColumn)) then
		oppositeOrder = not existingSortReverse
	elseif (sortColumn == "level") then
		oppositeOrder = true
	end

	-- set the new sort order
	OFAuctionFrame_SetSort(sortTable, sortColumn, oppositeOrder)

	-- apply the sort
    if (sortTable == "list") then
        OFAuctionFrameBrowse_Search()
    elseif(sortTable == "bidder") then
        OFAuctionFrameBid_Update()
    elseif (sortTable == "owner") then
        OFAuctionFrameAuctions_Update()
    end
end

local prevBrowseParams;
local function OFAuctionFrameBrowse_SearchHelper(...)
    local page = select(BROWSE_PARAM_INDEX_PAGE, ...);

	if ( not prevBrowseParams ) then
		-- if we are doing a search for the first time then create the browse param cache
		prevBrowseParams = { };
	else
		-- if we have already done a browse then see if any of the params have changed (except for the page number)
		local param;
		for i = 1, select('#', ...) do
            param = select(i, ...)
			if ( i ~= BROWSE_PARAM_INDEX_PAGE and param ~= prevBrowseParams[i] ) then
				-- if we detect a change then we want to reset the page number back to the first page
				page = 0;
				OFAuctionFrameBrowse.page = page;
				break;
			end
		end
	end

	-- store this query's params so we can compare them with the next set of params we get
	for i = 1, select('#', ...) do
		if ( i == BROWSE_PARAM_INDEX_PAGE ) then
			prevBrowseParams[i] = page;
		else
			prevBrowseParams[i] = select(i, ...);
		end
	end
end

function OFAuctionFrameBrowse_OnShow()
    -- Always trigger update when showing to ensure correct display
    browseResultCache = nil  -- Clear cache to force refresh
    
    -- Trigger update
    OFAuctionFrameBrowse_Update()
    
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
    
    -- Reset filters and update categories - force update
    OF_OPEN_FILTER_LIST = {}
    OFAuctionFrameBrowse.selectedCategoryIndex = nil
    OFAuctionFrameBrowse.selectedSubCategoryIndex = nil
    OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil
    OFAuctionFrameFilters_UpdateCategories()
    OFAuctionFrameFilters_Update()
    
    -- Trigger search and update
    OFAuctionFrameBrowse_Search()
    OFAuctionFrameBrowse_Update()
    
    local auctions = ns.GetBrowseAuctions({}, {})
    local itemIds = {}
    for _, auction in ipairs(auctions) do
        itemIds[auction.itemID] = ns.GetItemInfo(auction.itemID) ~= nil
    end

    local frame = CreateFrame("FRAME")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", function(self, event, ...)
        local itemId, success = ...
        if itemIds[itemId] ~= nil then
            itemIds[itemId] = true
        end
        local allDone = true
        for _, done in pairs(itemIds) do
            if not done then
                allDone = false
                break
            end
        end
        if allDone then
            OFAuctionFrameBrowse_Update()
            self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end)

    for itemId, hasInfo in pairs(itemIds) do
        if not hasInfo then
            C_Item.RequestLoadItemDataByID(itemId)
        end
    end
end
-- If string is quoted, return the string with the quotes removed, otherwise return nil.
local function DequoteString(s)
	-- Recognize the ASCII double character quote or (unlike mainline) Unicode curly double quotes.
	-- Also recognize the French "guillemet" double angle quote characters since the mainline
	-- auction house converts those to ASCII double quotes in CaseAccentInsensitiveParseInternal().
	-- Always recognize any of these quote characters, regardless of the user's locale setting.

	-- Unicode code points as UTF-8 strings.
	local doubleQuote = '"';					-- U+0022 Quotation Mark
	local leftDoubleQuote = "\226\128\156";		-- U+201C Left Double Quotation Mark
	local rightDoubleQuote = "\226\128\157";	-- U+201D Right Double Quotation Mark
	local leftGuillemet = "\194\171";			-- U+00AB Left-Pointing Double Angle Quotation Mark
	local rightGuillemet = "\194\187";			-- U+00BB Right-Pointing Double Angle Quotation Mark

	-- Check is the search string starts with a recognized opening quote and get its UTF-8 length.
	local quoteLen = 0;

	if (#s >= #doubleQuote and string.sub(s, 1, #doubleQuote) == doubleQuote) then
		quoteLen = #doubleQuote;
	elseif (#s >= #leftDoubleQuote and string.sub(s, 1, #leftDoubleQuote) == leftDoubleQuote) then
		quoteLen = #leftDoubleQuote;
	elseif (#s >= #leftGuillemet and string.sub(s, 1, #leftGuillemet) == leftGuillemet) then
		quoteLen = #leftGuillemet;
	end

	if (quoteLen == 0) then
		return nil;
	end

	-- Trim the opening quote
	s = string.sub(s, quoteLen + 1);

	-- Check is the search string ends with a recognized closing quote and get its UTF-8 length.
	quoteLen = 0;

	if (#s >= #doubleQuote and string.sub(s, -#doubleQuote) == doubleQuote) then
		quoteLen = #doubleQuote;
	elseif (#s >= #rightDoubleQuote and string.sub(s, -#rightDoubleQuote) == rightDoubleQuote) then
		quoteLen = #rightDoubleQuote;
	elseif (#s >= #rightGuillemet and string.sub(s, -#rightGuillemet) == rightGuillemet) then
		quoteLen = #rightGuillemet;
	end

	if (quoteLen == 0) then
		return nil;
	end

	-- Trim the closing quote	
	return string.sub(s, 1, -(quoteLen + 1));
end

function OFAuctionFrameBrowse_Search()
    if ( not OFAuctionFrameBrowse.page ) then
        OFAuctionFrameBrowse.page = 0;
    end

    -- If the search string is in quotes, do an exact match on the dequoted string, otherwise
    -- do the default substring search.
    local exactMatch = false;
    local text = OFBrowseName:GetText();
    if text == OF_BROWSE_SEARCH_PLACEHOLDER then
        OFBrowseName:SetTextColor(0.7, 0.7, 0.7);
        text = ""
    else
        OFBrowseName:SetTextColor(1, 1, 1);
    end
    local dequotedText = DequoteString(text);
    if ( dequotedText ~= nil ) then
        exactMatch = true;
        text = dequotedText;
    end
    local minLevel, maxLevel
    if OFBrowseMinLevel:GetText() ~= "" then
        minLevel = tonumber(OFBrowseMinLevel:GetNumber())
    end
    if OFBrowseMaxLevel:GetText() ~= "" then
        maxLevel = tonumber(OFBrowseMaxLevel:GetNumber())
    end

    OFAuctionFrameBrowse_SearchHelper(
        text,
        minLevel,
        maxLevel,
        OFAuctionFrameBrowse.selectedCategoryIndex,
        OFAuctionFrameBrowse.page,
        OFAuctionFrameBrowse.factionIndex,
        exactMatch,
        OFOnlineOnlyCheckButton:GetChecked(),
        OFAuctionsOnlyCheckButton:GetChecked()
    )
    -- after updating filters, we need to query auctions and item db again
    browseResultCache = nil

    OFAuctionFrameBrowse_Update()
    OFBrowseNoResultsText:SetText(BROWSE_NO_RESULTS);
end

function OFBrowseSearchButton_OnUpdate(self, elapsed)
    self:Enable();
    if ( OFBrowsePrevPageButton.isEnabled ) then
        OFBrowsePrevPageButton:Enable()
    else
        OFBrowsePrevPageButton:Disable()
    end
    if ( OFBrowseNextPageButton.isEnabled ) then
        OFBrowseNextPageButton:Enable()
    else
        OFBrowseNextPageButton:Disable()
    end
    OFAuctionFrameBrowse_UpdateArrows()

	if (OFAuctionFrameBrowse.isSearching) then
		if ( OFAuctionFrameBrowse.isSearchingThrottle <= 0 ) then
			OFAuctionFrameBrowse.dotCount = OFAuctionFrameBrowse.dotCount + 1;
			if ( OFAuctionFrameBrowse.dotCount > 3 ) then
				OFAuctionFrameBrowse.dotCount = 0
			end
			local dotString = "";
			for i=1, OFAuctionFrameBrowse.dotCount do
				dotString = dotString..".";
			end
			OFBrowseSearchDotsText:Show();
			OFBrowseSearchDotsText:SetText(dotString);
			OFBrowseNoResultsText:SetText(SEARCHING_FOR_ITEMS);
			OFAuctionFrameBrowse.isSearchingThrottle = 0.3;
		else
			OFAuctionFrameBrowse.isSearchingThrottle = OFAuctionFrameBrowse.isSearchingThrottle - elapsed;
		end
	else
		OFBrowseSearchDotsText:Hide();
	end
end

function OFAuctionFrameFilters_Update(forceSelectionIntoView)
	OFAuctionFrameFilters_UpdateCategories(forceSelectionIntoView);
	-- Update scrollFrame
	FauxScrollFrame_Update(OFBrowseFilterScrollFrame, #OF_OPEN_FILTER_LIST, OF_NUM_FILTERS_TO_DISPLAY, OF_BROWSE_FILTER_HEIGHT);
end

function OFAuctionFrameFilters_UpdateCategories(forceSelectionIntoView)
	-- Initialize the list of open filters
	OF_OPEN_FILTER_LIST = {};

	for categoryIndex, categoryInfo in ipairs(OFAuctionCategories) do
		local selected = OFAuctionFrameBrowse.selectedCategoryIndex and OFAuctionFrameBrowse.selectedCategoryIndex == categoryIndex;
        local blueHighlight = categoryInfo:HasFlag("BLUE_HIGHLIGHT")
        tinsert(OF_OPEN_FILTER_LIST, { name = categoryInfo.name, type = "category", categoryIndex = categoryIndex, selected = selected, isToken = false, blueHighlight=blueHighlight });

        if ( selected ) then
            OFAuctionFrameFilters_AddSubCategories(categoryInfo.subCategories);
        end
	end
	
	local hasScrollBar = #OF_OPEN_FILTER_LIST > OF_NUM_FILTERS_TO_DISPLAY;

	-- Display the list of open filters
	local offset = FauxScrollFrame_GetOffset(OFBrowseFilterScrollFrame);
	if ( forceSelectionIntoView and hasScrollBar and OFAuctionFrameBrowse.selectedCategoryIndex and ( not OFAuctionFrameBrowse.selectedSubCategoryIndex and not OFAuctionFrameBrowse.selectedSubSubCategoryIndex ) ) then
		if ( OFAuctionFrameBrowse.selectedCategoryIndex <= offset ) then
			FauxScrollFrame_OnVerticalScroll(OFBrowseFilterScrollFrame, math.max(0.0, (OFAuctionFrameBrowse.selectedCategoryIndex - 1) * OF_BROWSE_FILTER_HEIGHT), OF_BROWSE_FILTER_HEIGHT);
			offset = FauxScrollFrame_GetOffset(OFBrowseFilterScrollFrame);
		end
	end
	
	local dataIndex = offset;

	for i = 1, OF_NUM_FILTERS_TO_DISPLAY do
		local button = OFAuctionFrameBrowse.OFFilterButtons[i];
		button:SetWidth(hasScrollBar and 136 or 156);

		dataIndex = dataIndex + 1;

		if ( dataIndex <= #OF_OPEN_FILTER_LIST ) then
			local info = OF_OPEN_FILTER_LIST[dataIndex];

			if ( info ) then
				OFFilterButton_SetUp(button, info);
				
				if ( info.type == "category" ) then
					button.categoryIndex = info.categoryIndex;
				elseif ( info.type == "subCategory" ) then
					button.subCategoryIndex = info.subCategoryIndex;
				elseif ( info.type == "subSubCategory" ) then
					button.subSubCategoryIndex = info.subSubCategoryIndex;
				end
				
				if ( info.selected ) then
					button:LockHighlight();
				else
					button:UnlockHighlight();
				end
				button:Show();
			end
		else
			button:Hide();
		end
	end
end

function OFAuctionFrameFilters_AddSubCategories(subCategories)
	if subCategories then
		for subCategoryIndex, subCategoryInfo in ipairs(subCategories) do
			local selected = OFAuctionFrameBrowse.selectedSubCategoryIndex and OFAuctionFrameBrowse.selectedSubCategoryIndex == subCategoryIndex;

			tinsert(OF_OPEN_FILTER_LIST, { name = subCategoryInfo.name, type = "subCategory", subCategoryIndex = subCategoryIndex, selected = selected });
		 
			if ( selected ) then
				OFAuctionFrameFilters_AddSubSubCategories(subCategoryInfo.subCategories);
			end
		end
	end
end

function OFAuctionFrameFilters_AddSubSubCategories(subSubCategories)
	if subSubCategories then
		for subSubCategoryIndex, subSubCategoryInfo in ipairs(subSubCategories) do
			local selected = OFAuctionFrameBrowse.selectedSubSubCategoryIndex and OFAuctionFrameBrowse.selectedSubSubCategoryIndex == subSubCategoryIndex;
			local isLast = subSubCategoryIndex == #subSubCategories;

			tinsert(OF_OPEN_FILTER_LIST, { name = subSubCategoryInfo.name, type = "subSubCategory", subSubCategoryIndex = subSubCategoryIndex, selected = selected, isLast = isLast});
		end
	end
end

function OFFilterButton_SetUp(button, info)
	local normalText = _G[button:GetName().."NormalText"];
	local normalTexture = _G[button:GetName().."NormalTexture"];
	local line = _G[button:GetName().."Lines"];
	local tex = button:GetNormalTexture();

	if (info.blueHighlight) then
		tex:SetTexCoord(0, 1, 0, 1);
		tex:SetAtlas("token-button-category")
	else
		tex:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg");
		tex:SetTexCoord(0, 0.53125, 0, 0.625);
	end

	if ( info.type == "category" ) then
		button:SetNormalFontObject(GameFontNormalSmallLeft);
		button:SetText(info.name);
		normalText:SetPoint("LEFT", button, "LEFT", 4, 0);
		normalTexture:SetAlpha(1.0);	
		line:Hide();
	elseif ( info.type == "subCategory" ) then
		button:SetNormalFontObject(GameFontHighlightSmallLeft);
		button:SetText(info.name);
		normalText:SetPoint("LEFT", button, "LEFT", 12, 0);
		normalTexture:SetAlpha(0.4);
		line:Hide();
	elseif ( info.type == "subSubCategory" ) then
		button:SetNormalFontObject(GameFontHighlightSmallLeft);
		button:SetText(info.name);
		normalText:SetPoint("LEFT", button, "LEFT", 20, 0);
		normalTexture:SetAlpha(0.0);	
		
		if ( info.isLast ) then
			line:SetTexCoord(0.4375, 0.875, 0, 0.625);
		else
			line:SetTexCoord(0, 0.4375, 0, 0.625);
		end
		line:Show();
	end
	button.type = info.type; 
end

function OFAuctionFrameFilter_OnClick(self, button)
	if ( self.type == "category" ) then
		-- Special handling for "All" category (index 1) - always sets to nil (shows all)
		if ( self.categoryIndex == 1 ) then
			OFAuctionFrameBrowse.selectedCategoryIndex = nil;
		elseif ( OFAuctionFrameBrowse.selectedCategoryIndex == self.categoryIndex ) then
			OFAuctionFrameBrowse.selectedCategoryIndex = nil;
		else
			OFAuctionFrameBrowse.selectedCategoryIndex = self.categoryIndex;
            local sortParams = currentSortParams["list"]
            if sortParams and sortParams.column == "quality" and sortParams.desc then
                OFAuctionFrame_SetSort("list", "quality", false)
            end
		end
		OFAuctionFrameBrowse.selectedSubCategoryIndex = nil;
		OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
	elseif ( self.type == "subCategory" ) then
		if ( OFAuctionFrameBrowse.selectedSubCategoryIndex == self.subCategoryIndex ) then
			OFAuctionFrameBrowse.selectedSubCategoryIndex = nil;
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
		else
			OFAuctionFrameBrowse.selectedSubCategoryIndex = self.subCategoryIndex;
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
		end
	elseif ( self.type == "subSubCategory" ) then
		if ( OFAuctionFrameBrowse.selectedSubSubCategoryIndex == self.subSubCategoryIndex ) then
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = nil;
		else
			OFAuctionFrameBrowse.selectedSubSubCategoryIndex = self.subSubCategoryIndex
		end
	end
	OFAuctionFrameFilters_Update(true)
end

local function UpdateItemIcon(itemID, buttonName, texture, count, canUse)
    local iconTexture = _G[buttonName.."ItemIconTexture"];
    iconTexture:SetTexture(texture);
    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1);
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0);
    end
    local itemCount = _G[buttonName.."ItemCount"];
    if count > 1 and itemID ~= ns.ITEM_ID_GOLD then
        itemCount:SetText(count);
        itemCount:Show();
    else
        itemCount:Hide();
    end
end


local function UpdateItemName(quality, buttonName, name)
    -- Set name and quality color
    local color = ITEM_QUALITY_COLORS[quality];
    local itemName = _G[buttonName.."Name"];
    itemName:SetText(name);
    itemName:SetVertexColor(color.r, color.g, color.b);
end

local function ResizeEntryBrowse(i, button, numBatchAuctions, totalEntries)
    -- Resize button if there isn't a scrollbar
    local buttonHighlight = _G[button:GetName().."Highlight"]
    if ( numBatchAuctions < OF_NUM_BROWSE_TO_DISPLAY ) then
        button:SetWidth(625);
        buttonHighlight:SetWidth(589);
        OFBrowseCurrentBidSort:SetWidth(100);
    elseif ( numBatchAuctions == OF_NUM_BROWSE_TO_DISPLAY and totalEntries <= OF_NUM_BROWSE_TO_DISPLAY ) then
        button:SetWidth(625);
        buttonHighlight:SetWidth(589);
        OFBrowseCurrentBidSort:SetWidth(100);
    else
        button:SetWidth(600);
        buttonHighlight:SetWidth(562);
        OFBrowseCurrentBidSort:SetWidth(100);
    end
end

local function ResizeEntryAuctions(i, button, numBatchAuctions, totalEntries)
    -- Resize button if there isn't a scrollbar
    local buttonHighlight = _G[button:GetName().."Highlight"];
    if ( numBatchAuctions < OF_NUM_AUCTIONS_TO_DISPLAY ) then
        button:SetWidth(599);
        buttonHighlight:SetWidth(565);
    elseif ( numBatchAuctions == OF_NUM_AUCTIONS_TO_DISPLAY and totalEntries <= OF_NUM_AUCTIONS_TO_DISPLAY ) then
        button:SetWidth(599);
        buttonHighlight:SetWidth(565);
    else
        button:SetWidth(576);
        buttonHighlight:SetWidth(543);
    end
end

local function UpdateItemEntry(index, i, offset, button, item, numBatchAuctions, totalEntries, entryType)
    local icon
    local isGold = item.id == ns.ITEM_ID_GOLD
    if isGold then
        icon = item.icon
    else
        icon = select(5, ns.GetItemInfoInstant(item.id))
    end
    local name = item.name
    local quality = item.quality
    local level = item.level
    local buttonName = button:GetName()

    button:Show();

    if entryType == "list" then
        ResizeEntryBrowse(i, button, numBatchAuctions, totalEntries, entryType)
    elseif entryType == "owner" then
        ResizeEntryAuctions(i, button, numBatchAuctions, totalEntries, entryType)
    end

    UpdateItemName(quality, buttonName, name)

    UpdateItemIcon(item.id, buttonName, icon, 1, true)

    local function Hide(name)
        local frame = _G[buttonName..name]
        if frame then
            frame:Hide()
        end
    end

    Hide("AuctionType")
    Hide("DeliveryType")
    Hide("HighBidder")
    Hide("MoneyFrame")

    _G[buttonName.."RequestItem"]:Show()

    -- Hide Level column
    local levelText = _G[buttonName.."Level"]
    levelText:SetText("")
    levelText:Hide()

    Hide("DeathRollIcon")
    Hide("PriceText")
    Hide("RatingFrame")

    button.buyoutPrice = 0
    button.itemCount = 1
    button.itemIndex = index
    button.itemID = item.id
    button.isEnchantEntry = false
    button.auction = nil
    button:UnlockHighlight()
end

local function UpdateEnchantAuctionEntry(index, i, offset, button, numBatchAuctions, totalEntries)
    local icon = "Interface/Icons/Spell_holy_greaterheal"
    local name = "Enchants"
    local quality = 1
    local buttonName = button:GetName()

    button:Show()

    ResizeEntryAuctions(i, button, numBatchAuctions, totalEntries)

    UpdateItemName(quality, buttonName, name)

    UpdateItemIcon(0, buttonName, icon, 1, true)

    local function Hide(name)
        local frame = _G[buttonName..name]
        if frame then
            frame:Hide()
        end
    end

    Hide("AuctionType")
    Hide("DeliveryType")
    Hide("HighBidder")
    Hide("MoneyFrame")

    _G[buttonName.."RequestItem"]:Show()

    local levelText = _G[buttonName.."Level"]
    levelText:SetText("")

    Hide("DeathRollIcon")
    Hide("PriceText")
    Hide("RatingFrame")

    button.buyoutPrice = 0
    button.itemCount = 1
    button.itemIndex = index
    button.itemID = 0
    button.isEnchantEntry = true
    button:UnlockHighlight()
end


local function UpdateDeliveryType(buttonName, auction)
    local deliveryTypeFrame = _G[buttonName.."DeliveryType"];
    local deliveryTypeText = _G[buttonName.."DeliveryTypeText"];
    local deliveryTypeNoteIcon = _G[buttonName.."DeliveryTypeNoteIcon"];

    deliveryTypeText:SetText(ns.GetDeliveryTypeDisplayString(auction))
    deliveryTypeFrame.tooltip = ns.GetDeliveryTypeTooltip(auction)
    if auction.note and auction.note ~= "" then
        deliveryTypeNoteIcon:Show()
        deliveryTypeText:SetPoint("TOPLEFT", deliveryTypeFrame, "TOPLEFT", 14, 0)
    else
        deliveryTypeNoteIcon:Hide()
        deliveryTypeText:SetPoint("TOPLEFT", deliveryTypeFrame, "TOPLEFT", 0, 0)
    end
    deliveryTypeFrame:Show()
end

local function UpdatePrice(buttonName, auction)
    local button = _G[buttonName]
    local moneyFrame = _G[buttonName.."MoneyFrame"]
    local priceText = _G[buttonName.."PriceText"]
    local tipFrame = _G[buttonName.."TipMoneyFrame"]
    local deathRollIcon = _G[buttonName.."DeathRollIcon"]
    if tipFrame then
        tipFrame:Hide()
    end

    if auction.deathRoll or auction.duel then
        if deathRollIcon then
            deathRollIcon:Show()
            local iconXOffset
            if auction.deathRoll then
                deathRollIcon:SetTexture("Interface\\Addons\\" .. OF_AH_ADDON_NAME .. "\\Media\\icons\\Icn_DeathRoll")
                iconXOffset = -60
            else
                iconXOffset = -80
                deathRollIcon:SetTexture("Interface\\Addons\\" .. OF_AH_ADDON_NAME .. "\\Media\\icons\\Icn_Duel")
            end
            if auction.itemID == ns.ITEM_ID_GOLD then
                deathRollIcon:SetPoint("RIGHT", button, "RIGHT", iconXOffset, 3)
            else
                deathRollIcon:SetPoint("RIGHT", button, "RIGHT", iconXOffset, 10)
            end
        end
        
        MoneyFrame_Update(moneyFrame, auction.price)
        if priceText then
            if auction.deathRoll then
                priceText:SetText("Death Roll")
            else
                priceText:SetText("Duel (Normal)")
            end
            priceText:SetJustifyH("RIGHT")
            if auction.itemID == ns.ITEM_ID_GOLD then
                priceText:SetPoint("RIGHT", button, "RIGHT", -5, 3)
            else
                priceText:SetPoint("RIGHT", button, "RIGHT", -5, 10)
            end
            priceText:Show()
        end
        if auction.itemID == ns.ITEM_ID_GOLD then
            moneyFrame:Hide()
        else
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 10, -4)
            moneyFrame:Show()
        end
    elseif auction.priceType == ns.PRICE_TYPE_MONEY then
        if deathRollIcon then
            deathRollIcon:Hide()
        end
        if priceText then
            priceText:Hide()
        end
        moneyFrame:Show()
        MoneyFrame_Update(moneyFrame, auction.price)
        if auction.tip > 0 and tipFrame then
            tipFrame:Show()
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 10, 10)
            MoneyFrame_Update(_G[tipFrame:GetName().."Money"], auction.tip)
        else
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 10, 3)
        end
    elseif auction.priceType == ns.PRICE_TYPE_TWITCH_RAID then
        if deathRollIcon then
            deathRollIcon:Hide()
        end
        if priceText then
            priceText:SetJustifyH("CENTER")
            priceText:SetPoint("RIGHT", button, "RIGHT", 0, 3)
            priceText:SetText(string.format("Twitch Raid %d+", auction.raidAmount))
            priceText:Show()
        end
        moneyFrame:Hide()
    else
        if deathRollIcon then
            deathRollIcon:SetTexture("Interface\\Addons\\" .. OF_AH_ADDON_NAME .. "\\Media\\Icn_Note02")
            deathRollIcon:SetPoint("RIGHT", button, "RIGHT", -47, 3)
            deathRollIcon:Show()
        end
        if priceText then
            priceText:SetJustifyH("RIGHT")
            priceText:SetPoint("RIGHT", button, "RIGHT", -5, 3)
            priceText:SetText("Custom")
            priceText:Show()
        end
        moneyFrame:Hide()
    end
end

local function UpdateBrowseEntry(index, i, offset, button, auction, numBatchAuctions, totalEntries)
    local name, _, quality, level, _, _, _, _, _, texture, _  = ns.GetItemInfo(auction.itemID, auction.quantity)
    local buyoutPrice = auction.price
    local owner = auction.owner
    local ownerFullName = auction.owner
    local count = auction.quantity
    -- TODO jan easy way to check if item is usable?
    local canUse = true

    button:Show()

    local buttonName = "OFBrowseButton"..i

    ResizeEntryBrowse(i, button, numBatchAuctions, totalEntries)

    UpdateItemName(quality, buttonName, name)
    local itemButton = _G[buttonName.."Item"]

    local requestItem = _G[buttonName.."RequestItem"]
    if requestItem then
        requestItem:Hide()
    end

    -- Hide Type column
    local auctionTypeText = _G[buttonName.."AuctionTypeText"]
    if auctionTypeText then
        auctionTypeText:SetText("")
    end
    local auctionType = _G[buttonName.."AuctionType"]
    if auctionType then
        auctionType:Hide()
    end

    -- Hide Level column (removed from template)
    -- Level field was removed during template simplification

    -- Hide Rating column
    local ratingFrame = _G[buttonName.."RatingFrame"]
    if ratingFrame then
        ratingFrame:Hide()
    end

    -- Hide Misc/Delivery column
    local deliveryTypeFrame = _G[buttonName.."DeliveryType"]
    if deliveryTypeFrame then
        deliveryTypeFrame:Hide()
    end

    UpdateItemIcon(auction.itemID, buttonName, texture, count, canUse)

    UpdatePrice(buttonName, auction)
    MoneyFrame_SetMaxDisplayWidth(_G[buttonName.."MoneyFrame"], 90)

    local ownerFrame = _G[buttonName.."HighBidder"]
    ownerFrame.fullName = ownerFullName
    ownerFrame.Name:SetText(ns.GetDisplayName(owner))
    ownerFrame:Show()

    -- this is for comparing to the player name to see if they are the owner of this auction
    local ownerName;
    if (not ownerFullName) then
        ownerName = owner
    else
        ownerName = ownerFullName
    end

    button.auction = auction
    button.buyoutPrice = buyoutPrice
    button.itemCount = count
    button.itemIndex = index
    button.itemID = auction.itemID
    -- Set highlight
    local selected = OFGetSelectedAuctionItem("list")
    if ( selected and selected.id == auction.id) then
        button:LockHighlight()

        local canBuyout = 1
        if ( GetMoney() < buyoutPrice ) then
            canBuyout = nil
        end
        if ( (ownerName ~= UnitName("player")) ) then
            if auction.auctionType == ns.AUCTION_TYPE_BUY then
                if ns.GetItemCount(auction.itemID, true) >= auction.quantity then
                    OFBrowseFulfillButton:Enable()
                end
            else
                if canBuyout then
                    OFBrowseBuyoutButton:Enable()
                end
                -- Loan button removed
                -- if auction.allowLoan then
                --     OFBrowseLoanButton:Enable()
                -- end
            end
            OFAuctionFrame.buyoutPrice = buyoutPrice
            OFAuctionFrame.auction = auction
        end
    else
        button:UnlockHighlight()
    end

    if ( button.PriceTooltipFrame == activeTooltipPriceTooltipFrame ) then
        OFAuctionPriceTooltipFrame_OnEnter(button.PriceTooltipFrame)
    elseif ( itemButton == activeTooltipAuctionFrameItem ) then
        OFAuctionFrameItem_OnEnter(itemButton, "list")
    end
end

function OFAuctionFrameBrowse_Update()
    local auctions, items
    if browseResultCache ~= nil then
        auctions, items = browseResultCache.auctions, browseResultCache.items
    else
        -- For Marketplace, we want to see ALL offers including our own
        if OFAuctionFrameBrowse.showOnlyOffers then
            -- Get ALL auctions without the owner filter
            local allAuctions = ns.AuctionHouseAPI:QueryAuctions(function(item) 
                return item.status == ns.AUCTION_STATUS_ACTIVE 
            end)
            auctions = allAuctions or {}
        else
            auctions = ns.GetBrowseAuctions and ns.GetBrowseAuctions(prevBrowseParams or {}) or {}
        end
        if prevBrowseParams and ns.IsDefaultBrowseParams and not ns.IsDefaultBrowseParams(prevBrowseParams) then
            items = ns.ItemDB and ns.BrowseParamsToItemDBArgs and ns.ItemDB:Find(ns.BrowseParamsToItemDBArgs(prevBrowseParams or {})) or {}
        else
            items = {}
        end
        browseResultCache = { auctions = auctions, items = items }
        browseSortDirty = true
    end
    
    -- DEBUG: Log auction count
    -- Debug removed: Found auctions and items
    if browseSortDirty then
        local sortParams = currentSortParams["list"].params
        auctions = ns.SortAuctions and ns.SortAuctions(auctions, sortParams) or auctions
        items = ns.SortAuctions and ns.SortAuctions(items, sortParams) or items
        browseResultCache = { auctions = auctions, items = items }
        browseSortDirty = false
    end
    
    -- Filter based on current tab
    if OFAuctionFrameBrowse.showOnlyOffers then
        -- Marketplace tab: Show only offers (selling items, not buying requests)
        local filteredAuctions = {}
        for _, auction in ipairs(auctions) do
            -- Check if this is a sell offer (not a buy request)
            if auction.auctionType == ns.AUCTION_TYPE_SELL then
                table.insert(filteredAuctions, auction)
            end
        end
        auctions = filteredAuctions
        items = {}  -- No wishlist items in marketplace
    end

    local totalEntries = #auctions + #items
    -- gold item always the first item (only for non-filtered views and not in marketplace/requests tabs)
    local currentTab = OFAuctionFrame.selectedTab
    local shouldShowGold = not OFAuctionFrameBrowse.showOnlyOffers
                          and currentTab ~= TAB_MARKETPLACE
                          and currentTab ~= TAB_CREATE_OFFER and currentTab ~= TAB_CREATE_REQUEST
    if shouldShowGold then
        totalEntries = totalEntries + 1
    end
    local numBatchAuctions = min(totalEntries, OF_NUM_AUCTION_ITEMS_PER_PAGE)
    local button;
    local offset = FauxScrollFrame_GetOffset(OFBrowseScrollFrame);
    
    -- DEBUG: Log rendering info
    -- Debug removed: Rendering info
    local index;
    local isLastSlotEmpty;
    local hasAllInfo, itemName;
    OFBrowseBuyoutButton:Show();
    -- OFBrowseLoanButton:Show(); -- Loan button removed
    OFBrowseBuyoutButton:Disable();
    -- OFBrowseLoanButton:Disable(); -- Loan button removed
    OFBrowseFulfillButton:Disable();
    -- Update sort arrows
    OFAuctionFrameBrowse_UpdateArrows();

    -- Show the no results text if no items found
    if ( numBatchAuctions == 0 ) then
        OFBrowseNoResultsText:Show();
    else
        OFBrowseNoResultsText:Hide();
    end

    for i=1, OF_NUM_BROWSE_TO_DISPLAY do
        index = offset + i + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameBrowse.page);
        button = _G["OFBrowseButton"..i];
        -- Adjust auction index based on whether Gold item is shown
        local auctionIndex = shouldShowGold and (index - 1) or index
        local auction = auctions[auctionIndex]
        local shouldHide = not auction or index > (numBatchAuctions + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameBrowse.page));
        
        -- DEBUG: Log each button
        -- Debug removed: Button info
        if ( not shouldHide ) then
            itemName = ns.GetItemInfo(auction.itemID, auction.quantity)
            hasAllInfo = itemName ~= nil and auction ~= nil
            -- Debug removed: Item info
            if ( not hasAllInfo ) then --Bug  145328
                shouldHide = true;
                -- Debug removed: Hidden info
            end
        end

        if ( auction ) then
            button.auctionId = auction.id
        else
            button.auctionId = nil
        end
        local isItem = (shouldShowGold and index == 1) or ((index > (#auctions + (shouldShowGold and 1 or 0)) and (index - (shouldShowGold and 1 or 0) - #auctions) <= #items))
        -- Show or hide auction buttons
        if isItem then
            auction = nil
            local item
            if shouldShowGold and index == 1 then
                item = ns.ITEM_GOLD
            else
                item = items[index - (shouldShowGold and 1 or 0) - #auctions]
            end
            ns.TryExcept(
                function() UpdateItemEntry(index, i, offset, button, item, numBatchAuctions, totalEntries, "list") end,
                function(err)
                    button:Hide()
                    ns.DebugLog("Browse UpdateItemEntry failed: ", err)
                end
            )

        elseif ( shouldHide ) then
            button:Hide();
            -- If the last button is empty then set isLastSlotEmpty var
            if ( i == OF_NUM_BROWSE_TO_DISPLAY ) then
                isLastSlotEmpty = 1;
            end
            if auction ~= nil and itemName == nil then
                local deferredI, deferredIndex, deferredAuction, deferredOffset = i, index, auction, offset
                ns.GetItemInfoAsync(auction.itemID, function (...)
                    local deferredButton = _G["OFBrowseButton"..deferredI]
                    if (deferredButton.auctionId == deferredAuction.id) then
                        deferredButton:Show()
                        ns.TryExcept(
                            function() UpdateBrowseEntry(deferredIndex, deferredI, deferredOffset, deferredButton, deferredAuction, numBatchAuctions, totalEntries) end,
                            function(err) deferredButton:Hide(); ns.DebugLog("rendering deferred browse entry failed: ", err) end
                        )
                    end
                end)
            end
        else
            -- Debug removed: Render attempt
            ns.TryExcept(
                function() 
                    button:Show()
                    UpdateBrowseEntry(index, i, offset, button, auction, numBatchAuctions, totalEntries) 
                    -- Debug removed: Success
                end,
                function(err) 
                    button:Hide()
                    -- Error in rendering, silently continue
                    ns.DebugLog("rendering browse entry failed: ", err) 
                end
            )
        end
    end

    -- Update scrollFrame
    -- If more than one page of auctions, show the next and prev arrows and show the item ranges of the active page
    --  when page the scrollframe is scrolled all the way down
    if ( totalEntries > OF_NUM_AUCTION_ITEMS_PER_PAGE ) then
        OFBrowsePrevPageButton.isEnabled = (OFAuctionFrameBrowse.page ~= 0);
        OFBrowseNextPageButton.isEnabled = (OFAuctionFrameBrowse.page ~= (ceil(totalEntries /OF_NUM_AUCTION_ITEMS_PER_PAGE) - 1));
        if ( isLastSlotEmpty ) then
            OFBrowseSearchCountText:Show();
            local itemsMin = OFAuctionFrameBrowse.page * OF_NUM_AUCTION_ITEMS_PER_PAGE + 1;
            local itemsMax = itemsMin + numBatchAuctions - 1;
            OFBrowseSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalEntries);
        else
            OFBrowseSearchCountText:Hide();
        end

        -- Artifically inflate the number of results so the scrollbar scrolls one extra row
        numBatchAuctions = numBatchAuctions + 1;
    else
        OFBrowsePrevPageButton.isEnabled = false;
        OFBrowseNextPageButton.isEnabled = false;
        OFBrowseSearchCountText:Hide();
    end
    FauxScrollFrame_Update(OFBrowseScrollFrame, numBatchAuctions, OF_NUM_BROWSE_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT);
end

local function UpdatePendingEntry(index, i, offset, button, auction, numBatchAuctions, totalAuctions)
    local name, _, quality, _, _, _, _, _, _, texture, _  = ns.GetItemInfo(auction.itemID, auction.quantity)
    local buyoutPrice = auction.price
    local count = auction.quantity
    -- TODO jan easy way to check if item is usable?
    local canUse = true

    button:Show()

    local buttonName = "OFBidButton"..i

    -- Resize button if there isn't a scrollbar
    local buttonHighlight = _G[buttonName.."Highlight"];
    if ( numBatchAuctions < OF_NUM_BIDS_TO_DISPLAY ) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    elseif ( numBatchAuctions == OF_NUM_BIDS_TO_DISPLAY and totalAuctions <= OF_NUM_BIDS_TO_DISPLAY ) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    else
        button:SetWidth(769)
        buttonHighlight:SetWidth(735)
    end
    -- Set name and quality color
    local color = ITEM_QUALITY_COLORS[quality] or { r = 255, g = 255, b = 255 }
    local itemName = _G[buttonName.."Name"]
    itemName:SetText(name)
    itemName:SetVertexColor(color.r, color.g, color.b)


    local otherUserText = _G[buttonName.."BidBuyer"]
    local otherUser
    if auction.owner == UnitName("player") then
        otherUser = auction.buyer
    else
        otherUser = auction.owner
    end
    otherUserText:SetText(ns.GetDisplayName(otherUser))

    local statusText = _G[buttonName.."BidStatus"]
    statusText:SetText(ns.GetAuctionStatusDisplayString(auction))

    -- Set item texture, count, and usability
    local iconTexture = _G[buttonName.."ItemIconTexture"]
    iconTexture:SetTexture(texture)
    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1)
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0)
    end
    local itemCount = _G[buttonName.."ItemCount"]
    if auction.itemID ~= ns.ITEM_ID_GOLD and count > 1 then
        itemCount:SetText(count)
        itemCount:Show()
    else
        itemCount:Hide()
    end

    -- Hide Misc/Delivery column
    local deliveryTypeFrame = _G[buttonName.."DeliveryType"]
    if deliveryTypeFrame then
        deliveryTypeFrame:Hide()
    end

    local auctionType = auction.wish and ns.AUCTION_TYPE_BUY or ns.AUCTION_TYPE_SELL
    local auctionTypeText = _G[buttonName.."AuctionTypeText"]
    auctionTypeText:SetText(ns.GetAuctionTypeDisplayString(auctionType))

    _G[buttonName.."RatingFrame"].ratingWidget:SetRating(ns.AuctionHouseAPI:GetAverageRatingForUser(otherUser))

    local statusTooltip = _G[buttonName.."StatusTooltipFrame"]
    statusTooltip.tooltip = ns.GetAuctionStatusTooltip(auction)

    -- Set buyout price
    UpdatePrice(buttonName, auction)

    button.buyoutPrice = buyoutPrice;
    button.itemCount = count;
    button.itemID = auction.itemID
    button.auction = auction

    -- Set highlight
    local selected = OFGetSelectedAuctionItem("bidder")
    if ( selected and selected.id == auction.id) then
        button:LockHighlight();
        local me = UnitName("player")
        local isOwner
        if auction.wish then
            isOwner = auction.buyer == me
        else
            isOwner = auction.owner == me
        end
        local otherMember = auction.owner == me and auction.buyer or auction.owner
        if ns.GuildRegister:IsMemberOnline(otherMember) then
            OFBidWhisperButton:Enable()
            OFBidInviteButton:Enable()
        end
        local isLoan = auction.status == ns.AUCTION_STATUS_SENT_LOAN or auction.status == ns.AUCTION_STATUS_PENDING_LOAN
        if ns.IsSpellItem(auction.itemID) then
            OFBidForgiveLoanButtonText:SetText("Mark Auction Complete")
            if auction.owner == me then
                OFBidForgiveLoanButton:Enable()
            end
        elseif isLoan and auction.owner ~= me then
            OFBidForgiveLoanButtonText:SetText("Declare Bankruptcy")
            if auction.status == ns.AUCTION_STATUS_SENT_LOAN then
                OFBidForgiveLoanButton:Enable()
            end
        else
            OFBidForgiveLoanButtonText:SetText("Mark Loan Complete")
        end

        if not isOwner then
            -- auction can't be cancelled
        elseif auction.status == ns.AUCTION_STATUS_SENT_LOAN then
            OFBidForgiveLoanButton:Enable()
        elseif auction.status == ns.AUCTION_STATUS_SENT_COD then
            -- auction can't be cancelled
        else
            OFBidCancelAuctionButton:Enable()
        end
        OFAuctionFrame.buyoutPrice = buyoutPrice;
        OFAuctionFrame.auction = auction
    else
        button:UnlockHighlight();
    end
end

function OFAuctionFrameBid_OnLoad()
    OFAuctionFrame_SetSort("bidder", "quality", false);
    local callback = function(...)
        if OFAuctionFrame:IsShown() and OFAuctionFrameBid:IsShown() then
            OFAuctionFrameBid_Update();
        end
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, callback)
end

function OFAuctionFrameBid_Update()
    local auctions
    
    -- Filter based on current view
    if OFAuctionFrameBid.showOpenOnly then
        -- Open tab: Show only active auctions (not completed)
        local allAuctions = ns.GetMyActiveAuctions and ns.GetMyActiveAuctions(currentSortParams["owner"].params) or {}
        auctions = {}
        for _, auction in ipairs(allAuctions) do
            if not auction.buyer and not auction.fulfilled then
                table.insert(auctions, auction)
            end
        end
    elseif OFAuctionFrameBid.showPendingOnly then
        -- Pending tab: Show only pending fulfillment
        auctions = ns.GetMyPendingAuctions and ns.GetMyPendingAuctions(currentSortParams["bidder"].params) or {}
    else
        -- Default: Show all pending auctions
        auctions = ns.GetMyPendingAuctions and ns.GetMyPendingAuctions(currentSortParams["bidder"].params) or {}
    end
    
    local totalAuctions = #auctions
    local numBatchAuctions = min(totalAuctions, OF_NUM_AUCTION_ITEMS_PER_PAGE)
	local button, auction
	local offset = FauxScrollFrame_GetOffset(OFBidScrollFrame);
	local index;
	local isLastSlotEmpty;
    OFBidCancelAuctionButton:Disable()
    OFBidForgiveLoanButton:Disable()
    OFBidWhisperButton:Disable()
    OFBidInviteButton:Disable()

    -- Update sort arrows
	OFSortButton_UpdateArrow(OFBidQualitySort, "bidder", "quality")
    OFSortButton_UpdateArrow(OFBidTypeSort, "bidder", "type")
    OFSortButton_UpdateArrow(OFBidDeliverySort, "bidder", "delivery")
    OFSortButton_UpdateArrow(OFBidBuyerName, "bidder", "buyer")
    OFSortButton_UpdateArrow(OFBidRatingSort, "bidder", "rating")
    OFSortButton_UpdateArrow(OFBidStatusSort, "bidder", "status")
	OFSortButton_UpdateArrow(OFBidBidSort, "bidder", "bid")

	for i=1, OF_NUM_BIDS_TO_DISPLAY do
		index = offset + i;
		button = _G["OFBidButton"..i]

        auction = auctions[index]
        if (auction) then
            button.auctionId = auction.id
        else
            button.auctionId = nil
        end
		-- Show or hide auction buttons
		if ( auction == nil or index > numBatchAuctions ) then
			button:Hide();
			-- If the last button is empty then set isLastSlotEmpty var
			isLastSlotEmpty = (i == OF_NUM_BIDS_TO_DISPLAY);
		else
			button:Show()
            local itemName = ns.GetItemInfo(auction.itemID)
            if (itemName) then
                ns.TryExcept(
                        function() UpdatePendingEntry(index, i, offset, button, auctions[index], numBatchAuctions, totalAuctions) end,
                        function(err) button:Hide(); ns.DebugLog("rendering pending entry failed: ", err) end
                )
            else
                local deferredI, deferredIndex, deferredAuction, deferredOffset = i, index, auction, offset
                ns.GetItemInfoAsync(auction.itemID, function (...)
                    local deferredButton = _G["OFBidButton"..deferredI]
                    if (deferredButton.auctionId == deferredAuction.id) then
                        deferredButton:Show()
                        ns.TryExcept(
                                function() UpdatePendingEntry(deferredIndex, deferredI, deferredOffset, deferredButton, deferredAuction, numBatchAuctions, totalAuctions) end,
                                function(err) deferredButton:Hide(); ns.DebugLog("rendering deferred pending entry failed: ", err) end
                        )
                    end
                end)
            end
		end
	end
	-- If more than one page of auctions show the next and prev arrows when the scrollframe is scrolled all the way down
	if ( totalAuctions > OF_NUM_AUCTION_ITEMS_PER_PAGE ) then
		if ( isLastSlotEmpty ) then
			OFBidSearchCountText:Show()
			OFBidSearchCountText:SetFormattedText(SINGLE_PAGE_RESULTS_TEMPLATE, totalAuctions)
		else
			OFBidSearchCountText:Hide()
		end
		
		-- Artifically inflate the number of results so the scrollbar scrolls one extra row
		numBatchAuctions = numBatchAuctions + 1
	else
		OFBidSearchCountText:Hide()
	end

	-- Update scrollFrame
	FauxScrollFrame_Update(OFBidScrollFrame, numBatchAuctions, OF_NUM_BIDS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
end

function OFBidButton_OnClick(button)
	assert(button)
	
	OFSetSelectedAuctionItem("bidder", button.auction)
	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameBid_Update()
end

function OFIsGoldItemSelected()
    local itemID = select(10, OFGetAuctionSellItemInfo())
    return itemID == ns.ITEM_ID_GOLD
end

function OFIsSpellItemSelected()
    local itemID = select(10, OFGetAuctionSellItemInfo())
    return itemID and ns.IsSpellItem(itemID)
end
-- OFAuctions tab functions

function OFSetupPriceTypeDropdown(self)
    local isGoldSelected = OFIsGoldItemSelected()
    if isGoldSelected then
        self.priceTypeIndex = ns.PRICE_TYPE_CUSTOM
    else
        self.priceTypeIndex = ns.PRICE_TYPE_MONEY
    end

    local function IsPriceSelected(index)
        return self.priceTypeIndex == index
    end

    local function SetPriceSelected(index)
        if index == ns.PRICE_TYPE_TWITCH_RAID then
            deathRoll = false
            duel = false
        end
        self.priceTypeIndex = index
        OFUpdateAuctionSellItem()
    end

    OFPriceTypeDropdown:SetupMenu(function(dropdown, rootDescription)
        if not isGoldSelected then
            rootDescription:CreateRadio("Gold", IsPriceSelected, SetPriceSelected, ns.PRICE_TYPE_MONEY)
        end
        rootDescription:CreateRadio("Twitch Raid", IsPriceSelected, SetPriceSelected, ns.PRICE_TYPE_TWITCH_RAID)
        rootDescription:CreateRadio("Custom", IsPriceSelected, SetPriceSelected, ns.PRICE_TYPE_CUSTOM)
    end)
end


function OFSetupDeliveryDropdown(self, overrideDeliveryType)
    local isSpellSelected = OFIsSpellItemSelected()
    if isSpellSelected then
        self.deliveryTypeIndex = ns.DELIVERY_TYPE_TRADE
    else
        self.deliveryTypeIndex = overrideDeliveryType or ns.DELIVERY_TYPE_ANY
    end

    local function IsDeliverySelected(index)
        return self.deliveryTypeIndex == index
    end

    local function SetDeliverySelected(index)
        self.deliveryTypeIndex = index
        if index ~= ns.DELIVERY_TYPE_TRADE then
            deathRoll = false
            duel = false
            roleplay = false
            OFUpdateAuctionSellItem()
        end
    end

    OFDeliveryDropdown:SetupMenu(function(dropdown, rootDescription)
        if not OFIsSpellItemSelected() then
            rootDescription:CreateRadio("Any", IsDeliverySelected, SetDeliverySelected, ns.DELIVERY_TYPE_ANY)
            rootDescription:CreateRadio("Mail", IsDeliverySelected, SetDeliverySelected, ns.DELIVERY_TYPE_MAIL)
        end
        rootDescription:CreateRadio("Trade", IsDeliverySelected, SetDeliverySelected, ns.DELIVERY_TYPE_TRADE)
    end)
end

function OFAuctionFrameAuctions_OnLoad(self)
    local callback = function(...)
        if OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
            OFAuctionFrameAuctions_Update();
        end
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_ADD_OR_UPDATE, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_AUCTION_DELETED, callback)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_AUCTION_STATE_UPDATE, callback)
    -- set default sort
    OFAuctionFrame_SetSort("owner", "duration", false);

    OFSetupPriceTypeDropdown(self)
    OFSetupDeliveryDropdown(self)

    hooksecurefunc(_G, "ContainerFrameItemButton_OnModifiedClick", function(item, button, ...)
        -- Check if auction house is open and we're in Create Offer or Create Request tab
        if IsShiftKeyDown() and OFAuctionFrame:IsShown() then
            local currentTab = OFAuctionFrame.selectedTab
            if currentTab == TAB_CREATE_OFFER or currentTab == TAB_CREATE_REQUEST then
                local bagIdx, slotIdx = item:GetParent():GetID(), item:GetID()
                
                -- Check if item is soulbound (not tradable)
                local tooltip = CreateFrame("GameTooltip", "OFTempTooltip", UIParent, "GameTooltipTemplate")
                tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                tooltip:SetBagItem(bagIdx, slotIdx)
                
                local isSoulbound = false
                for i = 1, tooltip:NumLines() do
                    local text = _G["OFTempTooltipTextLeft"..i]:GetText()
                    if text and (text:find(ITEM_SOULBOUND) or text:find("Binds when picked up")) then
                        isSoulbound = true
                        break
                    end
                end
                
                -- Only allow tradable items
                if not isSoulbound then
                    -- For Classic, use different API
                    if C_Container and C_Container.PickupContainerItem then
                        C_Container.PickupContainerItem(bagIdx, slotIdx)
                    else
                        PickupContainerItem(bagIdx, slotIdx)
                    end
                    OFAuctionSellItemButton_OnClick(OFAuctionsItemButton, "LeftButton")
                end
            end
        end
    end)
end

function OFAuctionFrameAuctions_OnEvent(self, event, ...)
	if ( event == "AUCTION_OWNED_LIST_UPDATE") then
		OFAuctionFrameAuctions_Update();
	end
end

local function DeselectAuctionItem()
    if not OFGetAuctionSellItemInfo() then
        return
    end

    OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
    OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
    UnlockCheckButton(OFAllowLoansCheckButton)
    local prev = GetCVar("Sound_EnableSFX")
    SetCVar("Sound_EnableSFX", 0)
    ns.TryFinally(
            function()
                ClearCursor()
                ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
                ClearCursor()
                auctionSellItemInfo = nil
                OFUpdateAuctionSellItem()
            end,
            function()
                SetCVar("Sound_EnableSFX", prev)
            end
    )
end

function OFAuctionFrameAuctions_OnHide(self)
    DeselectAuctionItem()
end

function OFAuctionFrameAuctions_OnShow()
    -- Hide unwanted UI elements
    if OFAllowLoansCheckButton then OFAllowLoansCheckButton:Hide() end
    if OFRoleplayCheckButton then OFRoleplayCheckButton:Hide() end
    if OFDeathRollCheckButton then OFDeathRollCheckButton:Hide() end
    if OFDuelCheckButton then OFDuelCheckButton:Hide() end
    
    -- Trigger update
    OFAuctionFrameAuctions_Update()
    if OFPriceTypeDropdown then OFPriceTypeDropdown:Hide() end
    if OFPriceTypeDropdownName then OFPriceTypeDropdownName:Hide() end
    
    local currentTab = OFAuctionFrame.selectedTab
    
    if OFAuctionFrameAuctions.isRequestMode then
        OFAuctionsTitle:SetFormattedText("OnlyFangs AH - Create Request")
        -- Hide offer-specific elements and show request elements
        if OFAuctionsCreateAuctionButton then
            OFAuctionsCreateAuctionButton:SetText("Create Request")
        end
    else
        OFAuctionsTitle:SetFormattedText("OnlyFangs AH - Create Offer")
        if OFAuctionsCreateAuctionButton then
            OFAuctionsCreateAuctionButton:SetText("Create Offer")
        end
    end
    
    -- Adjust column headers for Create Offer tab - use Marketplace-style columns
    if currentTab == TAB_CREATE_OFFER then
        -- Match Marketplace layout with adjusted widths
        if OFAuctionsQualitySort then 
            OFAuctionsQualitySort:SetText("Item")
            OFAuctionsQualitySort:Show()
            OFAuctionsQualitySort:SetWidth(350)  -- Increased by 30px
            OFAuctionsQualitySort:ClearAllPoints()
            OFAuctionsQualitySort:SetPoint("TOPLEFT", OFAuctionFrameAuctions, "TOPLEFT", 220, -51)  -- 10px more left
        end
        
        -- Hide Level column
        if OFAuctionsLevelSort then 
            OFAuctionsLevelSort:Hide() 
        end
        
        -- Hide Type column (we'll use a custom header)
        if OFAuctionsTypeSort then 
            OFAuctionsTypeSort:Hide()
        end
        
        -- Hide Delivery column
        if OFAuctionsDeliverySort then 
            OFAuctionsDeliverySort:Hide() 
        end
        
        -- Keep Price column but make it smaller
        if OFAuctionsBidSort then 
            OFAuctionsBidSort:SetText("Price")
            OFAuctionsBidSort:Show()
            OFAuctionsBidSort:SetWidth(110)  -- Reduced by 30px
            OFAuctionsBidSort:ClearAllPoints()
            OFAuctionsBidSort:SetPoint("TOPLEFT", OFAuctionsQualitySort, "TOPLEFT", 468, 0)  -- Moved right by 30px (438 + 30)
        end
        
        -- Create "Created At" header as a clickable button
        if not OFAuctionsCreatedAtText then
            local button = CreateFrame("Button", "OFAuctionsCreatedAtButton", OFAuctionFrameAuctions)
            button:SetSize(120, 19)  -- 20px wider
            button:SetPoint("TOPLEFT", OFAuctionFrameAuctions, "TOPLEFT", 570, -52)  -- Moved right by 30px
            button:SetFrameLevel(OFAuctionFrameAuctions:GetFrameLevel() + 2)  -- Same level as other headers
            
            -- Create background textures exactly like other sort buttons
            local left = button:CreateTexture(button:GetName().."Left", "BACKGROUND")
            left:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
            left:SetTexCoord(0, 0.078125, 0, 0.59375)
            left:SetSize(5, 19)
            left:SetPoint("TOPLEFT", 0, 0)
            
            local right = button:CreateTexture(button:GetName().."Right", "BACKGROUND")
            right:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
            right:SetTexCoord(0.90625, 0.96875, 0, 0.59375)
            right:SetSize(4, 19)
            right:SetPoint("TOPRIGHT", 0, 0)
            
            local middle = button:CreateTexture(button:GetName().."Middle", "BACKGROUND")
            middle:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
            middle:SetTexCoord(0.078125, 0.90625, 0, 0.59375)
            middle:SetSize(10, 19)
            middle:SetPoint("LEFT", left, "RIGHT")
            middle:SetPoint("RIGHT", right, "LEFT")
            
            -- Create text
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetText("Created At")
            text:SetPoint("LEFT", button, "LEFT", 8, 0)
            
            -- Create sort arrow (hidden by default)
            local arrow = button:CreateTexture(nil, "OVERLAY")
            arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
            arrow:SetSize(9, 8)
            arrow:SetPoint("LEFT", text, "RIGHT", 3, -2)
            arrow:Hide()
            button.Arrow = arrow
            
            -- Add highlight on hover
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
            highlight:SetBlendMode("ADD")
            highlight:SetPoint("LEFT", 0, 0)
            highlight:SetPoint("RIGHT", 4, 0)
            highlight:SetHeight(24)
            
            -- Add click handler for sorting
            button:SetScript("OnClick", function()
                -- Implement sorting by created date
                OFAuctionFrame_OnClickSortColumn("owner", "duration")
            end)
            
            OFAuctionsCreatedAtText = button
        end
        OFAuctionsCreatedAtText:Show()
        
        -- Hide old button if it exists
        if OFAuctionsCreatedAtSort then
            OFAuctionsCreatedAtSort:Hide()
        end
        
        -- Hide old header if it exists
        if OFAuctionsCreatedAtHeader then
            OFAuctionsCreatedAtHeader:Hide()
        end
    else
        -- Reset columns for other tabs
        if OFAuctionsQualitySort then 
            OFAuctionsQualitySort:SetText("Item")
            OFAuctionsQualitySort:Show()
        end
        
        -- Hide custom Created At header when not in Create Offer tab
        if OFAuctionsCreatedAtHeader then
            OFAuctionsCreatedAtHeader:Hide()
        end
        if OFAuctionsCreatedAtSort then
            OFAuctionsCreatedAtSort:Hide()
        end
        if OFAuctionsCreatedAtText then
            OFAuctionsCreatedAtText:Hide()
        end
        if OFAuctionsLevelSort then OFAuctionsLevelSort:Show() end
        if OFAuctionsTypeSort then 
            OFAuctionsTypeSort:SetText("Type")
            OFAuctionsTypeSort:Show() 
        end
        if OFAuctionsDeliverySort then OFAuctionsDeliverySort:Show() end
        if OFAuctionsBidSort then OFAuctionsBidSort:Show() end
    end
	OFAuctionsFrameAuctions_ValidateAuction()
	OFAuctionFrameAuctions_Update()
    -- Don't show price type dropdown anymore
    -- OFPriceTypeDropdown:GenerateMenu()
    OFDeliveryDropdown:GenerateMenu()
    
    -- Show and update bag items only for Create Offer tab
    if OFBagItemsFrame then 
        local currentTab = OFAuctionFrame.selectedTab
        if currentTab == TAB_CREATE_OFFER then
            OFBagItemsFrame:Show()
            OFBagItemsFrame_Update()
        else
            OFBagItemsFrame:Hide()
        end
    end
end

local function UpdateAuctionEntry(index, i, offset, button, auction, numBatchAuctions, totalAuctions)
    local name, _, quality, level, _, _, _, _, _, texture, _  = ns.GetItemInfo(auction.itemID, auction.quantity)
    local buyoutPrice = auction.price
    local count = auction.quantity
    -- TODO jan easy way to check if item is usable?
    local canUse = true

    button:Show();

    local buttonName = "OFAuctionsButton"..i;
    
    -- Adjust button background textures for Create Offer tab
    local currentTab = OFAuctionFrame.selectedTab
    if currentTab == TAB_CREATE_OFFER then
        -- Move the background textures
        local leftTexture = _G[buttonName.."Left"]
        local rightTexture = _G[buttonName.."Right"]
        
        if leftTexture then
            leftTexture:ClearAllPoints()
            leftTexture:SetPoint("LEFT", button, "LEFT", 24, 2)  -- 10px left from original 34
        end
        
        if rightTexture then
            rightTexture:ClearAllPoints()
            rightTexture:SetPoint("RIGHT", button, "RIGHT", -20, 2)  -- Move in from right
        end
    end

    -- Resize button if there isn't a scrollbar

    -- Display differently based on the saleStatus
    -- saleStatus "1" means that the item was sold
    -- Set name and quality color
    local color = ITEM_QUALITY_COLORS[quality];
    local itemName = _G[buttonName.."Name"];
    local iconTexture = _G[buttonName.."ItemIconTexture"];
    if iconTexture then
        iconTexture:SetTexture(texture);
    end
    
    -- Move icon for Create Offer tab
    local currentTab = OFAuctionFrame.selectedTab
    if currentTab == TAB_CREATE_OFFER then
        local itemButton = _G[buttonName.."Item"]
        if itemButton then
            itemButton:ClearAllPoints()
            itemButton:SetPoint("TOPLEFT", button, "TOPLEFT", -15, 0)  -- Move 15px left
        end
    end
    local itemCount = _G[buttonName.."ItemCount"];

    UpdatePrice(buttonName, auction)
    
    -- Adjust price column for Create Offer tab
    local currentTab = OFAuctionFrame.selectedTab
    if currentTab == TAB_CREATE_OFFER then
        local moneyFrame = _G[buttonName.."MoneyFrame"]
        if moneyFrame then
            moneyFrame:ClearAllPoints()
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", -10, 0)  -- 20px more right (-30 + 20 = -10)
            MoneyFrame_SetMaxDisplayWidth(moneyFrame, 90)  -- Make 40% smaller (150 * 0.6 = 90)
        end
    end

    ResizeEntryAuctions(i, button, numBatchAuctions, totalAuctions)

    -- Normal item
    itemName:SetText(name);
    if (color) then
        itemName:SetVertexColor(color.r, color.g, color.b);
    end
    
    -- Adjust item name position for Create Offer tab (move 15px left total)
    local currentTab = OFAuctionFrame.selectedTab
    if currentTab == TAB_CREATE_OFFER then
        itemName:ClearAllPoints()
        itemName:SetPoint("TOPLEFT", button, "TOPLEFT", 28, 0)  -- Move 15px left (43 - 15 = 28)
        itemName:SetWidth(350)  -- Match header width (350px)
    end

    local requestItem = _G[buttonName.."RequestItem"]
    if requestItem then
        requestItem:Hide()
    end

    local auctionTypeTextElement = _G[buttonName.."AuctionTypeText"]
    if auctionTypeTextElement then
        auctionTypeTextElement:SetText(ns.GetAuctionTypeDisplayString(auction.auctionType))
    end

    -- Hide or show columns based on Create Offer tab
    local currentTab = OFAuctionFrame.selectedTab
    if currentTab == TAB_CREATE_OFFER then
        -- Use Marketplace-style formatting for Create Offer
        -- Hide unnecessary columns
        local deliveryTypeFrame = _G[buttonName.."DeliveryType"]
        if deliveryTypeFrame then deliveryTypeFrame:Hide() end
        
        local auctionTypeText = _G[buttonName.."AuctionTypeText"]
        if auctionTypeText then auctionTypeText:Hide() end
        
        -- Use BidBuyer column for "Created At" date
        local createdAtText = _G[buttonName.."BidBuyer"]
        if createdAtText then
            if auction.createdAt then
                local timeDiff = time() - auction.createdAt
                local timeText = ""
                if timeDiff < 60 then
                    timeText = "Just now"
                elseif timeDiff < 3600 then
                    timeText = math.floor(timeDiff / 60) .. " min ago"
                elseif timeDiff < 86400 then
                    timeText = math.floor(timeDiff / 3600) .. " hours ago"
                else
                    timeText = math.floor(timeDiff / 86400) .. " days ago"
                end
                createdAtText:SetText(timeText)
            else
                createdAtText:SetText("Unknown")
            end
            createdAtText:Show()
            -- Center the text
            createdAtText:SetJustifyH("CENTER")
            -- Position 25px more to the left
            createdAtText:ClearAllPoints()
            createdAtText:SetPoint("TOPLEFT", button, "TOPLEFT", 330, 0)  -- Moved right by 30px (300 + 30)
            createdAtText:SetWidth(120)  -- Match header width
        end
        
        -- Hide the BidStatus column (Rating)
        local bidStatus = _G[buttonName.."BidStatus"]
        if bidStatus then
            bidStatus:Hide()
        end
        
        -- Hide RatingFrame if it exists
        local ratingFrame = _G[buttonName.."RatingFrame"]
        if ratingFrame then
            ratingFrame:Hide()
        end
    else
        -- Normal display for other tabs
        local deliveryTypeFrame = _G[buttonName.."DeliveryType"]
        if deliveryTypeFrame then
            deliveryTypeFrame:Hide()
        end
        
        -- Show normal columns for other tabs
        local bidBuyer = _G[buttonName.."BidBuyer"]
        if bidBuyer then
            bidBuyer:SetText("")
            bidBuyer:ClearAllPoints()
            bidBuyer:SetPoint("TOPLEFT", button, "TOPLEFT", 274, 0)  -- Reset to original position
            bidBuyer:SetJustifyH("LEFT")
        end
        
        local bidStatus = _G[buttonName.."BidStatus"]
        if bidStatus then
            bidStatus:Show()
        end
        
        -- Reset positions
        local itemButton = _G[buttonName.."Item"]
        if itemButton then
            itemButton:ClearAllPoints()
            itemButton:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)  -- Reset to original
        end
        
        itemName:ClearAllPoints()
        itemName:SetPoint("TOPLEFT", button, "TOPLEFT", 43, 0)  -- Reset to original
        
        local moneyFrame = _G[buttonName.."MoneyFrame"]
        if moneyFrame then
            moneyFrame:ClearAllPoints()
            moneyFrame:SetPoint("RIGHT", button, "RIGHT", 6, 0)  -- Reset to original
        end
        
        -- Reset background textures
        local leftTexture = _G[buttonName.."Left"]
        local rightTexture = _G[buttonName.."Right"]
        
        if leftTexture then
            leftTexture:ClearAllPoints()
            leftTexture:SetPoint("LEFT", button, "LEFT", 34, 2)  -- Original position
        end
        
        if rightTexture then
            rightTexture:ClearAllPoints()
            rightTexture:SetPoint("RIGHT", button, "RIGHT", 0, 2)  -- Original position
        end
        
        -- Reset highlight
        local highlight = _G[buttonName.."Highlight"]
        if highlight then
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 33, 0)  -- Original
            highlight:SetWidth(670)  -- Original width
        end
    end

    if ( not canUse ) then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1);
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0);
    end

    if count > 1 and auction.itemID ~= ns.ITEM_ID_GOLD then
        itemCount:SetText(count)
        itemCount:Show()
    else
        itemCount:Hide()
    end
    button.itemCount = count
    button.itemID = auction.itemID
    button.itemIndex = index
    button.cancelPrice = 0
    button.auction = auction
    button.buyoutPrice = buyoutPrice
    button.isEnchantEntry = false
    
    -- Make the button clickable
    if not button.hasOnClick then
        button:SetScript("OnClick", function(self)
            OFAuctionsButton_OnClick(self)
        end)
        button.hasOnClick = true
    end
    
    -- Adjust highlight for Create Offer tab
    if currentTab == TAB_CREATE_OFFER then
        local highlight = _G[buttonName.."Highlight"]
        if highlight then
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 23, 0)  -- 10px left from original 33
            highlight:SetWidth(525)  -- Keep at 525px (Price is smaller now)
        end
    end

    -- Set highlight
    local selected = OFGetSelectedAuctionItem("owner")
    if ( selected and selected.id == auction.id ) then
        OFAuctionFrame.auction = auction
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

function OFAuctionFrameAuctions_Update()
    local auctions = ns.GetMyActiveAuctions and ns.GetMyActiveAuctions(currentSortParams["owner"].params) or {}
    
    -- Filter based on Create Offer vs Create Request tab
    local currentTab = OFAuctionFrame.selectedTab
    if currentTab == TAB_CREATE_OFFER then
        -- Only show offers (items the player is selling)
        local filteredAuctions = {}
        for _, auction in ipairs(auctions) do
            if auction.isRequest ~= true then
                table.insert(filteredAuctions, auction)
            end
        end
        auctions = filteredAuctions
    elseif currentTab == TAB_CREATE_REQUEST then
        -- Only show requests (items the player wants to buy)
        local filteredAuctions = {}
        for _, auction in ipairs(auctions) do
            if auction.isRequest == true then
                table.insert(filteredAuctions, auction)
            end
        end
        auctions = filteredAuctions
    end
    
    local totalAuctions = #auctions
    -- Don't show Gold and Enchant entries in Create Offer/Request tabs
    local shouldShowSpecialItems = currentTab ~= TAB_CREATE_OFFER and currentTab ~= TAB_CREATE_REQUEST
    local numBatchAuctions = min(totalAuctions + (shouldShowSpecialItems and 2 or 0), OF_NUM_AUCTION_ITEMS_PER_PAGE)
	local offset = FauxScrollFrame_GetOffset(OFAuctionsScrollFrame)
	local index
	local isLastSlotEmpty
	local auction, button, itemName

	-- Update scroll frame
	FauxScrollFrame_Update(OFAuctionsScrollFrame, totalAuctions, OF_NUM_AUCTIONS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT);
	
	-- Make sure the scroll frame is visible
	if OFAuctionsScrollFrame then
		OFAuctionsScrollFrame:Show()
	end
	
	-- Update sort arrows
	OFSortButton_UpdateArrow(OFAuctionsQualitySort, "owner", "quality")
	OFSortButton_UpdateArrow(OFAuctionsLevelSort, "owner", "level")
    OFSortButton_UpdateArrow(OFAuctionsTypeSort, "owner", "type")
    OFSortButton_UpdateArrow(OFAuctionsDeliverySort, "owner", "delivery")
    OFSortButton_UpdateArrow(OFAuctionsBidSort, "owner", "bid")

	for i=1, OF_NUM_AUCTIONS_TO_DISPLAY do
		index = offset + i + (OF_NUM_AUCTION_ITEMS_PER_PAGE * OFAuctionFrameAuctions.page)
        
        -- Calculate the actual auction index  
        local auctionIndex
        if shouldShowSpecialItems then
            -- When showing special items, first 2 indices are for Gold and Enchant
            auctionIndex = index - 2
        else
            -- When not showing special items, use direct indexing
            auctionIndex = offset + i
        end
        
        -- Get the auction if the index is valid
        auction = nil
        if auctionIndex > 0 and auctionIndex <= #auctions then
            auction = auctions[auctionIndex]
        end
        
        button = _G["OFAuctionsButton"..i];
        if not button then
            break
        end
        button.auction = auction  -- Store the auction for click handler
        
        if (auction == nil) then
            button.auctionId = nil
        else
            button.auctionId = auction.id
        end

        local isItem = shouldShowSpecialItems and index == 1
        local isEnchantEntry = shouldShowSpecialItems and index == 2
		-- Show or hide auction buttons
        if isItem then
            auction = nil

            ns.TryExcept(
                function() UpdateItemEntry(index, i, offset, button, ns.ITEM_GOLD, numBatchAuctions, totalAuctions + (shouldShowSpecialItems and 2 or 0), "owner") end,
                function(err)
                    button:Hide()
                    ns.DebugLog("OFAuctionFrameAuctions_Update UpdateItemEntry failed: ", err)
                end
            )
        elseif isEnchantEntry then
            auction = nil

            ns.TryExcept(
                function() UpdateEnchantAuctionEntry(index, i, offset, button, numBatchAuctions, totalAuctions + (shouldShowSpecialItems and 2 or 0)) end,
                function(err)
                    button:Hide()
                    ns.DebugLog("rendering auction item entry failed: ", err)
                end
            )

		elseif ( auction == nil ) then
			button:Hide();
			-- If the last button is empty then set isLastSlotEmpty var
			isLastSlotEmpty = (i == OF_NUM_AUCTIONS_TO_DISPLAY);
		else
            itemName = ns.GetItemInfo(auction.itemID)
            if (itemName) then
                ns.TryExcept(
                    function() 
                        UpdateAuctionEntry(index, i, offset, button, auction, numBatchAuctions, totalAuctions + (shouldShowSpecialItems and 2 or 0))
                    end,
                    function(err) 
                        button:Hide()
                        ns.DebugLog("rendering auction entry failed: ", err) 
                    end
                )
            else
                local deferredI, deferredIndex, deferredAuction, deferredOffset = i, index, auction, offset
                ns.GetItemInfoAsync(auction.itemID, function (...)
                    local deferredButton = _G["OFAuctionsButton"..deferredI]
                    if (deferredButton.auctionId == deferredAuction.id) then
                        deferredButton:Show()
                        ns.TryExcept(
                            function() UpdateAuctionEntry(deferredIndex, deferredI, deferredOffset, deferredButton, deferredAuction, numBatchAuctions, totalAuctions + (shouldShowSpecialItems and 2 or 0)) end,
                            function(err) deferredButton:Hide(); ns.DebugLog("rendering deferred auction entry failed: ", err) end
                        )
                    end
                end)
            end
		end
	end
	-- If more than one page of auctions show the next and prev arrows when the scrollframe is scrolled all the way down
	if ( totalAuctions > OF_NUM_AUCTION_ITEMS_PER_PAGE ) then
		if ( isLastSlotEmpty ) then
			OFAuctionsSearchCountText:Show();
			OFAuctionsSearchCountText:SetFormattedText(SINGLE_PAGE_RESULTS_TEMPLATE, totalAuctions);
		else
			OFAuctionsSearchCountText:Hide();
		end

		-- Artifically inflate the number of results so the scrollbar scrolls one extra row
		numBatchAuctions = numBatchAuctions + 1;
	else
		OFAuctionsSearchCountText:Hide();
	end

    local selected = OFGetSelectedAuctionItem("owner")

	if (selected and ns.CanCancelAuction(selected)) then
        OFAuctionsCancelAuctionButton.auction = selected
		OFAuctionsCancelAuctionButton:Enable()
	else
        OFAuctionsCancelAuctionButton.auction = nil
		OFAuctionsCancelAuctionButton:Disable()
	end

	-- Update scrollFrame
	FauxScrollFrame_Update(OFAuctionsScrollFrame, numBatchAuctions, OF_NUM_AUCTIONS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT);
end

function GetEffectiveAuctionsScrollFrameOffset()
	return FauxScrollFrame_GetOffset(OFAuctionsScrollFrame)
end

function OFAuctionsButton_OnClick(button)
	assert(button)
    OFSetSelectedAuctionItem("owner", button.auction)
	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameAuctions.cancelPrice = button.cancelPrice
	OFAuctionFrameAuctions_Update()
end


function OFAuctionSellItemButton_OnEvent(self, event, ...)
    if ( event == "NEW_AUCTION_UPDATE") then
        auctionSellItemInfo = pack(GetAuctionSellItemInfo())
        if ( name == OF_LAST_ITEM_AUCTIONED and count == OF_LAST_ITEM_COUNT ) then
            MoneyInputFrame_SetCopper(OFBuyoutPrice, OF_LAST_ITEM_BUYOUT)
        else
            local name, _, count, _, _, price, _, _, _, _ = OFGetAuctionSellItemInfo()
            MoneyInputFrame_SetCopper(OFBuyoutPrice, max(100, floor(price * 1.5)))
            if ( name ) then
                OF_LAST_ITEM_AUCTIONED = name
                OF_LAST_ITEM_COUNT = count
                OF_LAST_ITEM_BUYOUT = MoneyInputFrame_GetCopper(OFBuyoutPrice)
            end
        end
        UnlockCheckButton(OFAllowLoansCheckButton)
        OFSetupDeliveryDropdown(OFAuctionFrameAuctions)
        OFSetupPriceTypeDropdown(OFAuctionFrameAuctions)
        OFUpdateAuctionSellItem()
	end
end

function OFAuctionSellItemButton_OnClick(self, button)
    if button == "RightButton" then
        DeselectAuctionItem()
    end
	ClickAuctionSellItemButton(self, button)
	OFAuctionsFrameAuctions_ValidateAuction()
end

function OFAuctionsFrameAuctions_ValidateAuction()
	OFAuctionsCreateAuctionButton:Disable()
	-- No item
    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = OFGetAuctionSellItemInfo()
	if not name then
		return
	end

    local priceType = OFAuctionFrameAuctions.priceTypeIndex
    if priceType == ns.PRICE_TYPE_MONEY then
        if ( MoneyInputFrame_GetCopper(OFBuyoutPrice) < 1 or MoneyInputFrame_GetCopper(OFBuyoutPrice) > OF_MAXIMUM_BID_PRICE) then
            return
        end
    elseif priceType == ns.PRICE_TYPE_TWITCH_RAID then
        if OFTwitchRaidViewerAmount:GetNumber() < 1 then
            return
        end
    elseif priceType == ns.PRICE_TYPE_CUSTOM then
        local note = OFAuctionsNote:GetText()
        if (note == "" or note == OF_NOTE_PLACEHOLDER) and not duel and not deathRoll and not roleplay then
            return
        end
    end

    local isGold = itemID == ns.ITEM_ID_GOLD
    if isGold then
        if priceType == ns.PRICE_TYPE_MONEY then
            return
        end
    end

	OFAuctionsCreateAuctionButton:Enable()
end


function OFAuctionFrame_GetTimeLeftText(id)
	return _G["AUCTION_TIME_LEFT"..id]
end

function OFAuctionFrame_GetTimeLeftTooltipText(id)
	local text = _G["AUCTION_TIME_LEFT"..id.."_DETAIL"]
	return text
end

local function SetupUnitPriceTooltip(tooltip, type, auctionItem, excludeMissions)
    if not excludeMissions and auctionItem.auction and auctionItem.auction.deathRoll then
        GameTooltip_SetTitle(tooltip, "Death Roll")
        GameTooltip_AddNormalLine(tooltip, OF_DEATH_ROLL_TOOLTIP, true)
        tooltip:Show()
        return true
    end
    if not excludeMissions and auctionItem.auction and auctionItem.auction.duel then
        GameTooltip_SetTitle(tooltip, "Duel (Normal)")
        GameTooltip_AddNormalLine(tooltip, OF_DUEL_TOOLTIP, true)
        tooltip:Show()
        return true
    end
    if not excludeMissions and auctionItem.auction and auctionItem.auction.priceType == ns.PRICE_TYPE_CUSTOM then
        GameTooltip_SetTitle(tooltip, "Custom Price")
        GameTooltip_AddNormalLine(tooltip, auctionItem.auction.note, true)
        tooltip:Show()
        return true
    end

    if ( auctionItem and auctionItem.itemCount > 1 and auctionItem.buyoutPrice > 0 and auctionItem.itemID ~= ns.ITEM_ID_GOLD and (not auctionItem.auction or auctionItem.auction.priceType == ns.PRICE_TYPE_MONEY)) then
		-- If column is showing total price, then tooltip shows price per unit, and vice versa.

        local prefix
        local amount

        amount = auctionItem.buyoutPrice;
        prefix = AUCTION_TOOLTIP_BUYOUT_PREFIX
        amount = ceil(amount / auctionItem.itemCount)
        SetTooltipMoney(tooltip, amount, nil, prefix)

		-- This is necessary to update the extents of the tooltip
		tooltip:Show()

		return true
	end

    -- Show delivery tooltip if available
    if auctionItem.auction then
        GameTooltip_AddNormalLine(tooltip, ns.GetDeliveryTypeTooltip(auctionItem.auction), true)
        tooltip:Show()
        return true
    end

	return false
end

local function GetAuctionButton(buttonType, id)
	if ( buttonType == "owner" ) then
		return _G["OFAuctionsButton"..id];
	elseif ( buttonType == "bidder" ) then
		return _G["OFBidButton"..id];
	elseif ( buttonType == "list" ) then
		return _G["OFBrowseButton"..id];
	end
end

function OFAuctionBrowseFrame_CheckUnlockHighlight(self, selectedType, offset)
	local selected = OFGetSelectedAuctionItem(selectedType)
    local button = self.auction and self or self:GetParent()
    local auction = button.auction
	if ( not selected or not auction or selected.id ~= auction.id) then
		self:GetParent():UnlockHighlight()
	end
end

function OFAuctionPriceTooltipFrame_OnLoad(self)
	self:SetMouseClickEnabled(false)
	self:SetMouseMotionEnabled(true)
end

function OFAuctionPriceTooltipFrame_OnEnter(self)
	self:GetParent():LockHighlight();

	-- Unit price is only supported on the list tab, no need to pass in buttonType argument
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	local button = GetAuctionButton("list", self:GetParent():GetID());
	local hasTooltip = SetupUnitPriceTooltip(GameTooltip, "list", button, false);
	if (not hasTooltip) then
		GameTooltip_Hide();
	end
	activeTooltipPriceTooltipFrame = self;
end

function OFAuctionPriceTooltipFrame_OnLeave(self)
	OFAuctionBrowseFrame_CheckUnlockHighlight(self, "list", FauxScrollFrame_GetOffset(OFBrowseScrollFrame));
	GameTooltip_Hide();
	activeTooltipPriceTooltipFrame = nil;
end

function OFAuctionFrameItem_OnEnter(self, type)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

	-- add price per unit info
	local button = self:GetParent()
    if button.isEnchantEntry then
        GameTooltip_SetTitle(GameTooltip, "Enchants")
        GameTooltip_AddNormalLine(GameTooltip, "Select the enchant you want to put up for auction", true)
    elseif type == "owner" and button.itemID == ns.ITEM_ID_GOLD then
        GameTooltip_SetTitle(GameTooltip, "Gold")
        GameTooltip_AddNormalLine(GameTooltip, "Select the amount of gold you want to put up for auction", true)
    elseif ns.IsFakeItem(button.itemID) then
        local title, description = ns.GetFakeItemTooltip(button.itemID)
        GameTooltip_SetTitle(GameTooltip, title)
        GameTooltip_AddNormalLine(GameTooltip, description, true)
    elseif ns.IsSpellItem(button.itemID) then
        GameTooltip:SetSpellByID(ns.ItemIDToSpellID(button.itemID))
    else
        GameTooltip:SetItemByID(button.itemID)
    end
    GameTooltip:Show()

    SetupUnitPriceTooltip(GameTooltip, type, button, true);
	if (type == "list") then
		activeTooltipAuctionFrameItem = self;
	end
    if button.itemID ~= ns.ITEM_ID_GOLD then
        GameTooltip_ShowCompareItem()
    end

	if ( IsModifiedClick("DRESSUP") ) then
		ShowInspectCursor();
	else
		ResetCursor();
	end
end

function OFAuctionFrameItem_OnClickModified(self, type, index, overrideID)
    local button = GetAuctionButton(type, overrideID or self:GetParent():GetID())
    local _, link = ns.GetItemInfo(button.itemID)
    if link then
        HandleModifiedItemClick(link)
    end
end

function OFAuctionFrameItem_OnLeave(self)
	GameTooltip_Hide()
	ResetCursor()
	activeTooltipAuctionFrameItem = nil
end


-- SortButton functions
function OFSortButton_UpdateArrow(button, type, sort)
	local primaryColumn, reversed = GetAuctionSortColumn(type);
	button.Arrow:SetShown(sort == primaryColumn);
	if (sort == primaryColumn) then
		if (reversed) then
			button.Arrow:SetTexCoord(0, 0.5625, 1, 0);
		else
			button.Arrow:SetTexCoord(0, 0.5625, 0, 1);
		end
	end
end

-- Function to close popups if another auction item is selected
function OFCloseAuctionStaticPopups()
	StaticPopup_Hide("OF_CANCEL_AUCTION_PENDING")
    StaticPopup_Hide("OF_BUY_AUCTION_DEATH_ROLL")
    StaticPopup_Hide("OF_BUY_AUCTION_DUEL")
    StaticPopup_Hide("OF_BUY_AUCTION_GOLD")
    StaticPopup_Hide("OF_MARK_AUCTION_COMPLETE")
    StaticPopup_Hide("OF_CANCEL_AUCTION_ACTIVE")
    StaticPopup_Hide("OF_FORGIVE_LOAN")
    StaticPopup_Hide("OF_DECLARE_BANKRUPTCY")
    StaticPopup_Hide("OF_FULFILL_AUCTION")
    StaticPopup_Hide("OF_SELECT_AUCTION_MONEY")

    ns.AuctionBuyConfirmPrompt:Hide()
    ns.AuctionWishlistConfirmPrompt:Hide()
end

function OFBidForgiveLoanButton_OnClick(self)
    if ns.IsSpellItem(OFAuctionFrame.auction.itemID) then
        StaticPopup_Show("OF_MARK_AUCTION_COMPLETE")
    elseif OFAuctionFrame.auction.owner == UnitName("player") then
        StaticPopup_Show("OF_FORGIVE_LOAN")
    else
        StaticPopup_Show("OF_DECLARE_BANKRUPTCY")
    end
    self:Disable()
end

function OFAuctionsCreateAuctionButton_OnClick()
    OF_LAST_ITEM_BUYOUT = MoneyInputFrame_GetCopper(OFBuyoutPrice)
    DropCursorMoney()

    local name, texture, count, quality, canUse, price, pricePerUnit, stackCount, totalCount, itemID = OFGetAuctionSellItemInfo()
    
    -- Get the actual quantity from the stack fields if visible
    if OFAuctionsStackSizeEntry and OFAuctionsStackSizeEntry:IsVisible() then
        local stackSize = tonumber(OFAuctionsStackSizeEntry:GetText()) or count
        -- For now, we'll use the stack size as the count per auction
        -- In the future, could create multiple auctions for numStacks > 1
        count = stackSize
    end
    
    local note = OFAuctionsNote:GetText()
    if note == OF_NOTE_PLACEHOLDER then
        note = ""
    end

    local priceType = OFAuctionFrameAuctions.priceTypeIndex
    local deliveryType = OFAuctionFrameAuctions.deliveryTypeIndex
    local buyoutPrice, raidAmount
    if priceType == ns.PRICE_TYPE_MONEY then
        buyoutPrice = GetBuyoutPrice()
        raidAmount = 0
    elseif priceType == ns.PRICE_TYPE_TWITCH_RAID then
        buyoutPrice = 0
        raidAmount = OFTwitchRaidViewerAmount:GetNumber()
    else
        buyoutPrice = 0
        raidAmount = 0
    end


    local error, auctionCap, _
    auctionCap = ns.GetConfig().auctionCap
    if #ns.GetMyAuctions() >= auctionCap then
        error = string.format("You cannot have more than %d auctions", auctionCap)
    else
        _, error = ns.AuctionHouseAPI:CreateAuction(itemID, buyoutPrice, count, allowLoans, priceType, deliveryType, ns.AUCTION_TYPE_SELL, roleplay, deathRoll, duel, raidAmount, note)
    end
    if error then
        UIErrorsFrame:AddMessage(error, 1.0, 0.1, 0.1, 1.0);
        PlaySoundFile("sound/interface/error.ogg", "Dialog")
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
    end

    -- do these actions without playing the SFX connected to selecting and dropping the item in your bag
    local prev = GetCVar("Sound_EnableSFX")
    SetCVar("Sound_EnableSFX", 0)
    ns.TryFinally(
        function()
            OFAuctionsNote:SetText(OF_NOTE_PLACEHOLDER)
            ClickAuctionSellItemButton(OFAuctionsItemButton, "LeftButton")
            auctionSellItemInfo = nil
            OFUpdateAuctionSellItem()
            OFAuctionFrameAuctions_Update()
            ClearCursor()
        end,
        function()
            SetCVar("Sound_EnableSFX", prev)
        end
    )
end

function OFReadOnlyEditBox_OnLoad(self, content)
    self:SetText(content)
    self:SetCursorPosition(0)
    self:SetScript("OnEscapePressed", function()
        self:ClearFocus()
    end)
    self:SetScript("OnEditFocusLost", function()
        self:SetText(content)
    end)
    self:SetScript("OnEditFocusGained", function()
        self:SetText(content)
        C_Timer.After(0.2, function()
            self:SetCursorPosition(0)
            self:HighlightText()
        end)
    end)

end

function OFRatingFrame_OnLoad(self)
    local starRating = ns.CreateStarRatingWidget({
        starSize = 6,
        panelHeight = 6,
        marginBetweenStarsX = 1,
        leftMargin = 2,
        labelFont = "GameFontNormalSmall",
    })
    self.ratingWidget = starRating
    starRating.frame:SetParent(self)
    starRating.frame:SetPoint("LEFT", self, "LEFT", -2, 0)
    starRating:SetRating(3.5)
    starRating.frame:Show()
end

-- Test Data Function for Development
function OFAuctionFrame_PopulateTestData()
    -- Clear cache to force refresh
    browseResultCache = nil
    
    -- Trigger update for all tabs
    OFAuctionFrameBrowse_Update()
    OFAuctionFrameBid_Update()
    OFAuctionFrameAuctions_Update()
    
    print("|cFF00FF00Auction data refreshed!|r")
    if ns.GetBrowseAuctions then
        local testAuctions = ns.GetBrowseAuctions({})
        if testAuctions and #testAuctions > 0 then
            print("|cFF00FF00Found " .. #testAuctions .. " auctions|r")
        end
    end
end

-- Original complex test data function - removed due to compatibility issues
--[[
function OFAuctionFrame_PopulateTestData_OLD()
    -- Toggle test data
    testDataEnabled = not testDataEnabled
    
    if testDataEnabled then
        -- Generate test items first
        local testItems = {
            {id = 6948, name = "Hearthstone", q = 1, lvl = 1},
            {id = 2589, name = "Linen Cloth", q = 1, lvl = 5},
            {id = 2771, name = "Tin Ore", q = 1, lvl = 10},
            {id = 858, name = "Lesser Healing Potion", q = 1, lvl = 3},
            {id = 4306, name = "Silk Cloth", q = 1, lvl = 20},
            {id = 2840, name = "Copper Bar", q = 1, lvl = 5},
            {id = 2318, name = "Light Leather", q = 1, lvl = 10},
            {id = 774, name = "Malachite", q = 2, lvl = 7},
            {id = 818, name = "Tigerseye", q = 2, lvl = 15},
            {id = 1210, name = "Shadowgem", q = 2, lvl = 20},
            {id = 929, name = "Healing Potion", q = 1, lvl = 12},
            {id = 3356, name = "Kingsblood", q = 1, lvl = 24},
            {id = 2447, name = "Peacebloom", q = 1, lvl = 5},
            {id = 765, name = "Silverleaf", q = 1, lvl = 5},
            {id = 2449, name = "Earthroot", q = 1, lvl = 10},
            {id = 2450, name = "Briarthorn", q = 1, lvl = 15},
            {id = 2453, name = "Bruiseweed", q = 1, lvl = 20},
            {id = 3369, name = "Grave Moss", q = 1, lvl = 25},
            {id = 3820, name = "Stranglekelp", q = 1, lvl = 15},
            {id = 3372, name = "Leaping Potion", q = 1, lvl = 8},
            {id = 6359, name = "Firefin Snapper", q = 1, lvl = 10},
            {id = 6358, name = "Oily Blackmouth", q = 1, lvl = 15},
            {id = 4603, name = "Raw Spotted Yellowtail", q = 1, lvl = 25},
            {id = 12202, name = "Tiger Meat", q = 1, lvl = 25},
            {id = 2674, name = "Crawler Meat", q = 1, lvl = 10},
            {id = 2672, name = "Stringy Wolf Meat", q = 1, lvl = 5},
            {id = 769, name = "Chunk of Boar Meat", q = 1, lvl = 5},
            {id = 1015, name = "Lean Wolf Flank", q = 1, lvl = 10},
            {id = 2886, name = "Crag Boar Rib", q = 1, lvl = 5},
            {id = 3173, name = "Bear Meat", q = 1, lvl = 15},
            {id = 3730, name = "Big Bear Meat", q = 1, lvl = 20},
            {id = 5784, name = "Slimy Murloc Scale", q = 1, lvl = 8},
            {id = 5785, name = "Thick Murloc Scale", q = 1, lvl = 15},
            {id = 7071, name = "Iron Buckle", q = 1, lvl = 25},
            {id = 4234, name = "Heavy Leather", q = 1, lvl = 20},
            {id = 4304, name = "Thick Leather", q = 1, lvl = 30},
            {id = 2321, name = "Fine Thread", q = 1, lvl = 10},
            {id = 4291, name = "Silken Thread", q = 1, lvl = 20},
            {id = 8343, name = "Heavy Silken Thread", q = 1, lvl = 30},
            {id = 2320, name = "Coarse Thread", q = 1, lvl = 5},
            {id = 2996, name = "Bolt of Linen Cloth", q = 1, lvl = 5},
            {id = 2997, name = "Bolt of Woolen Cloth", q = 1, lvl = 15},
            {id = 4305, name = "Bolt of Silk Cloth", q = 1, lvl = 25},
            {id = 4339, name = "Bolt of Mageweave", q = 1, lvl = 35},
            {id = 5498, name = "Small Lustrous Pearl", q = 2, lvl = 15},
            {id = 5500, name = "Iridescent Pearl", q = 2, lvl = 25},
            {id = 13926, name = "Golden Pearl", q = 2, lvl = 40},
            {id = 6037, name = "Truesilver Bar", q = 2, lvl = 30},
            {id = 3860, name = "Mithril Bar", q = 1, lvl = 30},
            {id = 3575, name = "Iron Bar", q = 1, lvl = 15}
        }
        
        -- Store original data
        originalBrowseData = {
            info = g_auctionBrowseInfo,
            entries = g_auctionBrowseEntries,
            numEntries = g_numAuctionBrowseEntries
        }
        originalBidData = {
            info = g_auctionBidInfo,
            entries = g_auctionBidEntries,
            numEntries = g_numAuctionBidEntries
        }
        originalAuctionsData = {
            info = g_auctionAuctionsInfo,
            entries = g_auctionAuctionsEntries,
            numEntries = g_numAuctionEntries
        }
        
        -- Store original GetItemInfo and replace with mock
        if ns then
            originalGetItemInfo = ns.GetItemInfo
            
            -- Create a lookup table for test items
            local itemLookup = {}
            for _, item in ipairs(testItems) do
                itemLookup[item.id] = item
            end
            
            -- Mock GetItemInfo function for test data
            ns.GetItemInfo = function(itemID, quantity)
                local item = itemLookup[itemID]
                if item then
                    -- Return format: name, link, quality, level, minLevel, type, subType, stackCount, equipLoc, texture, sellPrice
                    return item.name, 
                           string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", item.q == 2 and "1eff00" or "ffffff", itemID, item.name),
                           item.q,
                           item.lvl,
                           item.lvl,
                           "Trade Goods",
                           "Trade Goods",
                           20,
                           "",
                           "Interface\\Icons\\INV_Misc_QuestionMark",
                           100
                else
                    -- Fallback to original if available
                    if originalGetItemInfo then
                        return originalGetItemInfo(itemID, quantity)
                    end
                    return nil
                end
            end
        end
        
        -- Create test auctions for Browse/Marketplace
        local testAuctions = {}
        local playerNames = {"Asmongold", "Esfand", "Staysafe", "TipsOut", "Venruki", 
                            "Payo", "Cdew", "Soda", "Xaryu", "Savix",
                            "Pikaboo", "Mes", "Swifty", "Bajheera", "Pilav",
                            "Grubby", "T1", "Ahmpy", "Guzu", "Crix",
                            "Sonydigital", "Ziqo", "Mvq", "Jellybeans", "Snupy"}
        
        for i = 1, 50 do
            local item = testItems[((i-1) % #testItems) + 1]
            local auction = {
                itemID = item.id,
                itemName = item.name,
                itemLink = string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                    item.q == 2 and "1eff00" or "ffffff", item.id, item.name),
                quality = item.q,
                level = item.lvl,
                owner = playerNames[((i-1) % #playerNames) + 1],
                price = math.random(100, 50000),
                priceType = ns and ns.PRICE_TYPE_MONEY or 1,
                quantity = math.random(1, 20),
                timeLeft = math.random(1, 4), -- 1=short, 2=medium, 3=long, 4=very long
                bidAmount = 0,
                texture = "Interface\\Icons\\INV_Misc_QuestionMark", -- Default icon
                count = math.random(1, 20),
                minBid = math.random(50, 5000),
                buyoutPrice = math.random(100, 50000),
                isRequest = false
            }
            
            -- Add some variety with different auction types
            if i % 10 == 0 then
                auction.deathRoll = true
                auction.priceType = ns and ns.PRICE_TYPE_MONEY or 1
            elseif i % 15 == 0 then
                auction.priceType = ns and ns.PRICE_TYPE_TWITCH_RAID or 2
                auction.raidAmount = math.random(100, 1000)
            end
            
            testAuctions[i] = auction
        end
        
        -- Set test data for Browse
        g_auctionBrowseInfo = {}
        g_auctionBrowseEntries = testAuctions
        g_numAuctionBrowseEntries = #testAuctions
        for i, auction in ipairs(testAuctions) do
            g_auctionBrowseInfo[i] = auction
        end
        
        -- Create test data for Bids/Requests (similar items but different status)
        local testBids = {}
        for i = 1, 50 do
            local item = testItems[((i-1) % #testItems) + 1]
            local bid = {
                itemID = item.id,
                itemName = item.name,
                itemLink = string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                    item.q == 2 and "1eff00" or "ffffff", item.id, item.name),
                quality = item.q,
                level = item.lvl,
                owner = UnitName("player") or "TestPlayer", -- You are the owner for bid items
                bidder = playerNames[((i-1) % #playerNames) + 1],
                price = math.random(100, 50000),
                priceType = ns and ns.PRICE_TYPE_MONEY or 1,
                quantity = math.random(1, 20),
                timeLeft = math.random(1, 4),
                status = math.random(1, 3), -- Different statuses
                texture = "Interface\\Icons\\INV_Misc_QuestionMark",
                count = math.random(1, 20),
                minBid = math.random(50, 5000),
                buyoutPrice = math.random(100, 50000),
                isRequest = i % 4 == 0
            }
            testBids[i] = bid
        end
        
        -- Set test data for Bids
        g_auctionBidInfo = {}
        g_auctionBidEntries = testBids
        g_numAuctionBidEntries = #testBids
        for i, bid in ipairs(testBids) do
            g_auctionBidInfo[i] = bid
        end
        
        -- Create test data for Auctions/Owner
        local testOwner = {}
        for i = 1, 50 do
            local item = testItems[((i-1) % #testItems) + 1]
            local owned = {
                itemID = item.id,
                itemName = item.name,
                itemLink = string.format("|cff%s|Hitem:%d::::::::1:::::::|h[%s]|h|r", 
                    item.q == 2 and "1eff00" or "ffffff", item.id, item.name),
                quality = item.q,
                level = item.lvl,
                owner = UnitName("player") or "TestPlayer",
                highBidder = i % 3 == 0 and playerNames[((i-1) % #playerNames) + 1] or nil,
                price = math.random(100, 50000),
                priceType = ns and ns.PRICE_TYPE_MONEY or 1,
                quantity = math.random(1, 20),
                timeLeft = math.random(1, 4),
                status = i % 3 == 0 and "Sold" or "Active",
                texture = "Interface\\Icons\\INV_Misc_QuestionMark",
                count = math.random(1, 20),
                minBid = math.random(50, 5000),
                buyoutPrice = math.random(100, 50000),
                isRequest = i % 5 == 0
            }
            testOwner[i] = owned
        end
        
        -- Set test data for Auctions
        g_auctionAuctionsInfo = {}
        g_auctionAuctionsEntries = testOwner
        g_numAuctionEntries = #testOwner
        for i, owned in ipairs(testOwner) do
            g_auctionAuctionsInfo[i] = owned
        end
        
        print("|cFF00FF00Test data ENABLED:|r 50 items loaded for each tab")
    else
        -- Restore original data
        if originalBrowseData then
            g_auctionBrowseInfo = originalBrowseData.info or {}
            g_auctionBrowseEntries = originalBrowseData.entries or {}
            g_numAuctionBrowseEntries = originalBrowseData.numEntries or 0
        end
        if originalBidData then
            g_auctionBidInfo = originalBidData.info or {}
            g_auctionBidEntries = originalBidData.entries or {}
            g_numAuctionBidEntries = originalBidData.numEntries or 0
        end
        if originalAuctionsData then
            g_auctionAuctionsInfo = originalAuctionsData.info or {}
            g_auctionAuctionsEntries = originalAuctionsData.entries or {}
            g_numAuctionEntries = originalAuctionsData.numEntries or 0
        end
        
        -- Restore original GetItemInfo function
        if ns and originalGetItemInfo then
            ns.GetItemInfo = originalGetItemInfo
            originalGetItemInfo = nil
        end
        
        print("|cFFFF0000Test data DISABLED:|r Original data restored")
    end
    
    -- Update all UIs
    OFAuctionFrameBrowse_Update()
    OFAuctionFrameBid_Update()
    OFAuctionFrameAuctions_Update()
    
    -- Update button text to show state
    local button = _G["OFBrowseTestDataButton"]
    if button then
        if testDataEnabled then
            button:SetText("Test: ON")
        else
            button:SetText("Test: OFF")
        end
    end
end
--]]