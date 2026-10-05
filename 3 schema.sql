-- =============================================================
-- E-commerce database schema
-- Logical and physical structure with PostgreSQL types, constraints,
-- foreign keys, indexes, views, and partitioning plan.
-- =============================================================

DROP SCHEMA IF EXISTS ecommerce CASCADE;
CREATE SCHEMA ecommerce;

SET search_path TO ecommerce;

-- =============================================================
-- 1. categories
-- =============================================================
CREATE TABLE categories (
    category_id      SERIAL PRIMARY KEY,
    parent_category_id BIGINT NULL,
    name             VARCHAR(100) NOT NULL,
    slug             VARCHAR(120) NOT NULL UNIQUE,
    description      TEXT,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_categories_parent_category_id ON categories(parent_category_id);
CREATE INDEX idx_categories_name ON categories(name);

-- =============================================================
-- 2. customers
-- =============================================================
CREATE TABLE customers (
    customer_id      BIGSERIAL PRIMARY KEY,
    first_name       VARCHAR(50) NOT NULL,
    last_name        VARCHAR(50) NOT NULL,
    email            VARCHAR(255) NOT NULL UNIQUE,
    phone            VARCHAR(20),
    password_hash    VARCHAR(255) NOT NULL,
    birth_date       DATE,
    gender           CHAR(1),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_customer_gender
        CHECK (gender IS NULL OR gender IN ('M', 'F', 'O')),
    CONSTRAINT chk_customer_phone_format
        CHECK (phone IS NULL OR phone ~ '^\+?[0-9()\-\s]{7,20}$')
);

CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_last_name ON customers(last_name);

-- =============================================================
-- 3. products
-- =============================================================
CREATE TABLE products (
    product_id       BIGSERIAL PRIMARY KEY,
    category_id      BIGINT NOT NULL,
    sku              VARCHAR(64) NOT NULL UNIQUE,
    name             VARCHAR(200) NOT NULL,
    short_description VARCHAR(500),
    description      TEXT,
    price            NUMERIC(12,2) NOT NULL,
    cost_price       NUMERIC(12,2) NOT NULL,
    stock_quantity   INTEGER NOT NULL DEFAULT 0,
    weight_kg        NUMERIC(8,3),
    is_published     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_products_price_nonnegative
        CHECK (price >= 0),
    CONSTRAINT chk_products_cost_nonnegative
        CHECK (cost_price >= 0),
    CONSTRAINT chk_products_stock_nonnegative
        CHECK (stock_quantity >= 0),
    CONSTRAINT chk_products_weight_nonnegative
        CHECK (weight_kg IS NULL OR weight_kg >= 0)
);

CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_is_published ON products(is_published);

-- =============================================================
-- 4. orders
-- =============================================================
CREATE TYPE order_status AS ENUM (
    'pending',
    'paid',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
    'refunded'
);

CREATE TABLE orders (
    order_id         BIGSERIAL PRIMARY KEY,
    customer_id      BIGINT NOT NULL,
    order_number     VARCHAR(32) NOT NULL UNIQUE,
    status           order_status NOT NULL DEFAULT 'pending',
    subtotal         NUMERIC(14,2) NOT NULL DEFAULT 0,
    discount_amount  NUMERIC(14,2) NOT NULL DEFAULT 0,
    shipping_cost    NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_amount     NUMERIC(14,2) NOT NULL DEFAULT 0,
    currency         CHAR(3) NOT NULL DEFAULT 'RUB',
    shipping_address VARCHAR(500) NOT NULL,
    billing_address  VARCHAR(500),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_orders_amounts_nonnegative
        CHECK (subtotal >= 0 AND discount_amount >= 0 AND shipping_cost >= 0 AND total_amount >= 0),
    CONSTRAINT chk_orders_currency_code
        CHECK (currency = UPPER(currency))
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_orders_order_number ON orders(order_number);

-- =============================================================
-- 5. order_items
-- =============================================================
CREATE TABLE order_items (
    order_item_id    BIGSERIAL PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    product_id       BIGINT NOT NULL,
    quantity         INTEGER NOT NULL,
    unit_price       NUMERIC(12,2) NOT NULL,
    discount_amount  NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_price      NUMERIC(14,2) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_order_items_quantity_positive
        CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price_nonnegative
        CHECK (unit_price >= 0),
    CONSTRAINT chk_order_items_discount_nonnegative
        CHECK (discount_amount >= 0),
    CONSTRAINT chk_order_items_total_nonnegative
        CHECK (total_price >= 0)
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- =============================================================
-- 6. payments
-- =============================================================
CREATE TYPE payment_status AS ENUM ('pending', 'authorized', 'captured', 'failed', 'refunded', 'cancelled');
CREATE TYPE payment_method AS ENUM ('card', 'bank_transfer', 'cash', 'wallet', 'crypto');

CREATE TABLE payments (
    payment_id       BIGSERIAL PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    payment_method   payment_method NOT NULL,
    status           payment_status NOT NULL DEFAULT 'pending',
    amount           NUMERIC(14,2) NOT NULL,
    transaction_ref  VARCHAR(128),
    paid_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_payments_amount_nonnegative
        CHECK (amount >= 0)
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_paid_at ON payments(paid_at);

-- =============================================================
-- 7. addresses
-- =============================================================
CREATE TABLE addresses (
    address_id       BIGSERIAL PRIMARY KEY,
    customer_id      BIGINT NOT NULL,
    country          VARCHAR(60) NOT NULL,
    region           VARCHAR(100),
    city             VARCHAR(100) NOT NULL,
    postal_code      VARCHAR(20),
    street           VARCHAR(200) NOT NULL,
    house_number     VARCHAR(20) NOT NULL,
    apartment_number VARCHAR(20),
    address_type     VARCHAR(20) NOT NULL DEFAULT 'shipping',
    is_default       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_addresses_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_address_type
        CHECK (address_type IN ('shipping', 'billing', 'both'))
);

CREATE INDEX idx_addresses_customer_id ON addresses(customer_id);
CREATE INDEX idx_addresses_city ON addresses(city);

-- =============================================================
-- =============================================================
-- Sample data for validation
-- =============================================================
-- =============================================================

INSERT INTO categories (parent_category_id, name, slug, description, is_active)
VALUES
    (NULL, 'Электроника', 'electronics', 'Техника и гаджеты', TRUE),
    (NULL, 'Одежда', 'clothing', 'Одежда и аксессуары', TRUE),
    (1, 'Смартфоны', 'smartphones', 'Мобильные телефоны', TRUE),
    (1, 'Ноутбуки', 'laptops', 'Портативные компьютеры', TRUE),
    (2, 'Мужская одежда', 'mens-clothing', 'Мужская одежда', TRUE);

INSERT INTO customers (first_name, last_name, email, phone, password_hash, birth_date, gender, is_active)
VALUES
    ('Иван', 'Иванов', 'ivan.ivanov@example.com', '+79001234567', 'hash_1', '1990-05-12', 'M', TRUE),
    ('Мария', 'Петрова', 'maria.petrova@example.com', '+79007654321', 'hash_2', '1992-08-20', 'F', TRUE),
    ('Алексей', 'Сидоров', 'alex.sidorov@example.com', '+79009876543', 'hash_3', '1988-02-11', 'M', TRUE);

INSERT INTO products (category_id, sku, name, short_description, description, price, cost_price, stock_quantity, weight_kg, is_published)
VALUES
    (3, 'SKU-1001', 'Samsung Galaxy S24', 'Флагманский смартфон', 'Смартфон с AMOLED экраном и камерой 50 МП', 79990.00, 52000.00, 25, 0.170, TRUE),
    (4, 'SKU-2001', 'Lenovo ThinkPad X1', 'Бизнес-ноутбук', 'Лёгкий ноутбук для работы и путешествий', 149990.00, 98000.00, 12, 1.350, TRUE),
    (5, 'SKU-3001', 'Куртка зимняя', 'Тёплая куртка', 'Утеплённая куртка для холодного сезона', 6990.00, 4100.00, 40, 0.800, TRUE);

INSERT INTO orders (customer_id, order_number, status, subtotal, discount_amount, shipping_cost, total_amount, currency, shipping_address, billing_address)
VALUES
    (1, 'ORD-20260001', 'paid', 79990.00, 0.00, 300.00, 80290.00, 'RUB', 'Москва, ул. Ленина, д. 10, кв. 15', 'Москва, ул. Ленина, д. 10, кв. 15'),
    (2, 'ORD-20260002', 'processing', 149990.00, 5000.00, 400.00, 145390.00, 'RUB', 'Санкт-Петербург, пр. Невский, 42, кв. 8', 'Санкт-Петербург, пр. Невский, 42, кв. 8'),
    (3, 'ORD-20260003', 'pending', 6990.00, 0.00, 250.00, 7240.00, 'RUB', 'Казань, ул. Баумана, 18, кв. 3', 'Казань, ул. Баумана, 18, кв. 3');

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_amount, total_price)
VALUES
    (1, 1, 1, 79990.00, 0.00, 79990.00),
    (2, 2, 1, 149990.00, 5000.00, 144990.00),
    (3, 3, 1, 6990.00, 0.00, 6990.00);

INSERT INTO payments (order_id, payment_method, status, amount, transaction_ref, paid_at)
VALUES
    (1, 'card', 'captured', 80290.00, 'TXN-1001', NOW()),
    (2, 'bank_transfer', 'authorized', 145390.00, 'TXN-1002', NOW());

INSERT INTO addresses (customer_id, country, region, city, postal_code, street, house_number, apartment_number, address_type, is_default)
VALUES
    (1, 'Россия', 'Московская область', 'Москва', '101000', 'ул. Ленина', '10', '15', 'both', TRUE),
    (2, 'Россия', 'Санкт-Петербург', 'Санкт-Петербург', '190000', 'пр. Невский', '42', '8', 'both', TRUE),
    (3, 'Россия', 'Республика Татарстан', 'Казань', '420000', 'ул. Баумана', '18', '3', 'both', TRUE);

-- =============================================================
-- View: summary of orders by customer
-- =============================================================
CREATE VIEW ecommerce.customer_order_summary AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    o.order_id,
    o.order_number,
    o.status,
    o.created_at AS order_created_at,
    o.total_amount,
    COUNT(oi.order_item_id) AS items_count,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    o.order_id,
    o.order_number,
    o.status,
    o.created_at,
    o.total_amount;

-- =============================================================
-- Example query using the view
-- SELECT * FROM ecommerce.customer_order_summary ORDER BY customer_id, order_created_at;

-- =============================================================
-- Notes on PostgreSQL data types and design choices
-- =============================================================
-- 1. SERIAL / BIGSERIAL:
--    - Identifiers of objects that are expected to grow significantly (customers, orders, products)
--      are stored as BIGINT or BIGSERIAL, because INT may overflow in large e-commerce systems.
--    - SERIAL is used for smaller tables where 32-bit IDs are sufficient; BIGSERIAL is preferred for
--      high-volume transactional systems.
--
-- 2. VARCHAR(n):
--    - Used for short to medium text values with known maximums: names, emails, SKUs, slugs, phone numbers.
--    - Why not TEXT? Because VARCHAR(n) gives clear business constraints and often better indexing/validation
--      while still being efficient. TEXT is preferable for unlimited lengths or variable free-form content.
--
-- 3. TEXT:
--    - Used for product descriptions and shipping addresses when length is not limited by business rules.
--    - For large free-form content, TEXT is natural and avoids artificial size constraints.
--
-- 4. NUMERIC(12,2) / NUMERIC(14,2):
--    - Monetary values must not be represented with floating point because of precision errors.
--    - PostgreSQL NUMERIC stores decimal values exactly, which is essential for money, taxes, discounts, totals.
--    - FLOAT/REAL are unacceptable for accounting and price calculations due to rounding issues.
--
-- 5. DATE / TIMESTAMPTZ:
--    - DATE is used for birth_date, because date-only data does not need time.
--    - TIMESTAMPTZ is used for created_at/updated_at and paid_at because the system must correctly handle
--      time zones and global operations.
--
-- 6. BOOLEAN:
--    - Used for flags such as is_active, is_published, is_default, because it clearly represents binary states.
--
-- 7. ENUM:
--    - Used for order_status and payment_status/payment_method to constrain values to a fixed list.
--    - This improves data integrity and makes reporting easier.
--
-- 8. CHAR(3):
--    - Currency code is fixed-length and standardised as ISO 4217 (e.g., RUB, USD, EUR) => CHAR(3).
--
-- 9. BIGINT vs INTEGER vs SMALLINT:
--    - BIGINT: large numeric identifiers and values that may exceed 2.1 billion.
--    - INTEGER: stock_quantity and other counts where range is sufficient.
--    - SMALLINT is not used here because typical e-commerce systems tend to exceed small ranges for identifiers
--      and counts. If required, SMALLINT could be used for statuses or flags, but in this design BIGINT is safer.

-- =============================================================
-- Partitioning plan for orders
-- =============================================================
-- The table orders is the primary candidate for partitioning because it is expected to grow rapidly.
-- We should partition by created_at (or order_date) using monthly partitions.
--
-- Why created_at:
-- 1. Most reports and operational queries filter orders by time intervals.
-- 2. Data retention / archival / cleanup is easier by month.
-- 3. Growth over time is usually monotonic and naturally grouped by date.
--
-- Recommended partition strategy:
-- - Partition by RANGE on created_at.
-- - Create one partition per month.
-- - Example: orders_2026_10, orders_2026_11, orders_2026_12, etc.
-- - For each partition: CHECK (created_at >= '2026-10-01'::timestamptz AND created_at < '2026-11-01'::timestamptz)
--
-- Why monthly and not daily:
-- - Daily partitions may create too many partitions and excessive metadata overhead.
-- - Monthly partitions balance query performance and maintenance simplicity.
-- - For a large e-commerce system with potentially millions of rows per year, monthly partitions are a practical default.
--
-- Example skeleton (not executed here, but valid PostgreSQL approach):
-- CREATE TABLE orders (
--     order_id BIGSERIAL,
--     customer_id BIGINT NOT NULL,
--     order_number VARCHAR(32) NOT NULL,
--     status order_status NOT NULL,
--     subtotal NUMERIC(14,2) NOT NULL,
--     discount_amount NUMERIC(14,2) NOT NULL,
--     shipping_cost NUMERIC(12,2) NOT NULL,
--     total_amount NUMERIC(14,2) NOT NULL,
--     currency CHAR(3) NOT NULL,
--     shipping_address VARCHAR(500) NOT NULL,
--     billing_address VARCHAR(500),
--     created_at TIMESTAMPTZ NOT NULL,
--     updated_at TIMESTAMPTZ NOT NULL,
--     PRIMARY KEY (order_id, created_at)
-- ) PARTITION BY RANGE (created_at);
--
-- CREATE TABLE orders_2026_10 PARTITION OF orders
-- FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
--
-- CREATE TABLE orders_2026_11 PARTITION OF orders
-- FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
--
-- Additional notes:
-- - For queries by customer_id or order status, indexes should still be created on the partitioned table or on each partition.
-- - If query patterns heavily use customer_id, a composite index (customer_id, created_at) may be useful.
-- - This reduces scanning of old partitions and supports time-based data lifecycle management.

-- =============================================================
-- End of file
-- =============================================================
