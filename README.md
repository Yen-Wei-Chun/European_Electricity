# Carbon-Aware Compute Framework

> Scheduling a 10MW flexible AI workload in **France (00:00–04:00 UTC)** instead of **Italy (20:00–24:00 UTC)** avoids **5,349 tonnes of CO₂ per year** — equivalent to removing ~2,139 passenger cars from the road annually.

A data pipeline and dispatch framework that identifies optimal scheduling windows for flexible AI compute workloads across 4 European electricity markets, using structural carbon intensity patterns derived from hourly grid generation data.

**Countries**: Germany · France · Spain · Italy  
**Data sources**: ENTSO-E (primary) + Electricity Maps (validation layer)  
**Stack**: Python · PostgreSQL · Tableau  
**Methodology**: Full write-up in [`docs/Methodology_Note.pdf`]

---

## The problem

AI data centres are the fastest-growing source of electricity demand in Europe. Unlike fixed industrial loads, batch inference and training workloads can shift by hours without affecting output. Europe's renewable build-out has made grid carbon intensity highly variable — the same kilowatt-hour carries 10× more CO₂ depending on country, hour, and season.

This framework quantifies that arbitrage and derives a carbon-aware dispatch strategy: **when and where should flexible compute be scheduled to minimise grid carbon cost?**

---

## Key finding: 4-hour block dispatch ranking

| Rank | Country | Time block (UTC) | Grid profile | Action |
|------|---------|-----------------|--------------|--------|
| 1 | FR | 00:00–04:00 | ~70–80% nuclear baseload. Near-zero carbon floor, flat across all seasons. | Primary anchor — schedule highest-intensity batch workloads here |
| 2 | ES | 10:00–14:00 | Solar-dominant. Strong intraday trough in Q2/Q3. | Tactical — competitive with FR during summer daylight hours |
| 3 | DE | 16:00–20:00 | Wind-heavy but intermittent. Gas/coal backup engages at evening demand peak. | Avoidance — 300+ gCO₂/kWh swing risk |
| 4 | IT | 20:00–24:00 | Gas-dependent. Highest baseline emissions, pronounced evening peaker spikes. | Critical avoidance — maximises Scope 2 exposure |

The structural carbon intensity delta between rank 1 and rank 4 is **300–400 gCO₂/kWh** — equivalent to the emissions difference between driving an EV and a petrol car.

---

## Dashboard

Explore the interactive dashboard on Tableau Public:
[EU Electricity Intermittency Analysis](https://public.tableau.com/views/EUElectricityIntermittencyAnalysis/IntermittencyAnalysis?:language=en-US&:sid=&:display_count=n&:origin=viz_share_link)

[EU Electricity Dispatch Analysis](https://public.tableau.com/views/EUElectricityDispatchAnalysis/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## Project structure

```
GDA_European_Electricity/
├── notebook/
│   ├── entsoe_ingest.ipynb              # ENTSO-E generation mix ingestion
│   ├── em_ingest.ipynb                  # Electricity Maps carbon intensity pull
│   ├── crossborder_ingest.ipynb         # Cross-border flow ingestion
│   ├── carbon_intensity_calculation.ipynb  # Derives gCO₂/kWh from generation mix
│   ├── intermittency_analysis.ipynb     # Hour-of-day and seasonal profiles
│   ├── dispatch_framework.ipynb         # 4-hour block ranking and CO₂ savings calc
│   └── data_completeness_audit.ipynb    # Gap detection and data quality log
├── sql/
│   ├── schema.sql                       # All 5 tables — run this first
│   ├── Derived_carbon_intensity.sql     # Core carbon intensity calculation query
│   └── Derived_vs_EM.sql               # Validation comparison against Electricity Maps
├── docs/
│   ├── Methodology_Note.pdf            # Full methodology, validation results, 
├── data/                               # Gitignored — see Data sources below
├── .env.example                        # Copy to .env and fill in keys
└── requirements.txt
```

---

## Setup

```bash
# 1. Clone and create virtual environment
git clone https://github.com/[your-username]/GDA_European_Electricity.git
cd GDA_European_Electricity
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Set up environment variables
cp .env.example .env
# Edit .env — add ENTSO-E token, Electricity Maps key, and DB connection string

# 4. Create the database and run schema
createdb carbon_compute
psql carbon_compute < sql/schema.sql

# 5. Run ingestion in order (see below)
```

## Recommended ingestion order

1. `em_ingest.ipynb` — pull Electricity Maps carbon intensity for all 4 countries (~90 days, free tier)
2. `entsoe_ingest.ipynb` — start with one country and one year: set `COUNTRY = "DE_LU"`, `YEAR = 2024`
3. `data_completeness_audit.ipynb` — validate row counts and timestamp continuity before proceeding
4. Expand ENTSO-E ingestion to all 4 countries
5. `crossborder_ingest.ipynb` — ingest FR↔DE, FR↔ES, FR↔IT interconnector flows
6. `carbon_intensity_calculation.ipynb` — derive gCO₂/kWh from generation mix
7. `Derived_vs_EM.sql` — run MAE validation against Electricity Maps

---

## Data sources

| Source | What it provides | Access |
|--------|-----------------|--------|
| [ENTSO-E Transparency Platform](https://transparency.entsoe.eu) | Hourly generation mix by source type, cross-border physical flows | Free — register and request API token by email |
| [Electricity Maps API](https://api.electricitymap.org) | Pre-calculated carbon intensity (gCO₂/kWh) | Free tier — real-time + ~90 days historical |

Raw data files are gitignored. The `data/` folder is not included in this repo. Register at the sources above to reproduce the dataset.

---

## Methodology summary

Carbon intensity is derived from ENTSO-E generation mix using IPCC AR6 lifecycle emission factor medians:

```
gCO₂/kWh = Σ(MW_by_source × IPCC_factor) / Total_MW
```

| Source | gCO₂/kWh |
|--------|----------|
| Nuclear | 12 |
| Wind onshore / offshore | 11 / 12 |
| Solar PV | 45 |
| Hydro | 24 |
| Gas | 490 |
| Coal | 820 |

Derived figures are validated against Electricity Maps for a 90-day overlapping window. Correlation exceeds 0.94 across all countries. DE_LU shows elevated MAE (109.6 gCO₂/kWh) due to Germany's high lignite share — actual plant emissions exceed the IPCC coal median — and is documented as a known methodological divergence, not a data error.

Full validation results and limitations are in [`docs/Methodology_Note.pdf`](docs/Methodology_Note.pdf).

---

## Known data quirks

- **Germany**: Use bidding zone `DE_LU` (Germany + Luxembourg), not `DE`
- **Spain**: Reports solar PV (B16) and solar thermal (B17) separately — both mapped to `solar_pv` and `solar_thermal` in the generation table
- **France**: Nuclear occasionally reported as an aggregated total — normal ENTSO-E behaviour
- **Italy**: Generation-based carbon intensity systematically overstates consumption-based figures by up to 175 gCO₂/kWh due to untracked low-carbon imports (French nuclear, Swiss hydro). Documented in the methodology note.
- **All countries**: `mw = NULL` in the generation table means a reported gap, not zero generation

---

## Honest limitations

This framework is a directional probability guide, not a real-time execution model. Three things it does not model: minimum uptime SLAs and base-load constraints that prevent full workload flexibility; physical network latency and cross-border regulatory restrictions (GDPR data residency); and marginal emission factors, which are more operationally precise than the IPCC lifecycle values used here. The dispatch ranking is based on historical medians — it describes structural patterns, not day-ahead forecasts.

---

## License

© [Gillian Yen] 2026 — All rights reserved
