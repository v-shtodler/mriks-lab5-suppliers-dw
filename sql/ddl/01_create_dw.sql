-- ЛР5 МРІКС. Сховище даних «Надійні постачальники»
-- СУБД: PostgreSQL. Схема «зірка»: 1 таблиця фактів і 4 виміри

-- Вимір «Період»
CREATE TABLE dim_date (
    date_key    INTEGER PRIMARY KEY,      -- дата у вигляді числа, напр. 20260315
    full_date   DATE NOT NULL,
    month_num   INTEGER NOT NULL,
    month_name  VARCHAR(20) NOT NULL,
    quarter_num INTEGER NOT NULL,
    year_num    INTEGER NOT NULL
);

-- Вимір «Постачальник»
CREATE TABLE dim_supplier (
    supplier_key  INTEGER PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    supplier_type VARCHAR(30) NOT NULL,   -- виробник або дистриб'ютор
    city          VARCHAR(50) NOT NULL
);

-- Вимір «Матеріал»
CREATE TABLE dim_material (
    material_key   INTEGER PRIMARY KEY,
    material_name  VARCHAR(100) NOT NULL,
    material_group VARCHAR(50) NOT NULL,  -- фанера, фарби і лаки, пакування
    unit           VARCHAR(10) NOT NULL   -- одиниця виміру
);

-- Вимір «Склад»
CREATE TABLE dim_warehouse (
    warehouse_key  INTEGER PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    city           VARCHAR(50) NOT NULL
);

-- Таблиця фактів «Поставка»: один рядок = одна поставка одного матеріалу
CREATE TABLE fact_supply (
    supply_key    INTEGER PRIMARY KEY,
    date_key      INTEGER NOT NULL REFERENCES dim_date (date_key),
    supplier_key  INTEGER NOT NULL REFERENCES dim_supplier (supplier_key),
    material_key  INTEGER NOT NULL REFERENCES dim_material (material_key),
    warehouse_key INTEGER NOT NULL REFERENCES dim_warehouse (warehouse_key),
    qty_ordered   NUMERIC(10,2) NOT NULL, -- замовлена кількість
    qty_delivered NUMERIC(10,2) NOT NULL, -- привезена кількість
    qty_defective NUMERIC(10,2) NOT NULL, -- кількість браку
    unit_price    NUMERIC(10,2) NOT NULL, -- ціна за одиницю, грн
    amount        NUMERIC(12,2) NOT NULL, -- сума поставки, грн
    delay_days    INTEGER NOT NULL        -- запізнення в днях (0 = вчасно)
);
