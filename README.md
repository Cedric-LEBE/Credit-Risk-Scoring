# 🏦 Credit Risk Scoring (Score de défaut client)

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
├── index.qmd
├── session_info.txt         # Informations de session R (reproductibilité)
├── README.md
└── Credit-Risk-Scoring.Rproj
```
---

## 🔄 Pipeline d’ingestion et de modélisation

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

## 🧱 Technologies utilisées

-	R : pour l'analyse des données, modélisation et restitution décisionnelle
-	RStudio : environnement de développement
-	Quarto : pour la génération de rapports HTML reproductibles
-	Shiny : pour la création du dashboard interactif 
-	GitHub Pages : pour le déploiement du rapport (Quarto)
-	shinyapps.io : pour le déploiement du dashboard interactif (Shiny)

## 🌐 Déploiement

Le projet est déployée et accessible à l’adresse suivante :

🔗 https://cedric-lebe.github.io/Credit-Risk-Scoring/

Cette application centralise l’accès :

-	au rapport analytique (Quarto),
-	au dashboard interactif (Shiny).

## 📄 Rapport analytique (Quarto)

Le rapport analytique présente :

-	le contexte métier et les objectifs décisionnels,
-	la structure des données,
-	une EDA orientée décision,
-	la comparaison des modèles,
-	l’interprétabilité du modèle retenu,
-	la politique de décision crédit.

Accès direct au rapport :

🔗 https://cedric-lebe.github.io/Credit-Risk-Scoring/reports/report.html

## 📊 Dashboard interactif (Shiny)

Le dashboard permet :

-	d’explorer la distribution des scores de défaut,
-	de filtrer par décision et probabilité de défaut,
-	d’identifier les clients à risque élevé,
-	de télécharger les résultats filtrés.

Accès direct au dashboard :

🔗 https://cedric-lebe.shinyapps.io/credit-risk-dashboard/

## ⚡ Exécution rapide en local

### 1. Cloner le dépôt

```bash
git clone https://github.com/Cedric-LEBE/Credit-Risk-Scoring.git
cd Credit-Risk-Scoring
```

### 2. Restaurer l’environnement R (renv)
```bash
Rscript -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript -e "renv::restore()"
```

### 3. Exécuter le pipeline d’ingestion et de modélisation
```bash
Rscript -e "source('R/run_all.R')"
```

### 4. Générer l'application (Rapport + Dashboard)
```bash
quarto render
open reports/_site/index.html
```

### 5. Générer uniquement le rapport 
```bash
quarto render
open reports/_site/reports/report.html
```

### 6. Générer uniquement le Dashbord
```bash
Rscript -e "shiny::runApp('dashboard')"
```