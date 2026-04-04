# Demografisk försörjningskvot – Sveriges kommuner

Interaktiv app byggd med Quarto + Shinylive. Körs som statisk sida på GitHub Pages – ingen server krävs.

---

## Funktioner

- **Alla kommuner** visas som grå bakgrundslinjer
- **Välj två kommuner** via dropdown – markeras i rosa och gul
- **Tre mått:** Försörjningskvot totalt / Barn (0–19) / Äldre (65+)
- **Referenslinjer** för Göteborgsregionen och Sverige (kryssrutor)
- **Datakälla:** Lokal Excel-fil eller SCB API (live)
- **Topp/botten 5-tabell** för senaste år

---

## Kom igång – steg för steg

### 1. Installera beroenden i R

```r
install.packages(c("shiny", "bslib", "tidyverse", "readxl", "httr2", "jsonlite"))
install.packages("quarto")

# Installera Shinylive-filtret
quarto::quarto_add_extension("quarto-ext/shinylive")
```

### 2. Klona eller skapa GitHub-repo

```bash
# Skapa nytt repo på github.com, klona sedan lokalt:
git clone https://github.com/DITT_NAMN/forsorjningskvot.git
cd forsorjningskvot
```

### 3. Kopiera filerna

Lägg dessa filer i repo-mappen:
- `index.qmd`
- `_quarto.yml`
- `styles.css`
- `demografisk_försörjningskvot.xlsx`

### 4. Rendera lokalt (testa innan publicering)

```r
# I RStudio – öppna projektet och kör:
quarto::quarto_render()

# Eller i terminalen:
quarto render
```

Öppna `docs/index.html` i webbläsaren för att testa.

### 5. Pusha till GitHub

```bash
git add .
git commit -m "Lägg till försörjningskvot-app"
git push origin main
```

### 6. Aktivera GitHub Pages

1. Gå till ditt repo på github.com
2. Klicka **Settings** → **Pages**
3. Under *Source*: välj **Deploy from a branch**
4. Branch: `main`, Folder: `/docs`
5. Klicka **Save**

Efter 1–2 minuter är appen tillgänglig på:
`https://DITT_NAMN.github.io/forsorjningskvot/`

---

## Lägg till ny data / nytt ämne

För att återanvända strukturen för ett annat ämne:

1. Byt ut Excel-filen mot din nya data
2. Justera `lasa_excel()`-funktionen om kolumnstrukturen skiljer sig
3. Byt ut SCB API-anropet i `hamta_scb()` mot rätt tabell
4. Uppdatera `GR_KOMMUNER`-listan om du vill ha korrekt GR-medel
5. Ändra titlar och beskrivningar

---

## Felsökning

**Appen laddar långsamt första gången (~10–15 sek)**
Det är normalt – Shinylive laddar R-paketen som WebAssembly i webbläsaren.

**"Lokal fil hittades inte"**
Excel-filen måste ligga i samma mapp som `index.qmd` och vara med i `resources:` i YAML-headern.

**SCB API returnerar fel**
SCB API kan vara nere eller ha ändrat sin URL. Använd "Lokal fil" som fallback.

---

## Teknisk stack

- [Quarto](https://quarto.org/) – dokumentformat och build-system
- [Shinylive](https://shinylive.io/r/) – Shiny i webbläsaren utan server
- [GitHub Pages](https://pages.github.com/) – gratis hosting av statiska sidor
- [SCB API](https://www.scb.se/vara-tjanster/oppna-data/api/) – öppna data från Statistiska centralbyrån
