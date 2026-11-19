-- ЛР5 МРІКС. Аналітичні запити до сховища «Надійні постачальники»

-- Запит 1. Хто з постачальників привозить вчасно
-- Рахуємо всі поставки, вчасні поставки і відсоток вчасних.
SELECT s.supplier_name,
       COUNT(*) AS supplies,
       SUM(CASE WHEN f.delay_days = 0 THEN 1 ELSE 0 END) AS on_time,
       ROUND(100.0 * SUM(CASE WHEN f.delay_days = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_pct
FROM fact_supply f
JOIN dim_supplier s ON s.supplier_key = f.supplier_key
GROUP BY s.supplier_name
ORDER BY on_time_pct DESC;

-- Запит 2. У кого найбільше браку
-- Ділимо кількість браку на привезену кількість.
SELECT s.supplier_name,
       SUM(f.qty_delivered) AS delivered,
       SUM(f.qty_defective) AS defective,
       ROUND(100.0 * SUM(f.qty_defective) / SUM(f.qty_delivered), 1) AS defect_pct
FROM fact_supply f
JOIN dim_supplier s ON s.supplier_key = f.supplier_key
GROUP BY s.supplier_name
ORDER BY defect_pct DESC;

-- Запит 3. Кому ми платимо найбільше
-- Сума закупівель у кожного постачальника.
SELECT s.supplier_name,
       s.supplier_type,
       SUM(f.amount) AS total_amount
FROM fact_supply f
JOIN dim_supplier s ON s.supplier_key = f.supplier_key
GROUP BY s.supplier_name, s.supplier_type
ORDER BY total_amount DESC;

-- Запит 4. Як змінюється запізнення по місяцях
-- Тут потрібен вимір «Період».
SELECT d.month_num,
       d.month_name,
       COUNT(*) AS supplies,
       ROUND(AVG(f.delay_days), 1) AS avg_delay_days
FROM fact_supply f
JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.month_num, d.month_name
ORDER BY d.month_num;

-- Запит 5. На які матеріали йде найбільше грошей
-- Сума і кількість поставок за групами матеріалів.
SELECT m.material_group,
       COUNT(*) AS supplies,
       SUM(f.amount) AS total_amount
FROM fact_supply f
JOIN dim_material m ON m.material_key = f.material_key
GROUP BY m.material_group
ORDER BY total_amount DESC;
