# 06b_threshold.R ----
source(here::here("R", "00_config.R"))
log_msg("[06b_threshold] Start")

make_default_factor <- function(x) {
  if (is.factor(x) || is.character(x)) {
    factor(x, levels = c("no_default", "default"))
  } else {
    factor(x, levels = c(0, 1), labels = c("no_default", "default"))
  }
}

split   <- readRDS(here::here("outputs", "tables", "data_split.rds"))
test    <- rsample::testing(split)
fit_log <- readRDS(here::here("outputs", "tables", "fit_logistic.rds"))

test <- test %>%
  dplyr::mutate(default = make_default_factor(default))

probs <- stats::predict(fit_log, test, type = "prob") %>%
  dplyr::bind_cols(test %>% dplyr::select(default)) %>%
  dplyr::mutate(p = .pred_default)

# Sanity checks
na_truth <- sum(is.na(probs$default))
if (na_truth > 0) stop(paste0("default contient ", na_truth, " NA dans le test (vérifie conversion/cleaning)."))

n_default <- sum(probs$default == "default", na.rm = TRUE)
log_msg("[06b_threshold] Test defaults:", n_default, "/", nrow(probs))
if (n_default == 0) stop("Aucun 'default' dans le test. Impossible de calibrer un seuil.")

compute_metrics <- function(thr, truth, p) {
  pred <- ifelse(p >= thr, "default", "no_default")
  
  TP <- sum(pred == "default"    & truth == "default", na.rm = TRUE)
  FN <- sum(pred == "no_default" & truth == "default", na.rm = TRUE)
  FP <- sum(pred == "default"    & truth == "no_default", na.rm = TRUE)
  TN <- sum(pred == "no_default" & truth == "no_default", na.rm = TRUE)
  
  recall <- if ((TP + FN) == 0) NA_real_ else TP / (TP + FN)
  precision <- if ((TP + FP) == 0) NA_real_ else TP / (TP + FP)
  specificity <- if ((TN + FP) == 0) NA_real_ else TN / (TN + FP)
  f1 <- if (is.na(precision) || is.na(recall) || (precision + recall) == 0) NA_real_
  else 2 * precision * recall / (precision + recall)
  
  c(recall = recall, specificity = specificity, precision = precision, f1 = f1,
    TP = TP, FP = FP, TN = TN, FN = FN)
}

thr_grid <- seq(0.01, 0.99, by = 0.01)

metrics_by_thr <- purrr::map_dfr(thr_grid, \(t) {
  m <- compute_metrics(t, probs$default, probs$p)
  tibble::tibble(threshold = t, !!!as.list(m))
})

readr::write_csv(metrics_by_thr, here::here("outputs", "tables", "threshold_metrics.csv"))
log_msg("[06b_threshold] Exported threshold_metrics.csv")

target_recall <- 0.80

candidates <- metrics_by_thr %>%
  dplyr::filter(!is.na(recall), recall >= target_recall)

if (nrow(candidates) == 0) {
  best_recall <- metrics_by_thr %>%
    dplyr::filter(!is.na(recall)) %>%
    dplyr::summarise(max_recall = max(recall)) %>%
    dplyr::pull(max_recall)
  stop(paste0("Aucun seuil ne permet recall >= ", target_recall,
              ". Max recall observé = ", round(best_recall, 3), "."))
}

best <- candidates %>%
  dplyr::arrange(dplyr::desc(specificity), dplyr::desc(f1)) %>%
  dplyr::slice(1)

saveRDS(
  list(threshold = best$threshold[[1]], target_recall = target_recall, best_row = best),
  here::here("outputs", "tables", "chosen_threshold.rds")
)

log_msg("[06b_threshold] Chosen threshold:", best$threshold[[1]],
        "| recall:", round(best$recall[[1]], 3),
        "| specificity:", round(best$specificity[[1]], 3),
        "| precision:", round(best$precision[[1]], 3),
        "| f1:", round(best$f1[[1]], 3))

log_msg("[06b_threshold] End")