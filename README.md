# What If Bot: automatische "What if…?" TikTok-video's

Je typt één zin, bijvoorbeeld **"What if all rubber disappeared for 5 seconds?"**, en de bot maakt er een verticale TikTok-video van (1080×1920, 30 fps, met muziek), in de stijl van de bekende "what if"-simulatieaccounts.

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
- Bij **Instellingen** zet je je TikTok-naam (het watermerk in de video), de kwaliteit en de zelfcontrole.

Via de terminal:

```bash
npm run make -- "What if the Moon was 10 times closer?"
npm run make -- --spec examples/rubber.json      # zonder Claude, met een vaste scène
```

Alle video's komen in `output/<datum-titel>/video.mp4`. Daar staan ook `spec.json` (de scène-code) en `meta.json` (bronnen en TikTok-tekst).

## Instellingen (.env, optioneel)

```
ANTHROPIC_API_KEY=sk-ant-...   # gebruik de API in plaats van Claude Code
CLAUDE_MODEL=claude-sonnet-5-5 # ander model
PORT=3000
```

## Rendertijd

Een video van ~18 seconden kost op een moderne laptop een paar minuten. Op de kwaliteit **Snel** gaat het ongeveer twee keer zo snel.

## Mappen

```
engine/   3D-engine (Three.js): werelden, effecten, tekst-overlay
src/      bot: Claude-koppeling, pipeline, renderer, webserver
ui/       webapp
examples/ voorbeeld-scènes
output/   jouw video's
```
