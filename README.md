# What If Bot: automatische "What if…?" TikTok-video's

Je typt één zin, bijvoorbeeld **"What if all rubber disappeared for 5 seconds?"**, en de bot maakt er een verticale TikTok-video van (1080×1920, 30 fps, met voice-over en muziek, minstens 23 seconden), in de stijl van de bekende "what if"-simulatieaccounts.

Het is **geen AI-video**. Claude schrijft een scène als code, en jouw computer bouwt die als 3D-wereld en rendert hem frame voor frame.

## Hoe het werkt (5 stappen, net als in het filmpje)

1. **Eén zin.** Jij typt de prompt in de webapp.
2. **Idee en bronnen.** Claude kijkt of het idee sterk is en of je het al eerder hebt gemaakt (dan bedenkt hij een nieuwe twist). Elk getal in de video krijgt een bron.
3. **Het is code.** Claude schrijft een scène-spec: omgeving (stad, strand, snelweg…), camera, effecten (bevriezen, verdwijnen, meteoor, overstroming, zwaartekracht uit…), tellers en ondertitels.
4. **Hij verbetert zijn eigen werk.** De bot rendert eerst testframes. Bij een fout repareert Claude de code, en daarna bekijkt hij de frames zelf en verbetert wat niet goed is.
5. **Je computer rendert.** Een headless browser rendert de 3D-scène, ffmpeg maakt er een MP4 met soundtrack van.

Kosten: **€0 extra**. De bot gebruikt Claude Code, dus je bestaande Claude-abonnement. Je kunt ook een API-key gebruiken.

## Installatie (eenmalig)

Je hebt nodig: **Node.js 18+**, **ffmpeg** en **Claude Code**.

```bash
# Mac
brew install node ffmpeg
npm install -g @anthropic-ai/claude-code
claude            # één keer inloggen met je Claude-account

# daarna, in deze map:
npm install
npx playwright install chromium
```

Windows: installeer Node.js en ffmpeg (bv. `winget install Gyan.FFmpeg`) en voer daarna dezelfde npm-commando's uit.

## Gebruiken

```bash
npm start
```

Open daarna **http://localhost:3000**.

**Op je telefoon of tablet:** het venster toont ook een adres zoals `http://192.168.1.23:3000`. Open dat op je telefoon (die moet op dezelfde wifi zitten). Daar kun je prompts typen, video's bekijken en ze downloaden, en vanaf je telefoon zet je ze direct op TikTok. Vraagt je computer of Node verbindingen mag ontvangen? Klik dan op Toestaan.

**Buiten je wifi (overal):** de makkelijkste manier is een gratis tunnel, bijvoorbeeld `npx localtunnel --port 3000` of [Tailscale](https://tailscale.com). Je computer moet dan wel aan blijven staan, want die rendert de video's.

- Typ een "What if…?" en klik op **Maak video**. Wil je meerdere video's? Zet dan elke prompt op een eigen regel.
- **Geef me ideeën**: Claude bedenkt snel een paar nieuwe onderwerpen.
- **Promptmaker**: typ een onderwerp (of laat het leeg). Claude zoekt **live op YouTube, TikTok en uitlegsites** wat er al gemaakt is en geeft je korte prompts over wat **nog niet gedaan** is, met een link naar wat al bestaat. Met **Gebruik** zet je de prompt in het invulveld. Duurt 1 à 3 minuten.
- Onder **Mijn video's** kun je elke video bekijken, en:
  - **Download**: sla de MP4 op en upload hem zelf op TikTok.
  - **Kopieer tekst**: kopieer de beschrijving met hashtags, klaar om te plakken.
  - **Live**: speel de 3D-scène live af in je browser.
- Bij **Instellingen** zet je je TikTok-naam (het watermerk in de video), de kwaliteit, het doel (viraal of geld verdienen), de minimale lengte (standaard 23 seconden), de voice-over en de zelfcontrole.

Via de terminal:

```bash
npm run make -- "What if the Moon was 10 times closer?"
npm run make -- --spec examples/rubber.json      # zonder Claude, met een vaste scène
```

Alle video's komen in `output/<datum-titel>/video.mp4`. Daar staan ook `spec.json` (de scène-code) en `meta.json` (bronnen en TikTok-tekst).

## Geld verdienen met je video's

De bot maakt de video's, maar het geld komt van de platforms. Zo pak je het aan:

1. **Zet bij Instellingen → Doel op "💰 Geld verdienen (61+ s)".** TikTok betaalt via het **Creator Rewards Program** alleen voor video's van **langer dan 1 minuut**. In deze modus schrijft Claude een langere mini-documentaire met tijdsprongen ("1 uur later…", "1 jaar later…") en een re-hook halverwege, zodat mensen blijven kijken. Renderen duurt ongeveer twee keer zo lang.
2. **Eerst groeien.** Voor Creator Rewards heb je (bij het schrijven) ongeveer nodig: 18+, **10.000 volgers** en **100.000 views in de laatste 30 dagen**, en het programma moet in jouw land beschikbaar zijn. Controleer de actuele regels in de TikTok-app (Profiel → ☰ → TikTok Studio → Monetisatie); ze veranderen regelmatig. Zolang je die drempel niet haalt, kun je ook korte video's (23–32 s) mixen om sneller te groeien.
3. **Post vaak en vast.** 1 à 3 video's per dag. Zet meerdere prompts onder elkaar in de app, dan maakt de bot ze achter elkaar, bijvoorbeeld 's nachts.
4. **Dezelfde video op meer plekken.** Upload hem ook als **YouTube Short** (YouTube Partner Program: 1.000 abonnees + 10 miljoen Shorts-views in 90 dagen) en als **Instagram Reel**. Eén keer renderen, drie keer kansen.
5. **Regels die je uitbetaling beschermen:** de video's zijn je eigen gerenderde werk (geen gekopieerde clips), gebruik geen muziek waarop rechten rusten, en zet bij het uploaden het label voor door AI gemaakte content aan als TikTok erom vraagt. Klopt een getal niet, dan wordt het in de reacties afgebrand: laat de bronnen (in `meta.json`) staan.
6. **Extra inkomsten** zodra je een publiek hebt: TikTok Shop-affiliate (bijv. telescopen of science-kits bij ruimtevideo's), merkdeals via TikTok One, of op maat gemaakte "what if"-video's verkopen aan bedrijven en scholen.

## Voice-over

Elke video krijgt automatisch een vertelstem. Claude schrijft de tekst mee in de scène (veld `voiceover`), getimed op de ondertitels. De muziek wordt automatisch zachter wanneer de stem praat.

- Standaard gebruikt de bot de gratis neurale stemmen van Microsoft (internet nodig, geen account). De bot kiest een stem die bij de taal van je prompt past: Engels → *Andrew*, Nederlands → *Maarten*, Vlaams → *Arnaud*. Er is dus geen buitenlands accent.
- Een vrouwenstem kies je met `"voice": { "gender": "female" }` in de spec, of voor alles met `TTS_VOICE=nl-NL-FennaNeural` in `.env`.
- Uitzetten kan bij **Instellingen → Voice-over** in de app.
- Andere stemmen (optioneel, in `.env`): `ELEVENLABS_API_KEY=…` voor ElevenLabs of `TTS_ENGINE=openai` + `OPENAI_API_KEY=…`. Zonder internet valt de bot terug op de stemmen van je Mac (`say`) of op espeak.

## Instellingen (.env, optioneel)

```
ANTHROPIC_API_KEY=sk-ant-...   # gebruik de API in plaats van Claude Code
CLAUDE_MODEL=claude-sonnet-5-5 # ander model
PORT=3000
```

## Rendertijd

Een video van ~25 seconden kost op een moderne laptop een paar minuten. Op de kwaliteit **Snel** gaat het ongeveer twee keer zo snel.

## Mappen

```
engine/   3D-engine (Three.js): werelden, effecten, tekst-overlay
src/      bot: Claude-koppeling, pipeline, renderer, webserver
ui/       webapp
examples/ voorbeeld-scènes
output/   jouw video's
```
