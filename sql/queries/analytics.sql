-- ЛР5 МРІКС. Аналітичні запити до сховища «Надійні постачальники» (PostgreSQL)
SET search_path TO dw;

-- =====================================================================
-- Запит 1. Рейтинг надійності постачальників
-- Призначення: знайти найнадійніших постачальників за три показники:
--   вчасність (частка поставок без запізнення), повнота (частка привезеного
--   від замовленого) і якість (частка без браку). Ваги: 50 / 30 / 20 %.
-- =====================================================================
WITH kpi AS (
    SELECT s.supplier_name,
           COUNT(*)                                              AS supplies,
           ROUND(100.0 * AVG(f.is_on_time::int), 1)              AS on_time_pct,
           ROUND(100.0 * SUM(f.qty_delivered) / SUM(f.qty_ordered), 1) AS fill_rate_pct,
           ROUND(100.0 * SUM(f.qty_defective) / NULLIF(SUM(f.qty_delivered), 0), 2) AS defect_pct
    FROM fact_supply f
    JOIN dim_supplier s ON s.supplier_key = f.supplier_key
    WHERE f.delivery_date_key IS NOT NULL
    GROUP BY s.supplier_name
)
SELECT supplier_name, supplies, on_time_pct, fill_rate_pct, defect_pct,
       ROUND(0.5 * on_time_pct + 0.3 * fill_rate_pct + 0.2 * (100 - defect_pct), 1) AS reliability_score,
       RANK() OVER (ORDER BY 0.5 * on_time_pct + 0.3 * fill_rate_pct + 0.2 * (100 - defect_pct) DESC) AS place
FROM kpi
ORDER BY place;

-- =====================================================================
-- Запит 2. Динаміка вчасності по кварталах
-- Призначення: побачити, у кого надійність покращується, а в кого падає.
--   Це основа для прогнозу: кому можна збільшувати обсяги наступного періоду.
-- =====================================================================
WITH q AS (
    SELECT s.supplier_name, d.year_num, d.quarter_num,
           ROUND(100.0 * AVG(f.is_on_time::int), 1) AS on_time_pct
    FROM fact_supply f
    JOIN dim_supplier s ON s.supplier_key = f.supplier_key
    JOIN dim_date d     ON d.date_key = f.promised_date_key
    GROUP BY s.supplier_name, d.year_num, d.quarter_num
)
SELECT supplier_name, year_num, quarter_num, on_time_pct,
       on_time_pct - LAG(on_time_pct) OVER (PARTITION BY supplier_name
                                            ORDER BY year_num, quarter_num) AS change_vs_prev_quarter
FROM q
ORDER BY supplier_name, year_num, quarter_num;

-- =====================================================================
-- Запит 3. Брак за групами матеріалів і постачальниками
-- Призначення: знайти, хто і на якому матеріалі дає найбільше браку
--   і рекламацій, щоб знати, з ким говорити про якість.
-- =====================================================================
SELECT m.material_group, s.supplier_name,
       SUM(f.qty_delivered)                                           AS qty_delivered,
       SUM(f.qty_defective)                                           AS qty_defective,
       ROUND(100.0 * SUM(f.qty_defective) / NULLIF(SUM(f.qty_delivered), 0), 2) AS defect_pct,
       COUNT(*) FILTER (WHERE f.has_claim)                            AS claims
FROM fact_supply f
JOIN dim_material m ON m.material_key = f.material_key
JOIN dim_supplier s ON s.supplier_key = f.supplier_key
GROUP BY m.material_group, s.supplier_name
HAVING SUM(f.qty_delivered) > 0
ORDER BY defect_pct DESC, claims DESC;

-- =====================================================================
-- Запит 4. Залежність від ненадійних постачальників
-- Призначення: показати, яку частку грошей на закупівлі ми віддаємо
--   кожному постачальнику, і позначити ризик: велика частка + погана вчасність.
-- =====================================================================
WITH t AS (
    SELECT s.supplier_name,
           SUM(f.amount)                              AS amount_uah,
           ROUND(100.0 * AVG(f.is_on_time::int), 1)   AS on_time_pct
    FROM fact_supply f
    JOIN dim_supplier s ON s.supplier_key = f.supplier_key
    GROUP BY s.supplier_name
)
SELECT supplier_name, amount_uah,
       ROUND(100.0 * amount_uah / SUM(amount_uah) OVER (), 1) AS share_pct,
       on_time_pct,
       CASE WHEN 100.0 * amount_uah / SUM(amount_uah) OVER () >= 15 AND on_time_pct < 80 THEN 'високий ризик'
            WHEN on_time_pct < 80                                                        THEN 'середній ризик'
            ELSE 'надійний' END AS risk_level
FROM t
ORDER BY amount_uah DESC;

-- =====================================================================
-- Запит 5. Середнє запізнення за країнами і типами постачальників
-- Призначення: порівняти місцевих і закордонних постачальників, виробників
--   і посередників. ROLLUP додає проміжні підсумки і загальний рядок.
-- =====================================================================
SELECT COALESCE(s.country, 'УСІ КРАЇНИ')     AS country,
       COALESCE(s.supplier_type, 'усі типи') AS supplier_type,
       COUNT(*)                               AS supplies,
       ROUND(AVG(GREATEST(f.delay_days, 0)), 2) AS avg_delay_days,
       MAX(f.delay_days)                      AS max_delay_days
FROM fact_supply f
JOIN dim_supplier s ON s.supplier_key = f.supplier_key
GROUP BY ROLLUP (s.country, s.supplier_type)
ORDER BY s.country NULLS LAST, s.supplier_type NULLS LAST;
