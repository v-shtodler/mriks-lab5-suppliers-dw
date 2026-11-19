-- Тестові (вигадані) дані, щоб перевірити, що запити виконуються.
-- За завданням заповнювати сховище не обов'язково — це лише для тестувальника.
-- Усі назви постачальників і цифри вигадані, збіги з реальними компаніями випадкові.
-- Запуск після 01_create_dw.sql: psql -d <база> -f sql/dml/02_sample_data.sql

SET search_path TO dw;
SELECT setseed(0.42);   -- щоб випадкові дані щоразу були однакові

-- Календар на 2025–2026 роки
INSERT INTO dim_date
SELECT to_char(d, 'YYYYMMDD')::int, d::date,
       extract(day FROM d), extract(isodow FROM d), extract(week FROM d),
       extract(month FROM d),
       (ARRAY['Січень','Лютий','Березень','Квітень','Травень','Червень',
              'Липень','Серпень','Вересень','Жовтень','Листопад','Грудень'])[extract(month FROM d)::int],
       extract(quarter FROM d), extract(year FROM d),
       extract(isodow FROM d) IN (6, 7)
FROM generate_series('2025-01-01'::date, '2026-12-31'::date, interval '1 day') AS d;

INSERT INTO dim_supplier (supplier_code, supplier_name, supplier_type, country, region, city,
                          payment_terms_days, contract_start, is_certified) VALUES
('S001', 'Фанера-Захід',     'виробник',     'Україна',  'Львівська',         'Львів',     30, '2023-02-01', TRUE),
('S002', 'Карпат-Ліс',       'виробник',     'Україна',  'Закарпатська',      'Рахів',     14, '2022-06-15', TRUE),
('S003', 'Полісся-Плит',     'виробник',     'Україна',  'Житомирська',       'Коростень', 21, '2024-01-10', FALSE),
('S004', 'Baltic Birch OU',  'імпортер',     'Естонія',  'Harju',             'Таллінн',   45, '2024-05-20', TRUE),
('S005', 'Колор-Трейд',      'дистриб''ютор','Україна',  'Київська',          'Київ',       7, '2023-09-01', FALSE),
('S006', 'EcoLack GmbH',     'виробник',     'Німеччина','Bayern',            'Мюнхен',    60, '2025-01-15', TRUE),
('S007', 'Пак-Сервіс',       'виробник',     'Україна',  'Київська',          'Бровари',   14, '2022-11-11', FALSE),
('S008', 'Кріп-Майстер',     'дистриб''ютор','Україна',  'Дніпропетровська',  'Дніпро',     0, '2025-03-03', FALSE);

INSERT INTO dim_material (material_code, material_name, material_group, unit_of_measure, is_critical) VALUES
('M001', 'Фанера березова 6 мм',      'Фанера',        'лист', TRUE),
('M002', 'Фанера березова 3 мм',      'Фанера',        'лист', TRUE),
('M003', 'Фарба акрилова',            'Фарби і лаки',  'л',    TRUE),
('M004', 'Лак водний матовий',        'Фарби і лаки',  'л',    FALSE),
('M005', 'Коробка гофрокартонна',     'Пакування',     'шт',   TRUE),
('M006', 'Плівка захисна',            'Пакування',     'кг',   FALSE),
('M007', 'Двосторонній скотч',        'Кріплення',     'шт',   FALSE);

INSERT INTO dim_warehouse (warehouse_code, warehouse_name, city) VALUES
('W01', 'Склад сировини №1', 'Київ'),
('W02', 'Склад пакування',   'Бровари');

INSERT INTO dim_buyer (buyer_code, full_name, department) VALUES
('B01', 'Менеджер 1', 'Відділ закупівель'),
('B02', 'Менеджер 2', 'Відділ закупівель');

-- 600 поставок. У кожного постачальника свій «характер»: хтось возить вчасно, хтось запізнюється.
WITH raw AS (
    SELECT g,
           1 + (random() * 7)::int                       AS supplier_key,
           '2025-01-10'::date + (random() * 640)::int    AS order_date,
           5 + (random() * 15)::int                      AS lead_days,
           random() AS r_delay, random() AS r_qty, random() AS r_def, random() AS r_mat
    FROM generate_series(1, 600) AS g
), shaped AS (
    SELECT r.*,
           CASE r.supplier_key            -- матеріал залежить від профілю постачальника
               WHEN 1 THEN 1 + (r_mat * 1)::int  WHEN 2 THEN 1 + (r_mat * 1)::int
               WHEN 3 THEN 1 + (r_mat * 1)::int  WHEN 4 THEN 1 + (r_mat * 1)::int
               WHEN 5 THEN 3 + (r_mat * 1)::int  WHEN 6 THEN 3 + (r_mat * 1)::int
               WHEN 7 THEN 5 + (r_mat * 1)::int  ELSE 7 END AS material_key,
           -- ймовірність запізнення і частка браку для кожного постачальника
           (ARRAY[0.05, 0.10, 0.45, 0.20, 0.30, 0.08, 0.15, 0.55])[r.supplier_key] AS p_late,
           (ARRAY[0.005, 0.01, 0.06, 0.01, 0.03, 0.002, 0.02, 0.05])[r.supplier_key] AS p_def
    FROM raw r
), calc AS (
    SELECT s.*,
           order_date + lead_days AS promised_date,
           CASE WHEN r_delay < p_late THEN 1 + (random() * 9)::int ELSE -(random() * 2)::int END AS delay_days,
           (20 + (r_qty * 180)::int)::numeric AS qty_ordered,
           (ARRAY[620, 340, 185, 240, 28, 95, 45])[material_key]::numeric AS unit_price
    FROM shaped s
), fin AS (
    SELECT c.*,
           CASE WHEN r_qty < p_late / 2 THEN round(qty_ordered * 0.85) ELSE qty_ordered END AS qty_delivered
    FROM calc c
)
INSERT INTO fact_supply (order_date_key, promised_date_key, delivery_date_key, supplier_key, material_key,
                         warehouse_key, buyer_key, po_number, qty_ordered, qty_delivered, qty_defective,
                         unit_price, amount, delay_days, is_on_time, is_complete, has_claim)
SELECT to_char(order_date, 'YYYYMMDD')::int,
       to_char(promised_date, 'YYYYMMDD')::int,
       to_char(promised_date + delay_days, 'YYYYMMDD')::int,
       supplier_key, material_key,
       CASE WHEN material_key IN (5, 6) THEN 2 ELSE 1 END,
       1 + (g % 2),
       'PO-' || lpad(g::text, 5, '0'),
       qty_ordered, qty_delivered,
       round(qty_delivered * p_def * (0.5 + r_def)),
       unit_price, qty_delivered * unit_price,
       delay_days, delay_days <= 0, qty_delivered >= qty_ordered,
       round(qty_delivered * p_def * (0.5 + r_def)) > 2
FROM fin;
