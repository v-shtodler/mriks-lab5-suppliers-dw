-- ЛР5 МРІКС. Тести цілісності сховища «Надійні постачальники» (PostgreSQL)
-- Кожен тест повертає кількість порушень. Очікуваний результат усюди — 0.
-- Запуск після наповнення даними: psql -d <база> -f sql/tests/03_integrity_checks.sql
SET search_path TO dw;

SELECT 'T1: факти без постачальника у вимірі' AS test,
       COUNT(*) AS violations
FROM fact_supply f LEFT JOIN dim_supplier s ON s.supplier_key = f.supplier_key
WHERE s.supplier_key IS NULL
UNION ALL
SELECT 'T2: факти без матеріалу у вимірі', COUNT(*)
FROM fact_supply f LEFT JOIN dim_material m ON m.material_key = f.material_key
WHERE m.material_key IS NULL
UNION ALL
SELECT 'T3: обіцяна дата раніше дати замовлення', COUNT(*)
FROM fact_supply WHERE promised_date_key < order_date_key
UNION ALL
SELECT 'T4: привезено більше, ніж замовлено', COUNT(*)
FROM fact_supply WHERE qty_delivered > qty_ordered
UNION ALL
SELECT 'T5: браку більше, ніж привезено', COUNT(*)
FROM fact_supply WHERE qty_defective > qty_delivered
UNION ALL
SELECT 'T6: сума не дорівнює кількість × ціна', COUNT(*)
FROM fact_supply WHERE amount <> qty_delivered * unit_price
UNION ALL
SELECT 'T7: ознака «вчасно» суперечить запізненню', COUNT(*)
FROM fact_supply WHERE is_on_time <> (delay_days <= 0)
UNION ALL
SELECT 'T8: ознака «повна» суперечить кількості', COUNT(*)
FROM fact_supply WHERE is_complete <> (qty_delivered >= qty_ordered)
UNION ALL
SELECT 'T9: запізнення не збігається з різницею дат', COUNT(*)
FROM fact_supply f
JOIN dim_date p ON p.date_key = f.promised_date_key
JOIN dim_date d ON d.date_key = f.delivery_date_key
WHERE f.delay_days <> d.full_date - p.full_date
UNION ALL
SELECT 'T10: дублікати позицій замовлення', COUNT(*)
FROM (SELECT po_number, material_key FROM fact_supply
      GROUP BY po_number, material_key HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'T11: пропуски в календарі', (MAX(full_date) - MIN(full_date) + 1) - COUNT(*)
FROM dim_date
UNION ALL
SELECT 'T12: дублікати кодів постачальників', COUNT(*) - COUNT(DISTINCT supplier_code)
FROM dim_supplier;
