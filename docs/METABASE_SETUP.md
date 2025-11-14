# Metabase Dashboard Setup Guide

This guide provides step-by-step instructions for setting up a Metabase dashboard to visualize your SEO audit data. Metabase is a free, open-source business intelligence tool that makes it easy to create beautiful, interactive dashboards.

## Prerequisites

Before you begin, you must have **Docker Desktop** installed and running on your Windows machine. If you don't have it, you can download it from the [Docker website](https://www.docker.com/products/docker-desktop).

## Step 1: Start Metabase

We've included a simple script to make starting Metabase easy.

1.  Navigate to the `metabase` directory within the project folder.
2.  Run the `setup_metabase.ps1` script in PowerShell:

    ```powershell
    ./setup_metabase.ps1
    ```

    Alternatively, you can double-click the `metabase.bat` file to use a simple command-line menu.

3.  The script will download the latest Metabase image and start the container. This may take a few minutes the first time.
4.  Once it's ready, Metabase will be accessible at **http://localhost:3000**.

## Step 2: Initial Metabase Configuration

When you first open Metabase, you'll be greeted with a setup wizard.

1.  **Welcome**: Click "Let's get started".
2.  **Language**: Choose your preferred language.
3.  **Create your account**: Enter your name, email, and create a password for your Metabase admin account.
4.  **Add your data**: This is the most important step. Select **PostgreSQL** as the database type and enter the following connection details:

| Field                | Value                                                                                                                              |
| :------------------- | :--------------------------------------------------------------------------------------------------------------------------------- |
| **Display Name**     | `SEO Audit Database` (or any name you prefer)                                                                                      |
| **Host**             | `host.docker.internal` (This special DNS name allows the Docker container to connect to services running on your local machine) |
| **Port**             | `5432`                                                                                                                             |
| **Database Name**    | `seo_audits` (or the name you chose during setup)                                                                                  |
| **Username**         | The PostgreSQL username you configured (e.g., `seo_etl_user`)                                                                      |
| **Password**         | The password for your PostgreSQL user                                                                                              |
| **Use SSL**          | Leave this disabled unless you have configured SSL for your local PostgreSQL instance.                                             |

5.  **Usage Data Preferences**: Choose whether to allow Metabase to collect anonymous usage data.
6.  **Finish**: Click "Take me to Metabase".

## Step 3: Create Your First Dashboard

Now that Metabase is connected to your data, you can start building dashboards. We've provided a set of pre-built SQL queries to get you started quickly.

1.  **Create a New Question**:
    -   In Metabase, click the **+ New** button in the top right corner.
    -   Select **Question**.
    -   Choose **Native query**.
    -   Make sure your `SEO Audit Database` is selected.

2.  **Copy and Paste a Query**:
    -   Open the `metabase/METABASE_QUERIES.md` file in a text editor.
    -   Copy one of the SQL queries, for example, the "Site Health Summary".
    -   Paste the query into the Metabase query editor.

3.  **Visualize and Save**:
    -   Click the blue **play button** to run the query.
    -   Metabase will automatically display the results in a table. You can change the visualization type (e.g., to a bar chart or line chart) using the **Visualization** button at the bottom.
    -   Click **Save** in the top right. Give your question a descriptive name (e.g., "Site Health Summary") and save it to a collection.

4.  **Add to a Dashboard**:
    -   After saving, Metabase will ask if you want to add the question to a dashboard.
    -   Choose "Yes" and either create a new dashboard (e.g., "SEO Portfolio Overview") or add it to an existing one.

5.  **Repeat**: Repeat this process for the other queries in `METABASE_QUERIES.md` to build out a comprehensive set of dashboards for portfolio overview, site-specific details, and issue analysis.

## Managing Metabase

-   **To stop Metabase**, run `docker-compose down` in the `metabase` directory, or use the `metabase.bat` menu.
-   **To view logs**, run `docker-compose logs -f`.
-   **Data Persistence**: Your Metabase data (users, questions, dashboards) is stored in a Docker volume named `metabase-data`, so it will persist even if you stop and restart the container.

## Troubleshooting

-   **Cannot connect to `host.docker.internal`**: This can happen if you are not using Docker Desktop on Windows or Mac. In this case, you may need to use the direct IP address of your machine. You can find this by running `ipconfig` in a command prompt.
-   **Metabase fails to start**: Check the logs using `docker-compose logs` for any error messages. The most common issue is another service already using port 3000.
