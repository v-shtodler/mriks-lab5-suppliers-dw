-- ЛР5 МРІКС. Сховище даних «Надійні постачальники»
-- СУБД: PostgreSQL 14+
-- Схема «зірка»: 1 таблиця фактів + 5 вимірів
-- Запуск: psql -d <база> -f sql/ddl/01_create_dw.sql

DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;
SET search_path TO dw;

-- ---------- Вимір «Період» (календар) ----------
CREATE TABLE dim_date (
    date_key      INTEGER      PRIMARY KEY,           -- формат РРРРММДД, напр. 20261119
    full_date     DATE         NOT NULL UNIQUE,
    day_of_month  SMALLINT     NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_week   SMALLINT     NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- 1 = понеділок
    week_of_year  SMALLINT     NOT NULL,
    month_num     SMALLINT     NOT NULL CHECK (month_num BETWEEN 1 AND 12),
    month_name    VARCHAR(20)  NOT NULL,
    quarter_num   SMALLINT     NOT NULL CHECK (quarter_num BETWEEN 1 AND 4),
    year_num      SMALLINT     NOT NULL,
    is_weekend    BOOLEAN      NOT NULL
);

-- ---------- Вимір «Постачальник» ----------
CREATE TABLE dim_supplier (
    supplier_key       SERIAL       PRIMARY KEY,      -- сурогатний ключ сховища
    supplier_code      VARCHAR(20)  NOT NULL UNIQUE,  -- код з облікової системи
    supplier_name      VARCHAR(150) NOT NULL,
    supplier_type      VARCHAR(30)  NOT NULL,         -- виробник / дистриб'ютор / імпортер
    country            VARCHAR(60)  NOT NULL,
    region             VARCHAR(80),
    city               VARCHAR(80),
    payment_terms_days SMALLINT     NOT NULL DEFAULT 0,  -- відстрочка платежу, днів
    contract_start     DATE,
    is_certified       BOOLEAN      NOT NULL DEFAULT FALSE,  -- є сертифікат якості (FSC, ISO)
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------- Вимір «Матеріал» ----------
CREATE TABLE dim_material (
    material_key    SERIAL       PRIMARY KEY,
    material_code   VARCHAR(20)  NOT NULL UNIQUE,
    material_name   VARCHAR(150) NOT NULL,
    material_group  VARCHAR(60)  NOT NULL,   -- фанера / фарби і лаки / пакування / кріплення
    unit_of_measure VARCHAR(10)  NOT NULL,   -- лист, л, шт, кг
    is_critical     BOOLEAN      NOT NULL DEFAULT FALSE  -- без нього виробництво зупиняється
);

-- ---------- Вимір «Склад» ----------
CREATE TABLE dim_warehouse (
    warehouse_key  SERIAL       PRIMARY KEY,
    warehouse_code VARCHAR(20)  NOT NULL UNIQUE,
    warehouse_name VARCHAR(100) NOT NULL,
    city           VARCHAR(80)  NOT NULL
);

-- ---------- Вимір «Менеджер із закупівель» ----------
CREATE TABLE dim_buyer (
    buyer_key   SERIAL       PRIMARY KEY,
    buyer_code  VARCHAR(20)  NOT NULL UNIQUE,
    full_name   VARCHAR(120) NOT NULL,
    department  VARCHAR(80)  NOT NULL
);

-- ---------- Таблиця фактів «Поставка» ----------
-- Зернистість: один рядок = одна позиція замовлення постачальнику (один матеріал в одній поставці)
CREATE TABLE fact_supply (
    supply_key        BIGSERIAL     PRIMARY KEY,
    -- зовнішні ключі на виміри
    order_date_key    INTEGER       NOT NULL REFERENCES dim_date (date_key),      -- дата замовлення
    promised_date_key INTEGER       NOT NULL REFERENCES dim_date (date_key),      -- обіцяна дата поставки
    delivery_date_key INTEGER       REFERENCES dim_date (date_key),               -- фактична дата (NULL = ще не привезли)
    supplier_key      INTEGER       NOT NULL REFERENCES dim_supplier (supplier_key),
    material_key      INTEGER       NOT NULL REFERENCES dim_material (material_key),
    warehouse_key     INTEGER       NOT NULL REFERENCES dim_warehouse (warehouse_key),
    buyer_key         INTEGER       NOT NULL REFERENCES dim_buyer (buyer_key),
    -- вироджений вимір
    po_number         VARCHAR(30)   NOT NULL,         -- номер замовлення постачальнику
    -- міри
    qty_ordered       NUMERIC(12,2) NOT NULL CHECK (qty_ordered > 0),    -- адитивна
    qty_delivered     NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (qty_delivered >= 0),  -- адитивна
    qty_defective     NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (qty_defective >= 0),  -- адитивна
    unit_price        NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),    -- неадитивна
    amount            NUMERIC(14,2) NOT NULL CHECK (amount >= 0),        -- адитивна, грн
    delay_days        INTEGER       NOT NULL DEFAULT 0,                  -- адитивна; > 0 означає запізнення
    is_on_time        BOOLEAN       NOT NULL DEFAULT FALSE,              -- привезли не пізніше обіцяної дати
    is_complete       BOOLEAN       NOT NULL DEFAULT FALSE,              -- привезли всю замовлену кількість
    has_claim         BOOLEAN       NOT NULL DEFAULT FALSE,              -- була рекламація
    CHECK (qty_defective <= qty_delivered)
);

-- Індекси по зовнішніх ключах, щоб з'єднання з вимірами були швидкими
CREATE INDEX ix_fact_supply_supplier ON fact_supply (supplier_key);
CREATE INDEX ix_fact_supply_material ON fact_supply (material_key);
CREATE INDEX ix_fact_supply_order_dt ON fact_supply (order_date_key);
CREATE INDEX ix_fact_supply_deliv_dt ON fact_supply (delivery_date_key);
CREATE INDEX ix_fact_supply_warehouse ON fact_supply (warehouse_key);
CREATE INDEX ix_fact_supply_buyer    ON fact_supply (buyer_key);

COMMENT ON TABLE fact_supply  IS 'Факти поставок: одна позиція замовлення постачальнику';
COMMENT ON TABLE dim_date     IS 'Вимір «Період» (календар)';
COMMENT ON TABLE dim_supplier IS 'Вимір «Постачальник»';
COMMENT ON TABLE dim_material IS 'Вимір «Матеріал»';
COMMENT ON TABLE dim_warehouse IS 'Вимір «Склад»';
COMMENT ON TABLE dim_buyer    IS 'Вимір «Менеджер із закупівель»';
