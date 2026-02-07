# 07_export.R ----
source(here::here("R", "00_config.R"))
log_msg("[07_export] Start")

make_default_factor <- function(x) {
  if (is.factor(x) || is.character(x)) {
    factor(x, levels = c("no_default", "default"))
  } else {
    factor(x, levels = c(0, 1), labels = c("no_default", "default"))
  }
}

# Charger split + modèle + seuil recall>=80%

split   <- readRDS(here::here("outputs", "tables", "data_split.rds"))
test    <- rsample::testing(split)
fit_log <- readRDS(here::here("outputs", "tables", "fit_logistic.rds"))

thr_obj <- readRDS(here::here("outputs", "tables", "chosen_threshold.rds"))
thr_review <- thr_obj$threshold   # ex: 0.17 (recall >= 0.80)

test <- test %>% dplyr::mutate(default = make_default_factor(default))

# Prédire proba défaut

pred <- predict(fit_log, test, type = "prob") %>%
  dplyr::bind_cols(test %>% dplyr::select(default)) %>%
  dplyr::mutate(proba_default = .pred_default)

# Définir le seuil reject (top X% des risques)

reject_top_pct <- 0.10  # 10% les plus risqués
thr_reject <- stats::quantile(pred$proba_default, probs = 1 - reject_top_pct, na.rm = TRUE)

# Sécurité: thr_reject doit être >= thr_review
if (thr_reject < thr_review) thr_reject <- thr_review

# Scoring 3 niveaux

scores <- pred %>%
  dplyr::mutate(
    decision = dplyr::case_when(
      proba_default >= thr_reject ~ "reject",
      proba_default >= thr_review ~ "review",
      TRUE ~ "approve"
    )
  ) %>%
  dplyr::select(default, proba_default, decision)

# Export + log

readr::write_csv(scores, here::here("outputs", "tables", "client_scores_test.csv"))
log_msg("[07_export] Exported client_scores_test.csv")
log_msg("[07_export] Threshold review (recall>=80%):", round(thr_review, 3))
log_msg("[07_export] Threshold reject (top", reject_top_pct * 100, "%):", round(as.numeric(thr_reject), 3))

# Récap des décisions
decision_summary <- scores %>% dplyr::count(decision) %>% dplyr::mutate(p = n / sum(n))
readr::write_csv(decision_summary, here::here("outputs", "tables", "decision_summary.csv"))
log_msg("[07_export] Exported decision_summary.csv")

log_msg("[07_export] End")