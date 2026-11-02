# Handleiding: Sky Bakery Tycoon

Deze handleiding is voor jou, ook als Claude er niet meer is. Alles wat de game nodig heeft, staat in deze map en op jouw eigen Roblox-account. De game gebruikt **geen** Claude, geen API-sleutel, geen betaalde dienst en geen externe server.

---

## Inhoud
1. Gratis tools installeren (eenmalig)
2. Het project openen in Roblox Studio
3. Hoe de map in elkaar zit
4. Een prijs veranderen
5. Een item (machine of hoed) toevoegen
6. Een game pass of developer product koppelen
7. Een update publiceren
8. Back-ups maken en terugzetten
9. Inkomsten en cijfers bekijken
10. Admin en events
11. Als er iets misgaat
12. Tools en versies

---

## 1. Gratis tools installeren (eenmalig)

| Tool | Waarvoor | Waar |
|---|---|---|
| **Roblox Studio** | de game bouwen, testen en publiceren | create.roblox.com > Start creating |
| **Rokit** | installeert de andere tools met één opdracht | github.com/rojo-rbx/rokit (volg "Installation") |
| **Git** of **GitHub Desktop** | back-ups op GitHub | git-scm.com of desktop.github.com |
| **VS Code** (optioneel) | bestanden bewerken | code.visualstudio.com |

Na het installeren van Rokit: open een terminal **in de map `roblox-game`** en typ:
```
rokit install
```
Dit installeert Rojo, Lune, StyLua en Selene, in precies de versies uit `rokit.toml`.

> **Terminal openen in een map:** Windows: open de map in Verkenner, typ `cmd` in de adresbalk en druk op Enter. Mac: rechtsklik op de map > "Nieuwe Terminal bij map".

**Rojo-plugin in Studio** (eenmalig): typ in de terminal
```
rojo plugin install
```
en herstart Studio. Je ziet dan een knop "Rojo" bij het tabblad Plugins.

---

## 2. Het project openen in Roblox Studio

**Snel (alleen kijken of spelen):** dubbelklik op `backups/SkyBakeryTycoon-1.0.0.rbxl`.

**Met live code (aanrader bij aanpassen):**
1. Terminal in de map `roblox-game`:
   ```
   rojo serve
   ```
   Laat dit venster open staan.
2. Open in Studio je game (of een lege Baseplate).
3. Plugins > Rojo > **Connect**.
4. Nu staat de code in Studio. Elke keer dat je een bestand opslaat, verandert het meteen in Studio.
5. **Eén keer per game:** Home > Game Settings > Security > zet **Enable Studio Access to API Services** aan. Anders wordt er in Studio niets opgeslagen (je ziet dan een gele melding "Studio test mode").

> Let op: Rojo zet de **code** in Studio. De wereld (eilanden, bruggen) maakt de code zelf bij het starten. Je hoeft dus niets te bouwen in Studio.

**Een .rbxl-bestand maken van de code:**
```
rojo build -o build/SkyBakeryTycoon.rbxl
```

---

## 3. Hoe de map in elkaar zit

```
roblox-game/
├── default.project.json      Rojo: welke map waar in Roblox komt
├── rokit.toml                lijst met tools en versies
├── src/
│   ├── shared/               code voor server én speler
│   │   ├── Config/
│   │   │   ├── GameConfig.luau   ← BALANS: machines, prijzen in spelgeld, rebirth
│   │   │   ├── ShopConfig.luau   ← WINKEL: Robux-prijzen, ID's, cosmetica, seizoen
│   │   │   └── EventConfig.luau  ← EVENTS: admin abuse events
│   │   ├── Economy.luau          rekenregels
│   │   ├── Format.luau           getallen netjes tonen
│   │   └── Remotes.luau          communicatie server <-> speler
│   ├── server/               code die alleen op de server draait (veilig)
│   │   ├── Config/AdminConfig.luau  ← WIE admin is
│   │   ├── Main.server.luau     start alles
│   │   ├── Services/            de onderdelen (opslaan, winkel, eilanden, ...)
│   │   └── Util/                hulpjes (herhaalpogingen, veilig opslaan, aankopen)
│   └── client/               code op het apparaat van de speler (alleen tonen)
│       ├── Main.client.luau
│       ├── UI/                  het scherm: HUD, winkel, vensters, tutorial
│       └── Visuals.luau         taartjes op de band, lucht bij events, geluid
├── tests/                    automatische tests (lune run tests/run)
├── tools/new-update.luau     update klaarzetten
├── updates/                  één map per update
└── backups/                  .rbxl-back-ups
```

**Je hoeft bijna alleen de 4 bestanden met een ← te veranderen.**

---

## 4. Een prijs veranderen

### Prijs in spelgeld (machines)
Open `src/shared/Config/GameConfig.luau`, zoek de machine en verander `Price` (kosten) of `Income` (geld per seconde).
```lua
{
	Id = "brick_oven",
	Name = "Brick Oven",
	Price = 1500,   -- <- verander dit
	Income = 18,
	...
},
```
**Verander nooit het `Id`** van iets dat al gepubliceerd is: spelers verliezen het dan.

### Prijs in Robux (passes en producten)
1. Creator Hub > jouw game > Monetization > Passes (of Developer Products) > kies het item > verander de prijs.
2. Verander dezelfde prijs in `src/shared/Config/ShopConfig.luau` bij `Price` (dit getal is alleen een reserve voor de winkel; de echte prijs komt van Roblox).
3. Publiceer (stap 7).

Test daarna altijd:
```
lune run tests/run
```

---

## 5. Een item toevoegen

### Makkelijkste manier: met het update-script
```
lune run tools/new-update 1.1.0
```
Vul `updates/1.1.0/new-content.json` in (er staat een voorbeeld in, plus uitleg bij `_Help`) en daarna:
```
lune run tools/new-update 1.1.0 apply
lune run tests/run
```

### Met de hand
**Een machine:** kopieer in `GameConfig.luau` een bestaand item, plak het **boven** de regel `-- @@NEW_ITEMS@@` (laat die regel staan) en verander:
- `Id`: nieuw en uniek, kleine letters en `_` (bijvoorbeeld `"cherry_oven"`)
- `Requires`: het Id van het item dat je eerst moet hebben
- `Style`: uiterlijk (`oven`, `mixer`, `counter`, `station`, `fryer`, `press`, `tower`, `fountain`, `spinner`, `pad`, `flowers`, `tables`)
- `Floor`, `X`, `Z`: plek. Vrije plekken: verdieping 2: (X -30, Z 36), (X 2, Z 36), (X 32, Z 36). Verdieping 1: (X -18, -6, 6 of 18, Z 30).

**Een hoed die je gratis kunt kopen met sterren:** in `ShopConfig.luau` onder `ShopConfig.Cosmetics`:
```lua
{ Id = "lemon_hat", Name = "Lemon Hat", Kind = "Hat", Shape = "berry", Color = { 255, 230, 60 }, Get = { Stars = 2 } },
```

**Een hoed die je voor Robux verkoopt:** maak (1) een developer product in `ShopConfig.Products` met `Kind = "Cosmetic"` en (2) een cosmetic met `Get = { Robux = "<Key van het product>" }`. Kijk naar `HatStrawberry` en `strawberry_hat` als voorbeeld.

**Een seizoensitem:** geef het `Season = "Winter"`. Het is alleen te koop als `ShopConfig.ActiveSeason = "Winter"`. Wie het al heeft, houdt het altijd.

---

## 6. Een game pass of developer product koppelen

1. Creator Hub (create.roblox.com) > Creations > jouw game > **Monetization**.
2. **Passes** > Create a Pass > naam, beschrijving en icoon > Create. Open de pass > Sales > "Item for Sale" aan > prijs.
3. **Developer Products** > Create a Developer Product > naam, prijs, beschrijving.
4. Kopieer het **ID** (het nummer).
5. Zet het in `src/shared/Config/ShopConfig.luau`, bijvoorbeeld:
   ```lua
   DoubleCash = {
       Id = 123456789,   -- <- was 0
   ```
6. `lune run tests/run` (controleert ook of je een ID twee keer gebruikte).
7. Publiceren.

> Gebruik dezelfde naam en beschrijving als in ShopConfig, zodat spelers overal hetzelfde lezen.

---

## 7. Een update publiceren

Volg `UPDATE-SJABLOON.md`. In het kort:
1. Aanpassen en `lune run tests/run`
2. Testen in Studio (Play)
3. Back-up maken (stap 8)
4. Studio: **File > Publish to Roblox**
5. Oude servers draaien nog op de oude versie. Wil je iedereen meteen op de nieuwe versie? Creator Hub > jouw game > ... (drie puntjes) > **Restart servers** (of "Shut down all servers"). Spelers worden opnieuw verbonden; hun voortgang wordt eerst opgeslagen.

---

## 8. Back-ups maken en terugzetten

### Back-up maken (doe dit bij elke update)
1. **Code op GitHub (privé):**
   - Eenmalig: maak op github.com een nieuwe **private** repository, bijvoorbeeld `sky-bakery-tycoon`.
   - Met GitHub Desktop: File > Add local repository > kies de map `roblox-game` (of "Create a repository" als die nog geen git-map is) > Publish repository > vink **Keep this code private** aan.
   - Elke update: schrijf een korte samenvatting > **Commit to main** > **Push origin**.
2. **Het spel zelf (.rbxl):** Studio > File > **Save to File As** > `backups/SkyBakeryTycoon-<versie>.rbxl`. Zet dit bestand ook op een USB-stick of in je cloudopslag.

### Terugzetten
- **Een oude versie van de game op Roblox:** Creator Hub > jouw game > Places > jouw place > **Version History** > kies een versie > Restore. Of: open de .rbxl-back-up in Studio > File > Publish to Roblox (kies je bestaande game).
- **Oude code:** GitHub Desktop > History > rechtsklik op een commit > "Revert changes in commit". Of download de code van github.com > Code > Download ZIP.
- **Spelersdata** staat veilig bij Roblox (DataStore). Een oude versie publiceren wist geen data, zolang je de naam `SkyBakeryPlayerData_v1` in `DataService.luau` niet verandert.

---

## 9. Inkomsten en cijfers bekijken

Creator Hub > Creations > jouw game > **Analytics**:
- **Overview / Engagement**: spelers per dag, speeltijd, hoeveel spelers terugkomen (retention).
- **Monetization**: Robux per dag, welke passes en producten verkopen, en hoeveel betalende spelers.
- **Acquisition**: waar spelers vandaan komen.

Jouw Robux: roblox.com > Robux-icoon > **My Transactions** (bij "Sales of goods"). Let op:
- Roblox houdt ongeveer 30% van elke verkoop; jij krijgt ongeveer 70%.
- Robux zijn eerst **30 dagen "pending"** (wachttijd) voordat je ze kunt gebruiken.
- Robux omwisselen naar echt geld heet **DevEx**. Daarvoor gelden voorwaarden (onder andere een minimum aantal Robux, een minimumleeftijd en identiteitscontrole). Lees de actuele voorwaarden op de Roblox-site (zoek "Developer Exchange").

**Eerlijk:** de meeste nieuwe games krijgen in het begin weinig spelers. Regelmatige updates, events, een goed icoon en korte filmpjes (TikTok, YouTube Shorts) helpen. Inkomsten zijn nooit gegarandeerd.

---

## 10. Admin en events

**Jezelf admin maken:** zoek je User ID (in de adresbalk van je Roblox-profiel staat `roblox.com/users/123456789/profile`). Zet het in `src/server/Config/AdminConfig.luau`:
```lua
AdminConfig.UserIds = {
	123456789,
}
```
Als jij de eigenaar van de game bent, ben je ook automatisch admin (`IncludeGameOwner = true`).

**Opdrachten in de chat (alleen admins):**
| Opdracht | Wat het doet |
|---|---|
| `/event GoldenHour` | start Golden Hour (standaardduur) |
| `/event SugarRush 15` | start Sugar Rush voor 15 minuten |
| `/event CakeParty 10 all` | start in **alle** servers |
| `/endevent` of `/endevent all` | stop het event |
| `/announce Event at 3 PM!` | bericht voor iedereen (gaat door de filter) |
| `/givecash me 10k` | geef jezelf (of een speler) geld |
| `/kick naam` | speler uit de server |
| `/adminhelp` | lijst met opdrachten |

Of gebruik de knop **Admin** onderaan het scherm (die zien alleen admins).

**Een event aanpassen of toevoegen:** open `src/shared/Config/EventConfig.luau`. Alles staat met uitleg bovenaan het bestand: duur, x inkomen, snelheid, springkracht, zwaartekracht, kleur van de lucht, sterretjes en de beloning. Kopieer een bestaand event om een nieuw event te maken.

**Tip:** kondig events eerlijk aan ("Saturday 3 PM: Golden Hour!") en houd ze echt. Gebruik geen nep-aftellers.

---

## 11. Als er iets misgaat

| Probleem | Oplossing |
|---|---|
| Rode fouten in Output bij Play | Lees de eerste rode regel: daar staan het bestand en het regelnummer. Draai `lune run tests/run`. Zet zo nodig de laatste werkende versie terug (stap 8). |
| `[Config FOUT] ...` in Output | Je hebt een fout gemaakt in een config-bestand. De melding zegt welk item. `lune run tests/run` toont het ook. |
| "Studio test mode: progress is NOT saved" | Zet Game Settings > Security > Enable Studio Access to API Services aan (en publiceer de game eerst één keer). |
| Spelers zeggen dat hun voortgang weg is | Vraag of ze opnieuw joinen. Als Roblox even storing heeft, krijgen ze een melding in plaats van lege data. Controleer status.roblox.com. Verander NOOIT de naam van de DataStore. |
| "Your bakery is still saving..." | De speler sprong snel naar een andere server. Na 1 minuut opnieuw joinen lost het op. |
| Aankoop gedaan maar niets gekregen | Developer products: Roblox probeert het automatisch opnieuw (ook bij opnieuw joinen). Kijk in Output naar `[Purchase]`. Staat het ID goed in ShopConfig? Bij twijfel: geef met `/givecash` een vergoeding. |
| De winkel zegt "Soon" | Het ID in ShopConfig is nog 0 (stap 6). |
| Chat-opdrachten werken niet | Gebruik de Admin-knop. Controleer je User ID in AdminConfig. |
| `rojo serve` geeft een fout | Sluit andere `rojo serve`-vensters. Controleer of je in de map `roblox-game` staat. Zijn de plugin en de tool dezelfde versie? Doe opnieuw `rojo plugin install`. |
| De game is te makkelijk of te moeilijk | Pas Price en Income aan in GameConfig. Kijk naar de "INFO"-regel van de tests. |
| Roblox stuurt een moderatiebericht | Lees het goed, pas aan wat gevraagd wordt en antwoord via de link in het bericht. Kopieer nooit content van anderen. |

**Tests (doe dit na elke wijziging):**
```
lune run tests/run
rojo build -o build/SkyBakeryTycoon.rbxl
lune run tests/place_check
selene src
```
Voor `selene src` heb je het bestand `roblox.yml` nodig (staat al in de map; vernieuwen kan met `selene generate-roblox-std`).

---

## 12. Tools en versies

Allemaal gratis. Versies staan ook in `rokit.toml`.

| Tool | Versie | Gebruik |
|---|---|---|
| Roblox Studio | nieuwste (werkt zichzelf bij) | bouwen, testen, publiceren |
| Rojo (CLI + Studio-plugin) | 7.7.1 | code van bestanden naar Studio |
| Rokit | nieuwste | tools installeren |
| Lune | 0.11.1 | tests en update-script draaien |
| StyLua | 2.6.0 | code netjes opmaken (`stylua src`) |
| Selene | 0.31.0 | code controleren (`selene src`) |
| Git / GitHub Desktop | nieuwste | back-ups |
| VS Code (optioneel) | nieuwste | bestanden bewerken |

Getest met: 29 automatische tests (Lune 0.11.1), Rojo-build, place-controle, Selene en een controle van alle Roblox-namen tegen de officiële API-lijst (november 2026).
