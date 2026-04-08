# =============================================================================
# HÄMTA FÖRSÖRJNINGSKVOT FRÅN SCB API OCH EXPORTERA TILL JSON
# Göteborgs Stad – stadsledningskontoret
#
# Syfte:   Hämtar demografisk försörjningskvot direkt från SCB:s API,
#          bearbetar data och exporterar till JSON för webbappen.
#
# Kör:     source("hamta_data.R")  – en gång per år när ny statistik finns
#
# Utdata:  data/forsorjningskvot.json
# =============================================================================

library(tidyverse)
library(pxweb)
library(jsonlite)
library(here)

# =============================================================================
# 1. HÄMTA DATA FRÅN SCB API
# =============================================================================

message("Hämtar data från SCB API...")

pxweb_query_list <- list(
  "Region"       = c("*"),   # Alla regioner (kommuner + län + riket)
  "ContentsCode" = c("*"),   # Alla mått (totalt, äldre, yngre)
  "Tid"          = c("*")    # Alla tillgängliga år
)

px_data <- pxweb_get(
  url   = "https://api.scb.se/OV0104/v1/doris/sv/ssd/START/BE/BE0101/BE0101A/FkvotHVD",
  query = pxweb_query_list
)

# Konvertera till tibble med läsbara kolumnnamn
df_raw <- as.data.frame(
  px_data,
  column.name.type   = "text",
  variable.value.type = "text"
) |> as_tibble()

message(sprintf("Hämtade %s rader från SCB API", nrow(df_raw)))

# =============================================================================
# 2. RENSA OCH STRUKTURERA DATA
# =============================================================================

# Byt kolumnnamn till kortare internt format
df <- df_raw |>
  rename(
    region = region,
    ar     = år,
    totalt = `Försörjningskvot totalt`,
    aldre  = `Försörjningskvot, från äldre 65+`,
    yngre  = `Försörjningskvot, från yngre 0-19`
  ) |>
  mutate(
    ar     = as.integer(ar),
    totalt = as.numeric(totalt),
    aldre  = as.numeric(aldre),
    yngre  = as.numeric(yngre),
    # Nollvärden → NA (t.ex. Knivsta saknade data tidiga år)
    totalt = if_else(totalt == 0, NA_real_, round(totalt, 1)),
    aldre  = if_else(aldre  == 0, NA_real_, round(aldre,  1)),
    yngre  = if_else(yngre  == 0, NA_real_, round(yngre,  1)),
    # "Riket" → "Sverige" för visning i appen
    region = if_else(region == "Riket", "Sverige", region)
  )

# Identifiera senaste statistikår dynamiskt
senaste_ar <- max(df$ar, na.rm = TRUE)
message(sprintf("Senaste statistikår: %s", senaste_ar))
message(sprintf("Perioden täcker: %s–%s", min(df$ar), senaste_ar))

# Dela upp i kommuner/Sverige och län
# Länen identifieras via suffix " län"
df_lan    <- df |> filter(str_ends(region, " län"))
df_sverige <- df |> filter(region == "Sverige")
df_kom    <- df |> filter(
  region != "Sverige",
  !str_ends(region, " län")
)

message(sprintf(
  "Regioner: %s kommuner, %s län, Sverige",
  n_distinct(df_kom$region),
  n_distinct(df_lan$region)
))

# =============================================================================
# 3. FORMA DATA FÖR JSON-EXPORT
# =============================================================================

ar_vektor <- sort(unique(df$ar))

# Hjälpfunktion: skapa lista { namn, varden: [v_år1, v_år2, ...] }
# för en given grupp av regioner och ett givet mått
skapa_regionlista <- function(data_sub, matt_kol) {
  data_sub |>
    select(region, ar, v = all_of(matt_kol)) |>
    pivot_wider(id_cols = region, names_from = ar, values_from = v) |>
    pmap(function(region, ...) {
      list(
        namn   = region,
        varden = unname(round(c(...), 1))
      )
    })
}

# Hjälpfunktion: hämta Sverige-vektor för ett mått
skapa_sverige_vektor <- function(matt_kol) {
  df_sverige |>
    arrange(ar) |>
    pull(all_of(matt_kol)) |>
    round(1)
}

message("Bygger JSON-struktur...")

json_data <- list(
  # Metadata – används av appen för dynamiska titlar och tabellrubriker
  senaste_ar = senaste_ar,
  ar         = ar_vektor,

  # Kommundata per mått
  totalt = list(
    kommuner = skapa_regionlista(df_kom, "totalt"),
    lan      = skapa_regionlista(df_lan, "totalt"),
    sverige  = skapa_sverige_vektor("totalt")
  ),
  aldre = list(
    kommuner = skapa_regionlista(df_kom, "aldre"),
    lan      = skapa_regionlista(df_lan, "aldre"),
    sverige  = skapa_sverige_vektor("aldre")
  ),
  yngre = list(
    kommuner = skapa_regionlista(df_kom, "yngre"),
    lan      = skapa_regionlista(df_lan, "yngre"),
    sverige  = skapa_sverige_vektor("yngre")
  )
)

# =============================================================================
# 4. SPARA JSON
# =============================================================================

if (!dir.exists(here("data"))) dir.create(here("data"))

utfil <- here("data", "forsorjningskvot.json")
write_json(json_data, utfil, auto_unbox = TRUE, na = "null", digits = 1)

fil_kb <- file.size(utfil) / 1024
message(sprintf("✅ Exporterat till: %s (%.0f KB)", utfil, fil_kb))
message(sprintf("✅ Klar! Kör nu: quarto render index.qmd --to html"))
