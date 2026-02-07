# 00_config.R ----

options(stringsAsFactors = FALSE)
set.seed(123)

# ---- Libraries ----

library(tidyverse)
library(readxl)
library(janitor)
library(skimr)
library(here)
library(lubridate)
library(tidymodels)
library(pROC)
library(vip)

tidymodels_prefer()

# ---- Paths ----
dir.create(here("data", "raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "interim"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("data", "processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("outputs", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("outputs", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("outputs", "logs"), recursive = TRUE, showWarnings = FALSE)

# ---- Simple logger ----
log_msg <- function(..., file = here("outputs", "logs", "pipeline.log")) {
  msg <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ", paste(..., collapse = " "))
  cat(msg, "\n")
  cat(msg, "\n", file = file, append = TRUE)
}

# ---- Helpers ----
stop_if_missing <- function(path) {
  if (!file.exists(path)) stop("Fichier introuvable: ", path)
}

