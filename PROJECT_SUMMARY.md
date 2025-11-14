# SEO Audit Pipeline - Project Summary

## Overview

This project is a complete, production-ready automated SEO audit pipeline designed to monitor the technical health of multiple websites over time. The system integrates Screaming Frog SEO Spider for crawling, PostgreSQL for structured data storage, and a suite of PowerShell and Python scripts for orchestration, data processing, and backups.

## Key Features Implemented

### 1. Enhanced Error Handling

All scripts include comprehensive error handling to ensure that a single failure does not stop the entire pipeline. Errors are logged with detailed context to facilitate quick diagnosis and resolution.

### 2. Secure Credential Management

Database and AWS credentials are never hardcoded. The system supports multiple secure methods for credential storage, including Windows Credential Manager and environment variables, following industry best practices.

### 3. Performance Optimization

The crawler supports parallel processing to significantly reduce total crawl time. The database schema includes strategic indexes on all foreign keys and frequently queried columns to ensure that reporting dashboards remain fast even as the dataset grows.

### 4. Configuration Management

All paths, settings, and parameters are centralized in a single `config.json` file, making the system easy to deploy across different environments and simple to maintain.

### 5. Automated Backups

The pipeline includes automated daily backups of both the PostgreSQL database and the raw CSV exports to AWS S3, ensuring data durability and enabling disaster recovery.

### 6. Comprehensive Logging

Every component of the pipeline logs its activities. The ETL process writes logs directly to the database, making it easy to monitor the health of the system over time and to quickly identify issues.

## Repository Structure

The project is organized into clear, logical directories:

-   **`config/`**: All configuration files, including the main `config.json` and the list of domains to crawl.
-   **`scripts/`**: All automation scripts, including the crawler, ETL, backup, and setup helpers.
-   **`sql/`**: Database schema definitions and sample queries for reporting.
-   **`docs/`**: Comprehensive documentation covering architecture, database schema, and troubleshooting.

## Technology Stack

| Component          | Technology         |
| :----------------- | :----------------- |
| Crawler            | Screaming Frog SEO Spider (CLI) |
| Orchestration      | PowerShell 5.1+    |
| ETL                | Python 3.8+        |
| Database           | PostgreSQL 12+     |
| Backup Storage     | AWS S3             |
| Scheduling         | Windows Task Scheduler |

## Getting Started

To deploy this pipeline in your own environment, follow these steps:

1.  Clone the repository from GitHub.
2.  Install the prerequisites (Screaming Frog, PostgreSQL, Python, AWS CLI).
3.  Configure the `config/config.json` file with your specific paths and settings.
4.  Run the database schema scripts to create the necessary tables.
5.  Use the `setup_credentials.ps1` script to securely configure your credentials.
6.  Use the `setup_scheduled_tasks.ps1` script to create the automated daily tasks.

Detailed instructions are available in the `README.md` file.

## Documentation

The project includes extensive documentation to help you understand, deploy, and maintain the system:

-   **`README.md`**: Quick start guide and overview.
-   **`docs/ARCHITECTURE.md`**: Detailed explanation of the system architecture and data flow.
-   **`docs/DATABASE.md`**: Complete database schema reference with table definitions and relationships.
-   **`docs/TROUBLESHOOTING.md`**: Solutions to common problems and debugging tips.

## GitHub Repository

The complete source code for this project is available on GitHub:

**Repository URL**: https://github.com/steadycalls/seo-audit-pipeline

## Next Steps

After deploying the pipeline, you can:

-   Connect a business intelligence tool (Power BI, Tableau, Metabase) to the PostgreSQL database to create custom dashboards.
-   Extend the ETL script to process additional CSV exports from Screaming Frog (e.g., images, external links).
-   Customize the `issues_summary` table to track specific SEO issues that are most relevant to your business.
