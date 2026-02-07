# 01_import.R ----
source(here::here("R", "00_config.R"))

log_msg("[01_import] Start")

raw_path <- here::here("data", "raw", "credit_default.csv")
stop_if_missing(raw_path)

df_raw <- readr::read_csv(raw_path, show_col_types = FALSE) %>%
  janitor::clean_names()

if (nrow(df_raw) == 0) stop("Le fichier credit_default.csv est vide.")

log_msg("[01_import] Rows:", nrow(df_raw), "| Cols:", ncol(df_raw))

dplyr::glimpse(df_raw)

readr::write_rds(df_raw, here::here("data", "interim", "df_raw.rds"))
log_msg("[01_import] Saved interim df_raw.rds")

log_msg("[01_import] End")
