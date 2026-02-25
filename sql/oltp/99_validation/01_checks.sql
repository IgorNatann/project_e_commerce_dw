-- ========================================
-- SCRIPT: 01_checks.sql
-- OBJETIVO: validacoes de qualidade OLTP para extracao incremental
-- ========================================

USE ECOMMERCE_OLTP;
GO

SET NOCOUNT ON;
GO

DECLARE @results TABLE
(
    check_order INT,
    check_name VARCHAR(120),
    status VARCHAR(10),
    details VARCHAR(400)
);

PRINT '========================================';
PRINT 'CHECKS OLTP - QUALIDADE DE EXTRACAO';
PRINT '========================================';

;WITH volume AS
(
    SELECT 'core.regions' AS table_name, COUNT(*) AS total FROM core.regions
    UNION ALL SELECT 'core.teams', COUNT(*) FROM core.teams
    UNION ALL SELECT 'core.suppliers', COUNT(*) FROM core.suppliers
    UNION ALL SELECT 'core.customers', COUNT(*) FROM core.customers
    UNION ALL SELECT 'core.products', COUNT(*) FROM core.products
    UNION ALL SELECT 'core.sellers', COUNT(*) FROM core.sellers
    UNION ALL SELECT 'core.discount_campaigns', COUNT(*) FROM core.discount_campaigns
    UNION ALL SELECT 'core.orders', COUNT(*) FROM core.orders
    UNION ALL SELECT 'core.order_items', COUNT(*) FROM core.order_items
    UNION ALL SELECT 'core.order_item_discounts', COUNT(*) FROM core.order_item_discounts
    UNION ALL SELECT 'core.seller_targets_monthly', COUNT(*) FROM core.seller_targets_monthly
)
INSERT INTO @results (check_order, check_name, status, details)
SELECT
    10,
    CONCAT('volume_', table_name),
    CASE WHEN total > 0 THEN 'PASS' ELSE 'FAIL' END,
    CONCAT('linhas=', total)
FROM volume;

INSERT INTO @results (check_order, check_name, status, details)
SELECT
    20,
    'volume_minimo_orders',
    CASE WHEN COUNT(*) >= 50000 THEN 'PASS' ELSE 'WARN' END,
    CONCAT('orders=', COUNT(*), ' | meta_referencial>=50000')
FROM core.orders;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 30, 'nulos_updated_at_customers', CASE WHEN SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('nulos=', SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END)) FROM core.customers
UNION ALL
SELECT 30, 'nulos_updated_at_products', CASE WHEN SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('nulos=', SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END)) FROM core.products
UNION ALL
SELECT 30, 'nulos_updated_at_orders', CASE WHEN SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('nulos=', SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END)) FROM core.orders
UNION ALL
SELECT 30, 'nulos_updated_at_order_items', CASE WHEN SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('nulos=', SUM(CASE WHEN updated_at IS NULL THEN 1 ELSE 0 END)) FROM core.order_items;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 40, 'duplicidade_customer_code', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('duplicados=', COUNT(*))
FROM (SELECT customer_code FROM core.customers GROUP BY customer_code HAVING COUNT(*) > 1) d
UNION ALL
SELECT 40, 'duplicidade_product_code', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('duplicados=', COUNT(*))
FROM (SELECT product_code FROM core.products GROUP BY product_code HAVING COUNT(*) > 1) d
UNION ALL
SELECT 40, 'duplicidade_sku', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('duplicados=', COUNT(*))
FROM (SELECT sku FROM core.products GROUP BY sku HAVING COUNT(*) > 1) d
UNION ALL
SELECT 40, 'duplicidade_order_number', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('duplicados=', COUNT(*))
FROM (SELECT order_number FROM core.orders GROUP BY order_number HAVING COUNT(*) > 1) d
UNION ALL
SELECT 40, 'duplicidade_order_item', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('duplicados=', COUNT(*))
FROM (SELECT order_id, item_number FROM core.order_items GROUP BY order_id, item_number HAVING COUNT(*) > 1) d
UNION ALL
SELECT 40, 'duplicidade_target_seller_mes', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('duplicados=', COUNT(*))
FROM (SELECT seller_id, target_month FROM core.seller_targets_monthly GROUP BY seller_id, target_month HAVING COUNT(*) > 1) d;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 50, 'orfao_orders_customer', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('orfandade=', COUNT(*))
FROM core.orders o
LEFT JOIN core.customers c
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 50, 'orfao_order_items_order', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('orfandade=', COUNT(*))
FROM core.order_items oi
LEFT JOIN core.orders o
    ON o.order_id = oi.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 50, 'orfao_order_items_product', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('orfandade=', COUNT(*))
FROM core.order_items oi
LEFT JOIN core.products p
    ON p.product_id = oi.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 50, 'orfao_item_discounts_item', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('orfandade=', COUNT(*))
FROM core.order_item_discounts oid
LEFT JOIN core.order_items oi
    ON oi.order_item_id = oid.order_item_id
WHERE oi.order_item_id IS NULL;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 60, 'regra_order_items_net_amount', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.order_items
WHERE net_amount <> gross_amount - discount_amount
UNION ALL
SELECT 60, 'regra_order_items_discount_gt_gross', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.order_items
WHERE discount_amount > gross_amount
UNION ALL
SELECT 60, 'regra_item_discounts_final_amount', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.order_item_discounts
WHERE final_amount <> base_amount - discount_amount;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 70, 'temporal_customers_updated_ge_created', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.customers
WHERE updated_at < created_at
UNION ALL
SELECT 70, 'temporal_products_updated_ge_created', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.products
WHERE updated_at < created_at
UNION ALL
SELECT 70, 'temporal_orders_updated_ge_created', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.orders
WHERE updated_at < created_at
UNION ALL
SELECT 70, 'temporal_order_items_updated_ge_created', CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('inconsistentes=', COUNT(*))
FROM core.order_items
WHERE updated_at < created_at;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 80, 'janela_incremental_orders',
       CASE WHEN DATEDIFF(DAY, MIN(updated_at), MAX(updated_at)) >= 30 THEN 'PASS' ELSE 'WARN' END,
       CONCAT('min=', CONVERT(VARCHAR(19), MIN(updated_at), 120), ' | max=', CONVERT(VARCHAR(19), MAX(updated_at), 120))
FROM core.orders
UNION ALL
SELECT 80, 'janela_incremental_products',
       CASE WHEN DATEDIFF(DAY, MIN(updated_at), MAX(updated_at)) >= 30 THEN 'PASS' ELSE 'WARN' END,
       CONCAT('min=', CONVERT(VARCHAR(19), MIN(updated_at), 120), ' | max=', CONVERT(VARCHAR(19), MAX(updated_at), 120))
FROM core.products
UNION ALL
SELECT 80, 'janela_incremental_customers',
       CASE WHEN DATEDIFF(DAY, MIN(updated_at), MAX(updated_at)) >= 30 THEN 'PASS' ELSE 'WARN' END,
       CONCAT('min=', CONVERT(VARCHAR(19), MIN(updated_at), 120), ' | max=', CONVERT(VARCHAR(19), MAX(updated_at), 120))
FROM core.customers;

INSERT INTO @results (check_order, check_name, status, details)
SELECT 90, 'soft_delete_customers_consistencia',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       CONCAT('inconsistentes=', COUNT(*))
FROM core.customers
WHERE deleted_at IS NOT NULL
  AND is_active = 1
UNION ALL
SELECT 90, 'soft_delete_products_consistencia',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       CONCAT('inconsistentes=', COUNT(*))
FROM core.products
WHERE deleted_at IS NOT NULL
  AND product_status = 'Ativo';

SELECT
    check_order,
    check_name,
    status,
    details
FROM @results
ORDER BY check_order, check_name;

SELECT
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS total_pass,
    SUM(CASE WHEN status = 'WARN' THEN 1 ELSE 0 END) AS total_warn,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS total_fail
FROM @results;

IF EXISTS (SELECT 1 FROM @results WHERE status = 'FAIL')
BEGIN
    THROW 51000, 'Checks OLTP com falhas bloqueantes. Corrija antes de seguir para ETL.', 1;
END;
GO
