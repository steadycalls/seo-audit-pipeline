# Automated SEO Audit Pipeline

This project provides a complete, automated pipeline for conducting technical SEO audits across multiple websites. It uses Screaming Frog SEO Spider for crawling, PostgreSQL for data storage, and a set of PowerShell and Python scripts for orchestration, ETL, and backups.

![Architecture Diagram](docs/architecture.png)

This system is designed to be robust, scalable, and easy to manage, allowing you to track the technical health of a portfolio of websites over time with minimal manual intervention.

## Features

- **Automated Batch Crawling**: Run Screaming Frog crawls for multiple domains in parallel.
- **Structured Data Storage**: Store all crawl data in a normalized PostgreSQL database for historical analysis.
- **Robust ETL Process**: Idempotent Python script to extract, transform, and load data from CSV exports into the database.
- **Secure Credential Management**: Best practices for handling database and AWS credentials securely.
- **Automated Backups**: Daily backups of the database and raw data to AWS S3.
- **Performance Optimized**: Parallel processing for crawls and indexed database schema for fast queries.
- **Comprehensive Logging**: Detailed logging for all processes to easily diagnose issues.
- **Easy Setup**: Includes scripts to help with credential and scheduled task setup.

## Project Structure

```
/seo-audit-pipeline
|-- config/                    # Configuration files
|   |-- config.json            # Main configuration
|   |-- domains.csv            # List of domains to crawl
|   `-- .env.template          # Template for environment variables
|-- db_backups/                # Local storage for database backups
|-- docs/                      # Documentation files
|   |-- ARCHITECTURE.md
|   |-- DATABASE.md
|   `-- TROUBLESHOOTING.md
|-- exports/                   # Raw CSV exports from Screaming Frog
|-- exports_archive/           # Archived CSVs after processing
|-- logs/                      # Log files for all scripts
|-- scripts/                   # All automation scripts
|   |-- run_crawler.ps1        # PowerShell script for batch crawling
|   |-- run_etl.py             # Python script for ETL process
|   |-- run_backup.ps1         # PowerShell script for backups
|   |-- setup_credentials.ps1  # Helper for setting up credentials
|   `-- setup_scheduled_tasks.ps1 # Helper for creating Windows tasks
|-- sql/                       # SQL scripts for database setup
|   |-- 01_create_schema.sql   # Main database schema
|   |-- 02_setup_user.sql      # Script to create a database user
|   `-- 03_sample_queries.sql  # Example queries for analysis
|-- .gitignore
|-- README.md
`-- requirements.txt           # Python dependencies
```

## Getting Started

### Prerequisites

- **Windows Machine**: The scripts are designed for a Windows environment with PowerShell 5.1+.
- **Screaming Frog SEO Spider**: A licensed version is required to use the command-line interface.
- **PostgreSQL**: Version 12 or higher.
- **Python**: Version 3.8 or higher.
- **AWS CLI**: For backing up data to S3.

### Installation and Setup

1.  **Clone the Repository**

    ```bash
    git clone <repository-url>
    cd seo-audit-pipeline
    ```

2.  **Configure the Pipeline**

    -   Rename `config/config.json.template` to `config.json` and update the paths and settings to match your environment.
    -   Edit `config/domains.csv` to add the websites you want to crawl.

3.  **Set up the Database**

    -   Create a PostgreSQL database (e.g., `seo_audits`).
    -   Run the `sql/01_create_schema.sql` script to create the tables and indexes.
    -   (Optional) Run `sql/02_setup_user.sql` to create a dedicated user for the ETL process.

4.  **Install Python Dependencies**

    ```bash
    pip install -r requirements.txt
    ```

5.  **Set up Credentials**

    Run the `setup_credentials.ps1` script in PowerShell to securely configure your database and AWS credentials.

    ```powershell
    ./scripts/setup_credentials.ps1
    ```

6.  **Schedule the Automated Tasks**

    Run the `setup_scheduled_tasks.ps1` script as an Administrator in PowerShell to create the daily tasks for crawling, ETL, and backups.

    ```powershell
    ./scripts/setup_scheduled_tasks.ps1
    ```

## Usage

Once set up, the pipeline will run automatically every day at the time you configured.

You can also run the scripts manually for testing:

-   **Run the Crawler**:
    ```powershell
    ./scripts/run_crawler.ps1
    ```
-   **Run the ETL Process**:
    ```bash
    python scripts/run_etl.py
    ```
-   **Run the Backup Process**:
    ```powershell
    ./scripts/run_backup.ps1
    ```

## Reporting

You can connect a business intelligence tool like Power BI, Tableau, or Metabase to the PostgreSQL database to create dashboards and reports. Use the queries in `sql/03_sample_queries.sql` as a starting point.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
