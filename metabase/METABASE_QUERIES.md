# Metabase Dashboard Queries for SEO Audit Pipeline

This document contains pre-built SQL queries that you can use to create dashboards in Metabase. Simply copy and paste these queries into Metabase's native query editor.

## Getting Started

1. Open Metabase at http://localhost:3000
2. Click "New" → "Question" → "Native query"
3. Select your PostgreSQL database connection
4. Copy and paste any query below
5. Click "Visualize" to see the results
6. Save the question and add it to a dashboard

---

## Dashboard 1: Portfolio Overview

### Query 1.1: Site Health Summary

**Purpose**: Shows the current status of all active sites with their latest crawl metrics.

```sql
SELECT 
    s.domain,
    s.label,
    c.crawl_date as "Last Crawl",
    c.total_pages as "Total Pages",
    c.crawl_status as "Status",
    c.avg_response_time_ms as "Avg Response Time (ms)"
FROM sites s
LEFT JOIN LATERAL (
    SELECT * FROM crawls 
    WHERE site_id = s.site_id 
    ORDER BY crawl_date DESC 
    LIMIT 1
) c ON true
WHERE s.status = 'active'
ORDER BY s.domain;
```

**Visualization**: Table

---

### Query 1.2: Total Issues by Category

**Purpose**: Pie chart showing the distribution of errors, warnings, and notices across all sites.

```sql
SELECT 
    i.issue_category as "Category",
    SUM(i.issue_count) as "Total Issues"
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
GROUP BY i.issue_category
ORDER BY "Total Issues" DESC;
```

**Visualization**: Pie Chart or Bar Chart

---

### Query 1.3: Top 10 Most Common Issues

**Purpose**: Shows which SEO issues appear most frequently across all sites.

```sql
SELECT 
    i.issue_type as "Issue Type",
    i.issue_category as "Category",
    SUM(i.issue_count) as "Total Occurrences",
    COUNT(DISTINCT c.site_id) as "Sites Affected"
FROM issues_summary i
JOIN crawls c ON i.crawl_id = c.crawl_id
WHERE c.crawl_id IN (
    SELECT DISTINCT ON (site_id) crawl_id 
    FROM crawls 
    ORDER BY site_id, crawl_date DESC
)
GROUP BY i.issue_type, i.issue_category
ORDER BY "Total Occurrences" DESC
LIMIT 10;
```

**Visualization**: Bar Chart (horizontal)

---

## Dashboard 2: Site Detail View

### Query 2.1: Crawl History for a Specific Site

**Purpose**: Line chart showing how page count has changed over time.

**Note**: Replace `'example.com'` with the actual domain you want to analyze.

```sql
SELECT 
    crawl_date as "Date",
    total_pages as "Total Pages",
    total_internal_links as "Internal Links",
    avg_response_time_ms as "Avg Response Time"
FROM crawls
WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
ORDER BY crawl_date ASC;
```

**Visualization**: Line Chart (multiple series)

---

### Query 2.2: Issue Trends Over Time

**Purpose**: Shows how specific issues have changed over time for a site.

```sql
SELECT 
    c.crawl_date as "Date",
    i.issue_type as "Issue",
    i.issue_count as "Count"
FROM crawls c
JOIN issues_summary i ON c.crawl_id = i.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
AND i.issue_category = 'error'
ORDER BY c.crawl_date ASC, i.issue_count DESC;
```

**Visualization**: Line Chart or Area Chart

---

### Query 2.3: Current Issues Breakdown

**Purpose**: Table showing all current issues for a specific site.

```sql
SELECT 
    i.issue_type as "Issue Type",
    i.issue_category as "Category",
    i.issue_count as "Count"
FROM crawls c
JOIN issues_summary i ON c.crawl_id = i.crawl_id
WHERE c.site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
AND c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls 
    WHERE site_id = (SELECT site_id FROM sites WHERE domain = 'example.com')
)
ORDER BY 
    CASE i.issue_category 
        WHEN 'error' THEN 1 
        WHEN 'warning' THEN 2 
        ELSE 3 
    END,
    i.issue_count DESC;
```

**Visualization**: Table

---

## Dashboard 3: Page-Level Analysis

### Query 3.1: Pages with 404 Errors

**Purpose**: Find all broken pages in the latest crawl.

```sql
SELECT 
    s.domain as "Site",
    p.url as "URL",
    p.title as "Title"
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
JOIN sites s ON c.site_id = s.site_id
WHERE c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls WHERE site_id = c.site_id
)
AND p.status_code = 404
AND s.status = 'active'
ORDER BY s.domain, p.url
LIMIT 100;
```

**Visualization**: Table

---

### Query 3.2: Pages Missing Meta Descriptions

**Purpose**: Identify indexable pages without meta descriptions.

```sql
SELECT 
    s.domain as "Site",
    p.url as "URL",
    p.title as "Title",
    p.word_count as "Word Count"
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
JOIN sites s ON c.site_id = s.site_id
WHERE c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls WHERE site_id = c.site_id
)
AND (p.meta_description IS NULL OR p.meta_description = '')
AND p.indexability = 'Indexable'
AND s.status = 'active'
ORDER BY s.domain, p.url
LIMIT 100;
```

**Visualization**: Table

---

### Query 3.3: Slowest Pages

**Purpose**: Find pages with the longest response times.

```sql
SELECT 
    s.domain as "Site",
    p.url as "URL",
    p.response_time_ms as "Response Time (ms)",
    p.size_bytes / 1024 as "Size (KB)",
    p.status_code as "Status"
FROM pages p
JOIN crawls c ON p.crawl_id = c.crawl_id
JOIN sites s ON c.site_id = s.site_id
WHERE c.crawl_date = (
    SELECT MAX(crawl_date) FROM crawls WHERE site_id = c.site_id
)
AND s.status = 'active'
ORDER BY p.response_time_ms DESC
LIMIT 50;
```

**Visualization**: Table

---

## Dashboard 4: Performance Metrics

### Query 4.1: Average Response Time by Site

**Purpose**: Compare site performance across your portfolio.

```sql
SELECT 
    s.domain as "Site",
    c.avg_response_time_ms as "Avg Response Time (ms)"
FROM sites s
JOIN LATERAL (
    SELECT * FROM crawls 
    WHERE site_id = s.site_id 
    ORDER BY crawl_date DESC 
    LIMIT 1
) c ON true
WHERE s.status = 'active'
ORDER BY c.avg_response_time_ms DESC;
```

**Visualization**: Bar Chart

---

### Query 4.2: Response Time Trends

**Purpose**: Track performance improvements or degradation over time.

```sql
SELECT 
    s.domain as "Site",
    c.crawl_date as "Date",
    c.avg_response_time_ms as "Avg Response Time (ms)"
FROM sites s
JOIN crawls c ON s.site_id = c.site_id
WHERE s.status = 'active'
AND c.crawl_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY s.domain, c.crawl_date ASC;
```

**Visualization**: Line Chart (grouped by site)

---

## Tips for Using These Queries in Metabase

1. **Parameters**: You can add filters to any query by clicking "Variables" in the query editor. For example, add `[[WHERE domain = {{site}}]]` to create a site selector.

2. **Scheduling**: Set up automated email reports by clicking "Schedule" on any saved question.

3. **Dashboards**: Combine multiple questions into a single dashboard for a comprehensive view.

4. **Drill-Through**: Enable click-through from summary charts to detail tables for deeper analysis.

5. **Alerts**: Set up alerts to notify you when metrics exceed thresholds (e.g., more than 100 404 errors).
