-- ========================================
-- SCRIPT: 01_seed_base.sql
-- OBJETIVO: carga base OLTP (3 anos) para simular extract real
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

DECLARE @customers_target INT = 20000;
DECLARE @products_target INT = 5000;
DECLARE @suppliers_target INT = 80;
DECLARE @sellers_target INT = 300;
DECLARE @discount_target INT = 40;
DECLARE @orders_target INT = 90000;

DECLARE @period_end DATE = DATEADD(DAY, -1, CAST(SYSUTCDATETIME() AS DATE));
DECLARE @period_start DATE = DATEADD(DAY, 1, DATEADD(YEAR, -3, @period_end));
DECLARE @period_days INT = DATEDIFF(DAY, @period_start, @period_end);

PRINT '========================================';
PRINT 'SEED BASE OLTP';
PRINT '========================================';
PRINT CONCAT('Janela historica: ', CONVERT(VARCHAR(10), @period_start, 120), ' a ', CONVERT(VARCHAR(10), @period_end, 120));

BEGIN TRY
    BEGIN TRAN;

    DELETE FROM core.order_item_discounts;
    DELETE FROM core.order_items;
    DELETE FROM core.seller_targets_monthly;
    DELETE FROM core.orders;
    DELETE FROM core.discount_campaigns;
    DELETE FROM core.sellers;
    DELETE FROM core.products;
    DELETE FROM core.customers;
    DELETE FROM core.suppliers;
    DELETE FROM core.teams;
    DELETE FROM core.regions;

    DBCC CHECKIDENT ('core.order_item_discounts', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.order_items', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.seller_targets_monthly', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.orders', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.discount_campaigns', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.sellers', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.products', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.customers', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.suppliers', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.teams', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('core.regions', RESEED, 0) WITH NO_INFOMSGS;

    INSERT INTO core.regions
    (
        region_code,
        country,
        region_name,
        state,
        state_name,
        city,
        ibge_code,
        is_active,
        created_at,
        updated_at,
        deleted_at
    )
    VALUES
    ('RG-SP-SAO', 'Brasil', 'Sudeste', 'SP', 'Sao Paulo', 'Sao Paulo', '3550308', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-SP-CAM', 'Brasil', 'Sudeste', 'SP', 'Sao Paulo', 'Campinas', '3509502', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-RJ-RIO', 'Brasil', 'Sudeste', 'RJ', 'Rio de Janeiro', 'Rio de Janeiro', '3304557', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-MG-BHZ', 'Brasil', 'Sudeste', 'MG', 'Minas Gerais', 'Belo Horizonte', '3106200', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-PR-CTB', 'Brasil', 'Sul', 'PR', 'Parana', 'Curitiba', '4106902', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-RS-POA', 'Brasil', 'Sul', 'RS', 'Rio Grande do Sul', 'Porto Alegre', '4314902', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-SC-FLN', 'Brasil', 'Sul', 'SC', 'Santa Catarina', 'Florianopolis', '4205407', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-BA-SSA', 'Brasil', 'Nordeste', 'BA', 'Bahia', 'Salvador', '2927408', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-PE-REC', 'Brasil', 'Nordeste', 'PE', 'Pernambuco', 'Recife', '2611606', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-CE-FOR', 'Brasil', 'Nordeste', 'CE', 'Ceara', 'Fortaleza', '2304400', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-DF-BSB', 'Brasil', 'Centro-Oeste', 'DF', 'Distrito Federal', 'Brasilia', '5300108', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-GO-GYN', 'Brasil', 'Centro-Oeste', 'GO', 'Goias', 'Goiania', '5208707', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-AM-MAO', 'Brasil', 'Norte', 'AM', 'Amazonas', 'Manaus', '1302603', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-PA-BEL', 'Brasil', 'Norte', 'PA', 'Para', 'Belem', '1501402', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL),
    ('RG-ES-VIX', 'Brasil', 'Sudeste', 'ES', 'Espirito Santo', 'Vitoria', '3205309', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL);

    DECLARE @regions_count INT = (SELECT COUNT(*) FROM core.regions);
    DECLARE @regions_min_id BIGINT = (SELECT MIN(region_id) FROM core.regions);

    ;WITH n AS
    (
        SELECT TOP (12)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects
    )
    INSERT INTO core.teams
    (
        team_code,
        team_name,
        team_type,
        team_category,
        region_id,
        is_active,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        CONCAT('TEAM-', RIGHT('000' + CAST(n.n AS VARCHAR(3)), 3)),
        CONCAT('Time Comercial ', n.n),
        CASE WHEN n.n % 2 = 0 THEN 'Inside Sales' ELSE 'Field Sales' END,
        CASE WHEN n.n % 3 = 0 THEN 'Enterprise' WHEN n.n % 3 = 1 THEN 'SMB' ELSE 'Mid-Market' END,
        @regions_min_id + ((n.n - 1) % @regions_count),
        1,
        SYSUTCDATETIME(),
        SYSUTCDATETIME(),
        NULL
    FROM n;

    DECLARE @teams_count INT = (SELECT COUNT(*) FROM core.teams);
    DECLARE @teams_min_id BIGINT = (SELECT MIN(team_id) FROM core.teams);

    ;WITH n AS
    (
        SELECT TOP (@suppliers_target)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    )
    INSERT INTO core.suppliers
    (
        supplier_code,
        supplier_name,
        country,
        is_active,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        CONCAT('SUP-', RIGHT(REPLICATE('0', 4) + CAST(n.n AS VARCHAR(10)), 4)),
        CONCAT('Fornecedor ', n.n),
        CASE WHEN n.n % 5 = 0 THEN 'China' WHEN n.n % 7 = 0 THEN 'Estados Unidos' ELSE 'Brasil' END,
        CASE WHEN n.n % 29 = 0 THEN 0 ELSE 1 END,
        SYSUTCDATETIME(),
        SYSUTCDATETIME(),
        NULL
    FROM n;

    DECLARE @supplier_count INT = (SELECT COUNT(*) FROM core.suppliers);
    DECLARE @supplier_min_id BIGINT = (SELECT MIN(supplier_id) FROM core.suppliers);
    ;WITH n AS
    (
        SELECT TOP (@customers_target)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
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
        CONCAT('CUST-', RIGHT(REPLICATE('0', 7) + CAST(n.n AS VARCHAR(10)), 7)),
        CONCAT('Cliente ', RIGHT(REPLICATE('0', 7) + CAST(n.n AS VARCHAR(10)), 7)),
        CONCAT('cliente', RIGHT(REPLICATE('0', 7) + CAST(n.n AS VARCHAR(10)), 7), '@mail.com'),
        CONCAT('+55', RIGHT(REPLICATE('0', 11) + CAST(11900000000 + n.n AS VARCHAR(20)), 11)),
        RIGHT('00000000000' + CAST(10000000000 + n.n AS VARCHAR(20)), 11),
        DATEADD(DAY, -(7000 + (n.n % 9000)), @period_start),
        CASE n.n % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'O' END,
        CASE WHEN n.n % 23 = 0 THEN 'VIP' WHEN n.n % 7 = 0 THEN 'Recorrente' ELSE 'Novo' END,
        CASE WHEN n.n % 11 = 0 THEN 'Pessoa Juridica' ELSE 'Pessoa Fisica' END,
        420 + (n.n % 520),
        CASE WHEN n.n % 23 = 0 THEN 'Alto Valor' WHEN n.n % 5 = 0 THEN 'Medio Valor' ELSE 'Base' END,
        CONCAT('Rua ', n.n),
        CONCAT('Bairro ', (n.n % 150) + 1),
        r.city,
        r.state,
        'Brasil',
        RIGHT('00000000' + CAST(10000000 + n.n AS VARCHAR(20)), 8),
        d.signup_date,
        CASE WHEN d.purchase_date >= d.signup_date THEN d.purchase_date ELSE d.signup_date END,
        CASE WHEN n.n % 50 = 0 THEN 0 ELSE 1 END,
        CASE WHEN n.n % 3 = 0 THEN 1 ELSE 0 END,
        CASE WHEN n.n % 23 = 0 THEN 1 ELSE 0 END,
        DATEADD(DAY, -((n.n % 1000) + 1), SYSUTCDATETIME()),
        DATEADD(DAY, -((n.n % 1000) + 1), SYSUTCDATETIME()),
        NULL
    FROM n
    JOIN core.regions r
        ON r.region_id = @regions_min_id + ((n.n - 1) % @regions_count)
    CROSS APPLY
    (
        SELECT
            DATEADD(DAY, -((n.n % 700) + 30), @period_start) AS signup_date,
            DATEADD(DAY, ((n.n * 17) % (@period_days + 1)), @period_start) AS purchase_date
    ) d;

    DECLARE @customer_count INT = (SELECT COUNT(*) FROM core.customers);
    DECLARE @customer_min_id BIGINT = (SELECT MIN(customer_id) FROM core.customers);

    ;WITH n AS
    (
        SELECT TOP (@products_target)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
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
        CONCAT('PROD-', RIGHT(REPLICATE('0', 7) + CAST(n.n AS VARCHAR(10)), 7)),
        CONCAT('SKU-', RIGHT(REPLICATE('0', 7) + CAST(n.n AS VARCHAR(10)), 7)),
        RIGHT('0000000000000' + CAST(7890000000000 + n.n AS VARCHAR(20)), 13),
        CONCAT('Produto ', n.n),
        CONCAT('Descricao curta do produto ', n.n),
        CONCAT('Descricao completa do produto ', n.n),
        CASE n.n % 8
            WHEN 0 THEN 'Eletronicos'
            WHEN 1 THEN 'Casa'
            WHEN 2 THEN 'Moda'
            WHEN 3 THEN 'Esporte'
            WHEN 4 THEN 'Beleza'
            WHEN 5 THEN 'Livros'
            WHEN 6 THEN 'Informatica'
            ELSE 'Brinquedos'
        END,
        CONCAT('Subcategoria ', (n.n % 20) + 1),
        CONCAT('Linha ', (n.n % 10) + 1),
        CONCAT('Marca ', (n.n % 60) + 1),
        CONCAT('Fabricante ', (n.n % 80) + 1),
        @supplier_min_id + ((n.n - 1) % @supplier_count),
        CASE WHEN n.n % 4 = 0 THEN 'Brasil' WHEN n.n % 4 = 1 THEN 'China' WHEN n.n % 4 = 2 THEN 'Estados Unidos' ELSE 'Mexico' END,
        CAST(ROUND(0.20 + ((n.n % 700) / 10.0), 3) AS DECIMAL(8,3)),
        CAST(ROUND(5 + ((n.n % 300) / 3.0), 2) AS DECIMAL(6,2)),
        CAST(ROUND(5 + ((n.n % 250) / 2.5), 2) AS DECIMAL(6,2)),
        CAST(ROUND(3 + ((n.n % 220) / 2.0), 2) AS DECIMAL(6,2)),
        CASE n.n % 6 WHEN 0 THEN 'Preto' WHEN 1 THEN 'Branco' WHEN 2 THEN 'Azul' WHEN 3 THEN 'Vermelho' WHEN 4 THEN 'Verde' ELSE 'Cinza' END,
        CASE WHEN n.n % 3 = 0 THEN 'Plastico' WHEN n.n % 3 = 1 THEN 'Metal' ELSE 'Tecido' END,
        p.cost_price,
        p.list_price,
        CAST(ROUND(((p.list_price - p.cost_price) / NULLIF(p.list_price, 0)) * 100.0, 2) AS DECIMAL(5,2)),
        CASE WHEN n.n % 13 = 0 THEN 1 ELSE 0 END,
        CASE WHEN n.n % 7 = 0 THEN 1 ELSE 0 END,
        CASE WHEN n.n % 19 = 0 THEN 1 ELSE 0 END,
        CASE WHEN n.n % 9 = 0 THEN 18 ELSE NULL END,
        (n.n % 25),
        (n.n % 25) + 120,
        7 + (n.n % 20),
        CASE WHEN n.n % 37 = 0 THEN 'Descontinuado' WHEN n.n % 31 = 0 THEN 'Inativo' ELSE 'Ativo' END,
        DATEADD(DAY, -(1200 - (n.n % 900)), @period_end),
        CASE WHEN n.n % 37 = 0 THEN DATEADD(DAY, -(n.n % 50), @period_end) ELSE NULL END,
        CAST(ROUND((n.n % 50) / 10.0, 1) AS DECIMAL(2,1)),
        10 + (n.n % 500),
        CONCAT('produto-', n.n, ',ecommerce,teste'),
        DATEADD(DAY, -((n.n % 1200) + 10), SYSUTCDATETIME()),
        DATEADD(DAY, -((n.n % 1200) + 10), SYSUTCDATETIME()),
        NULL
    FROM n
    CROSS APPLY
    (
        SELECT
            CAST(ROUND(12 + ((n.n % 2000) / 5.0), 2) AS DECIMAL(10,2)) AS cost_price,
            CAST(ROUND((12 + ((n.n % 2000) / 5.0)) * (1.20 + ((n.n % 25) / 100.0)), 2) AS DECIMAL(10,2)) AS list_price
    ) p;

    DECLARE @product_count INT = (SELECT COUNT(*) FROM core.products);
    DECLARE @product_min_id BIGINT = (SELECT MIN(product_id) FROM core.products);
    ;WITH n AS
    (
        SELECT TOP (@sellers_target)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects
    )
    INSERT INTO core.sellers
    (
        seller_code,
        seller_name,
        team_id,
        manager_seller_id,
        home_state,
        home_city,
        monthly_goal_amount,
        hire_date,
        seller_status,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        CONCAT('SELL-', RIGHT(REPLICATE('0', 5) + CAST(n.n AS VARCHAR(10)), 5)),
        CONCAT('Vendedor ', n.n),
        @teams_min_id + ((n.n - 1) % @teams_count),
        NULL,
        r.state,
        r.city,
        CAST(ROUND(60000 + ((n.n % 120) * 2500), 2) AS DECIMAL(15,2)),
        DATEADD(DAY, -(1500 + (n.n % 2200)), @period_end),
        CASE WHEN n.n % 41 = 0 THEN 'Inativo' ELSE 'Ativo' END,
        DATEADD(DAY, -((n.n % 1100) + 1), SYSUTCDATETIME()),
        DATEADD(DAY, -((n.n % 1100) + 1), SYSUTCDATETIME()),
        NULL
    FROM n
    JOIN core.regions r
        ON r.region_id = @regions_min_id + ((n.n - 1) % @regions_count);

    UPDATE s
    SET s.manager_seller_id = CASE WHEN s.seller_id <= 20 THEN NULL ELSE ((s.seller_id - 1) % 20) + 1 END,
        s.updated_at = SYSUTCDATETIME()
    FROM core.sellers s;

    DECLARE @seller_count INT = (SELECT COUNT(*) FROM core.sellers);
    DECLARE @seller_min_id BIGINT = (SELECT MIN(seller_id) FROM core.sellers);

    ;WITH n AS
    (
        SELECT TOP (@discount_target)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects
    )
    INSERT INTO core.discount_campaigns
    (
        discount_code,
        campaign_name,
        description,
        discount_type,
        discount_method,
        discount_value,
        min_order_value,
        max_discount_value,
        max_uses_per_customer,
        max_uses_total,
        apply_scope,
        product_restriction,
        start_at,
        end_at,
        is_active,
        is_stackable,
        approval_required,
        current_usage_count,
        total_revenue_generated,
        total_discount_given,
        created_at,
        updated_at,
        deleted_at
    )
    SELECT
        CONCAT('DISC-', RIGHT(REPLICATE('0', 4) + CAST(n.n AS VARCHAR(10)), 4)),
        CONCAT('Campanha ', n.n),
        CONCAT('Campanha promocional ', n.n),
        CASE n.n % 6
            WHEN 0 THEN 'Cupom'
            WHEN 1 THEN 'Promocao Automatica'
            WHEN 2 THEN 'Desconto Progressivo'
            WHEN 3 THEN 'Fidelidade'
            WHEN 4 THEN 'Primeira Compra'
            ELSE 'Cashback'
        END,
        CASE n.n % 5
            WHEN 0 THEN 'Percentual'
            WHEN 1 THEN 'Valor Fixo'
            WHEN 2 THEN 'Frete Gratis'
            WHEN 3 THEN 'Brinde'
            ELSE 'Combo'
        END,
        CAST(ROUND(5 + (n.n % 30), 2) AS DECIMAL(10,2)),
        CAST(ROUND(80 + ((n.n % 40) * 15), 2) AS DECIMAL(15,2)),
        CAST(ROUND(120 + ((n.n % 60) * 25), 2) AS DECIMAL(15,2)),
        1 + (n.n % 5),
        1000 + (n.n * 200),
        CASE n.n % 5
            WHEN 0 THEN 'Pedido Total'
            WHEN 1 THEN 'Produto Especifico'
            WHEN 2 THEN 'Categoria'
            WHEN 3 THEN 'Frete'
            ELSE 'Item Individual'
        END,
        CASE WHEN n.n % 2 = 0 THEN 'Sem restricao' ELSE 'Categorias prioritarias' END,
        DATEADD(DAY, (n.n * 23) % (@period_days + 1), CAST(@period_start AS DATETIME2(0))),
        DATEADD(DAY, 45 + (n.n % 120), DATEADD(DAY, (n.n * 23) % (@period_days + 1), CAST(@period_start AS DATETIME2(0)))),
        1,
        CASE WHEN n.n % 4 = 0 THEN 1 ELSE 0 END,
        CASE WHEN n.n % 10 = 0 THEN 1 ELSE 0 END,
        0,
        0,
        0,
        SYSUTCDATETIME(),
        SYSUTCDATETIME(),
        NULL
    FROM n;

    DECLARE @discount_count INT = (SELECT COUNT(*) FROM core.discount_campaigns);
    DECLARE @discount_min_id BIGINT = (SELECT MIN(discount_id) FROM core.discount_campaigns);

    ;WITH n AS
    (
        SELECT TOP (@orders_target)
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
        CONCAT('ORD-', RIGHT(REPLICATE('0', 9) + CAST(n.n AS VARCHAR(10)), 9)),
        @customer_min_id + ((n.n * 17) % @customer_count),
        CASE WHEN n.n % 10 = 0 THEN NULL ELSE @seller_min_id + ((n.n * 19) % @seller_count) END,
        CASE WHEN n.n % 25 = 0 THEN NULL ELSE @regions_min_id + ((n.n * 7) % @regions_count) END,
        s.order_status,
        s.payment_status,
        d.order_ts,
        s.approved_at,
        s.shipped_at,
        s.delivered_at,
        s.canceled_at,
        CASE n.n % 4 WHEN 0 THEN 'Site' WHEN 1 THEN 'App' WHEN 2 THEN 'Marketplace' ELSE 'Televendas' END,
        'BRL',
        CONCAT('Pedido gerado automaticamente #', n.n),
        d.order_ts,
        COALESCE(s.delivered_at, s.canceled_at, s.shipped_at, s.approved_at, d.order_ts),
        NULL
    FROM n
    CROSS APPLY
    (
        SELECT DATEADD(SECOND, (n.n * 97) % 86400, CAST(DATEADD(DAY, (n.n * 13) % (@period_days + 1), @period_start) AS DATETIME2(0))) AS order_ts
    ) d
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN n.n % 100 BETWEEN 0 AND 2 THEN 'Cancelado'
                WHEN n.n % 100 BETWEEN 3 AND 6 THEN 'Devolvido'
                WHEN n.n % 100 BETWEEN 7 AND 14 THEN 'Enviado'
                WHEN n.n % 100 BETWEEN 15 AND 56 THEN 'Entregue'
                WHEN n.n % 100 BETWEEN 57 AND 75 THEN 'Faturado'
                WHEN n.n % 100 BETWEEN 76 AND 90 THEN 'Pago'
                ELSE 'Pendente'
            END AS order_status
    ) st
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN st.order_status IN ('Pago', 'Faturado', 'Enviado', 'Entregue', 'Devolvido') THEN 'Pago'
                WHEN st.order_status = 'Cancelado' THEN 'Estornado'
                ELSE 'Pendente'
            END AS payment_status,
            CASE WHEN st.order_status = 'Pendente' THEN NULL ELSE DATEADD(HOUR, 1, d.order_ts) END AS approved_at,
            CASE WHEN st.order_status IN ('Enviado', 'Entregue', 'Devolvido') THEN DATEADD(HOUR, 18, d.order_ts) ELSE NULL END AS shipped_at,
            CASE WHEN st.order_status IN ('Entregue', 'Devolvido') THEN DATEADD(DAY, 4, d.order_ts) ELSE NULL END AS delivered_at,
            CASE WHEN st.order_status = 'Cancelado' THEN DATEADD(HOUR, 6, d.order_ts) ELSE NULL END AS canceled_at,
            st.order_status
    ) s;
    ;WITH item_slot AS
    (
        SELECT 1 AS item_number
        UNION ALL SELECT 2
        UNION ALL SELECT 3
        UNION ALL SELECT 4
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
        @product_min_id + ((o.order_id * 13 + i.item_number * 17) % @product_count),
        a.qty,
        a.unit_price,
        a.gross_amount,
        a.discount_amount,
        a.net_amount,
        a.cost_amount,
        CASE WHEN o.order_status = 'Devolvido' AND i.item_number = 1 THEN 1 ELSE 0 END,
        CASE WHEN o.order_status = 'Devolvido' AND i.item_number = 1 THEN a.unit_price ELSE 0 END,
        CASE WHEN o.seller_id IS NULL THEN NULL ELSE CAST(3.50 + ((o.order_id + i.item_number) % 4) AS DECIMAL(5,2)) END,
        CASE WHEN o.seller_id IS NULL THEN NULL ELSE CAST(ROUND(a.net_amount * (3.50 + ((o.order_id + i.item_number) % 4)) / 100.0, 2) AS DECIMAL(15,2)) END,
        CASE WHEN a.discount_amount > 0 THEN 1 ELSE 0 END,
        o.created_at,
        DATEADD(MINUTE, (o.order_id + i.item_number) % 45, o.updated_at),
        NULL
    FROM core.orders o
    JOIN item_slot i
        ON i.item_number <= ((o.order_id % 4) + 1)
    JOIN core.products p
        ON p.product_id = @product_min_id + ((o.order_id * 13 + i.item_number * 17) % @product_count)
    CROSS APPLY
    (
        SELECT
            1 + ((o.order_id + i.item_number) % 5) AS qty,
            CAST(ROUND(p.list_price * (0.90 + ((o.order_id + i.item_number) % 11) / 100.0), 2) AS DECIMAL(15,2)) AS unit_price
    ) q
    CROSS APPLY
    (
        SELECT
            q.qty,
            q.unit_price,
            CAST(q.qty * q.unit_price AS DECIMAL(15,2)) AS gross_amount,
            CAST(CASE WHEN (o.order_id + i.item_number) % 5 = 0 THEN ROUND((q.qty * q.unit_price) * 0.10, 2) ELSE 0 END AS DECIMAL(15,2)) AS discount_amount,
            CAST((q.qty * q.unit_price) - CASE WHEN (o.order_id + i.item_number) % 5 = 0 THEN ROUND((q.qty * q.unit_price) * 0.10, 2) ELSE 0 END AS DECIMAL(15,2)) AS net_amount,
            CAST(ROUND(q.qty * p.cost_price, 2) AS DECIMAL(15,2)) AS cost_amount
    ) a;

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
        @discount_min_id + ((oi.order_item_id * 7) % @discount_count),
        'Item',
        oi.discount_amount,
        oi.gross_amount,
        oi.net_amount,
        DATEADD(MINUTE, 5, o.order_date),
        1,
        NULL,
        oi.created_at,
        oi.updated_at,
        NULL
    FROM core.order_items oi
    JOIN core.orders o
        ON o.order_id = oi.order_id
    WHERE oi.discount_amount > 0;

    ;WITH months AS
    (
        SELECT DATEFROMPARTS(YEAR(@period_start), MONTH(@period_start), 1) AS target_month
        UNION ALL
        SELECT DATEADD(MONTH, 1, target_month)
        FROM months
        WHERE target_month < DATEFROMPARTS(YEAR(@period_end), MONTH(@period_end), 1)
    )
    INSERT INTO core.seller_targets_monthly
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
    SELECT
        s.seller_id,
        m.target_month,
        CAST(ROUND(ISNULL(s.monthly_goal_amount, 80000) * (0.85 + ((s.seller_id + MONTH(m.target_month)) % 35) / 100.0), 2) AS DECIMAL(15,2)),
        120 + ((s.seller_id + MONTH(m.target_month)) % 220),
        CAST(ROUND(ISNULL(s.monthly_goal_amount, 80000) * (0.70 + ((s.seller_id + (MONTH(m.target_month) * 2)) % 55) / 100.0), 2) AS DECIMAL(15,2)),
        90 + ((s.seller_id + (MONTH(m.target_month) * 3)) % 200),
        'Mensal',
        CASE WHEN m.target_month < DATEFROMPARTS(YEAR(@period_end), MONTH(@period_end), 1) THEN 1 ELSE 0 END,
        DATEADD(DAY, 1, m.target_month),
        DATEADD(DAY, 15, m.target_month),
        NULL
    FROM core.sellers s
    CROSS JOIN months m
    OPTION (MAXRECURSION 400);

    ;WITH disc_agg AS
    (
        SELECT
            d.discount_id,
            COUNT_BIG(*) AS usage_count,
            CAST(SUM(oid.discount_amount) AS DECIMAL(15,2)) AS total_discount,
            CAST(SUM(oid.final_amount) AS DECIMAL(15,2)) AS total_revenue
        FROM core.order_item_discounts oid
        JOIN core.discount_campaigns d
            ON d.discount_id = oid.discount_id
        GROUP BY d.discount_id
    )
    UPDATE dc
    SET
        dc.current_usage_count = ISNULL(a.usage_count, 0),
        dc.total_discount_given = ISNULL(a.total_discount, 0),
        dc.total_revenue_generated = ISNULL(a.total_revenue, 0),
        dc.is_active = CASE WHEN dc.end_at >= SYSUTCDATETIME() THEN 1 ELSE 0 END,
        dc.updated_at = SYSUTCDATETIME()
    FROM core.discount_campaigns dc
    LEFT JOIN disc_agg a
        ON a.discount_id = dc.discount_id;

    COMMIT TRAN;

    PRINT '';
    PRINT 'Carga base concluida com sucesso.';
    PRINT 'Resumo de volumes:';

    SELECT 'core.regions' AS tabela, COUNT(*) AS total_linhas FROM core.regions
    UNION ALL SELECT 'core.teams', COUNT(*) FROM core.teams
    UNION ALL SELECT 'core.suppliers', COUNT(*) FROM core.suppliers
    UNION ALL SELECT 'core.customers', COUNT(*) FROM core.customers
    UNION ALL SELECT 'core.products', COUNT(*) FROM core.products
    UNION ALL SELECT 'core.sellers', COUNT(*) FROM core.sellers
    UNION ALL SELECT 'core.discount_campaigns', COUNT(*) FROM core.discount_campaigns
    UNION ALL SELECT 'core.orders', COUNT(*) FROM core.orders
    UNION ALL SELECT 'core.order_items', COUNT(*) FROM core.order_items
    UNION ALL SELECT 'core.order_item_discounts', COUNT(*) FROM core.order_item_discounts
    UNION ALL SELECT 'core.seller_targets_monthly', COUNT(*) FROM core.seller_targets_monthly;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @error_line INT = ERROR_LINE();
    DECLARE @error_number INT = ERROR_NUMBER();

    RAISERROR('Falha no seed base (linha %d, erro %d): %s', 16, 1, @error_line, @error_number, @error_message);
END CATCH;
GO
