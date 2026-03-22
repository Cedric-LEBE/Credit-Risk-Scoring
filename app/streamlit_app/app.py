from pathlib import Path
import io

import numpy as np
import pandas as pd
import streamlit as st
import plotly.express as px


# Config

st.set_page_config(
    page_title="Credit Risk Scoring",
    layout="wide"
)

BASE_DIR = Path(__file__).resolve().parents[2]
P_SCORES = BASE_DIR / "outputs" / "tables" / "client_scores_test.csv"
P_METRICS = BASE_DIR / "outputs" / "tables" / "model_metrics_test.csv"
P_DEC_SUM = BASE_DIR / "outputs" / "tables" / "decision_summary.csv"
P_THR_GRID = BASE_DIR / "outputs" / "tables" / "threshold_metrics.csv"
P_THR_PICK = BASE_DIR / "outputs" / "tables" / "chosen_threshold.csv"

# Helpers

def safe_read_csv(path: Path) -> pd.DataFrame | None:
    if not path.exists():
        return None
    return pd.read_csv(path)


def fmt_pct(x: float) -> str:
    return f"{x * 100:.1f}%"


def clean_thr(df: pd.DataFrame | None, y_col: str) -> pd.DataFrame | None:
    if df is None:
        return None
    required = {"threshold", y_col}
    if not required.issubset(df.columns):
        return None

    out = df.copy()
    out = out[
        out["threshold"].notna()
        & np.isfinite(out["threshold"])
        & out[y_col].notna()
        & np.isfinite(out[y_col])
    ]
    return out


def require_df(df: pd.DataFrame | None, name: str) -> pd.DataFrame:
    if df is None:
        st.error(
            f"Fichier manquant: {name}. Lance d'abord le pipeline R avec : "
            f"`Rscript -e \"source('R/run_all.R')\"`"
        )
        st.stop()
    return df

# Load data

scores = safe_read_csv(P_SCORES)
metrics = safe_read_csv(P_METRICS)
decision_summary = safe_read_csv(P_DEC_SUM)
thr_grid = safe_read_csv(P_THR_GRID)
thr_pick = safe_read_csv(P_THR_PICK)

scores = require_df(scores, str(P_SCORES))

req_cols = {"default", "proba_default", "decision"}
missing_cols = req_cols - set(scores.columns)
if missing_cols:
    st.error(
        "Colonnes manquantes dans client_scores_test.csv : "
        + ", ".join(sorted(missing_cols))
    )
    st.stop()

thr_review = 0.50
target_recall = 0.80

if thr_pick is not None and not thr_pick.empty:
    if "threshold" in thr_pick.columns:
        thr_review = float(thr_pick["threshold"].iloc[0])
    if "target_recall" in thr_pick.columns:
        target_recall = float(thr_pick["target_recall"].iloc[0])

thr_reject = float(scores["proba_default"].quantile(0.90))

# Sidebar
st.title("Credit Risk Scoring")

with st.sidebar:
    st.header("Filtres")

    decision_choices = ["all"] + sorted(scores["decision"].dropna().astype(str).unique().tolist())
    decision = st.selectbox("Décision", decision_choices, index=0)

    truth_choices = ["all"] + sorted(scores["default"].dropna().astype(str).unique().tolist())
    truth = st.selectbox("Vérité terrain", truth_choices, index=0)

    p_min, p_max = st.slider(
        "Filtrer P(défaut)",
        min_value=0.0,
        max_value=1.0,
        value=(0.0, 1.0),
        step=0.01
    )

    st.markdown("---")
    st.header("Seuils")
    st.text(
        f"review threshold (Recall>={target_recall:.2f}): {thr_review:.3f}\n"
        f"reject threshold (Top 10%):        {thr_reject:.3f}"
    )

    st.markdown("---")
    st.header("Actions")


# Filtering
filtered = scores.copy()

if decision != "all":
    filtered = filtered[filtered["decision"].astype(str) == decision]

if truth != "all":
    filtered = filtered[filtered["default"].astype(str) == truth]

filtered = filtered[
    (filtered["proba_default"] >= p_min) &
    (filtered["proba_default"] <= p_max)
].copy()

# Download
csv_buffer = io.StringIO()
filtered.to_csv(csv_buffer, index=False)

with st.sidebar:
    st.download_button(
        label="Télécharger le scoring filtré (CSV)",
        data=csv_buffer.getvalue(),
        file_name="client_scores_filtered.csv",
        mime="text/csv"
    )

# KPI

col1, col2, col3 = st.columns(3)

with col1:
    st.metric("Observations (filtrées)", len(filtered))

with col2:
    if "default" in filtered.columns and filtered["default"].astype(str).isin(["default", "no_default"]).any():
        default_rate = (filtered["default"].astype(str) == "default").mean()
        st.metric("Taux de défaut (filtré)", fmt_pct(default_rate))
    else:
        st.metric("Taux de défaut (filtré)", "NA")

with col3:
    st.metric("Score moyen P(défaut)", f"{filtered['proba_default'].mean():.3f}")


# Tabs

tab1, tab2, tab3, tab4 = st.tabs([
    "Vue globale",
    "Analyse seuils",
    "Top clients",
    "Performance modèles"
])

# Tab 1 - Vue globale
with tab1:
    st.subheader("Distribution des scores")

    hist_df = filtered.copy()
    hist_df["default"] = hist_df["default"].astype(str)

    fig_hist = px.histogram(
        hist_df,
        x="proba_default",
        color="default",
        nbins=30,
        opacity=0.65,
        barmode="overlay",
        title="Distribution des scores (filtrée)",
        labels={
            "proba_default": "P(défaut)",
            "count": "Nombre",
            "default": "Vérité terrain"
        }
    )
    fig_hist.update_layout(legend_title_text="Vérité terrain")
    st.plotly_chart(fig_hist, use_container_width=True)

    st.subheader("Scores par décision")
    box_df = filtered.copy()
    box_df["decision"] = box_df["decision"].astype(str)

    if not box_df.empty:
        fig_box = px.box(
            box_df,
            x="decision",
            y="proba_default",
            color="decision",
            title="Scores par décision",
            labels={
                "decision": "Décision",
                "proba_default": "P(défaut)"
            }
        )
        fig_box.update_layout(showlegend=False)
        st.plotly_chart(fig_box, use_container_width=True)

    st.subheader("Répartition des décisions")
    dec_counts = (
        filtered.groupby("decision", dropna=False)
        .size()
        .reset_index(name="n")
        .sort_values("n", ascending=False)
    )

    if not dec_counts.empty:
        fig_bar = px.bar(
            dec_counts,
            x="decision",
            y="n",
            color="decision",
            title="Répartition des décisions (filtrée)",
            labels={
                "decision": "Décision",
                "n": "Nombre"
            }
        )
        fig_bar.update_layout(showlegend=False)
        st.plotly_chart(fig_bar, use_container_width=True)

        dec_counts["p"] = (dec_counts["n"] / dec_counts["n"].sum() * 100).round(1)
        st.dataframe(dec_counts, use_container_width=True)

# Tab 2 - Analyse seuils
with tab2:
    st.subheader("Analyse seuils (Recall / Precision)")

    if thr_grid is None:
        st.info("threshold_metrics.csv introuvable. Relance le pipeline pour générer l'analyse de seuils.")
    else:
        g_recall = clean_thr(thr_grid, "recall")
        g_precision = clean_thr(thr_grid, "precision")

        if g_recall is not None and len(g_recall) > 1:
            fig_recall = px.line(
                g_recall,
                x="threshold",
                y="recall",
                title="Recall(default) vs seuil",
                labels={
                    "threshold": "Seuil",
                    "recall": "Recall(default)"
                }
            )
            fig_recall.add_hline(y=target_recall, line_dash="dash")
            st.plotly_chart(fig_recall, use_container_width=True)
        else:
            st.warning("Données seuils insuffisantes pour tracer la courbe recall.")

        if g_precision is not None and len(g_precision) > 1:
            fig_precision = px.line(
                g_precision,
                x="threshold",
                y="precision",
                title="Precision(default) vs seuil",
                labels={
                    "threshold": "Seuil",
                    "precision": "Precision(default)"
                }
            )
            st.plotly_chart(fig_precision, use_container_width=True)
        else:
            st.warning("Données seuils insuffisantes pour tracer la courbe precision.")

# Tab 3 - Top clients
with tab3:
    st.subheader("Top clients les plus risqués (filtré)")
    top_clients = filtered.sort_values("proba_default", ascending=False).head(15)
    st.dataframe(top_clients, use_container_width=True)

# Tab 4 - Metrics
with tab4:
    st.subheader("Performance modèles")
    if metrics is None:
        st.info("model_metrics_test.csv introuvable.")
    else:
        st.dataframe(metrics, use_container_width=True)