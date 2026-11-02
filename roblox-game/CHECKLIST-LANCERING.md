# Checklist lancering: Sky Bakery Tycoon

Vink af wat klaar is (`[x]`). Alles hieronder doe **jij** op je eigen account. Claude vraagt nooit om je wachtwoord of cookies.

## A. Wat Claude al gedaan en getest heeft
- [x] Code van de game (Luau, Rojo-project)
- [x] Automatische tests: opslaan, aankopen, rekenregels, balans (`lune run tests/run`)
- [x] Controle van het place-bestand en alle require-paden (`lune run tests/place_check`)
- [x] Code-controle met Selene en tegen de Roblox API-lijst
- [x] Back-up: `backups/SkyBakeryTycoon-1.0.0.rbxl`
- [ ] **Nog niet getest in echte Roblox Studio** (dat kan alleen jij, zie B)

## B. Testen in Roblox Studio (± 30 minuten)
Open het project (HANDLEIDING.md, stap 2) en zet eerst aan: **Game Settings > Security > Enable Studio Access to API Services** (anders wordt er niet opgeslagen).

1. **Starten**
   - [ ] Druk op Play. Geen rode fouten in het Output-venster? (View > Output)
   - [ ] Je verschijnt op een eigen eiland. Het bord toont "<jouw naam>'s Bakery".
2. **Tutorial en spelen**
   - [ ] De tutorial wijst naar de groene knop. Stap erop: je koopt de Little Oven.
   - [ ] Taartjes rijden over de band. De kassa telt op. Stap op de kassa: het geld gaat naar je portemonnee.
   - [ ] Koop de Dough Mixer: de tutorial gaat verder en stopt bij "Got it!".
3. **Ongeldige acties (de server moet ze tegenhouden)**
   - [ ] Stap op een rode knop (te weinig geld): je krijgt een melding en NIETS wordt gekocht.
   - [ ] Probeer "Rebirth" zonder Rocket Delivery Pad: het knopje zegt "Locked".
   - [ ] Geef je bakkerij een naam van 1 letter: je krijgt een melding en de naam verandert niet.
   - [ ] Zet in `src/server/Config/AdminConfig.luau` tijdelijk `AdminInStudio = false` (en laat UserIds leeg). Typ `/event GoldenHour`: je krijgt "only for admins" en de Admin-knop is weg. Zet het daarna terug op `true`.
4. **Testaankopen** (ID's nog 0 = gratis testknop "Test R$...")
   - [ ] Shop > Passes > 2x Cash Forever: het inkomen verdubbelt.
   - [ ] Shop > Extras > Bag of Coins: je krijgt geld, en de melding toont hoeveel.
   - [ ] Shop > Extras > 2x Cash (15 min): de gele timer verschijnt.
   - [ ] Shop > Looks: koop de Strawberry Hat en trek hem aan. Zit hij op je hoofd?
   - [ ] Na het invullen van de echte ID's (stap D): test opnieuw. Studio toont dan een testvenster van Roblox; dat kost geen echte Robux.
5. **Opslaan en laden**
   - [ ] Koop een paar machines, stop (Stop) en speel opnieuw: alles is er nog.
   - [ ] Je krijgt "Welcome back! Your bakery earned..." als je even weg was.
6. **Meerdere spelers**
   - [ ] Test > Clients and Servers > 3 spelers > Start. Iedereen krijgt een eigen eiland.
   - [ ] Speler 2 kan niet kopen op het eiland van speler 1.
7. **Telefoon en tablet**
   - [ ] Test > Device: kies een kleine telefoon (bijvoorbeeld iPhone SE) in **liggende** en **staande** stand.
   - [ ] De menuknoppen onderaan passen tussen de joystick en de springknop.
   - [ ] De winkel past op het scherm en je kunt scrollen.
   - [ ] Kies ook een tablet en een pc-scherm.
8. **Admin en events**
   - [ ] Klik op de knop "Admin" > Start Golden Hour (5 min): de lucht kleurt, je loopt sneller en er vallen sterretjes.
   - [ ] Je krijgt één keer de melding "Event gift: ...", ook als je je personage reset (Esc > Reset Character). Elk nieuw event geeft één nieuwe beloning.
   - [ ] "Stop event" zet alles terug.
   - [ ] Werkt de chat-opdracht `/event GoldenHour 2` niet? Gebruik dan de Admin-knop en laat het mij weten.

## C. Publiceren op JOUW account
- [ ] Studio: **File > Publish to Roblox** > "Create new experience" (kies jouw account als eigenaar).
- [ ] Naam: `Sky Bakery Tycoon` (of je eigen naam; check dat geen bekende game zo heet).
- [ ] Zet de game eerst op **Private** tot alles getest is.
- [ ] Creator Hub > jouw game > Places > Settings: **Max Players = 6** (er zijn 6 eilanden).
- [ ] Zet je User ID in `src/server/Config/AdminConfig.luau` (zie HANDLEIDING.md). Als jij de eigenaar bent, ben je ook automatisch admin.

## D. Game passes en developer products aanmaken
Creator Hub (create.roblox.com) > Creations > Sky Bakery Tycoon > **Monetization**.

Game passes (Monetization > Passes > Create a Pass): naam, beschrijving en icoon (512x512). Zet de pass daarna "On Sale" en vul de prijs in.
| Key in ShopConfig | Naam | Prijs | ID (vul in) |
|---|---|---|---|
| AutoCollect | Auto Collect | 99 | |
| PastryWardrobe | Pastry Wardrobe | 149 | |
| DoubleCash | 2x Cash Forever | 199 | |
| VIP | VIP Baker | 249 | |

Developer products (Monetization > Developer Products > Create):
| Key in ShopConfig | Naam | Prijs | ID (vul in) |
|---|---|---|---|
| CashSmall | Bag of Coins | 15 | |
| Boost15 | 2x Cash (15 min) | 29 | |
| HatStrawberry | Strawberry Hat | 35 | |
| HatSnowman | Snowman Hat (seizoen Winter) | 45 | |
| CashMedium | Chest of Coins | 49 | |
| TrailRainbow | Rainbow Sprinkles Trail | 59 | |
| Boost60 | 2x Cash (60 min) | 79 | |
| ThemeCandy | Candy Land Theme | 89 | |
| CashLarge | Vault of Coins | 99 | |

- [ ] Alle ID's ingevuld in `src/shared/Config/ShopConfig.luau` (vervang de `0`).
- [ ] `lune run tests/run`: zegt het dat er een ID dubbel is? Dan heb je er een twee keer geplakt.
- [ ] Zet `ShopConfig.StudioTestPurchases = false` als je niet meer gratis wilt testen (in de echte game werkt het sowieso nooit).
- [ ] Private servers (optioneel): Monetization > Private Servers > aanzetten, prijs bijvoorbeeld 50 Robux per maand.
- [ ] Opnieuw publiceren.

## E. Leeftijdsvragenlijst (Maturity & Compliance)
Creator Hub > jouw game > **Audience > Maturity & Compliance** (de naam kan iets anders zijn). Beantwoord eerlijk. Voor deze game klopt naar verwachting:
- [ ] Geweld: geen
- [ ] Bloed, angst, grof taalgebruik, romantiek, alcohol, gokken: geen
- [ ] **Paid random items: NEE.** (Er is niets willekeurigs te koop.)
- [ ] Spelers kunnen tekst typen die anderen zien: ja (chat en bakkerijnaam, beide gefilterd)
- [ ] Verwachte uitkomst: een lage leeftijdsclassificatie. Roblox bepaalt dit zelf.

## F. Naam, beschrijving, icoon en thumbnails
- [ ] **Beschrijving** (voorstel, in het Engels):
  > Build your own bakery on a floating island in the sky! 🍰 Buy ovens, mixers and cake machines, collect your money and grow the biggest bakery in the clouds. Rebirth for a permanent bonus, collect free hats with stars, and join live admin events. Works great on phone, tablet and PC. Everything in the shop is optional, and you always see exactly what you get.
- [ ] **Icoon** (512x512): je eiland met een grote taart, felle kleuren, weinig tekst. Maak een screenshot in Studio en bewerk het in een gratis programma (bijvoorbeeld Paint.NET, GIMP of Canva-gratis).
- [ ] **Thumbnails** (1920x1080, 3 tot 5 stuks): (1) je volle bakkerij, (2) verdieping 2 met de raket, (3) een event met gouden lucht, (4) de winkel met hoeden.
- [ ] Geen merken, bekende figuren of plaatjes van anderen.
- [ ] Genre: Tycoon (of Simulation).

## G. Live zetten
- [ ] Alles van B tot en met F klaar
- [ ] Game op **Public**
- [ ] Back-up: File > Save to File As > `backups/SkyBakeryTycoon-1.0.0-live.rbxl` en git push
- [ ] Speel zelf even mee in een echte server en test 1 echte aankoop van 15 Robux. Werkt die, dan werkt alles.
- [ ] Na 24 uur en na 7 dagen: kijk in Analytics (HANDLEIDING.md, stap 9).
