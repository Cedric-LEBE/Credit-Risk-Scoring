# 02_quality_checks.R ----
source(here::here("R", "00_config.R"))
log_msg("[02_quality_checks] Start")

df_raw <- readr::read_rds(here::here("data", "interim", "df_raw.rds"))

# ---- Détection cible (avant nettoyage) ----

if (!"class" %in% names(df_raw)) {
  stop("Colonne cible 'class' introuvable après lecture des données. Vérifie le fichier german.data.")
}

target_col <- "class"

log_msg("[02_quality_checks] Target detected:", target_col)

# ---- Profil rapide ----
skimr::skim(df_raw)

# ---- NA rate ----
na_rate <- df_raw %>%
  dplyr::summarise(dplyr::across(dplyr::everything(), ~ mean(is.na(.)))) %>%
  tidyr::pivot_longer(dplyr::everything(), names_to = "var", values_to = "na_rate") %>%
  dplyr::arrange(dplyr::desc(na_rate))

readr::write_csv(na_rate, here::here("outputs", "tables", "na_rate.csv"))
log_msg("[02_quality_checks] Exported na_rate.csv")

# ---- Doublons ----
dup_n <- sum(duplicated(df_raw))
log_msg("[02_quality_checks] Duplicate rows:", dup_n)

# ---- Distribution cible ----
target_dist <- df_raw %>%
  dplyr::count(.data[[target_col]]) %>%
  dplyr::mutate(p = n / sum(n))

readr::write_csv(target_dist, here::here("outputs", "tables", "target_distribution_raw.csv"))
log_msg("[02_quality_checks] Exported target_distribution_raw.csv")

log_msg("[02_quality_checks] End")