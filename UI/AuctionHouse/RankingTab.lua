local _, ns = ...

local WEEK_START_DAY = 4 -- Wednesday (1=Sunday, 2=Monday, etc.)
local WEEK_START_HOUR = 8
local SECONDS_IN_WEEK = 604800

function OFAuctionFrameRanking_OnLoad(self)
    self.selectedWeek = "current"  -- Default to Current Week view
    self.contributors = {}
    self.weeklyData = {}
    self.allTimeData = {}
    self.sortColumn = "sales"  -- Default sort by sales
    self.reverseSort = true     -- Highest first
    
    currentSortParams = currentSortParams or {}
    currentSortParams["ranking"] = {
        sortColumn = "sales",
        reverseSort = true,
        params = {}
    }
    
    -- Initialize saved variables with separate seller and buyer tracking
    if not OFRankingData then
        OFRankingData = {
            currentWeek = {
                sellers = {},
                buyers = {}
            },
            historicalWeeks = {},
            allTime = {
                sellers = {},
                buyers = {}
            },
            weekStartTime = 0
        }
    end
    
    -- Migrate old data format if necessary
    if OFRankingData.currentWeek and not OFRankingData.currentWeek.sellers then
        local oldData = OFRankingData.currentWeek
        OFRankingData.currentWeek = {
            sellers = oldData,
            buyers = {}
        }
    end
    if OFRankingData.allTime and not OFRankingData.allTime.sellers then
        local oldData = OFRankingData.allTime
        OFRankingData.allTime = {
            sellers = oldData,
            buyers = {}
        }
    end
    
    -- Register slash commands for debugging
    SLASH_RANKINGSYNC1 = "/rankingsync"
    SLASH_RANKINGDEBUG1 = "/rankingdebug"
    SLASH_RANKINGUPDATE1 = "/rankingupdate"
    
    SlashCmdList["RANKINGSYNC"] = function()
        print("|cFFFFFF00[Ranking]|r Forcing sync request...")
        if ns.RankingSync then
            ns.RankingSync:RequestRankingState()
        end
    end
    
    SlashCmdList["RANKINGDEBUG"] = function()
        OFAuctionFrameRanking_InitializeData()
        print("|cFFFFFF00[Ranking Debug]|r Current Rankings:")
        print("  Week Start: " .. (OFRankingData.weekStartTime or 0))
        print("  Current Week Sales:")
        for name, points in pairs(OFRankingData.currentWeek.sellers or {}) do
            print("    " .. name .. ": " .. points .. " sales")
        end
        print("  Current Week Purchases:")
        for name, points in pairs(OFRankingData.currentWeek.buyers or {}) do
            print("    " .. name .. ": " .. points .. " purchases")
        end
        print("  All Time Sales:")
        for name, points in pairs(OFRankingData.allTime.sellers or {}) do
            print("    " .. name .. ": " .. points .. " sales")
        end
        print("  All Time Purchases:")
        for name, points in pairs(OFRankingData.allTime.buyers or {}) do
            print("    " .. name .. ": " .. points .. " purchases")
        end
    end
    
    SlashCmdList["RANKINGUPDATE"] = function()
        print("|cFFFFFF00[Ranking]|r Forcing UI update...")
        if OFAuctionFrameRanking then
            -- Force show the frame to test
            if not OFAuctionFrameRanking:IsShown() then
                print("|cFFFFFF00[Ranking]|r Frame was hidden, showing it now")
                OFAuctionFrameRanking:Show()
            end
            OFAuctionFrameRanking_UpdateList()
            print("|cFF00FF00[Ranking]|r UpdateList called successfully")
        else
            print("|cFFFF0000[Ranking]|r OFAuctionFrameRanking not found!")
        end
    end
    
    -- Style the sidebar with backdrop (if SetBackdrop is available)
    if OFRankingSidebar and OFRankingSidebar.SetBackdrop then
        OFRankingSidebar:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
        OFRankingSidebar:SetBackdropColor(0, 0, 0, 0.8)
    end
    
    -- Create sidebar buttons
    OFRankingSidebar.buttons = {}
    for i = 1, 20 do
        local button = CreateFrame("Button", "OFRankingSidebarButton"..i, OFRankingSidebar, "UIPanelButtonTemplate")
        button:SetSize(130, 22)
        button:SetPoint("TOPLEFT", 10, -30 - (i-1) * 25)  -- Adjusted for title
        button:SetNormalFontObject("GameFontNormalSmall")
        button:SetHighlightFontObject("GameFontHighlightSmall")
        button:Hide()
        OFRankingSidebar.buttons[i] = button
    end
    
    -- Create ranking list buttons aligned with headers
    OFRankingScrollFrame.buttons = {}
    local NUM_RANKING_BUTTONS = 15  -- Show 15 rows in visible area
    for i = 1, NUM_RANKING_BUTTONS do
        local button = CreateFrame("Frame", "OFRankingButton"..i, OFAuctionFrameRanking)
        button:SetSize(600, 20)
        button:SetPoint("TOPLEFT", OFRankingScrollFrame, "TOPLEFT", 0, -(i-1) * 20)
        button:Hide()  -- Initially hide all buttons
        
        -- Background texture for alternating rows
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i % 2 == 0 then
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
        else
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.2)
        end
        button.bg = bg
        
        -- Highlight texture
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.3)
        
        -- Rank text aligned with # header
        local rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rank:SetPoint("LEFT", button, "LEFT", 15, 0)
        rank:SetWidth(50)
        rank:SetJustifyH("CENTER")
        button.rank = rank
        
        -- Name text aligned with Player header
        local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", button, "LEFT", 65, 0)
        name:SetWidth(310)
        name:SetJustifyH("LEFT")
        button.name = name
        
        -- Sales points aligned with Sales header
        local salesPoints = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        salesPoints:SetPoint("LEFT", button, "LEFT", 380, 0)
        salesPoints:SetWidth(65)
        salesPoints:SetJustifyH("CENTER")
        button.salesPoints = salesPoints
        
        -- Purchases points aligned with Purchases header
        local purchasePoints = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        purchasePoints:SetPoint("LEFT", button, "LEFT", 450, 0)
        purchasePoints:SetWidth(85)
        purchasePoints:SetJustifyH("CENTER")
        button.purchasePoints = purchasePoints
        
        -- Total points aligned with Total header
        local totalPoints = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        totalPoints:SetPoint("LEFT", button, "LEFT", 540, 0)
        totalPoints:SetWidth(65)
        totalPoints:SetJustifyH("CENTER")
        button.totalPoints = totalPoints
        
        -- Medal icon for top 3
        local medal = button:CreateTexture(nil, "ARTWORK")
        medal:SetSize(16, 16)
        medal:SetPoint("LEFT", button, "LEFT", -5, 0)
        medal:Hide()
        button.medal = medal
        
        button:SetScript("OnEnter", function(self)
            if self.playerData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.playerData.name, 1, 1, 1)
                GameTooltip:AddLine(string.format("Sales: %d points", self.playerData.sales), 0, 1, 0)
                GameTooltip:AddLine(string.format("Purchases: %d points", self.playerData.purchases), 0.5, 0.5, 1)
                GameTooltip:AddLine(string.format("Total: %d points", self.playerData.total), 1, 1, 0)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        OFRankingScrollFrame.buttons[i] = button
    end
    
    OFAuctionFrameRanking_CheckWeekReset()
end

function OFAuctionFrameRanking_CheckWeekReset()
    local currentTime = time()
    local currentDate = date("*t", currentTime)
    
    local daysUntilWednesday = (WEEK_START_DAY - currentDate.wday + 7) % 7
    if daysUntilWednesday == 0 and currentDate.hour < WEEK_START_HOUR then
        daysUntilWednesday = 7
    end
    
    local lastWednesday = currentTime - ((7 - daysUntilWednesday) % 7) * 86400
    local lastWednesdayDate = date("*t", lastWednesday)
    lastWednesdayDate.hour = WEEK_START_HOUR
    lastWednesdayDate.min = 0
    lastWednesdayDate.sec = 0
    local weekStartTime = time(lastWednesdayDate)
    
    if not OFRankingData.weekStartTime or weekStartTime > OFRankingData.weekStartTime then
        if OFRankingData.weekStartTime > 0 then
            local hasData = false
            if OFRankingData.currentWeek.sellers and next(OFRankingData.currentWeek.sellers) then
                hasData = true
            end
            if OFRankingData.currentWeek.buyers and next(OFRankingData.currentWeek.buyers) then
                hasData = true
            end
            
            if hasData then
                local weekKey = date("%Y-%m-%d", OFRankingData.weekStartTime)
                OFRankingData.historicalWeeks[weekKey] = CopyTable(OFRankingData.currentWeek)
            end
        end
        
        OFRankingData.currentWeek = {sellers = {}, buyers = {}}
        OFRankingData.weekStartTime = weekStartTime
    end
end

function OFAuctionFrameRanking_OnShow(self)
    -- Initialize saved variables if needed
    if not OFRankingData then
        OFRankingData = {
            currentWeek = {sellers = {}, buyers = {}},
            historicalWeeks = {},
            allTime = {sellers = {}, buyers = {}},
            weekStartTime = 0
        }
    end
    
    -- Ensure new structure
    OFAuctionFrameRanking_InitializeData()
    
    -- Clean up any test data
    OFAuctionFrameRanking_CleanTestData()
    
    OFAuctionFrameRanking_CheckWeekReset()
    
    -- Set frame level to be in front of other frames
    if self.SetFrameLevel then
        local parentLevel = self:GetParent():GetFrameLevel()
        self:SetFrameLevel(parentLevel + 10)
    end
    
    if OFRankingScrollFrame then
        OFRankingScrollFrame:Show()
    end
    
    if OFRankingSidebar then
        OFRankingSidebar:Show()
        OFAuctionFrameRanking_UpdateSidebar()
    end
    
    OFAuctionFrameRanking_UpdateList()
end

function OFAuctionFrameRanking_CleanTestData()
    if not OFRankingData then return end
    
    -- Remove test players from all data structures
    local testPlayers = {"TestPlayer1", "TestPlayer2", "TestPlayer3"}
    
    for _, player in ipairs(testPlayers) do
        if OFRankingData.currentWeek then
            OFRankingData.currentWeek[player] = nil
        end
        if OFRankingData.allTime then
            OFRankingData.allTime[player] = nil
        end
        if OFRankingData.historicalWeeks then
            for weekKey, weekData in pairs(OFRankingData.historicalWeeks) do
                if weekData[player] then
                    weekData[player] = nil
                end
            end
        end
    end
end

function OFAuctionFrameRanking_OnHide(self)
    -- Just hide the frames
end

function OFAuctionFrameRanking_AddSellerPoint(contributor)
    if not contributor or contributor == "" then return end
    
    print("|cFF00FF00[Ranking]|r Adding SELLER point for: " .. contributor)
    
    OFAuctionFrameRanking_InitializeData()
    OFAuctionFrameRanking_CheckWeekReset()
    
    OFRankingData.currentWeek.sellers[contributor] = (OFRankingData.currentWeek.sellers[contributor] or 0) + 1
    OFRankingData.allTime.sellers[contributor] = (OFRankingData.allTime.sellers[contributor] or 0) + 1
    
    print(string.format("|cFF00FF00[Ranking]|r %s now has %d sales this week, %d total", 
        contributor, 
        OFRankingData.currentWeek.sellers[contributor], 
        OFRankingData.allTime.sellers[contributor]))
    
    if ns.RankingSync then
        ns.RankingSync:BroadcastRankingUpdate(contributor, "seller", OFRankingData.currentWeek.sellers[contributor])
    end
    
    if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
        OFAuctionFrameRanking_UpdateList()
    end
end

function OFAuctionFrameRanking_AddBuyerPoint(contributor)
    if not contributor or contributor == "" then return end
    
    print("|cFF00FFFF[Ranking]|r Adding BUYER point for: " .. contributor)
    
    OFAuctionFrameRanking_InitializeData()
    OFAuctionFrameRanking_CheckWeekReset()
    
    OFRankingData.currentWeek.buyers[contributor] = (OFRankingData.currentWeek.buyers[contributor] or 0) + 1
    OFRankingData.allTime.buyers[contributor] = (OFRankingData.allTime.buyers[contributor] or 0) + 1
    
    print(string.format("|cFF00FFFF[Ranking]|r %s now has %d purchases this week, %d total", 
        contributor, 
        OFRankingData.currentWeek.buyers[contributor], 
        OFRankingData.allTime.buyers[contributor]))
    
    if ns.RankingSync then
        ns.RankingSync:BroadcastRankingUpdate(contributor, "buyer", OFRankingData.currentWeek.buyers[contributor])
    end
    
    if OFAuctionFrameRanking and OFAuctionFrameRanking:IsShown() then
        OFAuctionFrameRanking_UpdateList()
    end
end

-- Keep old function for compatibility
function OFAuctionFrameRanking_AddContributorPoint(contributor)
    OFAuctionFrameRanking_AddSellerPoint(contributor)
end

function OFAuctionFrameRanking_InitializeData()
    if not OFRankingData then
        OFRankingData = {
            currentWeek = {sellers = {}, buyers = {}},
            historicalWeeks = {},
            allTime = {sellers = {}, buyers = {}},
            weekStartTime = 0
        }
    end
    
    -- Ensure structure exists
    if not OFRankingData.currentWeek.sellers then
        OFRankingData.currentWeek.sellers = OFRankingData.currentWeek or {}
        OFRankingData.currentWeek.buyers = {}
    end
    if not OFRankingData.allTime.sellers then
        OFRankingData.allTime.sellers = OFRankingData.allTime or {}
        OFRankingData.allTime.buyers = {}
    end
end

function OFAuctionFrameRanking_UpdateList()
    if not OFRankingData then
        print("|cFFFF0000[Ranking]|r No ranking data available")
        return
    end
    
    OFAuctionFrameRanking_InitializeData()
    
    -- Debug output
    local debugMode = false -- Set to true for debugging
    if debugMode then
        print("|cFFFFFF00[Ranking UpdateList]|r Called with selectedWeek: " .. (OFAuctionFrameRanking.selectedWeek or "nil"))
    end
    
    local sellersData = {}
    local buyersData = {}
    
    if OFAuctionFrameRanking.selectedWeek == "current" then
        sellersData = OFRankingData.currentWeek.sellers or {}
        buyersData = OFRankingData.currentWeek.buyers or {}
    elseif OFAuctionFrameRanking.selectedWeek == "alltime" then
        sellersData = OFRankingData.allTime.sellers or {}
        buyersData = OFRankingData.allTime.buyers or {}
    else
        local weekData = OFRankingData.historicalWeeks and OFRankingData.historicalWeeks[OFAuctionFrameRanking.selectedWeek]
        if weekData then
            sellersData = weekData.sellers or {}
            buyersData = weekData.buyers or {}
        end
    end
    
    -- Combine all players
    local allPlayers = {}
    for player, _ in pairs(sellersData) do
        allPlayers[player] = true
    end
    for player, _ in pairs(buyersData) do
        allPlayers[player] = true
    end
    
    local sortedList = {}
    for player, _ in pairs(allPlayers) do
        local sales = sellersData[player] or 0
        local purchases = buyersData[player] or 0
        local total = sales + purchases
        table.insert(sortedList, {
            name = player,
            sales = sales,
            purchases = purchases,
            total = total
        })
    end
    
    -- Sort based on selected column
    local sortColumn = currentSortParams["ranking"].sortColumn or "sales"
    local reverseSort = currentSortParams["ranking"].reverseSort
    
    table.sort(sortedList, function(a, b)
        local aValue, bValue
        
        if sortColumn == "name" then
            aValue = a.name or ""
            bValue = b.name or ""
        elseif sortColumn == "sales" then
            aValue = a.sales or 0
            bValue = b.sales or 0
        elseif sortColumn == "purchases" then
            aValue = a.purchases or 0
            bValue = b.purchases or 0
        elseif sortColumn == "total" then
            aValue = a.total or 0
            bValue = b.total or 0
        else  -- rank (default to total for ranking)
            aValue = a.total or 0
            bValue = b.total or 0
        end
        
        if sortColumn == "name" then
            -- String comparison
            if reverseSort then
                return aValue > bValue
            else
                return aValue < bValue
            end
        else
            -- Numeric comparison
            if reverseSort then
                return aValue > bValue
            else
                return aValue < bValue
            end
        end
    end)
    
    local scrollFrame = OFRankingScrollFrame
    if not scrollFrame or not scrollFrame.buttons then return end
    
    local buttons = scrollFrame.buttons
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
    
    -- Show header based on selection
    local headerText = "All Time Rankings"
    if OFAuctionFrameRanking.selectedWeek == "current" then
        headerText = "Current Week Rankings"
    elseif OFAuctionFrameRanking.selectedWeek ~= "alltime" then
        headerText = "Week of " .. OFAuctionFrameRanking.selectedWeek
    end
    
    for i = 1, #buttons do
        local button = buttons[i]
        local index = i + offset
        
        if index <= #sortedList then
            local entry = sortedList[index]
            
            -- Store player data for tooltip
            button.playerData = entry
            
            -- Set rank
            if button.rank then
                button.rank:SetText(tostring(index))
            end
            
            -- Set name
            if button.name then
                button.name:SetText(entry.name)
            end
            
            -- Set sales points
            if button.salesPoints then
                button.salesPoints:SetText(tostring(entry.sales))
                button.salesPoints:SetTextColor(0, 1, 0)  -- Green for sales
            end
            
            -- Set purchase points
            if button.purchasePoints then
                button.purchasePoints:SetText(tostring(entry.purchases))
                button.purchasePoints:SetTextColor(0.5, 0.5, 1)  -- Blue for purchases
            end
            
            -- Set total points
            if button.totalPoints then
                button.totalPoints:SetText(tostring(entry.total))
                button.totalPoints:SetTextColor(1, 1, 0)  -- Yellow for total
            end
            
            -- Special styling for top 3
            if index == 1 then
                button.rank:SetFontObject("GameFontNormal")
                button.name:SetFontObject("GameFontHighlight")
                if button.salesPoints then button.salesPoints:SetFontObject("GameFontNormal") end
                if button.purchasePoints then button.purchasePoints:SetFontObject("GameFontNormal") end
                if button.totalPoints then button.totalPoints:SetFontObject("GameFontNormal") end
                button.medal:SetTexture("Interface\\PVPFrame\\PVP-Currency-Alliance")
                button.medal:SetVertexColor(1, 0.843, 0)  -- Gold
                button.medal:Show()
                button.bg:SetColorTexture(0.8, 0.7, 0.1, 0.2)  -- Gold tint
            elseif index == 2 then
                button.rank:SetFontObject("GameFontNormal")
                button.name:SetFontObject("GameFontHighlight")
                if button.salesPoints then button.salesPoints:SetFontObject("GameFontNormal") end
                if button.purchasePoints then button.purchasePoints:SetFontObject("GameFontNormal") end
                if button.totalPoints then button.totalPoints:SetFontObject("GameFontNormal") end
                button.medal:SetTexture("Interface\\PVPFrame\\PVP-Currency-Alliance")
                button.medal:SetVertexColor(0.75, 0.75, 0.75)  -- Silver
                button.medal:Show()
                button.bg:SetColorTexture(0.6, 0.6, 0.6, 0.15)  -- Silver tint
            elseif index == 3 then
                button.rank:SetFontObject("GameFontNormal")
                button.name:SetFontObject("GameFontHighlight")
                if button.salesPoints then button.salesPoints:SetFontObject("GameFontNormal") end
                if button.purchasePoints then button.purchasePoints:SetFontObject("GameFontNormal") end
                if button.totalPoints then button.totalPoints:SetFontObject("GameFontNormal") end
                button.medal:SetTexture("Interface\\PVPFrame\\PVP-Currency-Alliance")
                button.medal:SetVertexColor(0.8, 0.5, 0.2)  -- Bronze
                button.medal:Show()
                button.bg:SetColorTexture(0.6, 0.4, 0.2, 0.15)  -- Bronze tint
            else
                button.rank:SetFontObject("GameFontNormal")
                button.name:SetFontObject("GameFontHighlight")
                if button.salesPoints then button.salesPoints:SetFontObject("GameFontNormal") end
                if button.purchasePoints then button.purchasePoints:SetFontObject("GameFontNormal") end
                if button.totalPoints then button.totalPoints:SetFontObject("GameFontNormal") end
                button.medal:Hide()
                -- Reset background to default alternating colors
                if i % 2 == 0 then
                    button.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
                else
                    button.bg:SetColorTexture(0.15, 0.15, 0.15, 0.2)
                end
            end
            
            button:Show()
        else
            button.playerData = nil
            button:Hide()
        end
    end
    
    -- Show empty state if no data
    if #sortedList == 0 then
        if buttons[1] then
            if buttons[1].rank then buttons[1].rank:SetText("") end
            if buttons[1].name then buttons[1].name:SetText("No rankings yet - be the first contributor!") end
            if buttons[1].salesPoints then buttons[1].salesPoints:SetText("") end
            if buttons[1].purchasePoints then buttons[1].purchasePoints:SetText("") end
            if buttons[1].totalPoints then buttons[1].totalPoints:SetText("") end
            if buttons[1].medal then buttons[1].medal:Hide() end
            buttons[1].playerData = nil
            buttons[1]:Show()
            for i = 2, #buttons do
                buttons[i]:Hide()
            end
        end
    end
    
    -- Update scroll frame with correct item height (20 pixels per row)
    FauxScrollFrame_Update(scrollFrame, #sortedList, #buttons, 20)
end

function OFAuctionFrameRanking_UpdateSidebar()
    local sidebar = OFRankingSidebar
    if not sidebar or not sidebar.buttons then return end
    
    -- Hide all buttons first
    for i, button in ipairs(sidebar.buttons) do
        button:Hide()
    end
    
    local buttonIndex = 1
    
    -- Current Week button (FIRST - now default)
    local button = sidebar.buttons[buttonIndex]
    if button then
        button:SetText("Current Week")
        button:SetScript("OnClick", function()
            OFAuctionFrameRanking.selectedWeek = "current"
            OFAuctionFrameRanking_UpdateList()
            OFAuctionFrameRanking_UpdateSidebarHighlight()
        end)
        button:Show()
        if OFAuctionFrameRanking.selectedWeek == "current" then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
        buttonIndex = buttonIndex + 1
    end
    
    -- All Time button (SECOND)
    button = sidebar.buttons[buttonIndex]
    if button then
        button:SetText("All Time")
        button:SetScript("OnClick", function()
            OFAuctionFrameRanking.selectedWeek = "alltime"
            OFAuctionFrameRanking_UpdateList()
            OFAuctionFrameRanking_UpdateSidebarHighlight()
        end)
        button:Show()
        if OFAuctionFrameRanking.selectedWeek == "alltime" then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
        buttonIndex = buttonIndex + 1
    end
    
    -- Separator line
    buttonIndex = buttonIndex + 1
    
    -- Historical weeks (sorted newest first)
    if OFRankingData and OFRankingData.historicalWeeks then
        local historicalWeeks = {}
        for weekKey in pairs(OFRankingData.historicalWeeks) do
            table.insert(historicalWeeks, weekKey)
        end
        table.sort(historicalWeeks, function(a, b) return a > b end)  -- Newest first
        
        for i, weekKey in ipairs(historicalWeeks) do
            if buttonIndex <= #sidebar.buttons then
                button = sidebar.buttons[buttonIndex]
                button:SetText(weekKey)
                button:SetScript("OnClick", function()
                    OFAuctionFrameRanking.selectedWeek = weekKey
                    OFAuctionFrameRanking_UpdateList()
                    OFAuctionFrameRanking_UpdateSidebarHighlight()
                end)
                button:Show()
                if OFAuctionFrameRanking.selectedWeek == weekKey then
                    button:LockHighlight()
                else
                    button:UnlockHighlight()
                end
                buttonIndex = buttonIndex + 1
            end
        end
    end
end

function OFAuctionFrameRanking_UpdateSidebarHighlight()
    local sidebar = OFRankingSidebar
    if not sidebar or not sidebar.buttons then return end
    
    for i, button in ipairs(sidebar.buttons) do
        if button:IsShown() then
            button:UnlockHighlight()
        end
    end
    
    -- Find and highlight the selected button
    for i, button in ipairs(sidebar.buttons) do
        if button:IsShown() then
            local text = button:GetText()
            if (OFAuctionFrameRanking.selectedWeek == "alltime" and text == "All Time") or
               (OFAuctionFrameRanking.selectedWeek == "current" and text == "Current Week") or
               (OFAuctionFrameRanking.selectedWeek == text) then
                button:LockHighlight()
                break
            end
        end
    end
end

function OFRankingSort_OnClick(column)
    if not currentSortParams["ranking"] then
        currentSortParams["ranking"] = {
            sortColumn = "sales",
            reverseSort = true,
            params = {}
        }
    end
    
    -- If clicking the same column, reverse the sort
    if currentSortParams["ranking"].sortColumn == column then
        currentSortParams["ranking"].reverseSort = not currentSortParams["ranking"].reverseSort
    else
        -- New column selected
        currentSortParams["ranking"].sortColumn = column
        -- Default sort order for each column
        if column == "rank" then
            currentSortParams["ranking"].reverseSort = false  -- Lowest rank first
        elseif column == "name" then
            currentSortParams["ranking"].reverseSort = false  -- A-Z
        else  -- sales, purchases, total
            currentSortParams["ranking"].reverseSort = true   -- Highest first
        end
    end
    
    -- Update the list with new sort
    OFAuctionFrameRanking_UpdateList()
end