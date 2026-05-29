CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,

    transaction_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),

    merchant_id VARCHAR(64) NOT NULL,

    amount NUMERIC(18,2) NOT NULL,
    currency CHAR(3) NOT NULL,

    status VARCHAR(32) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);