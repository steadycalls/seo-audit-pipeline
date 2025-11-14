# Automated SEO Audit Pipeline

This project provides a complete, automated pipeline for conducting technical SEO audits across multiple websites. It uses Screaming Frog SEO Spider for crawling, PostgreSQL for data storage, and a suite of PowerShell and Python scripts for orchestration, ETL, and backups. The entire setup process is automated with a master PowerShell script.

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
- **Easy Setup**: A master setup script automates prerequisite installation, configuration, and task scheduling.

## Project Structure

```
/seo-audit-pipeline
|-- config/                    # Configuration files
|-- docs/                      # Documentation files
|-- scripts/                   # Automation and setup helper scripts
|-- sql/                       # Database schema and query scripts
|-- .gitignore
|-- README.md
|-- requirements.txt           # Python dependencies
`-- setup.ps1                  # MASTER SETUP SCRIPT
```

## Getting Started

This project includes a master setup script that automates the entire installation and configuration process.

### Prerequisites

- **Windows Machine**: The scripts are designed for a Windows environment with PowerShell 5.1+.
- **Screaming Frog SEO Spider**: A licensed version is required for command-line use. The setup script will prompt you for the installation path.

### Automated Installation

1.  **Clone the Repository**

    ```bash
    git clone https://github.com/steadycalls/seo-audit-pipeline.git
    cd seo-audit-pipeline
    ```

2.  **Run the Master Setup Script**

    Open PowerShell **as an Administrator**, navigate to the project directory, and run the `setup.ps1` script.

    ```powershell
    ./setup.ps1
    ```

    The script will guide you through the following steps:
    -   **Prerequisite Check**: It will check for and offer to install Python, PostgreSQL, and the AWS CLI using Chocolatey.
    -   **Configuration**: It will ask you for all necessary settings, such as file paths, database details, and S3 bucket names.
    -   **Database Setup**: It will create the database and all the necessary tables.
    -   **Credential Setup**: It will help you securely store your database and AWS credentials.
    -   **Task Scheduling**: It will automatically create the daily scheduled tasks in Windows Task Scheduler.

That's it! The pipeline is now fully configured and ready to run.

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
