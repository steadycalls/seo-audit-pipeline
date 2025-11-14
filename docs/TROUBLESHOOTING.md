# SEO Audit Pipeline - Troubleshooting Guide

This guide provides solutions to common problems you might encounter while using the Automated SEO Audit Pipeline.

## Crawler Issues (run_crawler.ps1)

### Problem: Crawls are not starting.

-   **Check Task Scheduler**: Ensure the `SEO_Audit_Pipeline_1_Crawler` task ran and completed successfully. Check the "Last Run Result" column in Task Scheduler. A result of `0x0` means success.
-   **Check Log File**: Look at `logs/pipeline.log` for any errors. The log file is the best place to start for any issue.
-   **Screaming Frog Path**: Verify that the `screaming_frog_cli_path` in `config/config.json` is correct and that the Screaming Frog application is installed at that location.
-   **License**: Ensure your Screaming Frog license is active and has been entered into the UI. The CLI will not run without a valid license.

### Problem: A specific domain fails to crawl.

-   **Robots.txt**: Check the domain's `robots.txt` file to ensure it is not blocking the Screaming Frog user agent (`Screaming Frog SEO Spider`).
-   **Firewall / IP Blocking**: The server may be blocking the IP address of the machine running the crawler. Try crawling the site manually from the same machine using the Screaming Frog UI.
-   **Manual Crawl**: Run the crawl manually from the command line to see more detailed output:

    ```powershell
    & "C:\Program Files\Screaming Frog SEO Spider\screamingfrogseospidercli.exe" --crawl https://example.com --headless --output-folder ./
    ```

### Problem: Crawls are slow.

-   **Parallel Crawls**: Increase the `max_parallel_crawls` value in `config/config.json`. Be mindful of your machine's CPU and RAM, as each instance of Screaming Frog is resource-intensive. A good starting point is 3-4 instances for a machine with 16GB of RAM.
-   **Screaming Frog Configuration**: Adjust the Screaming Frog crawl speed. In the UI, go to `Configuration > Speed` and reduce the number of concurrent threads. Save this configuration and reference it in `config.json`.

## ETL Issues (run_etl.py)

### Problem: Data is not appearing in the database.

-   **Check ETL Logs**: The `etl_logs` table in the `seo_audits` database is the first place to look. Query it for recent errors:

    ```sql
    SELECT * FROM etl_logs WHERE log_level = 'ERROR' ORDER BY created_at DESC LIMIT 10;
    ```

-   **Database Connection**: Ensure the credentials in your environment variables or Windows Credential Manager are correct. The ETL script will fail immediately if it cannot connect to the database.
-   **CSV Files**: Verify that the crawl script is correctly generating CSV files in the `exports/YYYY_MM_DD/domain.com/` directory. The ETL script looks for a file named `internal_all.csv`.
-   **File Paths**: Make sure the `base_export_path` in `config/config.json` is correct.

### Problem: Script fails with a `psycopg2` error.

-   **Connection Refused**: This means the database is not running or is not accessible from where you are running the script. Check that the PostgreSQL service is running and that the host and port in your configuration are correct.
-   **Authentication Failed**: This indicates incorrect username or password. Re-run the `setup_credentials.ps1` script to reset them.

## Backup Issues (run_backup.ps1)

### Problem: Database backup fails.

-   **`pg_dump` not found**: This error means the PostgreSQL client tools are not in your system's PATH. You may need to add the `bin` directory of your PostgreSQL installation (e.g., `C:\Program Files\PostgreSQL\14\bin`) to your PATH environment variable.
-   **Password Prompt**: If the script hangs or asks for a password, it means the `POSTGRES_PASSWORD` environment variable is not set correctly for the user running the task. Use the `setup_credentials.ps1` script to set it up.

### Problem: S3 sync fails.

-   **AWS Credentials**: This is the most common issue. Ensure you have configured your AWS credentials correctly using `aws configure --profile s3_backup_user`. The profile name must match the `aws_credential_profile` value in `config/config.json`.
-   **Permissions**: The IAM user associated with your AWS credentials must have `s3:Sync`, `s3:ListBucket`, `s3:GetObject`, and `s3:PutObject` permissions on the target S3 bucket.
-   **Bucket Name**: Double-check that the `s3_bucket_name` in `config/config.json` is spelled correctly and that the bucket exists in your AWS account.

## General Tips

-   **Run Manually**: Always try running a failing script manually from a PowerShell or command prompt. The output is often more detailed than what is available in the Task Scheduler logs.
-   **Check the Logs**: This cannot be overstated. The `logs/pipeline.log` file and the `etl_logs` database table were designed to be the first place you look to diagnose any problem.
-   **Permissions**: Many issues are related to file or user permissions. Ensure the user account running the scheduled tasks has permission to read/write to all the directories defined in `config.json` and to execute the necessary command-line tools.


## System Health and Startup Issues

### Problem: Tasks don't run after a computer reboot.

-   **Check Health Check Log**: A new health check script runs automatically on system startup. Check the log file at `C:\sf_batch\logs\health_check.log` for any errors. This log will tell you if essential services like PostgreSQL failed to start.
-   **PostgreSQL Service**: Ensure the PostgreSQL service is set to "Automatic" startup type. The health check script will attempt to start it, but it's best if it starts automatically with Windows.
    1.  Open `services.msc`.
    2.  Find the `postgresql-x64-14` (or similar) service.
    3.  Right-click, go to `Properties`, and set "Startup type" to `Automatic`.
-   **Task Settings**: The scheduled tasks are configured to run if they were missed. You can verify this by opening Task Scheduler, going to the task's `Settings` tab, and ensuring "Run task as soon as possible after a scheduled start is missed" is checked.

### Problem: A task failed and didn't run again.

-   **Check Restart Settings**: The tasks are configured to restart up to 3 times on failure. You can check this in the task's `Settings` tab. The restart interval is set to 10 minutes for the crawler and 5 minutes for the other tasks.
-   **Execution Time Limit**: Each task has an execution time limit to prevent it from running indefinitely. If a task is terminated because it exceeded this limit, it will be logged in the Task Scheduler history.
