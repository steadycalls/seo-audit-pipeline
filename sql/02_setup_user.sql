-- ============================================
-- SEO Audit Pipeline - User Setup
-- ============================================
-- This script creates a dedicated database user for the ETL process
-- Run this as the PostgreSQL superuser (postgres)
-- ============================================

-- Create the ETL user (change password to something secure)
CREATE USER seo_etl_user WITH PASSWORD 'your_secure_password_here';

-- Grant connection to the database
GRANT CONNECT ON DATABASE seo_audits TO seo_etl_user;

-- Connect to the database
\c seo_audits;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO seo_etl_user;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO seo_etl_user;

-- Grant sequence permissions (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO seo_etl_user;

-- Grant permissions on future tables (optional, for convenience)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO seo_etl_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO seo_etl_user;

-- Verify permissions
\du seo_etl_user
