# Quick Start Guide - SEO Audit Pipeline

This guide will help you get the SEO Audit Pipeline up and running in just a few minutes.

## What You'll Need

Before starting, make sure you have:

1.  **A Windows machine** with PowerShell 5.1 or higher
2.  **Administrator access** to install software and create scheduled tasks
3.  **A licensed copy of Screaming Frog SEO Spider** (the CLI requires a paid license)
4.  **An AWS account** (optional, but required if you want automated S3 backups)

## Installation Steps

### Step 1: Clone the Repository

Open a command prompt or PowerShell window and run:

```bash
git clone https://github.com/steadycalls/seo-audit-pipeline.git
cd seo-audit-pipeline
```

### Step 2: Run the Master Setup Script

Right-click on PowerShell and select **"Run as Administrator"**, then navigate to the project directory and execute:

```powershell
./setup.ps1
```

The script will walk you through the entire setup process interactively.

### Step 3: Follow the Prompts

The setup script will guide you through:

**Prerequisite Installation**
-   It will check if Python, PostgreSQL, and AWS CLI are installed
-   If any are missing, it will offer to install them automatically using Chocolatey
-   You can also choose to install them manually

**Configuration**
-   You'll be asked to provide a base directory for the pipeline (default: `C:\sf_batch`)
-   You'll configure database connection details (host, port, database name)
-   You'll provide your S3 bucket name and AWS profile for backups
-   You'll set the maximum number of parallel crawls

**Database Setup**
-   The script will create the `seo_audits` database
-   It will run the schema script to create all necessary tables and indexes

**Credential Configuration**
-   You'll securely store your PostgreSQL credentials
-   You'll configure your AWS credentials using the AWS CLI

**Scheduled Task Creation**
-   The script will create three scheduled tasks in Windows Task Scheduler
-   These tasks will run the crawler, ETL, and backup processes daily

### Step 4: Add Your Domains

After setup is complete, edit the domains CSV file to add the websites you want to monitor:

```
C:\sf_batch\config\domains.csv
```

The file format is simple:

```csv
domain,label,status
example.com,Example Site,active
mysite.com,My Website,active
```

Set `status` to `active` for domains you want to crawl, or `inactive` to skip them.

### Step 5: Test the Pipeline

Before relying on the automated schedule, test each component manually:

**Test the Crawler:**
```powershell
./scripts/run_crawler.ps1
```

This will crawl all active domains and save the results to the `exports` directory.

**Test the ETL Process:**
```bash
python ./scripts/run_etl.py
```

This will process the CSV files and load the data into PostgreSQL.

**Test the Backup:**
```powershell
./scripts/run_backup.ps1
```

This will create a database backup and sync it to S3.

## What Happens Next?

Once the pipeline is set up and the scheduled tasks are created, the system will run automatically every day at 2:00 AM (or whatever time you configured).

The workflow is:
1.  **2:00 AM**: The crawler runs and generates CSV exports for all active domains
2.  **~2:05 AM**: The ETL script processes the CSVs and loads data into the database
3.  **~2:10 AM**: The backup script creates a database dump and syncs everything to S3

You can monitor the pipeline by checking the log files:
-   Main log: `C:\sf_batch\logs\pipeline.log`
-   Database ETL logs: Query the `etl_logs` table in PostgreSQL

## Connecting a Dashboard

To visualize your data, connect a business intelligence tool to the PostgreSQL database:

**Power BI:**
1.  Open Power BI Desktop
2.  Click "Get Data" → "PostgreSQL database"
3.  Enter your database connection details
4.  Use the sample queries in `sql/03_sample_queries.sql` as a starting point

**Metabase (Open Source):**
1.  Install Metabase from https://www.metabase.com/
2.  Add a PostgreSQL connection
3.  Create dashboards using the pre-built queries

## Troubleshooting

If you encounter any issues, refer to the `docs/TROUBLESHOOTING.md` file for common problems and solutions.

For more detailed information about the system architecture and database schema, see:
-   `docs/ARCHITECTURE.md`
-   `docs/DATABASE.md`

## Need Help?

If you're stuck, check the following:
-   **Log files**: `C:\sf_batch\logs\pipeline.log` and the `etl_logs` database table
-   **Task Scheduler**: Open Windows Task Scheduler and check the "Last Run Result" for each task
-   **Documentation**: The `docs/` directory contains detailed guides

Happy auditing!
