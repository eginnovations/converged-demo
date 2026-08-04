-- Orders table for the Checkout transaction.
-- Note: no index on created_at, which (together with SLEEP()) keeps the
-- checkout_risk_lookup SELECT slow and interesting for Database Visibility.
CREATE TABLE IF NOT EXISTS orders (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id   VARCHAR(32) NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    status     VARCHAR(16) NOT NULL,
    created_at TIMESTAMP NOT NULL
);
