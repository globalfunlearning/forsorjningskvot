# Demografisk försörjningskvot – Sveriges kommuner

Interaktiv webbapplikation som visar demografisk försörjningskvot för alla Sveriges kommuner och län 2000–2025, med möjlighet att lägga till SCB:s befolkningsprognos 2026–2050.

**Länk:** https://globalfunlearning.github.io/forsorjningskvot/

![Skärmdump av applikationen](skärmdump.png)

---

## Funktioner

- Välj mellan tre mått: totalt (0–19 + 65+), från äldre (65+) eller från yngre (0–19)
- Jämför valfria kommuner eller län mot varandra
- Visa Sverige, min/max-linjer och grå bakgrundslinjer för alla kommuner
- **Prognos 2026–2050** (SCB): lägg till streckade prognoslinjer med ljusblå bakgrund för prognosåren
- Tabeller: topp/botten 5, Göteborgsregionens kommuner, 10 största kommunerna
- Exportera diagram som PNG eller data som TSV (klistras in i Excel)
- Responsiv layout – fungerar på mobil och desktop

---

## Filstruktur

```
forsorjningskvot/
├── index.qmd            # Huvudfil – Quarto + HTML + JavaScript
├── styles.css           # CSS enligt Göteborgs grafiska profil
├── _quarto.yml          # Quarto-konfiguration
├── gbg_li_rgb.svg       # Göteborgs logotyp
├── hamta_data.R         # Hämtar historiska data från SCB API → data/forsorjningskvot.json
├── hamta_prognos.R      # Hämtar SCB:s befolkningsprognos → data/prognos.json
├── README.md            # Projektbeskrivning
├── skärmdump.png        # Skärmdump i README
├── data/                # Genererad JSON (gitignorerad)
└── docs/                # Renderad HTML (publiceras via GitHub Pages)
```

---

## Arbetsflöde

```r
# 1. Hämta historiska data (behövs bara vid nytt statistikår)
source("hamta_data.R")        # → data/forsorjningskvot.json

# 2. Hämta prognosdata (behövs vid ny SCB-prognos)
source("hamta_prognos.R")     # → data/prognos.json
```

```bash
# 3. Rendera HTML
quarto render index.qmd --to html

# 4. Publicera
git add . && git commit -m "uppdatera data" && git push
```

---

## JSON-struktur

### `data/forsorjningskvot.json`
```json
{
  "senaste_ar": 2025,
  "ar": [2000, 2001, ..., 2025],
  "totalt": {
    "kommuner": [{ "namn": "Göteborg", "varden": [58.4, ...] }],
    "lan":      [{ "namn": "Västra Götalands län", "varden": [...] }],
    "sverige":  [70.4, ...]
  },
  "aldre": { ... },
  "yngre": { ... }
}
```

### `data/prognos.json`
```json
{
  "ar": [2026, 2027, ..., 2050],
  "forsta_ar": 2026,
  "sista_ar": 2050,
  "totalt": {
    "kommuner": [{ "namn": "Göteborg", "varden": [59.1, ...] }],
    "lan":      [{ "namn": "Västra Götalands län", "varden": [...] }],
    "sverige":  [78.2, ...]
  },
  "aldre": { ... },
  "yngre": { ... }
}
```

---

## Teknikval

| Teknik | Motivering |
|--------|-----------|
| Chart.js | Enkelt, snabbt, professionellt utseende |
| Quarto | R bäddar in JSON i HTML vid rendering |
| `embed-resources: true` | Allt i en HTML-fil – fungerar offline och på GitHub Pages |
| pxweb (R) | Hämtar från SCB API |
| GitHub Pages | Statisk publicering utan server |

---

## Göteborgs grafiska profil

```css
--gb-bla:   #0076bc   /* Göteborgsblå – Kommun 1, knappar */
--gb-rosa:  #e8457a   /* Rosa – Kommun 2 */
--gb-gul:   #f0a800   /* Gul – Sverige-linjen */
--gb-mork:  #1a3a5c   /* Mörkblå – rubriker, text */
```

---

## SCB-tabeller

| Tabell | Innehåll |
|--------|---------|
| `FkvotHVD` | Historisk försörjningskvot per kommun och län 2000– |
| `BefProgRegFakN` | Befolkningsprognos per kommun, ettårsklasser, 2024–2070 |

---

## Att tänka på

- `data/`-mappen är gitignorerad – JSON-filerna genereras lokalt och bäddas in vid `quarto render`
- Knivsta har `null`-värden för 2000–2001 (kommunen tillkom 2002) – hanteras korrekt
- `senaste_ar` i JSON uppdaterar automatiskt alla årsrubriker i tabellerna
- Prognosdata (`prognos.json`) är valfritt – saknas filen visas en informationstext i sidebaren
- SCB:s prognos sträcker sig till 2070 men appen visar bara 2026–2050
