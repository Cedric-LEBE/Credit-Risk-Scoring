# 03_cleaning.R ----
source(here::here("R", "00_config.R"))
log_msg("[03_cleaning] Start")

df_raw <- readr::read_rds(here::here("data", "interim", "df_raw.rds"))

# Vérifier présence de la cible brute

if (!"class" %in% names(df_raw)) {
  stop("Colonne cible manquante: 'class' (UCI German Credit).")
}

# Créer default (1 = mauvais crédit / défaut)
# class: 1 = good, 2 = bad

df_clean <- df_raw %>%
  dplyr::mutate(
    default = dplyr::case_when(
      class == 2 ~ 1L,
      class == 1 ~ 0L,
      TRUE ~ NA_integer_
    )
  ) %>%
  dplyr::select(-class)

# Contrôle
if (any(is.na(df_clean$default))) stop("default contient des NA après mapping. Vérifie 'class'.")
if (any(!df_clean$default %in% c(0L, 1L))) stop("default doit être binaire 0/1.")

# Dédoublonnage

df_clean <- df_clean %>% dplyr::distinct()

# Typage : caractères -> facteurs
# (UCI codes Axx)

cat_cols <- df_clean %>% dplyr::select(where(is.character)) %>% names()
df_clean <- df_clean %>% dplyr::mutate(dplyr::across(dplyr::all_of(cat_cols), as.factor))

# Gestion NA (simple et assumée)
# - facteurs: "unknown"
# - numériques: médiane

num_cols <- df_clean %>% dplyr::select(where(is.numeric)) %>% names()
num_cols <- setdiff(num_cols, "default")

df_clean <- df_clean %>%
  dplyr::mutate(dplyr::across(where(is.factor), ~ forcats::fct_na_value_to_level(.x, level = "unknown"))) %>%
  dplyr::mutate(dplyr::across(dplyr::all_of(num_cols), ~ ifelse(is.na(.x), median(.x, na.rm = TRUE), .x)))

# Sauvegarde

readr::write_rds(df_clean, here::here("data", "processed", "df_clean.rds"))
log_msg("[03_cleaning] Saved df_clean.rds")
log_msg("[03_cleaning] End")