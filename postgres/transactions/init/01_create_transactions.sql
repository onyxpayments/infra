CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE payment_status AS ENUM (
    'NEW','PENDING',
    'APPROVED',
    'DECLINED',
    'ERROR',
    'EXPIRED'
    );

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tracking_id VARCHAR(100),

    notification_url TEXT NOT NULL,

    provider_transaction_id VARCHAR(100) UNIQUE,
    -- provider_reference VARCHAR(100),

    amount NUMERIC(18,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,

    status payment_status NOT NULL DEFAULT 'NEW',
    error_code VARCHAR(100),
    error_message TEXT,

    customer_first_name VARCHAR(100) NOT NULL,
    customer_last_name VARCHAR(100) NOT NULL,
    customer_personal_id VARCHAR(50) NOT NULL,
    -- customer_email VARCHAR(255) NOT NULL,
    -- bcustomer_country VARCHAR(2) NOT NULL,
    -- customer_ip INET NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
