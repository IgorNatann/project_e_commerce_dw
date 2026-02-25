-- ========================================
-- SCRIPT: 02_seed_incremental.sql
-- OBJETIVO: simular onda incremental (insert/update/soft delete)
-- ========================================

USE ECOMMERCE_OLTP;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

DECLARE @wave_code VARCHAR(20) = 'INC001';
DECLARE @wave_ts DATETIME2(0) = DATEADD(MINUTE, 5, SYSUTCDATETIME());
DECLARE @today DATE = CAST(@wave_ts AS DATE);
DECLARE @current_month DATE = DATEFROMPARTS(YEAR(@today), MONTH(@today), 1);

DECLARE @ins_customers INT = 0;
DECLARE @ins_products INT = 0;
DECLARE @ins_orders INT = 0;
DECLARE @ins_order_items INT = 0;
DECLARE @ins_item_discounts INT = 0;
DECLARE @upd_orders INT = 0;
DECLARE @upd_products INT = 0;
DECLARE @upd_customers INT = 0;
DECLARE @soft_del_customers INT = 0;
DECLARE @soft_del_products INT = 0;

PRINT '========================================';
PRINT 'SEED INCREMENTAL OLTP';
PRINT '========================================';
PRINT CONCAT('Lote: ', @wave_code, ' | timestamp de controle: ', CONVERT(VARCHAR(19), @wave_ts, 120));

IF EXISTS
(
    SELECT 1
    FROM core.orders
    WHERE order_number LIKE CONCAT('ORD-', @wave_code, '-%')
)
BEGIN
    PRINT CONCAT('Lote ', @wave_code, ' ja aplicado anteriormente. Nenhuma alteracao nova foi executada.');

    SELECT
        @ins_customers AS inseridos_customers,
        @ins_products AS inseridos_products,
        @ins_orders AS inseridos_orders,
        @ins_order_items AS inseridos_order_items,
        @ins_item_discounts AS inseridos_order_item_discounts,
        @upd_orders AS atualizados_orders,
        @upd_products AS atualizados_products,
        @upd_customers AS atualizados_customers,
        @soft_del_customers AS soft_delete_customers,
        @soft_del_products AS soft_delete_products;

    RETURN;
END;

BEGIN TRY
    BEGIN TRAN;

    DECLARE @regions_count INT = (SELECT COUNT(*) FROM core.regions);
    DECLARE @supplier_count INT = (SELECT COUNT(*) FROM core.suppliers);
    DECLARE @seller_count INT = (SELECT COUNT(*) FROM core.sellers);
    DECLARE @customer_count INT = (SELECT COUNT(*) FROM core.customers);
    DECLARE @product_count INT = (SELECT COUNT(*) FROM core.products);
    DECLARE @discount_count INT = (SELECT COUNT(*) FROM core.discount_campaigns);
    DECLARE @regions_min_id BIGINT = (SELECT MIN(region_id) FROM core.regions);
    DECLARE @supplier_min_id BIGINT = (SELECT MIN(supplier_id) FROM core.suppliers);
    DECLARE @seller_min_id BIGINT = (SELECT MIN(seller_id) FROM core.sellers);
    DECLARE @customer_min_id BIGINT = (SELECT MIN(customer_id) FROM core.customers);
    DECLARE @product_min_id BIGINT = (SELECT MIN(product_id) FROM core.products);
    DECLARE @discount_min_id BIGINT = (SELECT MIN(discount_id) FROM core.discount_campaigns);

    ;WITH n AS
    (
        SELECT TOP (300)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects
    )
    INSERT INTO core.customers
    (
        customer_code,
        full_name,
        email,
        phone,
        document_number,
        birth_date,
        gender,
        customer_type,
        segment,
        credit_score,
        value_category,
        address_line,
        district,
        city,
        state,
        country,
        zip_code,
        first_signup_date,
        last_purchase_date,
        is_active,
        accepts_email_marketing,
        is_vip,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        code.customer_code,
        CONCAT('Cliente Incremental ', RIGHT(code.customer_code, 6)),
        CONCAT(LOWER(code.customer_code), '@mail.com'),
        CONCAT('+55', RIGHT(REPLICATE('0', 11) + CAST(11970000000 + n.n AS VARCHAR(20)), 11)),
        RIGHT('00000000000' + CAST(20000000000 + n.n AS VARCHAR(20)), 11),
        DATEADD(DAY, -(6500 + (n.n % 7000)), @today),
        CASE n.n % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'O' END,
        CASE WHEN n.n % 17 = 0 THEN 'VIP' ELSE 'Novo' END,
        CASE WHEN n.n % 8 = 0 THEN 'Pessoa Juridica' ELSE 'Pessoa Fisica' END,
        450 + (n.n % 450),
        CASE WHEN n.n % 17 = 0 THEN 'Alto Valor' ELSE 'Base' END,
        CONCAT('Avenida Incremental ', n.n),
        CONCAT('Distrito ', n.n % 60),
        r.city,
        r.state,
        'Brasil',
        RIGHT('00000000' + CAST(20000000 + n.n AS VARCHAR(20)), 8),
        DATEADD(DAY, -(n.n % 25), @today),
        DATEADD(DAY, -(n.n % 5), @today),
        1,
        1,
        CASE WHEN n.n % 17 = 0 THEN 1 ELSE 0 END,
        @wave_ts,
        @wave_ts,
        NULL
    FROM n
    CROSS APPLY
    (
        SELECT CONCAT('CUST-', @wave_code, '-', RIGHT(REPLICATE('0', 6) + CAST(n.n AS VARCHAR(10)), 6)) AS customer_code
    ) code
    JOIN core.regions r
        ON r.region_id = @regions_min_id + ((n.n - 1) % @regions_count)
    LEFT JOIN core.customers c
        ON c.customer_code = code.customer_code
    WHERE c.customer_id IS NULL;

    SET @ins_customers = @@ROWCOUNT;
    SET @customer_count = (SELECT COUNT(*) FROM core.customers);

    ;WITH n AS
    (
        SELECT TOP (120)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects
    )
    INSERT INTO core.products
    (
        product_code,
        sku,
        barcode,
        product_name,
        short_description,
        full_description,
        category_name,
        subcategory_name,
        product_line,
        brand,
        manufacturer,
        supplier_id,
        country_origin,
        weight_kg,
        height_cm,
        width_cm,
        depth_cm,
        color,
        material,
        cost_price,
        list_price,
        suggested_margin_percent,
        is_perishable,
        is_fragile,
        requires_refrigeration,
        minimum_age,
        min_stock,
        max_stock,
        reorder_days,
        product_status,
        launch_date,
        discontinued_date,
        rating_avg,
        rating_count,
        keywords,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        code.product_code,
        CONCAT('SKU-', @wave_code, '-', RIGHT(REPLICATE('0', 6) + CAST(n.n AS VARCHAR(10)), 6)),
        RIGHT('0000000000000' + CAST(7900000000000 + n.n AS VARCHAR(20)), 13),
        CONCAT('Produto Incremental ', n.n),
        'Produto inserido em lote incremental',
        'Produto incremental para validacao do ETL por watermark',
        CASE n.n % 4 WHEN 0 THEN 'Eletronicos' WHEN 1 THEN 'Casa' WHEN 2 THEN 'Moda' ELSE 'Informatica' END,
        CONCAT('Subcategoria Inc ', n.n % 15),
        'Linha Incremental',
        CONCAT('Marca Inc ', n.n % 20),
        CONCAT('Fabricante Inc ', n.n % 20),
        @supplier_min_id + ((n.n - 1) % @supplier_count),
        'Brasil',
        CAST(ROUND(0.5 + (n.n / 30.0), 3) AS DECIMAL(8,3)),
        CAST(ROUND(10 + (n.n / 3.0), 2) AS DECIMAL(6,2)),
        CAST(ROUND(10 + (n.n / 3.5), 2) AS DECIMAL(6,2)),
        CAST(ROUND(8 + (n.n / 4.0), 2) AS DECIMAL(6,2)),
        CASE n.n % 3 WHEN 0 THEN 'Preto' WHEN 1 THEN 'Branco' ELSE 'Azul' END,
        CASE n.n % 2 WHEN 0 THEN 'Metal' ELSE 'Plastico' END,
        p.cost_price,
        p.list_price,
        CAST(ROUND(((p.list_price - p.cost_price) / p.list_price) * 100.0, 2) AS DECIMAL(5,2)),
        0,
        CASE WHEN n.n % 15 = 0 THEN 1 ELSE 0 END,
        0,
        NULL,
        10,
        200,
        12,
        'Ativo',
        @today,
        NULL,
        CAST(ROUND((n.n % 45) / 10.0, 1) AS DECIMAL(2,1)),
        20 + (n.n % 120),
        'incremental,etl,watermark',
        @wave_ts,
        @wave_ts,
        NULL
    FROM n
    CROSS APPLY
    (
        SELECT CONCAT('PROD-', @wave_code, '-', RIGHT(REPLICATE('0', 6) + CAST(n.n AS VARCHAR(10)), 6)) AS product_code
    ) code
    CROSS APPLY
    (
        SELECT
            CAST(ROUND(35 + (n.n * 1.9), 2) AS DECIMAL(10,2)) AS cost_price,
            CAST(ROUND((35 + (n.n * 1.9)) * 1.30, 2) AS DECIMAL(10,2)) AS list_price
    ) p
    LEFT JOIN core.products pr
        ON pr.product_code = code.product_code
    WHERE pr.product_id IS NULL;

    SET @ins_products = @@ROWCOUNT;
    SET @product_count = (SELECT COUNT(*) FROM core.products);

    ;WITH n AS
    (
        SELECT TOP (2200)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    )
    INSERT INTO core.orders
    (
        order_number,
        customer_id,
        seller_id,
        region_id,
        order_status,
        payment_status,
        order_date,
        approved_at,
        shipped_at,
        delivered_at,
        canceled_at,
        sales_channel,
        currency_code,
        notes,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        code.order_number,
        @customer_min_id + ((n.n * 29) % @customer_count),
        CASE WHEN n.n % 9 = 0 THEN NULL ELSE @seller_min_id + ((n.n * 7) % @seller_count) END,
        @regions_min_id + ((n.n * 3) % @regions_count),
        st.order_status,
        CASE WHEN st.order_status IN ('Pago', 'Faturado', 'Enviado', 'Entregue') THEN 'Pago' ELSE 'Pendente' END,
        d.order_ts,
        DATEADD(MINUTE, 20, d.order_ts),
        CASE WHEN st.order_status IN ('Enviado', 'Entregue') THEN DATEADD(HOUR, 8, d.order_ts) ELSE NULL END,
        CASE WHEN st.order_status = 'Entregue' THEN DATEADD(DAY, 2, d.order_ts) ELSE NULL END,
        NULL,
        CASE n.n % 3 WHEN 0 THEN 'Site' WHEN 1 THEN 'App' ELSE 'Marketplace' END,
        'BRL',
        CONCAT('Pedido incremental ', @wave_code),
        d.order_ts,
        @wave_ts,
        NULL
    FROM n
    CROSS APPLY
    (
        SELECT CONCAT('ORD-', @wave_code, '-', RIGHT(REPLICATE('0', 7) + CAST(n.n AS VARCHAR(10)), 7)) AS order_number
    ) code
    CROSS APPLY
    (
        SELECT DATEADD(MINUTE, -((n.n * 11) % 43200), @wave_ts) AS order_ts
    ) d
    CROSS APPLY
    (
        SELECT CASE WHEN n.n % 10 IN (0, 1) THEN 'Pago' WHEN n.n % 10 IN (2, 3, 4) THEN 'Faturado' WHEN n.n % 10 IN (5, 6) THEN 'Enviado' ELSE 'Entregue' END AS order_status
    ) st
    LEFT JOIN core.orders o
        ON o.order_number = code.order_number
    WHERE o.order_id IS NULL;

    SET @ins_orders = @@ROWCOUNT;
    ;WITH item_slot AS
    (
        SELECT 1 AS item_number
        UNION ALL SELECT 2
        UNION ALL SELECT 3
    )
    INSERT INTO core.order_items
    (
        order_id,
        item_number,
        product_id,
        quantity,
        unit_price,
        gross_amount,
        discount_amount,
        net_amount,
        cost_amount,
        return_quantity,
        returned_amount,
        commission_percent,
        commission_amount,
        had_discount,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        o.order_id,
        i.item_number,
        @product_min_id + ((o.order_id * 5 + i.item_number * 3) % @product_count),
        q.qty,
        q.unit_price,
        CAST(q.qty * q.unit_price AS DECIMAL(15,2)) AS gross_amount,
        q.discount_amount,
        CAST((q.qty * q.unit_price) - q.discount_amount AS DECIMAL(15,2)) AS net_amount,
        CAST(ROUND(q.qty * p.cost_price, 2) AS DECIMAL(15,2)) AS cost_amount,
        0,
        0,
        CASE WHEN o.seller_id IS NULL THEN NULL ELSE CAST(4.00 AS DECIMAL(5,2)) END,
        CASE WHEN o.seller_id IS NULL THEN NULL ELSE CAST(ROUND(((q.qty * q.unit_price) - q.discount_amount) * 0.04, 2) AS DECIMAL(15,2)) END,
        CASE WHEN q.discount_amount > 0 THEN 1 ELSE 0 END,
        o.created_at,
        @wave_ts,
        NULL
    FROM core.orders o
    JOIN item_slot i
        ON i.item_number <= ((o.order_id % 3) + 1)
    JOIN core.products p
        ON p.product_id = @product_min_id + ((o.order_id * 5 + i.item_number * 3) % @product_count)
    LEFT JOIN core.order_items oi
        ON oi.order_id = o.order_id
       AND oi.item_number = i.item_number
    CROSS APPLY
    (
        SELECT
            1 + ((o.order_id + i.item_number) % 4) AS qty,
            CAST(ROUND(p.list_price * (0.95 + ((o.order_id + i.item_number) % 6) / 100.0), 2) AS DECIMAL(15,2)) AS unit_price,
            CAST(CASE WHEN (o.order_id + i.item_number) % 4 = 0 THEN ROUND((1 + ((o.order_id + i.item_number) % 4)) * p.list_price * 0.07, 2) ELSE 0 END AS DECIMAL(15,2)) AS discount_amount
    ) q
    WHERE o.order_number LIKE CONCAT('ORD-', @wave_code, '-%')
      AND oi.order_item_id IS NULL;

    SET @ins_order_items = @@ROWCOUNT;

    INSERT INTO core.order_item_discounts
    (
        order_item_id,
        order_id,
        discount_id,
        application_level,
        discount_amount,
        base_amount,
        final_amount,
        applied_at,
        approved,
        rejection_reason,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        oi.order_item_id,
        oi.order_id,
        @discount_min_id + ((oi.order_item_id * 11) % @discount_count),
        'Item',
        oi.discount_amount,
        oi.gross_amount,
        oi.net_amount,
        @wave_ts,
        1,
        NULL,
        @wave_ts,
        @wave_ts,
        NULL
    FROM core.order_items oi
    LEFT JOIN core.order_item_discounts od
        ON od.order_item_id = oi.order_item_id
    WHERE oi.discount_amount > 0
      AND od.order_item_discount_id IS NULL;

    SET @ins_item_discounts = @@ROWCOUNT;

    ;WITH target_orders AS
    (
        SELECT TOP (2500)
            order_id,
            order_status,
            approved_at,
            shipped_at,
            delivered_at
        FROM core.orders
        WHERE deleted_at IS NULL
          AND order_status IN ('Pago', 'Faturado', 'Enviado')
        ORDER BY order_id DESC
    )
    UPDATE o
    SET
        o.order_status = CASE
                            WHEN t.order_status = 'Pago' THEN 'Faturado'
                            WHEN t.order_status = 'Faturado' THEN 'Enviado'
                            WHEN t.order_status = 'Enviado' THEN 'Entregue'
                            ELSE t.order_status
                         END,
        o.payment_status = 'Pago',
        o.approved_at = ISNULL(o.approved_at, DATEADD(MINUTE, 20, o.order_date)),
        o.shipped_at = CASE WHEN t.order_status IN ('Faturado', 'Enviado') THEN ISNULL(o.shipped_at, DATEADD(HOUR, 8, o.order_date)) ELSE o.shipped_at END,
        o.delivered_at = CASE WHEN t.order_status = 'Enviado' THEN ISNULL(o.delivered_at, DATEADD(DAY, 2, o.order_date)) ELSE o.delivered_at END,
        o.updated_at = @wave_ts
    FROM core.orders o
    JOIN target_orders t
        ON t.order_id = o.order_id;

    SET @upd_orders = @@ROWCOUNT;

    ;WITH target_products AS
    (
        SELECT TOP (600)
            product_id
        FROM core.products
        WHERE deleted_at IS NULL
          AND product_status = 'Ativo'
        ORDER BY product_id DESC
    )
    UPDATE p
    SET
        p.list_price = CAST(ROUND(p.list_price * 1.03, 2) AS DECIMAL(10,2)),
        p.suggested_margin_percent = CAST(ROUND(((CAST(ROUND(p.list_price * 1.03, 2) AS DECIMAL(10,2)) - p.cost_price) / NULLIF(CAST(ROUND(p.list_price * 1.03, 2) AS DECIMAL(10,2)), 0)) * 100.0, 2) AS DECIMAL(5,2)),
        p.updated_at = @wave_ts
    FROM core.products p
    JOIN target_products t
        ON t.product_id = p.product_id;

    SET @upd_products = @@ROWCOUNT;

    ;WITH target_customers AS
    (
        SELECT TOP (900)
            customer_id
        FROM core.customers
        WHERE deleted_at IS NULL
          AND is_active = 1
        ORDER BY customer_id DESC
    )
    UPDATE c
    SET
        c.accepts_email_marketing = 1,
        c.customer_type = CASE WHEN c.customer_type = 'Novo' THEN 'Recorrente' ELSE c.customer_type END,
        c.updated_at = @wave_ts
    FROM core.customers c
    JOIN target_customers t
        ON t.customer_id = c.customer_id;

    SET @upd_customers = @@ROWCOUNT;

    ;WITH target_soft_delete_customers AS
    (
        SELECT TOP (40)
            customer_id
        FROM core.customers
        WHERE deleted_at IS NULL
          AND is_active = 1
          AND customer_id % 53 = 0
        ORDER BY customer_id
    )
    UPDATE c
    SET
        c.is_active = 0,
        c.customer_type = 'Inativo',
        c.deleted_at = @wave_ts,
        c.updated_at = @wave_ts
    FROM core.customers c
    JOIN target_soft_delete_customers t
        ON t.customer_id = c.customer_id;

    SET @soft_del_customers = @@ROWCOUNT;

    ;WITH target_soft_delete_products AS
    (
        SELECT TOP (30)
            product_id
        FROM core.products
        WHERE deleted_at IS NULL
          AND product_status = 'Ativo'
          AND product_id % 41 = 0
        ORDER BY product_id
    )
    UPDATE p
    SET
        p.product_status = 'Inativo',
        p.deleted_at = @wave_ts,
        p.updated_at = @wave_ts
    FROM core.products p
    JOIN target_soft_delete_products t
        ON t.product_id = p.product_id;

    SET @soft_del_products = @@ROWCOUNT;

    MERGE core.seller_targets_monthly AS tgt
    USING
    (
        SELECT
            s.seller_id,
            CAST(ROUND(ISNULL(s.monthly_goal_amount, 80000) * (0.95 + (s.seller_id % 11) / 100.0), 2) AS DECIMAL(15,2)) AS target_amount,
            140 + (s.seller_id % 120) AS target_quantity,
            CAST(ROUND(ISNULL(s.monthly_goal_amount, 80000) * (0.62 + (s.seller_id % 15) / 100.0), 2) AS DECIMAL(15,2)) AS realized_amount,
            85 + (s.seller_id % 80) AS realized_quantity
        FROM core.sellers s
        WHERE s.seller_status = 'Ativo'
    ) AS src
      ON tgt.seller_id = src.seller_id
     AND tgt.target_month = @current_month
    WHEN MATCHED THEN
        UPDATE SET
            tgt.target_amount = src.target_amount,
            tgt.target_quantity = src.target_quantity,
            tgt.realized_amount = src.realized_amount,
            tgt.realized_quantity = src.realized_quantity,
            tgt.period_closed = 0,
            tgt.updated_at = @wave_ts
    WHEN NOT MATCHED THEN
        INSERT
        (
            seller_id,
            target_month,
            target_amount,
            target_quantity,
            realized_amount,
            realized_quantity,
            period_type,
            period_closed,
            created_at,
            updated_at,
            deleted_at
        )
        VALUES
        (
            src.seller_id,
            @current_month,
            src.target_amount,
            src.target_quantity,
            src.realized_amount,
            src.realized_quantity,
            'Mensal',
            0,
            @wave_ts,
            @wave_ts,
            NULL
        );

    ;WITH disc_agg AS
    (
        SELECT
            discount_id,
            COUNT_BIG(*) AS usage_count,
            CAST(SUM(discount_amount) AS DECIMAL(15,2)) AS total_discount,
            CAST(SUM(final_amount) AS DECIMAL(15,2)) AS total_revenue
        FROM core.order_item_discounts
        GROUP BY discount_id
    )
    UPDATE dc
    SET
        dc.current_usage_count = ISNULL(a.usage_count, 0),
        dc.total_discount_given = ISNULL(a.total_discount, 0),
        dc.total_revenue_generated = ISNULL(a.total_revenue, 0),
        dc.updated_at = @wave_ts
    FROM core.discount_campaigns dc
    LEFT JOIN disc_agg a
        ON a.discount_id = dc.discount_id;

    COMMIT TRAN;

    PRINT '';
    PRINT 'Incremental concluido.';
    SELECT
        @ins_customers AS inseridos_customers,
        @ins_products AS inseridos_products,
        @ins_orders AS inseridos_orders,
        @ins_order_items AS inseridos_order_items,
        @ins_item_discounts AS inseridos_order_item_discounts,
        @upd_orders AS atualizados_orders,
        @upd_products AS atualizados_products,
        @upd_customers AS atualizados_customers,
        @soft_del_customers AS soft_delete_customers,
        @soft_del_products AS soft_delete_products;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @error_line INT = ERROR_LINE();
    DECLARE @error_number INT = ERROR_NUMBER();

    RAISERROR('Falha no seed incremental (linha %d, erro %d): %s', 16, 1, @error_line, @error_number, @error_message);
END CATCH;
GO
