# dashboard/app.R ----
# Dashboard décisionnel (Score défaut)

library(shiny)
library(dplyr)
library(readr)
library(ggplot2)
library(here)
library(scales)

# Helpers

safe_read <- function(path) {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE)
}

safe_read_rds <- function(path) {
  if (!file.exists(path)) return(NULL)
  readRDS(path)
}

fmt_pct <- function(x) scales::percent(x, accuracy = 0.1)

# Clean threshold grid to avoid ggplot warnings (NA/Inf values)
clean_thr <- function(g, y_col) {
  if (is.null(g)) return(NULL)
  if (!all(c("threshold", y_col) %in% names(g))) return(NULL)
  
  g %>%
    dplyr::filter(
      !is.na(.data[["threshold"]]),
      is.finite(.data[["threshold"]]),
      !is.na(.data[[y_col]]),
      is.finite(.data[[y_col]])
    )
}

# Paths
p_scores   <- here("outputs", "tables", "client_scores_test.csv")
p_metrics  <- here("outputs", "tables", "model_metrics_test.csv")
p_dec_sum  <- here("outputs", "tables", "decision_summary.csv")
p_thr_grid <- here("outputs", "tables", "threshold_metrics.csv")
p_thr_pick <- here("outputs", "tables", "chosen_threshold.rds")

# Load data
scores  <- safe_read(p_scores)
metrics <- safe_read(p_metrics)
dec_sum <- safe_read(p_dec_sum)
thr_grid <- safe_read(p_thr_grid)
thr_pick <- safe_read_rds(p_thr_pick)

# Validate minimum required
if (is.null(scores)) {
  stop("Fichier manquant: outputs/tables/client_scores_test.csv. Lance d'abord le pipeline: Rscript -e \"source('R/run_all.R')\"")
}

# Ensure expected columns exist
req_cols <- c("default", "proba_default", "decision")
missing_cols <- setdiff(req_cols, names(scores))
if (length(missing_cols) > 0) {
  stop("Colonnes manquantes dans client_scores_test.csv: ", paste(missing_cols, collapse = ", "))
}

# Defaults (thresholds)
thr_review <- if (!is.null(thr_pick) && !is.null(thr_pick$threshold)) thr_pick$threshold else 0.50
# reject threshold is not saved; approximate from current scores based on top 10% rule
thr_reject <- as.numeric(stats::quantile(scores$proba_default, probs = 0.90, na.rm = TRUE))

# UI
ui <- fluidPage(
  tags$style(HTML("
    .kpi-box{border:1px solid #ddd; border-radius:12px; padding:12px 14px; background:#fff; margin-bottom:10px;}
    .kpi-title{font-size:12px; color:#666; margin-bottom:4px;}
    .kpi-value{font-size:22px; font-weight:700;}
    .subtle{color:#666;}
    .section-title{margin-top:16px;}
  ")),
  
  titlePanel("Credit Risk Scoring"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Filtres"),
      selectInput(
        "decision",
        "Décision",
        choices = c("all", sort(unique(scores$decision))),
        selected = "all"
      ),
      selectInput(
        "truth",
        "Vérité terrain",
        choices = c("all", sort(unique(scores$default))),
        selected = "all"
      ),
      sliderInput(
        "p_range",
        "Filtrer P(défaut)",
        min = 0, max = 1,
        value = c(0, 1),
        step = 0.01
      ),
      hr(),
      h4("Seuils"),
      #helpText("review = seuil calibré (Recall ≥ 80%); reject = top 10% risques (quantile)."),
      verbatimTextOutput("thresholds_box"),
      hr(),
      h4("Actions"),
      actionButton("reload", "Recharger les fichiers outputs/"),
      br(), br(),
      downloadButton("download_scores", "Télécharger le scoring filtré (CSV)")
    ),
    
    mainPanel(
      fluidRow(
        column(4, div(class = "kpi-box",
                      div(class = "kpi-title", "Observations (filtrées)"),
                      div(class = "kpi-value", textOutput("kpi_n")))),
        column(4, div(class = "kpi-box",
                      div(class = "kpi-title", "Taux de défaut (filtré)"),
                      div(class = "kpi-value", textOutput("kpi_default_rate")),
                      div(class = "subtle", "Sur le sous-ensemble affiché"))),
        column(4, div(class = "kpi-box",
                      div(class = "kpi-title", "Score moyen P(défaut)"),
                      div(class = "kpi-value", textOutput("kpi_mean_p"))))
      ),
      
      h3(class = "section-title", "1) Vue globale"),
      tabsetPanel(
        tabPanel("Distribution scores",
                 plotOutput("hist_scores", height = 320),
                 br(),
                 plotOutput("box_by_decision", height = 280)
        ),
        tabPanel("Répartition décisions",
                 plotOutput("bar_decisions", height = 320),
                 br(),
                 tableOutput("table_decisions")
        ),
        tabPanel("Performance modèles",
                 tableOutput("table_metrics")
        )
      ),
      
      h3(class = "section-title", "2) Analyse seuils (Recall/Précision)"),
      conditionalPanel(
        condition = "output.has_thr_grid === true",
        plotOutput("thr_recall_curve", height = 300),
        br(),
        plotOutput("thr_precision_curve", height = 300)
      ),
      conditionalPanel(
        condition = "output.has_thr_grid === false",
        helpText("threshold_metrics.csv introuvable. Relance le pipeline pour générer l'analyse de seuils.")
      ),
      
      h3(class = "section-title", "3) Top clients les plus risqués (filtré)"),
      tableOutput("table_top")
    )
  )
)

# Server

server <- function(input, output, session) {
  
  # reactive store (to support reload)
  rv <- reactiveValues(
    scores = scores,
    metrics = metrics,
    dec_sum = dec_sum,
    thr_grid = thr_grid,
    thr_review = thr_review,
    thr_reject = thr_reject
  )
  
  # Expose flag to UI for conditional panel
  output$has_thr_grid <- reactive({
    !is.null(rv$thr_grid)
  })
  outputOptions(output, "has_thr_grid", suspendWhenHidden = FALSE)
  
  observeEvent(input$reload, {
    rv$scores <- safe_read(p_scores)
    rv$metrics <- safe_read(p_metrics)
    rv$dec_sum <- safe_read(p_dec_sum)
    rv$thr_grid <- safe_read(p_thr_grid)
    thr_pick2 <- safe_read_rds(p_thr_pick)
    
    if (!is.null(thr_pick2) && !is.null(thr_pick2$threshold)) {
      rv$thr_review <- thr_pick2$threshold
    } else {
      rv$thr_review <- 0.50
    }
    
    if (!is.null(rv$scores)) {
      rv$thr_reject <- as.numeric(stats::quantile(rv$scores$proba_default, probs = 0.90, na.rm = TRUE))
    }
    
    showNotification("Outputs rechargés.", type = "message")
  })
  
  filtered <- reactive({
    x <- rv$scores
    
    if (input$decision != "all") x <- x %>% dplyr::filter(decision == input$decision)
    if (input$truth != "all")    x <- x %>% dplyr::filter(default == input$truth)
    
    x <- x %>% dplyr::filter(proba_default >= input$p_range[1], proba_default <= input$p_range[2])
    x
  })
  
  # KPIs
  output$kpi_n <- renderText({
    nrow(filtered())
  })
  
  output$kpi_default_rate <- renderText({
    x <- filtered()
    if (!("default" %in% names(x))) return("NA")
    if (!any(x$default %in% c("default", "no_default"))) return("NA")
    rate <- mean(x$default == "default", na.rm = TRUE)
    fmt_pct(rate)
  })
  
  output$kpi_mean_p <- renderText({
    x <- filtered()
    sprintf("%.3f", mean(x$proba_default, na.rm = TRUE))
  })
  
  output$thresholds_box <- renderText({
    paste0(
      "review threshold (Recall>=0.80): ", round(rv$thr_review, 3), "\n",
      "reject threshold (Top 10%):      ", round(rv$thr_reject, 3)
    )
  })
  
  # Plots
  output$hist_scores <- renderPlot({
    x <- filtered()
    ggplot(x, aes(x = proba_default, fill = default)) +
      geom_histogram(bins = 30, alpha = 0.6, position = "identity") +
      labs(x = "P(défaut)", y = "Nombre", title = "Distribution des scores (filtrée)")
  })
  
  output$box_by_decision <- renderPlot({
    x <- filtered()
    ggplot(x, aes(x = decision, y = proba_default, fill = decision)) +
      geom_boxplot(show.legend = FALSE) +
      labs(x = "Décision", y = "P(défaut)", title = "Scores par décision")
  })
  
  output$bar_decisions <- renderPlot({
    x <- filtered() %>% count(decision) %>% mutate(p = n / sum(n))
    ggplot(x, aes(x = decision, y = n, fill = decision)) +
      geom_col(show.legend = FALSE) +
      labs(x = "Décision", y = "Nombre", title = "Répartition des décisions (filtrée)")
  })
  
  output$table_decisions <- renderTable({
    filtered() %>%
      count(decision) %>%
      mutate(p = round(n / sum(n) * 100, 1)) %>%
      arrange(desc(n))
  })
  
  output$table_metrics <- renderTable({
    if (is.null(rv$metrics)) return(data.frame(info = "model_metrics_test.csv introuvable"))
    rv$metrics
  })
  
  output$thr_recall_curve <- renderPlot({
    g <- rv$thr_grid
    validate(need(!is.null(g), "threshold_metrics.csv introuvable"))
    
    g2 <- clean_thr(g, "recall")
    validate(need(!is.null(g2) && nrow(g2) > 1, "Données seuils insuffisantes pour tracer la courbe recall."))
    
    ggplot(g2, aes(x = threshold, y = recall)) +
      geom_line() +
      geom_hline(yintercept = 0.80, linetype = "dashed") +
      labs(x = "Seuil", y = "Recall(default)", title = "Recall(default) vs seuil")
  })
  
  output$thr_precision_curve <- renderPlot({
    g <- rv$thr_grid
    validate(need(!is.null(g), "threshold_metrics.csv introuvable"))
    
    g2 <- clean_thr(g, "precision")
    validate(need(!is.null(g2) && nrow(g2) > 1, "Données seuils insuffisantes pour tracer la courbe precision."))
    
    ggplot(g2, aes(x = threshold, y = precision)) +
      geom_line() +
      labs(x = "Seuil", y = "Precision(default)", title = "Precision(default) vs seuil")
  })
  
  output$table_top <- renderTable({
    filtered() %>%
      arrange(desc(proba_default)) %>%
      head(15)
  })
  
  # Download filtered scores
  output$download_scores <- downloadHandler(
    filename = function() {
      paste0("client_scores_filtered_", Sys.Date(), ".csv")
    },
    content = function(file) {
      readr::write_csv(filtered(), file)
    }
  )
}

shinyApp(ui, server)