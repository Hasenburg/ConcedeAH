# ConcedeAH - Auction House Addon

## Übersicht
ConcedeAH ist ein Guild-Auktionshaus-Addon für World of Warcraft Classic, das es Gildenmitgliedern ermöglicht, Items untereinander zu handeln mit automatisierter Unterstützung.

## Hauptfunktionen

### 1. **Automatisches Trade-Fenster Ausfüllen**
- Beim Öffnen eines Handelsfensters werden automatisch die relevanten Items eingefügt
- Unterstützt mehrere Auktionen in einem Trade (bis zu 6 Items)
- Zeigt automatisch ein Trade Amount Fenster mit detaillierter Auflistung

### 2. **Trade Amount Fenster**
- Zeigt eine itemisierte Liste aller zu handelnden Items
- Einzelpreise für jede Position
- Gesamtsumme am Ende
- Sichtbar für beide Parteien (Käufer und Verkäufer)

### 3. **Multi-Stack Support**
- Kann mehrere Stacks des gleichen Items korrekt handhaben
- Beispiel: 2x 5er Stack Leinenstoff werden als 2 separate Stacks eingefügt

### 4. **Ranking System**
- Jede abgeschlossene Auktion zählt als 1 Punkt
- Separate Zählung für Verkäufer und Käufer
- Wöchentliche und Gesamt-Ranglisten
- **Wichtig**: Mehrere Auktionen = Mehrere Punkte (2x 5er Stack = 2 Punkte)

## Einschränkungen & Bekannte Probleme

### Manuelle Aktionen erforderlich:

#### 1. **Gold muss manuell eingegeben werden**
- Der `/tm` Befehl wurde entfernt (Kompatibilitätsprobleme mit Classic API)
- Käufer müssen den Goldbetrag manuell in die Trade-Felder eingeben
- Der benötigte Betrag wird im Trade Amount Fenster angezeigt

#### 2. **Stacks müssen manuell getrennt werden**
- Items müssen in der exakten Stack-Größe vorhanden sein
- Beispiel: Für eine 5er Stack Auktion muss genau ein 5er Stack im Inventar sein
- Ein 10er Stack muss erst manuell in 2x 5er geteilt werden

### Technische Einschränkungen:

#### 1. **Maximum 6 Items pro Trade**
- WoW Classic Limitation
- Bei mehr als 6 Auktionen sind mehrere Trades nötig

#### 2. **Kein automatisches Gold-Setzen**
- Classic API unterstützt kein programmatisches Setzen von Trade-Gold
- `SetTradeMoney()` ist eine geschützte Funktion

#### 3. **TradeSkillMaster (TSM) Konflikt**
- TSM verursacht Fehler mit `SetTradeMoney()`
- Dies ist ein TSM-Problem, nicht ConcedeAH
- Addon funktioniert trotz der Fehlermeldung

## Verwendung

### Als Verkäufer:
1. Trade mit dem Käufer öffnen
2. Items werden automatisch eingefügt (wenn richtige Stack-Größe vorhanden)
3. Trade Amount Fenster zeigt erwarteten Goldbetrag
4. Auf Gold vom Käufer warten und Trade akzeptieren

### Als Käufer:
1. Trade mit dem Verkäufer öffnen
2. Trade Amount Fenster zeigt alle Items mit Preisen
3. **Manuell** den Goldbetrag eingeben (siehe Trade Amount Fenster)
4. Trade akzeptieren

## Fehlerbehebung

### "Wrong stack size" Fehler:
- Stack manuell auf die benötigte Größe aufteilen
- Rechtsklick auf Stack → "Stack aufteilen" → Gewünschte Menge eingeben

### "Trade window full" Fehler:
- Maximal 6 Items pro Trade möglich
- Trade abschließen und erneut handeln für weitere Items

### Items werden nicht automatisch eingefügt:
- Prüfen ob die exakte Stack-Größe vorhanden ist
- `/checkauctions` verwenden um ausstehende Auktionen zu sehen

## Befehle

- `/checkauctions` - Zeigt alle deine ausstehenden Auktionen
- `/testbuy <spielername>` - Erstellt eine Test-Auktion (nur für Tests)
- `/rankingdebug` - Zeigt aktuelle Ranking-Daten
- `/rankingsync` - Erzwingt Ranking-Synchronisation

## Support

Bei Problemen oder Fragen wenden Sie sich an die Gildenleitung oder den Addon-Entwickler.

## Version History

### Aktuelle Version
- Multi-Item Trade Support
- Itemisiertes Trade Amount Fenster
- Verbesserte Stack-Handhabung
- Ranking-System mit Käufer/Verkäufer-Trennung

### Bekannte Probleme
- `/tm` Befehl funktioniert nicht in Classic
- TSM Addon verursacht harmlose Fehlermeldungen
- Gold muss manuell eingegeben werden