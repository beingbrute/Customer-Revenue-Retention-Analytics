"""Builds output/forecast_variance_report.xlsx: variance and KPIs are live Excel formulas, not pasted values."""
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.formatting.rule import CellIsRule
from openpyxl.chart import LineChart, BarChart, Reference

OUT = Path(__file__).resolve().parent / "output"
bva = pd.read_csv(OUT / "budget_vs_actual.csv", parse_dates=["month"])
fc = pd.read_csv(OUT / "forecast_by_month.csv", parse_dates=["month"])
scores = pd.read_csv(OUT / "forecast_scores.csv")

wb = Workbook()
bold = Font(bold=True)
hdr_fill = PatternFill("solid", fgColor="1F3A5F")
hdr_font = Font(bold=True, color="FFFFFF")
red = PatternFill("solid", fgColor="FFC7CE")
green = PatternFill("solid", fgColor="C6EFCE")
gbp = '£#,##0;[Red]-£#,##0'
pct = '0.0%;[Red]-0.0%'
thin = Border(bottom=Side(style="thin", color="999999"))

def header(ws, row, names):
    for i, n in enumerate(names, 1):
        c = ws.cell(row=row, column=i, value=n)
        c.font, c.fill = hdr_font, hdr_fill
        c.alignment = Alignment(wrap_text=True, vertical="center")

# --- Sheet 1: Budget vs actual (formulas) ---
ws = wb.active
ws.title = "Budget vs Actual"
ws["A1"] = "Budget vs revised forecast vs actual: net revenue, Jun-Nov 2011"
ws["A1"].font = Font(bold=True, size=14)
ws["A2"] = "Illustrative budget: 2010 actual for the same month x (1 + planning growth). Hypothetical, not a real company budget."
ws["A3"] = "Planning growth"; ws["B3"] = 0.10; ws["B3"].number_format = "0%"; ws["A3"].font = bold
ws["C3"] = "← change this to test another budget scenario"
cols = ["Month", "2010 gross sales (same month)", "2010 cancellations (same month)",
        "Budget gross", "Budget cancellations", "Budget net", "Revised forecast net (May 2011)",
        "Actual gross", "Actual cancellations", "Actual net",
        "Variance vs budget", "Variance vs budget %", "Gross sales effect", "Cancellation effect",
        "Variance vs revised forecast"]
header(ws, 5, cols)
ly_gross = (bva.budget_gross / 1.10).round(2)
ly_canc = (bva.budget_cancellations / 1.10).round(2)
for i, r in bva.iterrows():
    x = 6 + i
    ws.cell(x, 1, r.month.strftime("%b %Y"))
    ws.cell(x, 2, float(ly_gross[i])); ws.cell(x, 3, float(ly_canc[i]))
    ws.cell(x, 4, f"=B{x}*(1+$B$3)"); ws.cell(x, 5, f"=C{x}*(1+$B$3)"); ws.cell(x, 6, f"=D{x}-E{x}")
    ws.cell(x, 7, float(r.revised_forecast_net))
    ws.cell(x, 8, float(r.actual_gross)); ws.cell(x, 9, float(r.actual_cancellations)); ws.cell(x, 10, f"=H{x}-I{x}")
    ws.cell(x, 11, f"=J{x}-F{x}"); ws.cell(x, 12, f"=IF(F{x}=0,\"\",K{x}/F{x})")
    ws.cell(x, 13, f"=H{x}-D{x}"); ws.cell(x, 14, f"=-(I{x}-E{x})"); ws.cell(x, 15, f"=J{x}-G{x}")
last = 6 + len(bva) - 1
tot = last + 1
ws.cell(tot, 1, "Total").font = bold
for c in range(2, 16):
    L = ws.cell(5, c).column_letter
    if c == 12:
        ws.cell(tot, c, f"=IF(F{tot}=0,\"\",K{tot}/F{tot})")
    else:
        ws.cell(tot, c, f"=SUM({L}6:{L}{last})")
    ws.cell(tot, c).font = bold
for row in ws.iter_rows(min_row=6, max_row=tot, min_col=2, max_col=15):
    for c in row:
        c.number_format = pct if c.column == 12 else gbp
for rng in [f"K6:K{tot}", f"L6:L{tot}", f"M6:O{tot}"]:
    ws.conditional_formatting.add(rng, CellIsRule(operator="lessThan", formula=["0"], fill=red))
    ws.conditional_formatting.add(rng, CellIsRule(operator="greaterThan", formula=["0"], fill=green))
chk = tot + 2
ws.cell(chk, 1, "Check: variance = gross effect + cancellation effect").font = bold
ws.cell(chk, 2, f'=IF(ABS(K{tot}-(M{tot}+N{tot}))<0.01,"OK","MISMATCH")')
ws.conditional_formatting.add(f"B{chk}", CellIsRule(operator="equal", formula=['"MISMATCH"'], fill=red))
ws.conditional_formatting.add(f"B{chk}", CellIsRule(operator="equal", formula=['"OK"'], fill=green))
ws.column_dimensions["A"].width = 30
for c in "BCDEFGHIJKLMNO":
    ws.column_dimensions[c].width = 15
ws.row_dimensions[5].height = 45
ws.freeze_panes = "B6"

# KPI cards
k = chk + 2
ws.cell(k, 1, "Key figures, Jun-Nov 2011").font = Font(bold=True, size=12)
cards = [("Budget net", f"=F{tot}", gbp), ("Actual net", f"=J{tot}", gbp),
         ("Variance vs budget", f"=K{tot}", gbp), ("Variance vs budget %", f"=L{tot}", pct),
         ("Months below budget", f'=COUNTIF(K6:K{last},"<0")', "0"),
         ("Largest shortfall month", f"=INDEX(A6:A{last},MATCH(MIN(K6:K{last}),K6:K{last},0))", "@")]
for j, (lab, f, nf) in enumerate(cards):
    ws.cell(k + 1 + j, 1, lab).font = bold
    ws.cell(k + 1 + j, 2, f).number_format = nf

ch = BarChart(); ch.type = "col"; ch.title = "Net revenue: budget vs revised forecast vs actual"
ch.y_axis.title = "£"; ch.height, ch.width = 8, 18
data = Reference(ws, min_col=6, max_col=7, min_row=5, max_row=last)
ch.add_data(data, titles_from_data=True)
ch.add_data(Reference(ws, min_col=10, max_col=10, min_row=5, max_row=last), titles_from_data=True)
ch.set_categories(Reference(ws, min_col=1, min_row=6, max_row=last))
ws.add_chart(ch, f"D{k}")

# --- Sheet 2: Forecast test ---
f2 = wb.create_sheet("Forecast Test")
f2["A1"] = "Six-month hold-out test: forecasts made once at the end of May 2011 (train Jan 2010 - May 2011)"
f2["A1"].font = Font(bold=True, size=12)
f2["A2"] = "December 2011 excluded: partial month (data ends 9 Dec 2011)."
header(f2, 4, ["Month", "Actual net", "Seasonal naive (last year)", "Seasonal naive x YoY growth", "Holt linear trend",
               "Abs error: seasonal naive", "Abs error: naive x growth", "Abs error: Holt"])
for i, r in fc.iterrows():
    x = 5 + i
    f2.cell(x, 1, r.month.strftime("%b %Y"))
    for c, v in zip(range(2, 6), [r.actual, r.seasonal_naive, r.seasonal_naive_growth, r.holt_linear]):
        f2.cell(x, c, float(v))
    f2.cell(x, 6, f"=ABS(B{x}-C{x})"); f2.cell(x, 7, f"=ABS(B{x}-D{x})"); f2.cell(x, 8, f"=ABS(B{x}-E{x})")
fl = 5 + len(fc) - 1
s = fl + 2
f2.cell(s, 1, "MAE (£)").font = bold
f2.cell(s + 1, 1, "WAPE").font = bold
for c, L in zip(range(6, 9), "FGH"):
    f2.cell(s, c, f"=AVERAGE({L}5:{L}{fl})").number_format = gbp
    f2.cell(s + 1, c, f"=SUM({L}5:{L}{fl})/SUM(B5:B{fl})").number_format = pct
f2.cell(s + 2, 1, "Best method").font = bold
f2.cell(s + 2, 2, f'=INDEX(F4:H4,MATCH(MIN(F{s+1}:H{s+1}),F{s+1}:H{s+1},0))')
for row in f2.iter_rows(min_row=5, max_row=fl, min_col=2, max_col=8):
    for c in row: c.number_format = gbp
for c in "ABCDEFGH":
    f2.column_dimensions[c].width = 18
f2.row_dimensions[4].height = 45
lc = LineChart(); lc.title = "Actual vs forecasts, Jun-Nov 2011"; lc.height, lc.width = 8, 18
lc.add_data(Reference(f2, min_col=2, max_col=5, min_row=4, max_row=fl), titles_from_data=True)
lc.set_categories(Reference(f2, min_col=1, min_row=5, max_row=fl))
f2.add_chart(lc, f"A{s+5}")

# --- Sheet 3: Definitions ---
d = wb.create_sheet("Definitions")
rows = [
    ("Term", "Definition"),
    ("Net revenue", "Gross sales minus cancellation value (estimated_net_revenue in the pipeline)."),
    ("Budget", "Illustrative: 2010 actual for the same month x (1 + planning growth on sheet 1). Hypothetical scenario, not a real budget."),
    ("Revised forecast", "Seasonal naive x Jan-May 2011 vs Jan-May 2010 growth (-4.93%), made at the end of May 2011."),
    ("Variance vs budget", "Actual net - budget net. Negative = below budget."),
    ("Gross sales effect", "Actual gross sales - budget gross sales."),
    ("Cancellation effect", "-(Actual cancellations - budget cancellations). Fewer cancellations than planned is favourable."),
    ("MAE", "Mean absolute error in £ across the 6 test months."),
    ("WAPE", "Sum of absolute errors / sum of actuals. Less distorted than MAPE when months differ in size."),
    ("Test design", "Fixed-origin: one forecast made at end of May 2011 for Jun-Nov 2011 (1 to 6 months ahead). Test months never used for fitting."),
    ("Excluded", "December 2011: partial month. December 2009: before the training window."),
]
for i, (a, b) in enumerate(rows, 1):
    d.cell(i, 1, a); d.cell(i, 2, b)
    if i == 1:
        d.cell(i, 1).font = hdr_font; d.cell(i, 2).font = hdr_font
        d.cell(i, 1).fill = hdr_fill; d.cell(i, 2).fill = hdr_fill
    else:
        d.cell(i, 1).font = bold
d.column_dimensions["A"].width = 22; d.column_dimensions["B"].width = 110

wb.save(OUT / "forecast_variance_report.xlsx")
print("saved")
