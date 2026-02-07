source(here::here("R", "00_config.R"))
source(here::here("R", "00_prepare_raw.R"))

source(here::here("R", "01_import.R"))
source(here::here("R", "02_quality_checks.R"))
source(here::here("R", "03_cleaning.R"))
source(here::here("R", "04_features.R"))
source(here::here("R", "05_eda.R"))
source(here::here("R", "06_modeling.R"))
source(here::here("R", "06b_threshold.R"))
source(here::here("R", "07_export.R"))

# ---- Session info (reproductibilité) ----
writeLines(capture.output(sessionInfo()), here::here("session_info.txt"))
log_msg("[run_all] session_info.txt generated")