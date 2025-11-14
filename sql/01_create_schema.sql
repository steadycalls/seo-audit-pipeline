-- ============================================
-- SEO Audit Pipeline - Database Schema
-- ============================================
-- This schema supports automated SEO audits with:
-- - Multi-site tracking
-- - Historical crawl data
-- - Performance-optimized indexes
-- - Issue tracking and aggregation
-- ============================================

-- Create the database (run separately if needed)
-- CREATE DATABASE seo_audits;

-- Connect to the database
\c seo_audits;

-- ============================================
-- Table: sites
-- Stores information about each website being monitored
-- ============================================
CREATE TABLE IF NOT EXISTS sites (
    site_id SERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL UNIQUE,
    label VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast domain lookups
CREATE INDEX IF NOT EXISTS idx_sites_domain ON sites(domain);
CREATE INDEX IF NOT EXISTS idx_sites_status ON sites(status);

-- ============================================
-- Table: crawls
-- Stores metadata for each crawl execution
-- ============================================
CREATE TABLE IF NOT EXISTS crawls (
    crawl_id SERIAL PRIMARY KEY,
    site_id INTEGER NOT NULL REFERENCES sites(site_id) ON DELETE CASCADE,
    crawl_date DATE NOT NULL,
    crawl_started_at TIMESTAMP,
    crawl_completed_at TIMESTAMP,
    total_pages INTEGER,
    total_internal_links INTEGER,
    total_external_links INTEGER,
    total_images INTEGER,
    avg_response_time_ms INTEGER,
    crawl_status VARCHAR(50) DEFAULT 'completed' CHECK (crawl_status IN ('running', 'completed', 'failed', 'partial')),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(site_id, crawl_date)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_crawls_site_id ON crawls(site_id);
CREATE INDEX IF NOT EXISTS idx_crawls_date ON crawls(crawl_date);
CREATE INDEX IF NOT EXISTS idx_crawls_status ON crawls(crawl_status);

-- ============================================
-- Table: pages
-- Stores detailed information about each page crawled
-- ============================================
CREATE TABLE IF NOT EXISTS pages (
    page_id BIGSERIAL PRIMARY KEY,
    crawl_id INTEGER NOT NULL REFERENCES crawls(crawl_id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    status_code INTEGER,
    indexability VARCHAR(50),
    indexability_status VARCHAR(100),
    title TEXT,
    title_length INTEGER,
    meta_description TEXT,
    meta_description_length INTEGER,
    h1 TEXT,
    h1_count INTEGER,
    word_count INTEGER,
    response_time_ms INTEGER,
    size_bytes INTEGER,
    canonical_link TEXT,
    robots_txt_status VARCHAR(50),
    x_robots_tag VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_pages_crawl_id ON pages(crawl_id);
CREATE INDEX IF NOT EXISTS idx_pages_url ON pages(url);
CREATE INDEX IF NOT EXISTS idx_pages_status_code ON pages(status_code);
CREATE INDEX IF NOT EXISTS idx_pages_indexability ON pages(indexability);

-- ============================================
-- Table: issues_summary
-- Pre-aggregated issue counts for fast dashboard loading
-- ============================================
CREATE TABLE IF NOT EXISTS issues_summary (
    summary_id SERIAL PRIMARY KEY,
    crawl_id INTEGER NOT NULL REFERENCES crawls(crawl_id) ON DELETE CASCADE,
    issue_type VARCHAR(100) NOT NULL,
    issue_category VARCHAR(50) NOT NULL CHECK (issue_category IN ('error', 'warning', 'notice')),
    issue_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crawl_id, issue_type)
);

-- Index for fast aggregation queries
CREATE INDEX IF NOT EXISTS idx_issues_summary_crawl_id ON issues_summary(crawl_id);
CREATE INDEX IF NOT EXISTS idx_issues_summary_category ON issues_summary(issue_category);

-- ============================================
-- Table: issues_detail (Optional)
-- Stores detailed issue information for deep analysis
-- ============================================
CREATE TABLE IF NOT EXISTS issues_detail (
    issue_id BIGSERIAL PRIMARY KEY,
    crawl_id INTEGER NOT NULL REFERENCES crawls(crawl_id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    issue_type VARCHAR(100) NOT NULL,
    issue_category VARCHAR(50) NOT NULL CHECK (issue_category IN ('error', 'warning', 'notice')),
    issue_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for filtering and searching
CREATE INDEX IF NOT EXISTS idx_issues_detail_crawl_id ON issues_detail(crawl_id);
CREATE INDEX IF NOT EXISTS idx_issues_detail_type ON issues_detail(issue_type);
CREATE INDEX IF NOT EXISTS idx_issues_detail_category ON issues_detail(issue_category);

-- ============================================
-- Table: etl_logs
-- Tracks ETL execution history and errors
-- ============================================
CREATE TABLE IF NOT EXISTS etl_logs (
    log_id SERIAL PRIMARY KEY,
    crawl_id INTEGER REFERENCES crawls(crawl_id) ON DELETE SET NULL,
    site_id INTEGER REFERENCES sites(site_id) ON DELETE SET NULL,
    log_level VARCHAR(20) NOT NULL CHECK (log_level IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    message TEXT NOT NULL,
    file_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for log queries
CREATE INDEX IF NOT EXISTS idx_etl_logs_created_at ON etl_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_etl_logs_level ON etl_logs(log_level);

-- ============================================
-- Function: Update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for sites table
CREATE TRIGGER update_sites_updated_at
    BEFORE UPDATE ON sites
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Grant permissions (adjust username as needed)
-- ============================================
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO seo_etl_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO seo_etl_user;

-- ============================================
-- Verification queries
-- ============================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
-- SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public';
