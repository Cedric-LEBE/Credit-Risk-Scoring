# 00_prepare_raw.R ----
# Convertit le fichier UCI "german.data" en un CSV "credit_default.csv" dans data/raw/.

source(here::here("R", "00_config.R"))
log_msg("[00_prepare_raw] Start")

data_path <- here::here("data", "raw", "german.data")
csv_path  <- here::here("data", "raw", "credit_default.csv")

# Si le CSV existe déjà, on ne fait rien
if (file.exists(csv_path)) {
  log_msg("[00_prepare_raw] CSV already exists -> skip:", csv_path)
  log_msg("[00_prepare_raw] End")
  return(invisible(TRUE))
}

# Sinon, si le fichier brut existe, on le convertit
if (!file.exists(data_path)) {
  log_msg("[00_prepare_raw] No german.data found and no CSV. Nothing to do.")
  log_msg("[00_prepare_raw] End")
  return(invisible(FALSE))
}

col_names <- c(
  "status_checking",
  "duration_months",
  "credit_history",
  "purpose",
  "credit_amount",
  "savings",
  "employment_since",
  "installment_rate",
  "personal_status_sex",
  "other_debtors",
  "residence_since",
  "property",
  "age",
  "other_installment_plans",
  "housing",
  "existing_credits",
  "job",
  "num_dependents",
  "telephone",
  "foreign_worker",
  "class"
)

df <- readr::read_table(
  data_path,
  col_names = col_names,
  show_col_types = FALSE
)

# Contrôle minimal
if (nrow(df) == 0) stop("german.data est vide ou illisible.")
if (!"class" %in% names(df)) stop("La colonne 'class' manque après lecture. Vérifie german.data.")

readr::write_csv(df, csv_path)
log_msg("[00_prepare_raw] Converted german.data -> credit_default.csv")
log_msg("[00_prepare_raw] End")