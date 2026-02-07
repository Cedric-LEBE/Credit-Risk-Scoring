# 05_eda.R ----
source(here("R", "00_config.R"))

log_msg("[05_eda] Start")

df <- readr::read_rds(here("data", "processed", "df_features.rds"))

# Changer la cible (default) en 0/1

if (!"default" %in% names(df)) {
  stop("Colonne 'default' introuvable dans df_features.rds.")
}

default_num <- dplyr::case_when(
  is.numeric(df$default) ~ as.integer(df$default),
  is.integer(df$default) ~ as.integer(df$default),
  is.logical(df$default) ~ as.integer(df$default),
  is.factor(df$default)  ~ as.integer(as.character(df$default) %in% c("1", "default")),
  is.character(df$default) ~ as.integer(df$default %in% c("1", "default")),
  TRUE ~ NA_integer_
)

if (any(is.na(default_num))) {
  log_msg("[05_eda] Warning: default contains NA after conversion (check your target encoding).")
}

df <- df %>% dplyr::mutate(default_num = default_num)

# KPI global

kpi <- df %>%
  dplyr::summarise(
    n = dplyr::n(),
    default_n = sum(default_num == 1, na.rm = TRUE),
    default_rate = mean(default_num, na.rm = TRUE)
  )

readr::write_csv(kpi, here("outputs", "tables", "kpi_global.csv"))
log_msg("[05_eda] Exported kpi_global.csv")

# Segmentation : taux de défaut par variable catégorielle

# On considère facteurs + caractères 
cat_candidates <- names(df %>% dplyr::select(where(is.factor), where(is.character)))
# On exclut la cible et variables dérivées
cat_candidates <- setdiff(cat_candidates, c("default", "decision"))

if (length(cat_candidates) > 0) {
  preferred <- c("status_checking", "credit_history", "purpose", "savings", "employment_since", "housing", "job")
  var_seg <- intersect(preferred, cat_candidates)
  var_seg <- if (length(var_seg) > 0) var_seg[1] else cat_candidates[1]
  
  seg <- df %>%
    dplyr::group_by(.data[[var_seg]]) %>%
    dplyr::summarise(
      n = dplyr::n(),
      default_rate = mean(default_num, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::arrange(desc(default_rate), desc(n))
  
  readr::write_csv(seg, here("outputs", "tables", paste0("default_rate_by_", var_seg, ".csv")))
  log_msg("[05_eda] Exported default_rate_by_", var_seg, ".csv")
  
  p <- ggplot2::ggplot(seg, ggplot2::aes(x = reorder(.data[[var_seg]], default_rate), y = default_rate)) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(
      title = paste("Taux de défaut par", var_seg),
      x = var_seg,
      y = "Taux de défaut"
    )
  
  ggplot2::ggsave(
    filename = here("outputs", "figures", paste0("default_rate_by_", var_seg, ".png")),
    plot = p, width = 8, height = 5
  )
  log_msg("[05_eda] Saved figure default_rate_by_", var_seg, ".png")
} else {
  log_msg("[05_eda] No categorical variables detected for segmentation.")
}

# Distribution variable numérique

num_candidates <- names(df %>% dplyr::select(where(is.numeric)))
num_candidates <- setdiff(num_candidates, c("default_num"))  

if (length(num_candidates) > 0) {
  preferred_num <- c("credit_amount", "duration_months", "age", "installment_rate")
  var_num <- intersect(preferred_num, num_candidates)
  var_num <- if (length(var_num) > 0) var_num[1] else num_candidates[1]
  
  p2 <- ggplot2::ggplot(df, ggplot2::aes(x = .data[[var_num]])) +
    ggplot2::geom_histogram(bins = 30) +
    ggplot2::labs(
      title = paste("Distribution de", var_num),
      x = var_num,
      y = "Count"
    )
  
  ggplot2::ggsave(
    filename = here("outputs", "figures", paste0("hist_", var_num, ".png")),
    plot = p2, width = 7, height = 4
  )
  log_msg("[05_eda] Saved figure hist_", var_num, ".png")
} else {
  log_msg("[05_eda] No numeric variables detected for histogram.")
}

log_msg("[05_eda] End")