-- =============================================================
-- Task 2: User Management and Access Control
-- Roles, privileges, pg_hba.conf configuration, audit schema
-- =============================================================

-- =============================================================
-- Part 1 & 2: CREATE ROLES and GRANT PRIVILEGES
-- =============================================================

-- =====================================================
-- 1. DBA (Database Administrator)
-- =====================================================
-- Role: Super-user with full control over database
-- Minimum privileges: Create/drop databases, manage users, 
-- modify schema, execute administrative functions
-- Principle: Only necessary for infrastructure management

CREATE ROLE dba_admin WITH
    CREATEDB
    CREATEROLE
    INHERIT
    LOGIN
    PASSWORD 'dba_secure_password_123'
    VALID UNTIL '2027-12-31';

COMMENT ON ROLE dba_admin IS 
    'Database Administrator: Full control, schema management, user administration';

-- Grant all schema privileges to DBA
GRANT ALL PRIVILEGES ON SCHEMA ecommerce TO dba_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ecommerce TO dba_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ecommerce TO dba_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA ecommerce TO dba_admin;

-- Grant future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT ALL ON TABLES TO dba_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT ALL ON SEQUENCES TO dba_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT ALL ON FUNCTIONS TO dba_admin;

-- =====================================================
-- 2. DATA_ANALYST (Analytics and Reporting)
-- =====================================================
-- Role: Read-only access for analytics and reporting
-- Minimum privileges: SELECT on all tables and views
-- Purpose: Generate reports without modifying data

CREATE ROLE data_analyst WITH
    INHERIT
    LOGIN
    PASSWORD 'analyst_secure_password_456'
    VALID UNTIL '2027-12-31';

COMMENT ON ROLE data_analyst IS 
    'Data Analyst: Read-only access for reporting and analytics';

-- Grant SELECT on all tables and views
GRANT USAGE ON SCHEMA ecommerce TO data_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA ecommerce TO data_analyst;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA ecommerce TO data_analyst;
GRANT SELECT ON ecommerce.customer_order_summary TO data_analyst;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT SELECT ON TABLES TO data_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT SELECT ON SEQUENCES TO data_analyst;

-- =====================================================
-- 3. SALES_MANAGER (Sales Manager)
-- =====================================================
-- Role: Insert/update on customers and orders, read on products
-- Minimum privileges: Manage customer data, create/update orders
-- Restrictions: Cannot delete, cannot modify schema

CREATE ROLE sales_manager WITH
    INHERIT
    LOGIN
    PASSWORD 'sales_secure_password_789'
    VALID UNTIL '2027-12-31';

COMMENT ON ROLE sales_manager IS 
    'Sales Manager: Insert/update customers and orders, read products';

-- Grant usage on schema
GRANT USAGE ON SCHEMA ecommerce TO sales_manager;

-- Grant SELECT on all tables (read access)
GRANT SELECT ON ALL TABLES IN SCHEMA ecommerce TO sales_manager;

-- Grant INSERT, UPDATE on customers and orders
GRANT INSERT, UPDATE ON ecommerce.customers TO sales_manager;
GRANT INSERT, UPDATE ON ecommerce.orders TO sales_manager;
GRANT INSERT, UPDATE ON ecommerce.order_items TO sales_manager;
GRANT INSERT, UPDATE ON ecommerce.addresses TO sales_manager;

-- Grant USAGE and SELECT on sequences (for auto-increment)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ecommerce TO sales_manager;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT SELECT ON TABLES TO sales_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT INSERT, UPDATE ON TABLES TO sales_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT USAGE, SELECT ON SEQUENCES TO sales_manager;

-- =====================================================
-- 4. APP_SERVICE (Application Service Account)
-- =====================================================
-- Role: Limited privileges for web application
-- Minimum privileges: SELECT, INSERT, UPDATE on application-specific tables
-- Purpose: Application backend operations (e.g., browse products, create orders, process payments)
-- Restrictions: No DDL, no SUPERUSER, IP-restricted (see pg_hba.conf)

CREATE ROLE app_service WITH
    INHERIT
    LOGIN
    PASSWORD 'app_secure_password_xyz'
    VALID UNTIL '2027-12-31';

COMMENT ON ROLE app_service IS 
    'Application Service Account: Limited privileges for web backend, IP-restricted';

-- Grant minimal schema access
GRANT USAGE ON SCHEMA ecommerce TO app_service;

-- Grant SELECT on all tables (read all data)
GRANT SELECT ON ALL TABLES IN SCHEMA ecommerce TO app_service;

-- Grant INSERT, UPDATE on critical tables
GRANT INSERT, UPDATE ON ecommerce.customers TO app_service;
GRANT INSERT, UPDATE ON ecommerce.orders TO app_service;
GRANT INSERT, UPDATE ON ecommerce.order_items TO app_service;
GRANT INSERT, UPDATE ON ecommerce.payments TO app_service;
GRANT INSERT, UPDATE ON ecommerce.addresses TO app_service;

-- Grant USAGE and SELECT on sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ecommerce TO app_service;

-- Explicit deny on sensitive operations
REVOKE DELETE ON ecommerce.customers FROM app_service;
REVOKE DELETE ON ecommerce.orders FROM app_service;
REVOKE DELETE ON ecommerce.products FROM app_service;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT SELECT ON TABLES TO app_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT INSERT, UPDATE ON TABLES TO app_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT USAGE, SELECT ON SEQUENCES TO app_service;

-- =====================================================
-- 5. DEVELOPER (Development/QA Engineer)
-- =====================================================
-- Role: Full access within development environment
-- Minimum privileges: Full control on development schema
-- Purpose: Testing, debugging, schema modifications during development
-- Note: This role should NOT be used in production

CREATE ROLE developer WITH
    INHERIT
    LOGIN
    PASSWORD 'dev_secure_password_dev'
    VALID UNTIL '2027-12-31';

COMMENT ON ROLE developer IS 
    'Developer: Full schema access for development and testing (not for production)';

-- Grant full permissions on schema
GRANT ALL PRIVILEGES ON SCHEMA ecommerce TO developer;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ecommerce TO developer;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ecommerce TO developer;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA ecommerce TO developer;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT ALL ON TABLES TO developer;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT ALL ON SEQUENCES TO developer;
ALTER DEFAULT PRIVILEGES IN SCHEMA ecommerce
    GRANT ALL ON FUNCTIONS TO developer;

-- =============================================================
-- Part 3: pg_hba.conf Configuration
-- =============================================================

-- File: /etc/postgresql/14/main/pg_hba.conf
-- (or equivalent path for your PostgreSQL installation)
-- 
-- This fragment configures:
-- 1. Service account (app_service) can only connect from 192.168.1.100
-- 2. Service account uses scram-sha-256 (strong authentication)
-- 3. Direct access from outside corporate network is blocked
-- 4. Other roles can connect locally with md5/scram-sha-256

-- ============================================================
-- pg_hba.conf FRAGMENT
-- ============================================================
-- TYPE  DATABASE        USER            ADDRESS                 METHOD
-- ----  --------        ----            -------                 ------

-- Local connections (development/admin)
local   ecommerce       dba_admin                               scram-sha-256
local   ecommerce       developer                               scram-sha-256
local   ecommerce       data_analyst                            scram-sha-256
local   ecommerce       sales_manager                           scram-sha-256

-- Application service account: ONLY from 192.168.1.100 (application server)
hostssl ecommerce       app_service     192.168.1.100/32        scram-sha-256

-- Reject app_service from any other IP (explicit deny)
host    ecommerce       app_service     0.0.0.0/0               reject
host    ecommerce       app_service     ::/0                    reject

-- Deny direct external access to all other users
host    ecommerce       all             0.0.0.0/0               reject
host    ecommerce       all             ::/0                    reject

-- Allow local connections for postgres superuser (maintenance)
local   all             postgres                                trust

-- ============================================================
-- JUSTIFICATION FOR pg_hba.conf:
-- ============================================================
-- 1. app_service restricted to 192.168.1.100/32:
--    - Application server has a static IP on internal network
--    - Only one source allowed, following principle of least privilege
--    - hostssl enforces SSL/TLS encryption for security
--
-- 2. scram-sha-256 authentication:
--    - Modern, secure password hashing (SCRAM-SHA-256 = Salted Challenge Response Auth)
--    - Password never sent in plaintext over the wire
--    - Resistant to rainbow table attacks
--    - Better than old md5 which is deprecated
--
-- 3. Explicit reject for app_service from any other source:
--    - Prevents lateral movement if compromised
--    - Blocks accidental misconfiguration
--    - Defense in depth
--
-- 4. All external access blocked (0.0.0.0/0 and ::/0):
--    - No direct database access from internet
--    - Only application layer can communicate with DB
--    - Prevents exposure of sensitive data
--    - Reduces attack surface

-- =============================================================
-- Part 4: AUDIT SCHEMA
-- =============================================================

-- =====================================================
-- Audit Log Table
-- =====================================================
-- Tracks all DML and DDL operations for compliance and security

CREATE TABLE IF NOT EXISTS ecommerce.audit_log (
    audit_id         BIGSERIAL PRIMARY KEY,
    event_type       VARCHAR(50) NOT NULL,  -- INSERT, UPDATE, DELETE, DDL
    table_name       VARCHAR(100),
    schema_name      VARCHAR(100),
    user_name        VARCHAR(100) NOT NULL,
    application_name VARCHAR(255),
    client_addr      INET,
    operation_date   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    old_data         JSONB,              -- Previous row data (for UPDATE/DELETE)
    new_data         JSONB,              -- New row data (for INSERT/UPDATE)
    changes          JSONB,              -- Diff between old and new
    row_id           BIGINT,             -- Identifier of modified row
    result           VARCHAR(20) NOT NULL DEFAULT 'SUCCESS'  -- SUCCESS, FAILED
);

CREATE INDEX idx_audit_log_operation_date ON ecommerce.audit_log(operation_date DESC);
CREATE INDEX idx_audit_log_table_name ON ecommerce.audit_log(table_name);
CREATE INDEX idx_audit_log_user_name ON ecommerce.audit_log(user_name);
CREATE INDEX idx_audit_log_event_type ON ecommerce.audit_log(event_type);

-- =====================================================
-- Security Events Log
-- =====================================================
-- Tracks authentication failures, privilege escalation attempts, 
-- unauthorized access attempts (critical for security monitoring)

CREATE TABLE IF NOT EXISTS ecommerce.security_events_log (
    security_event_id BIGSERIAL PRIMARY KEY,
    event_type        VARCHAR(100) NOT NULL,  -- LOGIN_FAILED, UNAUTHORIZED_ACCESS, PRIVILEGE_ESCALATION, etc.
    user_name         VARCHAR(100),
    client_addr       INET,
    database_name     VARCHAR(100),
    attempted_action  VARCHAR(500),           -- What user tried to do
    result            VARCHAR(20) NOT NULL,   -- BLOCKED, ALLOWED, DENIED
    event_timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    details           TEXT
);

CREATE INDEX idx_security_events_timestamp ON ecommerce.security_events_log(event_timestamp DESC);
CREATE INDEX idx_security_events_user ON ecommerce.security_events_log(user_name);
CREATE INDEX idx_security_events_type ON ecommerce.security_events_log(event_type);

-- =====================================================
-- Performance Events Log
-- =====================================================
-- Tracks slow queries, high-resource operations, locks
-- (for performance monitoring and optimization)

CREATE TABLE IF NOT EXISTS ecommerce.performance_events_log (
    perf_event_id     BIGSERIAL PRIMARY KEY,
    event_type        VARCHAR(100) NOT NULL,  -- SLOW_QUERY, HIGH_MEMORY, LOCK_WAIT, etc.
    user_name         VARCHAR(100),
    database_name     VARCHAR(100),
    query_text        TEXT,
    query_duration_ms NUMERIC(12,2),          -- Milliseconds
    memory_used_mb    NUMERIC(10,2),
    affected_rows     BIGINT,
    lock_time_ms      NUMERIC(12,2),
    event_timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    details           TEXT
);

CREATE INDEX idx_perf_events_duration ON ecommerce.performance_events_log(query_duration_ms DESC);
CREATE INDEX idx_perf_events_timestamp ON ecommerce.performance_events_log(event_timestamp DESC);
CREATE INDEX idx_perf_events_user ON ecommerce.performance_events_log(user_name);

-- =====================================================
-- Audit Function: Log DML Operations
-- =====================================================
-- Trigger function to capture INSERT, UPDATE, DELETE events

CREATE OR REPLACE FUNCTION ecommerce.audit_dml_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_changes  JSONB;
BEGIN
    -- Capture old and new data as JSON
    v_old_data := row_to_json(OLD);
    v_new_data := row_to_json(NEW);
    
    -- Build changes object (only for UPDATE)
    IF TG_OP = 'UPDATE' THEN
        v_changes := jsonb_object_agg(key, v_new_data->key)
            FROM jsonb_object_keys(v_new_data) AS key
            WHERE v_old_data->key IS DISTINCT FROM v_new_data->key;
    ELSE
        v_changes := NULL;
    END IF;

    -- Insert audit log record
    INSERT INTO ecommerce.audit_log (
        event_type,
        table_name,
        schema_name,
        user_name,
        application_name,
        client_addr,
        old_data,
        new_data,
        changes,
        row_id,
        result
    ) VALUES (
        TG_OP,
        TG_TABLE_NAME,
        TG_TABLE_SCHEMA,
        current_user,
        current_setting('application_name', TRUE),
        inet_client_addr(),
        CASE WHEN TG_OP = 'DELETE' THEN v_old_data ELSE NULL END,
        CASE WHEN TG_OP != 'DELETE' THEN v_new_data ELSE NULL END,
        v_changes,
        COALESCE((v_new_data->>'customer_id')::BIGINT, (v_old_data->>'customer_id')::BIGINT),
        'SUCCESS'
    );

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ecommerce.audit_log (event_type, table_name, schema_name, user_name, result)
    VALUES (TG_OP, TG_TABLE_NAME, TG_TABLE_SCHEMA, current_user, 'FAILED');
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Attach Audit Triggers to Tables
-- =====================================================
-- Monitor critical tables for compliance

CREATE TRIGGER audit_customers_dml
    AFTER INSERT OR UPDATE OR DELETE ON ecommerce.customers
    FOR EACH ROW EXECUTE FUNCTION ecommerce.audit_dml_changes();

CREATE TRIGGER audit_orders_dml
    AFTER INSERT OR UPDATE OR DELETE ON ecommerce.orders
    FOR EACH ROW EXECUTE FUNCTION ecommerce.audit_dml_changes();

CREATE TRIGGER audit_payments_dml
    AFTER INSERT OR UPDATE OR DELETE ON ecommerce.payments
    FOR EACH ROW EXECUTE FUNCTION ecommerce.audit_dml_changes();

CREATE TRIGGER audit_products_dml
    AFTER INSERT OR UPDATE OR DELETE ON ecommerce.products
    FOR EACH ROW EXECUTE FUNCTION ecommerce.audit_dml_changes();

-- =====================================================
-- Sample Query: View Recent Audit Events
-- =====================================================
-- Example: View last 24 hours of changes to orders by sales_manager

CREATE OR REPLACE VIEW ecommerce.audit_recent_changes AS
SELECT
    audit_id,
    event_type,
    table_name,
    user_name,
    operation_date,
    old_data,
    new_data,
    changes,
    AGE(NOW(), operation_date) AS time_ago
FROM ecommerce.audit_log
WHERE operation_date > NOW() - INTERVAL '24 hours'
ORDER BY operation_date DESC;

-- =============================================================
-- AUDIT STRATEGY EXPLANATION
-- =============================================================

-- Three Categories of Events Tracked:
-- 
-- 1. AUDIT_LOG (DML Operations)
--    ================================
--    What: INSERT, UPDATE, DELETE on critical tables
--    Why:
--    - Compliance: Regulatory requirements (GDPR, financial reporting)
--    - Accountability: Who changed what data and when
--    - Forensics: Investigate data discrepancies or fraud
--    - Recovery: Rollback capability using old_data
--    Critical Tables: customers, orders, payments, products
--    
--    Example Use Cases:
--    - Compliance audit: "Show all customer data changes in last quarter"
--    - Fraud investigation: "Who modified this payment record?"
--    - Data recovery: "Restore customer 123 to state before 2026-10-01"
--
-- 2. SECURITY_EVENTS_LOG (Authentication & Access Control)
--    ================================
--    What: Failed logins, unauthorized access attempts, privilege escalation
--    Why:
--    - Threat detection: Identify attack attempts (brute force, SQL injection)
--    - Incident response: Trace what happened during security breach
--    - Compliance: Many regulations require login/access event logging
--    - Alerting: Real-time monitoring for suspicious activity
--    
--    Example Events:
--    - app_service connection attempt from unauthorized IP
--    - dba_admin failed authentication
--    - data_analyst attempting INSERT (should be read-only)
--    - Multiple failed login attempts (brute force detection)
--
--    Example Use Cases:
--    - Alert: "10 failed login attempts on app_service in 5 minutes"
--    - Investigation: "Which IPs tried to connect as dba_admin last week?"
--    - Compliance: "Generate login audit for SOC2 attestation"
--
-- 3. PERFORMANCE_EVENTS_LOG (Query Performance & Resource Usage)
--    ================================
--    What: Slow queries, high memory usage, lock waits
--    Why:
--    - Performance tuning: Identify bottlenecks for optimization
--    - Resource planning: Anticipate infrastructure needs
--    - SLA monitoring: Ensure performance targets are met
--    - Anomaly detection: Unusual query patterns or resource spikes
--    
--    Example Events:
--    - Query taking >5 seconds (threshold-based)
--    - Memory spike to >500MB for single query
--    - Lock wait time >1 second (database contention)
--    - Unexpected number of rows processed
--
--    Example Use Cases:
--    - Performance report: "Top 10 slowest queries this week"
--    - Capacity planning: "Traffic is increasing 20% monthly, upgrade in 6 months?"
--    - Alert: "Query for customer_order_summary took 30 seconds (usually 100ms)"
--
-- Retention Policy Recommendation:
-- - Audit log: 1 year (compliance, financial audit trails)
-- - Security events: 6 months minimum (threat analysis, incident response)
-- - Performance events: 30-90 days (trending, optimization)
-- 
-- Archival: Move older audit logs to cold storage (cost optimization)
-- 
-- PostgreSQL Built-in Features to Enhance Auditing:
-- - log_statement = 'all' (enables query logging)
-- - log_min_duration_statement = 1000 (logs queries >1 second)
-- - log_connections = on (track login/logout)
-- - log_disconnections = on
-- - ssl = on (force SSL for remote connections)
-- - password_encryption = scram-sha-256 (secure hashing)

-- =============================================================
-- End of file
-- =============================================================
