-- Carbon-Aware Compute Framework
-- Schema Version 1.0

-- ── 1. Reference tables ──────────────────────────────────────────

CREATE TABLE countries (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(10)  NOT NULL UNIQUE,  -- e.g. 'DE_LU', 'FR', 'GB'
    name        VARCHAR(50)  NOT NULL,
    timezone    VARCHAR(50)  NOT NULL          -- e.g. 'Europe/Berlin'
);

INSERT INTO countries (code, name, timezone) VALUES
    ('DE_LU', 'Germany',  'Europe/Berlin'),
    ('FR',    'France',   'Europe/Paris'),
    ('ES',    'Spain',    'Europe/Madrid'),
    ('IT',    'Italy',    'Europe/Rome'),
    ('GB',    'UK',       'Europe/London');

CREATE TABLE emission_factors (
    source_type     VARCHAR(50) PRIMARY KEY,  -- e.g. 'wind_onshore', 'nuclear', 'gas'
    gco2_per_kwh    NUMERIC(6,2) NOT NULL,    -- IPCC lifecycle median
    source_note     TEXT                      -- e.g. 'IPCC AR6 lifecycle median'
);

INSERT INTO emission_factors (source_type, gco2_per_kwh, source_note) VALUES
    ('nuclear',          12,  'IPCC AR5 Annex III Table A.III.2 lifecycle median'),
    ('wind_onshore',     11,  'IPCC AR5 Annex III Table A.III.2 lifecycle median'),
    ('wind_offshore',    12,  'IPCC AR5 Annex III Table A.III.2 lifecycle median'),
    ('solar_pv',         45,  'IPCC AR5 Annex III Table A.III.2 lifecycle median — between rooftop (41) and utility (48)'),
    ('hydro',            24,  'IPCC AR5 Annex III Table A.III.2 lifecycle median — note wide range (1–2200) due to reservoir methane'),
    ('gas',             490,  'IPCC AR5 Annex III Table A.III.2 — Combined Cycle lifecycle median'),
    ('coal',            820,  'IPCC AR5 Annex III Table A.III.2 — Pulverised Coal lifecycle median'),
    ('biomass',         230,  'IPCC AR5 Annex III Table A.III.2 — dedicated biomass lifecycle median'),
    ('oil',             650,  'IEA estimate — not separately listed in IPCC AR5 Annex III Table A.III.2'),
    ('geothermal',       38,  'IPCC AR5 Annex III Table A.III.2 lifecycle median (range 6–79)'),
    ('other',           300,  'Estimated average — excludes geothermal and other renewables mapped separately');

-- ── 2. Core data tables ───────────────────────────────────────────

-- Hourly generation mix per country per source (rows, not columns)
CREATE TABLE generation (
    id              BIGSERIAL PRIMARY KEY,
    country         VARCHAR(10)  NOT NULL REFERENCES countries(code),
    timestamp_utc   TIMESTAMPTZ  NOT NULL,
    source_type     VARCHAR(50)  NOT NULL REFERENCES emission_factors(source_type),
    mw              NUMERIC(10,2),            -- NULL = reported gap, not zero
    UNIQUE (country, timestamp_utc, source_type)
);

CREATE INDEX idx_gen_country_ts ON generation (country, timestamp_utc);

-- Cross-border physical flows between country pairs
CREATE TABLE cross_border_flows (
    id              BIGSERIAL PRIMARY KEY,
    from_country    VARCHAR(10)  NOT NULL REFERENCES countries(code),
    to_country      VARCHAR(10)  NOT NULL REFERENCES countries(code),
    timestamp_utc   TIMESTAMPTZ  NOT NULL,
    mw              NUMERIC(10,2),
    UNIQUE (from_country, to_country, timestamp_utc)
);

CREATE INDEX idx_flow_pair_ts ON cross_border_flows (from_country, to_country, timestamp_utc);

-- Derived and validated carbon intensity
CREATE TABLE carbon_intensity (
    id              BIGSERIAL PRIMARY KEY,
    country         VARCHAR(10)  NOT NULL REFERENCES countries(code),
    timestamp_utc   TIMESTAMPTZ  NOT NULL,
    gco2_per_kwh    NUMERIC(8,2) NOT NULL,
    method          VARCHAR(30)  NOT NULL,    -- 'derived' | 'electricitymaps'
    UNIQUE (country, timestamp_utc, method)
);

CREATE INDEX idx_ci_country_ts ON carbon_intensity (country, timestamp_utc);

-- ── 3. Data quality log ───────────────────────────────────────────

CREATE TABLE data_notes (
    id          SERIAL PRIMARY KEY,
    country     VARCHAR(10),
    noted_at    TIMESTAMPTZ DEFAULT NOW(),
    note_type   VARCHAR(30),                  -- 'gap', 'anomaly', 'quirk'
    description TEXT NOT NULL
);
