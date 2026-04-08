# =============================================================================
# hamta_prognos.R
# Hämtar SCB:s kommunprognoser och beräknar demografisk försörjningskvot
# för åren 2026–2050. Sparar data/prognos.json i samma format som
# forsorjningskvot.json (totalt / aldre / yngre), med kommuner + län + sverige.
#
# Kör detta skript när ny prognos finns tillgänglig från SCB.
# Kör sedan: quarto render index.qmd --to html
# =============================================================================

library(pxweb)
library(dplyr)
library(tidyr)
library(jsonlite)
library(here)

# -----------------------------------------------------------------------------
# 1. HÄMTA DATA FRÅN SCB API
# -----------------------------------------------------------------------------

message("Hämtar prognosdata från SCB API...")

pxweb_query_list <- list(
  "Region"         = c("*"),   # Alla regioner (kommuner + län)
  "InrikesUtrikes" = "83",     # Inrikes och utrikes födda (totalt)
  "Alder"          = c("*"),   # Alla ettårsklasser 0–100+
  "ContentsCode"   = c("000005RC"),  # Antal personer
  "Tid"            = c("*")    # Alla tillgängliga år
)

px_data <- pxweb_get(
  url   = "https://api.scb.se/OV0104/v1/doris/sv/ssd/START/BE/BE0401/BE0401A/BefProgRegFakN",
  query = pxweb_query_list
)

df_raw <- as.data.frame(
  px_data,
  column.name.type    = "text",
  variable.value.type = "text"
) |> as_tibble()

message("Rader hämtade: ", nrow(df_raw))

# -----------------------------------------------------------------------------
# 2. RENSA OCH FILTRERA
# -----------------------------------------------------------------------------

# Byt till enklare kolumnnamn
df <- df_raw |>
  rename(
    region = 1,
    alder  = 3,
    ar     = 4,
    antal  = 5
  ) |>
  mutate(
    ar    = as.integer(ar),
    antal = as.numeric(antal),
    # Gör om ålder till heltal (0–100, där "100+ år" → 100)
    alder_int = as.integer(gsub("[^0-9]", "", alder))
  )

# Filtrera till prognosår 2026–2050
PROG_AR <- 2026:2050

df <- df |> filter(ar %in% PROG_AR)

message("Rader efter filtrering (2026–2050): ", nrow(df))

# -----------------------------------------------------------------------------
# 3. IDENTIFIERA KOMMUNER OCH LÄN
# -----------------------------------------------------------------------------

# SCB returnerar kommuner utan kod (t.ex. "Göteborg", "Stockholm")
# och länen med "läns"-suffix (t.ex. "Stockholms län")
alla_regioner <- unique(df$region)

lan_namn   <- alla_regioner[grepl("län$", alla_regioner)]
kom_namn   <- alla_regioner[!grepl("län$", alla_regioner)]

message("Antal kommuner: ", length(kom_namn))
message("Antal län: ",      length(lan_namn))

# -----------------------------------------------------------------------------
# 4. BERÄKNA FÖRSÖRJNINGSKVOT PER REGION OCH ÅR
# -----------------------------------------------------------------------------

# Försörjningskvot = (antal i grupp / antal i arbetsför ålder 20–64) * 100
# Totalt  = (0–19 + 65+)  / 20–64 * 100
# Äldre   = 65+            / 20–64 * 100
# Yngre   = 0–19           / 20–64 * 100

berakna_kvoter <- function(df_region) {
  df_region |>
    group_by(region, ar) |>
    summarise(
      n_yngre  = sum(antal[alder_int <= 19],           na.rm = TRUE),
      n_arbfor = sum(antal[alder_int >= 20 & alder_int <= 64], na.rm = TRUE),
      n_aldre  = sum(antal[alder_int >= 65],           na.rm = TRUE),
      .groups  = "drop"
    ) |>
    mutate(
      kvot_totalt = ifelse(n_arbfor > 0, (n_yngre + n_aldre) / n_arbfor * 100, NA_real_),
      kvot_aldre  = ifelse(n_arbfor > 0, n_aldre              / n_arbfor * 100, NA_real_),
      kvot_yngre  = ifelse(n_arbfor > 0, n_yngre              / n_arbfor * 100, NA_real_)
    )
}

# Kommuner
df_kom <- df |> filter(region %in% kom_namn)
kvoter_kom <- berakna_kvoter(df_kom)

# Län
df_lan <- df |> filter(region %in% lan_namn)
kvoter_lan <- berakna_kvoter(df_lan)

# Sverige = summa av alla läns befolkning per ålder och år
df_sverige <- df |>
  filter(region %in% lan_namn) |>
  group_by(alder_int, ar) |>
  summarise(antal = sum(antal, na.rm = TRUE), .groups = "drop") |>
  mutate(region = "Sverige")

kvoter_sve <- berakna_kvoter(df_sverige)

message("Kvoter beräknade.")

# -----------------------------------------------------------------------------
# 5. BYGG JSON-STRUKTUR
# -----------------------------------------------------------------------------

# Hjälp: forma en lista [{namn, varden:[...]}] sorterat på ar
forma_lista <- function(kvoter_df, kvot_kol) {
  kvoter_df |>
    select(region, ar, kvot = all_of(kvot_kol)) |>
    arrange(region, ar) |>
    group_by(region) |>
    summarise(
      namn   = first(region),
      varden = list(round(kvot, 2)),
      .groups = "drop"
    ) |>
    select(namn, varden) |>
    # Konvertera till lista av listor
    purrr::pmap(list) |>
    purrr::map(~ list(namn = .x$namn, varden = .x$varden))
}

# Sveriges värden som enkel vektor
sve_vektor <- function(kvoter_df, kvot_kol) {
  kvoter_df |>
    arrange(ar) |>
    pull(all_of(kvot_kol)) |>
    round(2)
}

# Bygg JSON-objekt
prognos_json <- list(
  ar          = PROG_AR,
  forsta_ar   = min(PROG_AR),
  sista_ar    = max(PROG_AR),
  totalt = list(
    kommuner = forma_lista(kvoter_kom, "kvot_totalt"),
    lan      = forma_lista(kvoter_lan, "kvot_totalt"),
    sverige  = sve_vektor(kvoter_sve, "kvot_totalt")
  ),
  aldre = list(
    kommuner = forma_lista(kvoter_kom, "kvot_aldre"),
    lan      = forma_lista(kvoter_lan, "kvot_aldre"),
    sverige  = sve_vektor(kvoter_sve, "kvot_aldre")
  ),
  yngre = list(
    kommuner = forma_lista(kvoter_kom, "kvot_yngre"),
    lan      = forma_lista(kvoter_lan, "kvot_yngre"),
    sverige  = sve_vektor(kvoter_sve, "kvot_yngre")
  )
)

# -----------------------------------------------------------------------------
# 6. SPARA JSON
# -----------------------------------------------------------------------------

data_mapp <- here("data")
if (!dir.exists(data_mapp)) dir.create(data_mapp)

json_fil <- file.path(data_mapp, "prognos.json")
write(toJSON(prognos_json, auto_unbox = TRUE, digits = 2), json_fil)

message("✓ Sparad: ", json_fil)
message("  Kommuner: ", length(prognos_json$totalt$kommuner))
message("  Län:      ", length(prognos_json$totalt$lan))
message("  År:       ", paste(PROG_AR[c(1, length(PROG_AR))], collapse = "–"))
