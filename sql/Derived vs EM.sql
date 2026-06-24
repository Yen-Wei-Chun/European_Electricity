WITH checked AS (
    SELECT d.country,
        d.timestamp_utc,
        d.gco2_per_kwh AS derived,
        e.gco2_per_kwh AS electricitymaps,
        ABS(d.gco2_per_kwh - e.gco2_per_kwh) AS abs_error
    FROM carbon_intensity d
        JOIN carbon_intensity e ON e.country = d.country
        AND e.timestamp_utc = d.timestamp_utc
        AND e.method = 'electricitymaps'
    WHERE d.method = 'derived'
        AND d.country = 'DE_LU'
    ORDER BY abs_error DESC
)
SELECT c.country AS country,
    c.timestamp_utc AS timestamp_utc,
    g.source_type AS source_type,
    g.mw AS mw
FROM checked AS c
    JOIN generation AS g ON c.timestamp_utc = g.timestamp_utc
WHERE g.country = 'DE_LU'
    AND g.source_type IN ('coal', 'gas')
ORDER BY c.abs_error DESC