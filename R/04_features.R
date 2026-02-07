# 04_features.R ----
source(here("R", "00_config.R"))

log_msg("[04_features] Start")

df_clean <- read_rds(here("data", "processed", "df_clean.rds"))

df_feat <- df_clean

write_rds(df_feat, here("data", "processed", "df_features.rds"))
log_msg("[04_features] Saved df_features.rds")
log_msg("[04_features] End")
