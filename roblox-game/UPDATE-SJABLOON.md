# Update-sjabloon (maandelijkse update)

Kopieer deze checklist voor elke update. Het script doet dit automatisch:

```
lune run tools/new-update 1.2.0
```

Daarna staat er een kopie in `updates/1.2.0/CHECKLIST.md`.

---

## 1. Plannen (week 1)
- [ ] Kies een thema (bijvoorbeeld "Winter Bakery", "Fruit Festival").
- [ ] Kies wat nieuw is. Klein is prima:
  - [ ] 1 tot 3 nieuwe machines
  - [ ] 2 tot 4 cosmetische items (minstens 1 gratis met sterren of via een event)
  - [ ] eventueel 1 nieuw admin abuse event
- [ ] Seizoen? Zet `ActiveSeason` in `new-content.json` (bijvoorbeeld "Winter").
- [ ] **Controle België/Nederland:** niets nieuws is willekeurig (geen kisten, eieren of geluk). Bij elk betaald item weet de speler vooraf precies wat hij krijgt.

## 2. Bouwen (week 2)
- [ ] `lune run tools/new-update <versie>`
- [ ] Vul `updates/<versie>/new-content.json` in.
- [ ] `lune run tools/new-update <versie> apply`
- [ ] Verkoop je iets nieuws voor Robux? Maak het developer product aan op create.roblox.com en zet het ID in `ShopConfig.luau` (zie HANDLEIDING.md, stap 6).

## 3. Testen (week 3)
- [ ] `lune run tests/run`: alles moet "geslaagd" zijn.
- [ ] `rojo build -o build/SkyBakeryTycoon.rbxl` en daarna `lune run tests/place_check`
- [ ] In Studio (Play):
  - [ ] Nieuwe machines zijn te koop, staan op een goede plek en zitten niet in andere dingen.
  - [ ] Nieuwe cosmetica kun je kopen (testaankoop) en aantrekken.
  - [ ] Nieuw event: `/event <naam> 1`. Werken de effecten, en krijg je de beloning maar één keer?
  - [ ] Telefoonweergave (Test > Device: een kleine telefoon): passen de knoppen?
- [ ] Opslaan en laden: speel, stop, start opnieuw. Is alles er nog?

## 4. Balans
- [ ] Kijk naar de "INFO"-regel van `lune run tests/run` (duur van een ronde).
- [ ] Nieuwe machines: prijs ongeveer 40 tot 90 seconden van het inkomen op dat moment.
- [ ] Geen nieuwe pass of product die gratis spelers duidelijk achterstelt.

## 5. Publiceren
- [ ] Maak een back-up: File > Save to File As > `backups/SkyBakeryTycoon-<versie>.rbxl`
- [ ] `git add .` en `git commit -m "Update <versie>"` en `git push` (of via GitHub Desktop)
- [ ] File > Publish to Roblox
- [ ] Creator Hub: gamebeschrijving bijwerken (wat is nieuw?)
- [ ] Optioneel: nieuw icoon of nieuwe thumbnail met het thema

## 6. Aankondigen
- [ ] Gebruik de tekst uit `updates/<versie>/UPDATE-NOTES.md`.
- [ ] Post in je Roblox-groep of op sociale media.
- [ ] Plan een admin abuse event (bijvoorbeeld zaterdag 15:00) en kondig het eerlijk aan.
- [ ] Na 1 week: kijk in Analytics (spelers, speeltijd, aankopen). Schrijf op wat je leerde:
  - Wat ging goed?
  - Wat kan beter?
