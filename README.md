# 🏦 Credit Risk Scoring (Score de défaut client)

## Objectif

Construire une chaîne décisionnelle **reproductible** de bout en bout pour le **scoring de défaut client** :
- préparation et nettoyage des données,
- entraînement/évaluation de modèles,
- calibration d’un seuil orienté risque (Recall défaut ≥ 80%),
- production d’un **tableau de scores** et d’une **politique de décision à 3 niveaux** (*approve / review / reject*),
- restitution via **rapport Quarto**, **dashboard Shiny** et **dashboard Streamlit**.

## Données

- Source : **UCI Statlog (German Credit Data)**
- Fichier brut : `german.data` (modalités qualitatives encodées Axx)
- Cible : `class` (1 = bon crédit, 2 = mauvais crédit) → transformée en `default` (0/1)

## Structure du projet

```text
Credit-Risk-Scoring/
│
├── app/                     # Applications
│   ├── shiny_app
│   ├── streamlit_app
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
├── session_info.txt         # Informations de session R (reproductibilité)
├── README.md
├── renv.lock
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
-   Python : pour la création de la page streamlit
-	RStudio : environnement de développement
-	Quarto : pour la génération de rapports HTML reproductibles
-	Shiny & Streamlit : pour la création de dashboards interactifs illustrant l’interopérabilité entre R et Python
-	GitHub Pages : pour le déploiement du rapport (Quarto)
-	shinyapps.io : pour le déploiement du dashboard interactif (Shiny)
-	Streamlit Cloud : pour le déploiement du dashboard interactif (Streamlit)


## 🌐 Déploiement

Le projet est déployé et accessible via les interfaces suivantes :

- 📄 **Rapport analytique (Quarto)**  
  Le rapport présente le contexte métier et les objectifs décisionnels, la structure des données, une analyse exploratoire orientée décision, la comparaison des modèles, l’interprétabilité du modèle retenu et la politique de décision crédit.
  - 🔗 [Voir le rapport](https://cedric-lebe.github.io/Credit-Risk-Scoring/reports/report.html)

- 📊 **Dashboard interactif Shiny**  
  Visualisation des scores, exploration des décisions et filtrage des clients.
  - 🔗 [Voir le dashboard Shiny](https://cedric-lebe.shinyapps.io/credit-risk-dashboard/)

- 📈 **Dashboard interactif Streamlit**  
  Interface alternative développée en Python, illustrant l’interopérabilité **R / Python**.
  - 🔗 [Voir le dashboard Streamlit](https://cedric-lebe.github.io/Credit-Risk-Scoring/reports/report.html)

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

### 4. Générer le rapport 
```bash
quarto render
open reports/_site/index.html
```

### 5. Générer l'application Shiny
```bash
Rscript -e "shiny::runApp('app/shiny_app')"
```

### 6. Générer l'application Streamlit
```bash
# Créer et activer un environnement virtuel
python3 -m venv .venv

# Sur Linux/Mac :
source .venv/bin/activate

# Sur Windows :
.venv\Scripts\activate

# Installer les dépendances
pip install -r app/streamlit_app/requirements.txt

# Lancer l'application Streamlit
streamlit run app/streamlit_app/app.py 
```