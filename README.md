# ConcedeAH - Benutzeranleitung

## Was ist ConcedeAH?
Ein Auktionshaus-Addon für den gildeninternen Handel in World of Warcraft Classic.

## ⚠️ WICHTIGE HINWEISE VOR DEM START

### Das musst du IMMER manuell machen:
1. **Gold selbst eingeben** - Das Addon kann kein Gold automatisch setzen
2. **Stacks vorher splitten** - Items müssen in der exakten Größe im Inventar sein
3. **Maximal 6 Items pro Trade** - Bei mehr Items mehrere Trades durchführen

---

## 📦 VERKAUFEN - Schritt für Schritt

### Vorbereitung:
1. **Stacks richtig vorbereiten**
   - Beispiel: Du sollst 3x 5er Stacks Leinenstoff verkaufen
   - Splitte deine Stacks VOR dem Trade auf genau 3x 5er Stacks
   - Rechtsklick auf Stack → "Stack aufteilen" → 5 eingeben

### Verkaufsprozess:
1. **Trade mit Käufer öffnen** (Rechtsklick → Handeln)
2. **Items werden automatisch eingefügt** (wenn Stack-Größe stimmt)
3. **Trade Amount Fenster erscheint** - zeigt Gesamtpreis
4. **Warten bis Käufer Gold eingibt**
5. **Trade akzeptieren** ✓

### Wenn Items NICHT automatisch eingefügt werden:
- Stack-Größe prüfen (muss exakt stimmen!)
- `/checkauctions` eingeben um deine Auktionen zu sehen
- Items manuell einfügen falls nötig

---

## 💰 KAUFEN - Schritt für Schritt

### Kaufprozess:
1. **Trade mit Verkäufer öffnen** (Rechtsklick → Handeln)
2. **Trade Amount Fenster zeigt dir:**
   - Alle Items mit Einzelpreisen
   - **GESAMTSUMME am Ende** ← Diesen Betrag brauchst du!
3. **Gold MANUELL eingeben:**
   - Rechtsklick auf Gold-Feld im Trade
   - Betrag aus Trade Amount Fenster eingeben
   - Format: [Gold] [Silber] [Kupfer]
4. **Trade akzeptieren** ✓

### Beispiel Gold eingeben:
- Trade Amount zeigt: **Total: 15g 50s**
- Du gibst ein: 15 Gold, 50 Silber

---

## 🏆 Ranking System
- Jede abgeschlossene Auktion = 1 Punkt
- **Achtung:** 3x 5er Stacks = 3 Punkte (nicht 1 Punkt!)
- Wöchentliche und Gesamt-Ranglisten verfügbar

---

## ❌ LIMITATIONEN - Das geht NICHT automatisch

### Manuell erforderlich:
| Was | Warum | Lösung |
|-----|-------|---------|
| **Gold eingeben** | WoW Classic API Beschränkung | Käufer muss Betrag manuell eingeben |
| **Stacks splitten** | Addon kann keine Stacks teilen | VOR Trade auf richtige Größe splitten |
| **Mehr als 6 Items** | WoW Trade-Limit | Mehrere Trades durchführen |

### Bekannte Probleme:
- **TSM Addon**: Zeigt harmlose Fehlermeldungen → ignorieren, funktioniert trotzdem
- **"Wrong stack size"**: Stack manuell auf benötigte Größe aufteilen
- **"Trade window full"**: Maximal 6 Items → Trade abschließen, neu öffnen

---

## 🛠️ Nützliche Befehle

| Befehl | Funktion |
|--------|----------|
| `/checkauctions` | Zeigt deine offenen Auktionen |
| `/rankingdebug` | Zeigt aktuelle Ranking-Punkte |
| `/rankingsync` | Synchronisiert Rankings mit Gilde |

---

## 📋 Schnell-Checkliste

### Vor dem Verkauf:
- [ ] Stacks auf richtige Größe gesplittet?
- [ ] Nicht mehr als 6 Items?
- [ ] Trade Amount Fenster zeigt korrekten Preis?

### Vor dem Kauf:
- [ ] Genug Gold dabei?
- [ ] Gesamtsumme im Trade Amount Fenster notiert?
- [ ] Gold manuell eingegeben?

---

## ⚡ Häufige Fehler vermeiden

1. **Fehler**: "Ich habe einen 20er Stack aber soll 4x 5er verkaufen"
   - **Lösung**: ERST splitten in 4x 5er, DANN Trade öffnen

2. **Fehler**: "Gold wird nicht automatisch gesetzt"
   - **Lösung**: Normal! Käufer muss IMMER manuell eingeben

3. **Fehler**: "Mehr als 6 Auktionen gleichzeitig"
   - **Lösung**: Erste 6 traden, dann Rest in neuem Trade

---

## 🆘 Hilfe
Bei Problemen wende dich an die Gildenleitung oder im Gildenchat fragen.