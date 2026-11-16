"""
Monthly revenue forecast and budget-vs-actual variance (Customer Revenue & Retention project).

Data: data/processed/analytics/monthly_revenue.csv (built by the main pipeline from UCI Online Retail II).
Run from the repository root or this folder: python forecast/forecast_variance.py
- December 2011 is a partial month (data ends 9 Dec 2011), so it is excluded from all evaluation.
- Train: Jan 2010 - May 2011 (17 months). Test: Jun - Nov 2011 (6 months), never used for fitting.
- Forecasts are made once, at the end of May 2011, for all six test months (fixed-origin, 1-6 months ahead).

Methods compared:
  1. Seasonal naive: same month last year.
  2. Seasonal naive with growth: same month last year x year-on-year growth of Jan-May 2011 vs Jan-May 2010.
  3. Holt's linear trend (exponential smoothing, no seasonality: 17 months is too short for a 12-month seasonal model).

Illustrative budget (hypothetical, not a real company budget):
  2011 budget = 2010 actual for the same month x (1 + PLAN_GROWTH), set before the year starts.
  Revised forecast = method 2 above, made at the end of May 2011.
"""
from pathlib import Path
import numpy as np
import pandas as pd
from statsmodels.tsa.holtwinters import Holt

PLAN_GROWTH = 0.10   # illustrative planning assumption: +10% on 2010 for every month of 2011
HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data" / "processed" / "analytics" / "monthly_revenue.csv"
OUT = HERE / "output"
OUT.mkdir(exist_ok=True)

df = pd.read_csv(DATA, parse_dates=["month"])
df = df[df.period_status == "Complete month"].set_index("month").sort_index()
net = df["estimated_net_revenue"]

train = net["2010-01-01":"2011-05-01"]
test = net["2011-06-01":"2011-11-01"]
assert len(train) == 17 and len(test) == 6

def last_year(idx):
    return net.reindex(idx - pd.DateOffset(years=1)).to_numpy()

growth = net["2011-01-01":"2011-05-01"].sum() / net["2010-01-01":"2010-05-01"].sum() - 1
fc = pd.DataFrame(index=test.index)
fc["actual"] = test
fc["seasonal_naive"] = last_year(test.index)
fc["seasonal_naive_growth"] = fc["seasonal_naive"] * (1 + growth)
holt = Holt(train.to_numpy(), initialization_method="estimated").fit()
fc["holt_linear"] = holt.forecast(len(test))

def mae(a, f): return float(np.mean(np.abs(a - f)))
def wape(a, f): return float(np.sum(np.abs(a - f)) / np.sum(np.abs(a)) * 100)
def bias(a, f): return float(np.sum(f - a) / np.sum(a) * 100)

scores = pd.DataFrame([
    {"method": m, "MAE_gbp": round(mae(fc.actual, fc[m]), 0),
     "WAPE_pct": round(wape(fc.actual, fc[m]), 2), "bias_pct": round(bias(fc.actual, fc[m]), 2)}
    for m in ["seasonal_naive", "seasonal_naive_growth", "holt_linear"]
]).sort_values("WAPE_pct")

# Budget vs revised forecast vs actual, net revenue and its two drivers
ly = df.reindex(test.index - pd.DateOffset(years=1))
bva = pd.DataFrame(index=test.index)
bva["budget_gross"] = ly["gross_sales"].to_numpy() * (1 + PLAN_GROWTH)
bva["budget_cancellations"] = ly["cancellation_value"].to_numpy() * (1 + PLAN_GROWTH)
bva["budget_net"] = bva.budget_gross - bva.budget_cancellations
bva["revised_forecast_net"] = fc["seasonal_naive_growth"]
bva["actual_gross"] = df.loc[test.index, "gross_sales"]
bva["actual_cancellations"] = df.loc[test.index, "cancellation_value"]
bva["actual_net"] = df.loc[test.index, "estimated_net_revenue"]
bva["var_vs_budget"] = bva.actual_net - bva.budget_net
bva["var_vs_budget_pct"] = bva.var_vs_budget / bva.budget_net * 100
bva["gross_sales_effect"] = bva.actual_gross - bva.budget_gross
bva["cancellation_effect"] = -(bva.actual_cancellations - bva.budget_cancellations)
bva["var_vs_revised"] = bva.actual_net - bva.revised_forecast_net
assert np.allclose(bva.var_vs_budget, bva.gross_sales_effect + bva.cancellation_effect)

tot = bva[["budget_net", "revised_forecast_net", "actual_net", "var_vs_budget",
           "gross_sales_effect", "cancellation_effect", "var_vs_revised"]].sum()

fc.round(2).to_csv(OUT / "forecast_by_month.csv")
scores.to_csv(OUT / "forecast_scores.csv", index=False)
bva.round(2).to_csv(OUT / "budget_vs_actual.csv")

print(f"YoY growth Jan-May 2011 vs 2010: {growth*100:.2f}%")
print(scores.to_string(index=False))
print(fc.round(0).to_string())
print(bva[["budget_net","revised_forecast_net","actual_net","var_vs_budget","var_vs_budget_pct","gross_sales_effect","cancellation_effect","var_vs_revised"]].round(1).to_string())
print(tot.round(0).to_string())
print("Budget total variance %:", round(tot.var_vs_budget / tot.budget_net * 100, 2))
