# Діаграма сховища даних (Dimensional Model)

Схема «зірка». У центрі — таблиця фактів `fact_supply`, навколо — п'ять вимірів. Вимір `dim_date` підключено тричі: дата замовлення, обіцяна дата й фактична дата поставки.

```mermaid
erDiagram
    dim_date      ||--o{ fact_supply : "дата замовлення / обіцяна / фактична"
    dim_supplier  ||--o{ fact_supply : "хто постачає"
    dim_material  ||--o{ fact_supply : "що постачає"
    dim_warehouse ||--o{ fact_supply : "куди"
    dim_buyer     ||--o{ fact_supply : "хто замовив"

    fact_supply {
        bigserial supply_key PK
        int order_date_key FK
        int promised_date_key FK
        int delivery_date_key FK
        int supplier_key FK
        int material_key FK
        int warehouse_key FK
        int buyer_key FK
        varchar po_number
        numeric qty_ordered
        numeric qty_delivered
        numeric qty_defective
        numeric unit_price
        numeric amount
        int delay_days
        boolean is_on_time
        boolean is_complete
        boolean has_claim
    }
    dim_date {
        int date_key PK
        date full_date
        smallint day_of_month
        smallint day_of_week
        smallint week_of_year
        smallint month_num
        varchar month_name
        smallint quarter_num
        smallint year_num
        boolean is_weekend
    }
    dim_supplier {
        serial supplier_key PK
        varchar supplier_code
        varchar supplier_name
        varchar supplier_type
        varchar country
        varchar region
        varchar city
        smallint payment_terms_days
        date contract_start
        boolean is_certified
        boolean is_active
    }
    dim_material {
        serial material_key PK
        varchar material_code
        varchar material_name
        varchar material_group
        varchar unit_of_measure
        boolean is_critical
    }
    dim_warehouse {
        serial warehouse_key PK
        varchar warehouse_code
        varchar warehouse_name
        varchar city
    }
    dim_buyer {
        serial buyer_key PK
        varchar buyer_code
        varchar full_name
        varchar department
    }
```

GitHub показує цю діаграму автоматично. Для звіту у Word зробіть знімок екрана або перемалюйте її в draw.io / pgModeler.
