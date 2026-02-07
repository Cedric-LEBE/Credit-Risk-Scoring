# Score de défaut client 

## Objectif

Construire une chaîne décisionnelle **reproductible** de bout en bout pour le **scoring de défaut client** :
- préparation et nettoyage des données,
- entraînement/évaluation de modèles,
- calibration d’un seuil orienté risque (Recall défaut ≥ 80%),
- production d’un **tableau de scores** et d’une **politique de décision à 3 niveaux** (*approve / review / reject*),
- restitution via **rapport Quarto** et **dashboard Shiny**.

## Données

- Source : **UCI Statlog (German Credit Data)**
- Fichier brut : `german.data` (modalités qualitatives encodées Axx)
- Cible : `class` (1 = bon crédit, 2 = mauvais crédit) → transformée en `default` (0/1)

## Structure du projet

```text
Credit-Risk-Scoring/
│
├── R/                       # Scripts du pipeline
│   ├── 00_config.R
│   ├── 00_prepare_raw.R
│   ├── 01_import.R
│   ├── 02_quality_checks.R
│   ├── 03_cleaning.R
│   ├── 04_features.R
│   ├── 05_eda.R
│   ├── 06_modeling.R
│   ├── 06b_threshold.R
│   ├── 07_export.R
│   └── run_all.R
│
├── data/
│   ├── raw/                 # Données brutes (german.data / CSV)
│   ├── interim/             # Données intermédiaires
│   └── processed/           # Données finales prêtes à modéliser
│
├── outputs/
│   ├── tables/              # Scores, métriques, décisions
│   ├── figures/             # Graphiques exportés
│   └── logs/                # Logs du pipeline
│
├── reports/
│   └── report.qmd           # Rapport Quarto (HTML)
│
├── dashboard/               # Mini-dashboard Shiny
│
├── session_info.txt         # Informations de session R (reproductibilité)
├── README.md
└── decisionnel-R-projet.Rproj
```
---

## 🔄 Pipeline analytique

Le pipeline suit une logique **end-to-end** :

1. Préparation et conversion des données brutes
2. Contrôles qualité (NA, doublons, cible)
3. Nettoyage et recodage
4. Feature engineering
5. Analyse exploratoire (EDA)
6. Modélisation (logistique + arbre)
7. Calibration du seuil (Recall ≥ 80 %)
8. Export des scores et décisions

L’ensemble est orchestré par **`R/run_all.R`**.

---

## 🧠 Modélisation

Deux modèles ont été comparés :

- **Régression logistique**
  - modèle de référence,
  - interprétable,
  - adapté au risque de crédit.
- **Arbre de décision**
  - tuning léger,
  - benchmark non linéaire.

Le modèle retenu est la **régression logistique**, offrant le meilleur compromis
entre performance et interprétabilité.

---

## ⚖️ Politique de décision

Le seuil de décision est calibré pour garantir :

- **Recall(default) ≥ 80 %** sur le jeu de test,
- une segmentation claire des clients en :
  - `approve`,
  - `review`,
  - `reject`.

Cette logique reflète une **approche prudente** adaptée aux enjeux du risque de crédit.

---

## 📊 Rapport Quarto

Le rapport fournit :
- une description des données,
- une EDA orientée décision,
- une comparaison des modèles,
- une analyse d’interprétabilité,
- une restitution métier claire.

### Génération du rapport

```bash
# Exécution complète du pipeline
Rscript -e "source('R/run_all.R')"

# Génération du rapport HTML
quarto render reports/report.qmd

# Lecture du rapport
open reports/_site/reports/report.html
```

---

## 📈 Dashboard Shiny

Un mini-dashboard Shiny est inclus pour :
- visualiser la distribution des scores,
- filtrer par décision,
- identifier rapidement les clients à risque.

### Lancer le dashboard Shiny

```r
shiny::runApp("dashbord")
```