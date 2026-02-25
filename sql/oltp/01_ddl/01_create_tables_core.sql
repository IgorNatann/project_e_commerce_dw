-- ========================================
-- SCRIPT: 01_create_tables_core.sql
-- OBJETIVO: modelagem fisica OLTP (fase 1)
-- BASE: ECOMMERCE_OLTP
-- ========================================

USE ECOMMERCE_OLTP;
GO

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

PRINT '========================================';
PRINT 'CRIACAO TABELAS OLTP - CORE';
PRINT '========================================';
PRINT '';

-- ========================================
-- 1) DROP (ORDEM DE DEPENDENCIA)
-- ========================================

IF OBJECT_ID('core.order_item_discounts', 'U') IS NOT NULL DROP TABLE core.order_item_discounts;
IF OBJECT_ID('core.order_items', 'U') IS NOT NULL DROP TABLE core.order_items;
IF OBJECT_ID('core.seller_targets_monthly', 'U') IS NOT NULL DROP TABLE core.seller_targets_monthly;
IF OBJECT_ID('core.orders', 'U') IS NOT NULL DROP TABLE core.orders;
IF OBJECT_ID('core.discount_campaigns', 'U') IS NOT NULL DROP TABLE core.discount_campaigns;
IF OBJECT_ID('core.sellers', 'U') IS NOT NULL DROP TABLE core.sellers;
IF OBJECT_ID('core.products', 'U') IS NOT NULL DROP TABLE core.products;
IF OBJECT_ID('core.customers', 'U') IS NOT NULL DROP TABLE core.customers;
IF OBJECT_ID('core.suppliers', 'U') IS NOT NULL DROP TABLE core.suppliers;
IF OBJECT_ID('core.teams', 'U') IS NOT NULL DROP TABLE core.teams;
IF OBJECT_ID('core.regions', 'U') IS NOT NULL DROP TABLE core.regions;
GO

PRINT 'Tabelas antigas removidas (quando existiam).';
PRINT '';

-- ========================================
-- 2) TABELAS DE REFERENCIA
-- ========================================

CREATE TABLE core.regions
(
    region_id BIGINT IDENTITY(1,1) NOT NULL,
    region_code VARCHAR(30) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'Brasil',
    region_name VARCHAR(30) NULL,
    state CHAR(2) NOT NULL,
    state_name VARCHAR(50) NOT NULL,
    city VARCHAR(100) NOT NULL,
    ibge_code VARCHAR(10) NULL,
    is_active BIT NOT NULL DEFAULT 1,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_regions PRIMARY KEY CLUSTERED (region_id),
    CONSTRAINT UQ_core_regions_region_code UNIQUE (region_code),
    CONSTRAINT UQ_core_regions_location UNIQUE (country, state, city),
    CONSTRAINT CK_core_regions_state_len CHECK (LEN(state) = 2)
);
GO

CREATE TABLE core.teams
(
    team_id BIGINT IDENTITY(1,1) NOT NULL,
    team_code VARCHAR(30) NOT NULL,
    team_name VARCHAR(120) NOT NULL,
    team_type VARCHAR(30) NULL,
    team_category VARCHAR(30) NULL,
    region_id BIGINT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_teams PRIMARY KEY CLUSTERED (team_id),
    CONSTRAINT UQ_core_teams_team_code UNIQUE (team_code),
    CONSTRAINT FK_core_teams_region FOREIGN KEY (region_id) REFERENCES core.regions(region_id)
);
GO

CREATE TABLE core.suppliers
(
    supplier_id BIGINT IDENTITY(1,1) NOT NULL,
    supplier_code VARCHAR(30) NOT NULL,
    supplier_name VARCHAR(150) NOT NULL,
    country VARCHAR(50) NULL,
    is_active BIT NOT NULL DEFAULT 1,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_suppliers PRIMARY KEY CLUSTERED (supplier_id),
    CONSTRAINT UQ_core_suppliers_supplier_code UNIQUE (supplier_code)
);
GO

-- ========================================
-- 3) ENTIDADES COMERCIAIS
-- ========================================

CREATE TABLE core.customers
(
    customer_id BIGINT IDENTITY(1,1) NOT NULL,
    customer_code VARCHAR(50) NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(200) NULL,
    phone VARCHAR(30) NULL,
    document_number VARCHAR(20) NULL,
    birth_date DATE NULL,
    gender CHAR(1) NULL,
    customer_type VARCHAR(20) NOT NULL DEFAULT 'Novo',
    segment VARCHAR(20) NOT NULL DEFAULT 'Pessoa Fisica',
    credit_score INT NULL,
    value_category VARCHAR(20) NULL,
    address_line VARCHAR(200) NULL,
    district VARCHAR(80) NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'Brasil',
    zip_code VARCHAR(10) NULL,
    first_signup_date DATE NOT NULL,
    last_purchase_date DATE NULL,
    is_active BIT NOT NULL DEFAULT 1,
    accepts_email_marketing BIT NOT NULL DEFAULT 0,
    is_vip BIT NOT NULL DEFAULT 0,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_customers PRIMARY KEY CLUSTERED (customer_id),
    CONSTRAINT UQ_core_customers_customer_code UNIQUE (customer_code),
    CONSTRAINT CK_core_customers_gender CHECK (gender IN ('M', 'F', 'O') OR gender IS NULL),
    CONSTRAINT CK_core_customers_type CHECK (customer_type IN ('Novo', 'Recorrente', 'VIP', 'Inativo')),
    CONSTRAINT CK_core_customers_segment CHECK (segment IN ('Pessoa Fisica', 'Pessoa Juridica')),
    CONSTRAINT CK_core_customers_state_len CHECK (LEN(state) = 2),
    CONSTRAINT CK_core_customers_credit_score CHECK (credit_score BETWEEN 0 AND 1000 OR credit_score IS NULL),
    CONSTRAINT CK_core_customers_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.products
(
    product_id BIGINT IDENTITY(1,1) NOT NULL,
    product_code VARCHAR(50) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    barcode VARCHAR(20) NULL,
    product_name VARCHAR(200) NOT NULL,
    short_description VARCHAR(255) NULL,
    full_description VARCHAR(MAX) NULL,
    category_name VARCHAR(50) NOT NULL,
    subcategory_name VARCHAR(50) NOT NULL,
    product_line VARCHAR(50) NULL,
    brand VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(100) NULL,
    supplier_id BIGINT NOT NULL,
    country_origin VARCHAR(50) NULL,
    weight_kg DECIMAL(8,3) NULL,
    height_cm DECIMAL(6,2) NULL,
    width_cm DECIMAL(6,2) NULL,
    depth_cm DECIMAL(6,2) NULL,
    color VARCHAR(30) NULL,
    material VARCHAR(50) NULL,
    cost_price DECIMAL(10,2) NOT NULL,
    list_price DECIMAL(10,2) NOT NULL,
    suggested_margin_percent DECIMAL(5,2) NULL,
    is_perishable BIT NOT NULL DEFAULT 0,
    is_fragile BIT NOT NULL DEFAULT 0,
    requires_refrigeration BIT NOT NULL DEFAULT 0,
    minimum_age INT NULL,
    min_stock INT NOT NULL DEFAULT 0,
    max_stock INT NOT NULL DEFAULT 1000,
    reorder_days INT NULL,
    product_status VARCHAR(20) NOT NULL DEFAULT 'Ativo',
    launch_date DATE NULL,
    discontinued_date DATE NULL,
    rating_avg DECIMAL(2,1) NULL,
    rating_count INT NOT NULL DEFAULT 0,
    keywords VARCHAR(200) NULL,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_products PRIMARY KEY CLUSTERED (product_id),
    CONSTRAINT UQ_core_products_product_code UNIQUE (product_code),
    CONSTRAINT UQ_core_products_sku UNIQUE (sku),
    CONSTRAINT FK_core_products_supplier FOREIGN KEY (supplier_id) REFERENCES core.suppliers(supplier_id),
    CONSTRAINT CK_core_products_status CHECK (product_status IN ('Ativo', 'Inativo', 'Descontinuado')),
    CONSTRAINT CK_core_products_cost CHECK (cost_price >= 0),
    CONSTRAINT CK_core_products_price CHECK (list_price >= 0),
    CONSTRAINT CK_core_products_stock CHECK (max_stock >= min_stock),
    CONSTRAINT CK_core_products_rating CHECK (rating_avg BETWEEN 0 AND 5 OR rating_avg IS NULL),
    CONSTRAINT CK_core_products_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.sellers
(
    seller_id BIGINT IDENTITY(1,1) NOT NULL,
    seller_code VARCHAR(50) NOT NULL,
    seller_name VARCHAR(200) NOT NULL,
    team_id BIGINT NULL,
    manager_seller_id BIGINT NULL,
    home_state CHAR(2) NULL,
    home_city VARCHAR(100) NULL,
    monthly_goal_amount DECIMAL(15,2) NULL,
    hire_date DATE NULL,
    seller_status VARCHAR(20) NOT NULL DEFAULT 'Ativo',
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_sellers PRIMARY KEY CLUSTERED (seller_id),
    CONSTRAINT UQ_core_sellers_seller_code UNIQUE (seller_code),
    CONSTRAINT FK_core_sellers_team FOREIGN KEY (team_id) REFERENCES core.teams(team_id),
    CONSTRAINT FK_core_sellers_manager FOREIGN KEY (manager_seller_id) REFERENCES core.sellers(seller_id),
    CONSTRAINT CK_core_sellers_status CHECK (seller_status IN ('Ativo', 'Inativo')),
    CONSTRAINT CK_core_sellers_goal CHECK (monthly_goal_amount >= 0 OR monthly_goal_amount IS NULL),
    CONSTRAINT CK_core_sellers_state_len CHECK (LEN(home_state) = 2 OR home_state IS NULL),
    CONSTRAINT CK_core_sellers_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.discount_campaigns
(
    discount_id BIGINT IDENTITY(1,1) NOT NULL,
    discount_code VARCHAR(50) NOT NULL,
    campaign_name VARCHAR(150) NULL,
    description VARCHAR(500) NULL,
    discount_type VARCHAR(30) NOT NULL,
    discount_method VARCHAR(30) NOT NULL,
    discount_value DECIMAL(10,2) NULL,
    min_order_value DECIMAL(15,2) NULL,
    max_discount_value DECIMAL(15,2) NULL,
    max_uses_per_customer INT NULL,
    max_uses_total INT NULL,
    apply_scope VARCHAR(30) NOT NULL,
    product_restriction VARCHAR(500) NULL,
    start_at DATETIME2(0) NOT NULL,
    end_at DATETIME2(0) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    is_stackable BIT NOT NULL DEFAULT 0,
    approval_required BIT NOT NULL DEFAULT 0,
    current_usage_count INT NOT NULL DEFAULT 0,
    total_revenue_generated DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_discount_given DECIMAL(15,2) NOT NULL DEFAULT 0,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_discount_campaigns PRIMARY KEY CLUSTERED (discount_id),
    CONSTRAINT UQ_core_discount_campaigns_discount_code UNIQUE (discount_code),
    CONSTRAINT CK_core_discount_campaigns_type CHECK (discount_type IN ('Cupom', 'Promocao Automatica', 'Desconto Progressivo', 'Fidelidade', 'Primeira Compra', 'Cashback')),
    CONSTRAINT CK_core_discount_campaigns_method CHECK (discount_method IN ('Percentual', 'Valor Fixo', 'Frete Gratis', 'Brinde', 'Combo')),
    CONSTRAINT CK_core_discount_campaigns_scope CHECK (apply_scope IN ('Pedido Total', 'Produto Especifico', 'Categoria', 'Frete', 'Item Individual')),
    CONSTRAINT CK_core_discount_campaigns_period CHECK (end_at >= start_at),
    CONSTRAINT CK_core_discount_campaigns_values CHECK ((discount_value IS NULL OR discount_value >= 0)
                                                        AND (min_order_value IS NULL OR min_order_value >= 0)
                                                        AND (max_discount_value IS NULL OR max_discount_value >= 0)),
    CONSTRAINT CK_core_discount_campaigns_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.orders
(
    order_id BIGINT IDENTITY(1,1) NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    customer_id BIGINT NOT NULL,
    seller_id BIGINT NULL,
    region_id BIGINT NULL,
    order_status VARCHAR(20) NOT NULL,
    payment_status VARCHAR(20) NULL,
    order_date DATETIME2(0) NOT NULL,
    approved_at DATETIME2(0) NULL,
    shipped_at DATETIME2(0) NULL,
    delivered_at DATETIME2(0) NULL,
    canceled_at DATETIME2(0) NULL,
    sales_channel VARCHAR(30) NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'BRL',
    notes VARCHAR(500) NULL,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_orders PRIMARY KEY CLUSTERED (order_id),
    CONSTRAINT UQ_core_orders_order_number UNIQUE (order_number),
    CONSTRAINT FK_core_orders_customer FOREIGN KEY (customer_id) REFERENCES core.customers(customer_id),
    CONSTRAINT FK_core_orders_seller FOREIGN KEY (seller_id) REFERENCES core.sellers(seller_id),
    CONSTRAINT FK_core_orders_region FOREIGN KEY (region_id) REFERENCES core.regions(region_id),
    CONSTRAINT CK_core_orders_status CHECK (order_status IN ('Pendente', 'Pago', 'Faturado', 'Enviado', 'Entregue', 'Cancelado', 'Devolvido')),
    CONSTRAINT CK_core_orders_currency CHECK (LEN(currency_code) = 3),
    CONSTRAINT CK_core_orders_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.order_items
(
    order_item_id BIGINT IDENTITY(1,1) NOT NULL,
    order_id BIGINT NOT NULL,
    item_number INT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    gross_amount DECIMAL(15,2) NOT NULL,
    discount_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    net_amount DECIMAL(15,2) NOT NULL,
    cost_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    return_quantity INT NOT NULL DEFAULT 0,
    returned_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    commission_percent DECIMAL(5,2) NULL,
    commission_amount DECIMAL(15,2) NULL,
    had_discount BIT NOT NULL DEFAULT 0,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_order_items PRIMARY KEY CLUSTERED (order_item_id),
    CONSTRAINT UQ_core_order_items_order_item UNIQUE (order_id, item_number),
    CONSTRAINT FK_core_order_items_order FOREIGN KEY (order_id) REFERENCES core.orders(order_id),
    CONSTRAINT FK_core_order_items_product FOREIGN KEY (product_id) REFERENCES core.products(product_id),
    CONSTRAINT CK_core_order_items_qty CHECK (quantity > 0),
    CONSTRAINT CK_core_order_items_price CHECK (unit_price >= 0),
    CONSTRAINT CK_core_order_items_amounts CHECK (gross_amount >= 0
                                                  AND discount_amount >= 0
                                                  AND net_amount = gross_amount - discount_amount
                                                  AND discount_amount <= gross_amount
                                                  AND cost_amount >= 0),
    CONSTRAINT CK_core_order_items_returns CHECK (return_quantity >= 0
                                                  AND return_quantity <= quantity
                                                  AND returned_amount >= 0),
    CONSTRAINT CK_core_order_items_commission CHECK ((commission_percent IS NULL OR commission_percent >= 0)
                                                     AND (commission_amount IS NULL OR commission_amount >= 0)),
    CONSTRAINT CK_core_order_items_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.order_item_discounts
(
    order_item_discount_id BIGINT IDENTITY(1,1) NOT NULL,
    order_item_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    discount_id BIGINT NOT NULL,
    application_level VARCHAR(30) NOT NULL,
    discount_amount DECIMAL(15,2) NOT NULL,
    base_amount DECIMAL(15,2) NOT NULL,
    final_amount DECIMAL(15,2) NOT NULL,
    applied_at DATETIME2(0) NOT NULL,
    approved BIT NOT NULL DEFAULT 1,
    rejection_reason VARCHAR(200) NULL,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_order_item_discounts PRIMARY KEY CLUSTERED (order_item_discount_id),
    CONSTRAINT FK_core_order_item_discounts_item FOREIGN KEY (order_item_id) REFERENCES core.order_items(order_item_id),
    CONSTRAINT FK_core_order_item_discounts_order FOREIGN KEY (order_id) REFERENCES core.orders(order_id),
    CONSTRAINT FK_core_order_item_discounts_discount FOREIGN KEY (discount_id) REFERENCES core.discount_campaigns(discount_id),
    CONSTRAINT CK_core_order_item_discounts_level CHECK (application_level IN ('Item', 'Pedido', 'Frete', 'Categoria')),
    CONSTRAINT CK_core_order_item_discounts_values CHECK (discount_amount >= 0
                                                          AND base_amount >= 0
                                                          AND final_amount = base_amount - discount_amount
                                                          AND discount_amount <= base_amount),
    CONSTRAINT CK_core_order_item_discounts_time CHECK (updated_at >= created_at)
);
GO

CREATE TABLE core.seller_targets_monthly
(
    seller_target_id BIGINT IDENTITY(1,1) NOT NULL,
    seller_id BIGINT NOT NULL,
    target_month DATE NOT NULL,
    target_amount DECIMAL(15,2) NOT NULL,
    target_quantity INT NULL,
    realized_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    realized_quantity INT NOT NULL DEFAULT 0,
    period_type VARCHAR(20) NOT NULL DEFAULT 'Mensal',
    period_closed BIT NOT NULL DEFAULT 0,
    created_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    deleted_at DATETIME2(0) NULL,

    CONSTRAINT PK_core_seller_targets_monthly PRIMARY KEY CLUSTERED (seller_target_id),
    CONSTRAINT UQ_core_seller_targets_monthly UNIQUE (seller_id, target_month),
    CONSTRAINT FK_core_seller_targets_monthly_seller FOREIGN KEY (seller_id) REFERENCES core.sellers(seller_id),
    CONSTRAINT CK_core_seller_targets_monthly_values CHECK (target_amount > 0
                                                            AND (target_quantity IS NULL OR target_quantity > 0)
                                                            AND realized_amount >= 0
                                                            AND realized_quantity >= 0),
    CONSTRAINT CK_core_seller_targets_monthly_period CHECK (period_type IN ('Mensal')),
    CONSTRAINT CK_core_seller_targets_monthly_time CHECK (updated_at >= created_at)
);
GO

-- ========================================
-- 4) INDICES DE EXTRACAO INCREMENTAL
-- ========================================

CREATE INDEX IX_core_regions_updated_id ON core.regions(updated_at, region_id);
CREATE INDEX IX_core_teams_updated_id ON core.teams(updated_at, team_id);
CREATE INDEX IX_core_suppliers_updated_id ON core.suppliers(updated_at, supplier_id);
CREATE INDEX IX_core_customers_updated_id ON core.customers(updated_at, customer_id);
CREATE INDEX IX_core_products_updated_id ON core.products(updated_at, product_id);
CREATE INDEX IX_core_sellers_updated_id ON core.sellers(updated_at, seller_id);
CREATE INDEX IX_core_discount_campaigns_updated_id ON core.discount_campaigns(updated_at, discount_id);
CREATE INDEX IX_core_orders_updated_id ON core.orders(updated_at, order_id);
CREATE INDEX IX_core_order_items_updated_id ON core.order_items(updated_at, order_item_id);
CREATE INDEX IX_core_order_item_discounts_updated_id ON core.order_item_discounts(updated_at, order_item_discount_id);
CREATE INDEX IX_core_seller_targets_monthly_updated_id ON core.seller_targets_monthly(updated_at, seller_target_id);
GO

-- ========================================
-- 5) INDICES OPERACIONAIS
-- ========================================

CREATE INDEX IX_core_orders_customer_date ON core.orders(customer_id, order_date);
CREATE INDEX IX_core_orders_seller_date ON core.orders(seller_id, order_date) WHERE seller_id IS NOT NULL;
CREATE INDEX IX_core_orders_region ON core.orders(region_id) WHERE region_id IS NOT NULL;
CREATE INDEX IX_core_order_items_order ON core.order_items(order_id, item_number);
CREATE INDEX IX_core_order_items_product ON core.order_items(product_id);
CREATE INDEX IX_core_order_item_discounts_discount ON core.order_item_discounts(discount_id, applied_at);
CREATE INDEX IX_core_products_status ON core.products(product_status);
CREATE INDEX IX_core_customers_state_city ON core.customers(state, city);
GO

PRINT '';
PRINT '========================================';
PRINT 'OLTP CORE CRIADO COM SUCESSO';
PRINT '========================================';
PRINT 'Tabelas criadas:';
PRINT ' - core.regions';
PRINT ' - core.teams';
PRINT ' - core.suppliers';
PRINT ' - core.customers';
PRINT ' - core.products';
PRINT ' - core.sellers';
PRINT ' - core.discount_campaigns';
PRINT ' - core.orders';
PRINT ' - core.order_items';
PRINT ' - core.order_item_discounts';
PRINT ' - core.seller_targets_monthly';
PRINT '========================================';
GO
