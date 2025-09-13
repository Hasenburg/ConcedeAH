# ConcedeAH - User Guide

## What is ConcedeAH?
An auction house addon for guild-internal trading in World of Warcraft Classic.

## ⚠️ IMPORTANT NOTES BEFORE STARTING

### You must ALWAYS do these manually:
1. **Enter gold yourself** - The addon cannot set gold automatically
2. **Split stacks beforehand** - Items must be in the exact size in your inventory
3. **Maximum 6 items per trade** - For more items, perform multiple trades

### Synchronization Limitation (WoW Classic Limitation):
⚠️ **Auctions and rankings are ONLY transmitted to players in the same zone!**
- New auctions/rankings only reach players in your vicinity
- Players in other zones see updates only after manual sync
- **Solution:** Meet in the same city (e.g., Orgrimmar/Stormwind) and use `/reload` or `/rankingsync`
- This is a WoW Classic API limitation of the GUILD channel

---

## 📦 SELLING - Step by Step

### Preparation:
1. **Prepare stacks correctly**
   - Example: You should sell 3x 5-stacks of Linen Cloth
   - Split your stacks BEFORE the trade to exactly 3x 5-stacks
   - Right-click on stack → "Split Stack" → Enter 5

### Selling Process:
1. **Open trade with buyer** (Right-click → Trade)
2. **Items are inserted automatically** (if stack size matches)
3. **Trade Amount window appears** - shows total price
4. **Wait for buyer to enter gold**
5. **Accept trade** ✓

### If items are NOT automatically inserted:
- Check stack size (must match exactly!)
- Type `/checkauctions` to see your auctions
- Insert items manually if necessary

---

## 💰 BUYING - Step by Step

### Buying Process:
1. **Open trade with seller** (Right-click → Trade)
2. **Trade Amount window shows you:**
   - All items with individual prices
   - **TOTAL at the end** ← This is the amount you need!
3. **Enter gold MANUALLY:**
   - Right-click on gold field in trade
   - Enter amount from Trade Amount window
   - Format: [Gold] [Silver] [Copper]
4. **Accept trade** ✓

### Example entering gold:
- Trade Amount shows: **Total: 15g 50s**
- You enter: 15 Gold, 50 Silver

---

## 🏆 Ranking System
- Each completed auction = 1 point
- **Note:** 3x 5-stacks = 3 points (not 1 point!)
- Weekly and total rankings available

---

## ❌ LIMITATIONS - What does NOT work automatically

### Manual actions required:
| What | Why | Solution |
|------|-----|----------|
| **Enter gold** | WoW Classic API limitation | Buyer must enter amount manually |
| **Split stacks** | Addon cannot split stacks | Split to correct size BEFORE trade |
| **More than 6 items** | WoW trade limit | Perform multiple trades |
| **Cross-zone sync** | GUILD channel range limit | Meet in same zone for sync |

### Known Issues:
- **TSM Addon**: Shows harmless error messages → ignore, still works
- **"Wrong stack size"**: Split stack manually to required size
- **"Trade window full"**: Maximum 6 items → Complete trade, open new one

---

## 🛠️ Useful Commands

| Command | Function |
|---------|----------|
| `/checkauctions` | Shows your open auctions |
| `/rankingdebug` | Shows current ranking points |
| `/rankingsync` | Synchronizes rankings with guild |

---

## 📋 Quick Checklist

### Before selling:
- [ ] Stacks split to correct size?
- [ ] Not more than 6 items?
- [ ] Trade Amount window shows correct price?

### Before buying:
- [ ] Enough gold available?
- [ ] Total from Trade Amount window noted?
- [ ] Gold entered manually?

---

## ⚡ Common Mistakes to Avoid

1. **Error**: "I have a 20-stack but should sell 4x 5-stacks"
   - **Solution**: FIRST split into 4x 5-stacks, THEN open trade

2. **Error**: "Gold is not set automatically"
   - **Solution**: Normal! Buyer must ALWAYS enter manually

3. **Error**: "More than 6 auctions simultaneously"
   - **Solution**: Trade first 6, then rest in new trade

4. **Error**: "Other players don't see my auctions"
   - **Solution**: You're in different zones! Meet in the same city

5. **Error**: "Rankings are not up to date"
   - **Solution**: Execute `/rankingsync` in the same zone as other guild members

---

## 🆘 Help
For problems, contact guild leadership or ask in guild chat.