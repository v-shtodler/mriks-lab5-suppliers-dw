-- ЛР5 МРІКС. Прості перевірки даних. У кожній має вийти 0.

-- 1. Привезено більше, ніж замовлено
SELECT COUNT(*) AS errors FROM fact_supply WHERE qty_delivered > qty_ordered;

-- 2. Браку більше, ніж привезено
SELECT COUNT(*) AS errors FROM fact_supply WHERE qty_defective > qty_delivered;

-- 3. Від'ємне запізнення
SELECT COUNT(*) AS errors FROM fact_supply WHERE delay_days < 0;

-- 4. Сума не дорівнює кількість × ціна
SELECT COUNT(*) AS errors FROM fact_supply WHERE amount <> qty_delivered * unit_price;
