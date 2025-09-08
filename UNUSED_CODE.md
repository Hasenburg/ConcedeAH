# Unused Code Documentation

## AuctionUITemplates.xml

### Hidden/Unused Elements:
1. **OFBrowseLevelSort** (line 448) - hidden="true" - Level sorting column
2. **OFBrowseTypeSort** (line 463) - hidden="true" - Type sorting column  
3. **OFBrowseDeliverySort** (line 475) - hidden="true" - Delivery/Misc sorting column
4. **OFBrowseRatingSort** (line 510) - hidden="true" - Rating sorting column
5. **$parentLevel** (line 934) - hidden="true" - Level display in auction buttons
6. **$parentAuctionType** (line 1108) - hidden="true" - Type column in auctions
7. **$parentDeliveryType** (line 1133) - hidden="true" - Misc column in auctions

### Template Notes:
- The BidButtonTemplate (line 522-914) appears to be unused as the addon uses Browse buttons for all tabs
- Many delivery type and note icon elements are defined but hidden

## MarketplaceTab.lua / RequestsTab.lua

These files reference buttons like "OFMarketplaceButton" and "OFRequestsButton" that don't exist in XML. The actual implementation reuses OFBrowseButton elements from the main browse frame.

## Recommendation

Consider removing truly unused code to improve maintainability. Hidden elements that might be toggled in settings should be kept.