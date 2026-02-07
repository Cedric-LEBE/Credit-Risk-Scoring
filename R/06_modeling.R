# 06_modeling.R ----
source(here::here("R", "00_config.R"))
log_msg("[06_modeling] Start")

df <- readr::read_rds(here::here("data", "processed", "df_features.rds")) %>%
  dplyr::mutate(
    default = factor(default, levels = c(0, 1), labels = c("no_default", "default"))
  )

set.seed(123)
split <- rsample::initial_split(df, prop = 0.8, strata = default)
train <- rsample::training(split)
test  <- rsample::testing(split)

rec <- recipes::recipe(default ~ ., data = train) %>%
  recipes::step_zv(recipes::all_predictors()) %>%
  recipes::step_dummy(recipes::all_nominal_predictors()) %>%
  recipes::step_zv(recipes::all_predictors()) %>%
  recipes::step_normalize(recipes::all_numeric_predictors())

# --- Logistique ---
model_log <- parsnip::logistic_reg() %>%
  parsnip::set_engine("glm") %>%
  parsnip::set_mode("classification")

wf_log <- workflows::workflow() %>%
  workflows::add_recipe(rec) %>%
  workflows::add_model(model_log)

fit_log <- parsnip::fit(wf_log, data = train)
log_msg("[06_modeling] Trained logistic regression")

# --- Arbre + tuning ---
model_tree <- parsnip::decision_tree(
  cost_complexity = tune::tune(),
  tree_depth = tune::tune()
) %>%
  parsnip::set_engine("rpart") %>%
  parsnip::set_mode("classification")

wf_tree <- workflows::workflow() %>%
  workflows::add_recipe(rec) %>%
  workflows::add_model(model_tree)

set.seed(123)
folds <- rsample::vfold_cv(train, v = 5, strata = default)

grid_tree <- dials::grid_regular(
  dials::cost_complexity(range = c(-4, -1)),
  dials::tree_depth(range = c(2, 8)),
  levels = 4
)

metric_set_used <- yardstick::metric_set(yardstick::roc_auc, yardstick::accuracy, yardstick::f_meas)

set.seed(123)
tuned_tree <- tune::tune_grid(
  wf_tree,
  resamples = folds,
  grid = grid_tree,
  metrics = metric_set_used
)

best_tree <- tune::select_best(tuned_tree, metric = "roc_auc")

final_tree <- tune::finalize_workflow(wf_tree, best_tree)

fit_tree <- parsnip::fit(final_tree, data = train)
log_msg("[06_modeling] Trained tuned decision tree")

# --- Eval test (positive = default) ---
eval_on_test <- function(fit_obj, data_test, name) {
  probs <- stats::predict(fit_obj, data_test, type = "prob") %>%
    dplyr::bind_cols(data_test %>% dplyr::select(default))
  
  auc <- yardstick::roc_auc(probs, truth = default, .pred_default, event_level = "second")
  
  preds <- probs %>%
    dplyr::mutate(
      pred_class = factor(
        dplyr::if_else(.pred_default >= 0.5, "default", "no_default"),
        levels = c("no_default", "default")
      )
    )
  
  acc <- yardstick::accuracy(preds, truth = default, estimate = pred_class)
  f1  <- yardstick::f_meas(preds, truth = default, estimate = pred_class, event_level = "second")
  
  tibble::tibble(
    model = name,
    roc_auc = auc$.estimate,
    accuracy = acc$.estimate,
    f1 = f1$.estimate
  )
}

m_log  <- eval_on_test(fit_log, test, "logistic_glm")
m_tree <- eval_on_test(fit_tree, test, "decision_tree_tuned")

metrics <- dplyr::bind_rows(m_log, m_tree)
readr::write_csv(metrics, here::here("outputs", "tables", "model_metrics_test.csv"))
log_msg("[06_modeling] Exported model_metrics_test.csv")

saveRDS(fit_log,  here::here("outputs", "tables", "fit_logistic.rds"))
saveRDS(fit_tree, here::here("outputs", "tables", "fit_tree.rds"))
saveRDS(split,    here::here("outputs", "tables", "data_split.rds"))

log_msg("[06_modeling] End")