-- Migration: 0001_initial_schema.sql
-- SplitCount Database Schema for Cloudflare D1

-- Groups table
CREATE TABLE IF NOT EXISTS groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    currency TEXT NOT NULL DEFAULT 'USD',
    group_token TEXT UNIQUE NOT NULL,
    image_url TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0
);

-- Group Members table (supports placeholder/shadow members)
CREATE TABLE IF NOT EXISTS group_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    avatar_url TEXT,
    device_id TEXT,
    is_claimed INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0
);

-- Categories table (built-in and custom per group)
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    group_id TEXT REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color TEXT NOT NULL,
    is_custom INTEGER NOT NULL DEFAULT 0
);

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    category_id TEXT NOT NULL REFERENCES categories(id),
    split_type TEXT NOT NULL, -- 'equal', 'exact', 'percentage', 'shares'
    expense_date INTEGER NOT NULL,
    notes TEXT,
    created_by TEXT NOT NULL REFERENCES group_members(id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    is_deleted INTEGER NOT NULL DEFAULT 0
);

-- Expense Payers (Multi-payer support)
CREATE TABLE IF NOT EXISTS expense_payers (
    id TEXT PRIMARY KEY,
    expense_id TEXT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL REFERENCES group_members(id),
    amount_paid REAL NOT NULL
);

-- Expense Splits (Who owes what)
CREATE TABLE IF NOT EXISTS expense_splits (
    id TEXT PRIMARY KEY,
    expense_id TEXT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL REFERENCES group_members(id),
    amount_owed REAL NOT NULL,
    split_value REAL
);

-- Settlements (Payments made between members)
CREATE TABLE IF NOT EXISTS settlements (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    payer_id TEXT NOT NULL REFERENCES group_members(id),
    recipient_id TEXT NOT NULL REFERENCES group_members(id),
    amount REAL NOT NULL,
    settlement_date INTEGER NOT NULL,
    notes TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0
);

-- Audit Log (Activity Feed: "Who did what")
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_id TEXT NOT NULL,
    action TEXT NOT NULL, -- 'create_expense', 'edit_expense', 'delete_expense', 'settle'
    entity_id TEXT NOT NULL,
    details TEXT,
    timestamp INTEGER NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_groups_token ON groups(group_token);
CREATE INDEX IF NOT EXISTS idx_expenses_group_updated ON expenses(group_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_members_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_audit_group_time ON audit_logs(group_id, timestamp DESC);
