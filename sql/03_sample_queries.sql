-- ============================================
-- SEO Audit Pipeline - Sample Queries
-- ============================================
-- Useful queries for Power BI dashboards and ad-hoc analysis
-- ============================================

-- ============================================
-- Portfolio Overview Queries
-- ============================================

-- Get latest crawl summary for all active sites
SELECT 
    s.domain,
    s.label,
    c.crawl_date,
    c.total_pages,
    c.crawl_status,
    c.avg_response_time_ms
FROM sites s
LEFT JOIN LATERAL (
    SELECT * FROM crawls 
    WHERE site_id = s.site_id 
    ORDER BY crawl_date DESC 
    LIMIT 1
) c ON true
WHERE s.status = 'active'
ORDER BY s.domain;

-- Get total issue counts by category for latest crawls
SELECT 
    s.domain,
    i.issue_category,
    SUM(i.issue_count) as total_issues
FROM sites s
JOIN crawls c ON s.site_id = c.site_id
JOIN issues_summary i ON c.crawl_id = i.crawl_id
WHERE c.crawl_id IN (
    SELECT crawl_id FROM crawls c2 
    WHERE c2.site_id = s.site_id 
    ORDER BY crawl_date DESC 
    LIMIT 1
)
AND s.status = 'active'
GROUP BY s.domain, i.issue_category
ORDER BY s.domain, i.issue_category;

-- ============================================
-- Site Detail Queries
-- ============================================

-- Get crawl history for a specific site
SELECT 
    crawl_date,
    total_pages,
    total_internal_links,
    total_external_links,
    avg_response_time_ms,
    crawl_status
FROM crawls
WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
ORDER BY crawl_date DESC;

-- Get issue trends over time for a specific site
SELECT 
    c.crawl_date,
    i.issue_type,
    i.issue_count
FROM crawls c
JOIN issues_summary i ON c.crawl_id = i.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
ORDER BY c.crawl_date DESC, i.issue_count DESC;

-- ============================================
-- Page-Level Analysis Queries
-- ============================================

-- Find all 404 errors in the latest crawl
SELECT 
    p.url,
    p.status_code,
    p.title
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
AND c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls 
    WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
)
AND p.status_code = 404
ORDER BY p.url;

-- Find pages with missing meta descriptions
SELECT 
    p.url,
    p.title,
    p.meta_description
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
AND c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls 
    WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
)
AND (p.meta_description IS NULL OR p.meta_description = '')
AND p.indexability = 'Indexable'
ORDER BY p.url;

-- Find pages with multiple H1 tags
SELECT 
    p.url,
    p.h1_count,
    p.title
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
AND c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls 
    WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
)
AND p.h1_count > 1
ORDER BY p.h1_count DESC, p.url;

-- ============================================
-- Performance Analysis Queries
-- ============================================

-- Get slowest pages in the latest crawl
SELECT 
    p.url,
    p.response_time_ms,
    p.size_bytes,
    p.status_code
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
AND c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls 
    WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
)
ORDER BY p.response_time_ms DESC
LIMIT 50;

-- ============================================
-- Issue Detail Queries
-- ============================================

-- Get all issues for a specific URL
SELECT 
    i.issue_type,
    i.issue_category,
    i.issue_description,
    c.crawl_date
FROM issues_detail i
JOIN crawls c ON i.crawl_id = c.crawl_id
WHERE i.url = 'https://example.com/some-page'
ORDER BY c.crawl_date DESC;

-- Get top 10 most common issues across all sites
SELECT 
    i.issue_type,
    i.issue_category,
    SUM(i.issue_count) as total_occurrences,
    COUNT(DISTINCT c.site_id) as sites_affected
FROM issues_summary i
JOIN crawls c ON i.crawl_id = c.crawl_id
WHERE c.crawl_id IN (
    SELECT DISTINCT ON (site_id) crawl_id 
    FROM crawls 
    ORDER BY site_id, crawl_date DESC
)
GROUP BY i.issue_type, i.issue_category
ORDER BY total_occurrences DESC
LIMIT 10;

-- ============================================
-- ETL Monitoring Queries
-- ============================================

-- Get recent ETL errors
SELECT 
    log_level,
    message,
    file_path,
    created_at
FROM etl_logs
WHERE log_level IN ('ERROR', 'CRITICAL')
ORDER BY created_at DESC
LIMIT 50;

-- Get ETL success rate by day
SELECT 
    DATE(created_at) as log_date,
    log_level,
    COUNT(*) as count
FROM etl_logs
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at), log_level
ORDER BY log_date DESC, log_level;
