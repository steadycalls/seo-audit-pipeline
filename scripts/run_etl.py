#!/usr/bin/env python3
"""
============================================
SEO Audit Pipeline - ETL Script
============================================
This script processes Screaming Frog CSV exports and loads them
into PostgreSQL with robust error handling and credential management
============================================
"""

import os
import sys
import json
import csv
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import psycopg2
from psycopg2.extras import execute_batch

# ============================================
# Configuration and Credential Management
# ============================================

def load_config(config_path: str = None) -> Dict:
    """Load configuration from JSON file"""
    if config_path is None:
        script_dir = Path(__file__).parent
        config_path = script_dir.parent / "config" / "config.json"
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        print(f"✓ Configuration loaded from: {config_path}")
        return config
    except Exception as e:
        print(f"✗ Failed to load configuration: {e}")
        sys.exit(1)

def get_db_credentials(config: Dict) -> Dict:
    """
    Get database credentials securely.
    Priority: Windows Credential Manager > Environment Variables > Config File
    """
    credentials = {
        'host': config.get('postgres_host', 'localhost'),
        'port': config.get('postgres_port', 5432),
        'database': config.get('postgres_database', 'seo_audits'),
        'user': None,
        'password': None
    }
    
    # Try to get credentials from environment variables first
    credentials['user'] = os.environ.get('POSTGRES_USER')
    credentials['password'] = os.environ.get('POSTGRES_PASSWORD')
    
    # If not in environment, try Windows Credential Manager (on Windows)
    if not credentials['user'] or not credentials['password']:
        if sys.platform == 'win32':
            try:
                import keyring
                cred_name = config.get('db_credential_name', 'Postgres_ETL_User')
                credentials['user'] = keyring.get_password(cred_name, 'username')
                credentials['password'] = keyring.get_password(cred_name, 'password')
            except ImportError:
                print("⚠ keyring module not installed. Install with: pip install keyring")
            except Exception as e:
                print(f"⚠ Could not retrieve credentials from Windows Credential Manager: {e}")
    
    # Validate we have credentials
    if not credentials['user'] or not credentials['password']:
        print("✗ Database credentials not found!")
        print("  Please set POSTGRES_USER and POSTGRES_PASSWORD environment variables")
        print("  or store them in Windows Credential Manager")
        sys.exit(1)
    
    return credentials

# ============================================
# Database Connection
# ============================================

class DatabaseConnection:
    """Manages PostgreSQL database connection with context manager support"""
    
    def __init__(self, credentials: Dict):
        self.credentials = credentials
        self.conn = None
        self.cursor = None
    
    def __enter__(self):
        try:
            self.conn = psycopg2.connect(**self.credentials)
            self.cursor = self.conn.cursor()
            print("✓ Database connection established")
            return self
        except Exception as e:
            print(f"✗ Failed to connect to database: {e}")
            sys.exit(1)
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.cursor:
            self.cursor.close()
        if self.conn:
            if exc_type is None:
                self.conn.commit()
            else:
                self.conn.rollback()
            self.conn.close()
        print("✓ Database connection closed")
    
    def execute(self, query: str, params: tuple = None):
        """Execute a single query"""
        try:
            self.cursor.execute(query, params)
            return self.cursor
        except Exception as e:
            print(f"✗ Query execution failed: {e}")
            raise
    
    def execute_many(self, query: str, data: List[tuple]):
        """Execute batch insert"""
        try:
            execute_batch(self.cursor, query, data, page_size=1000)
        except Exception as e:
            print(f"✗ Batch execution failed: {e}")
            raise

# ============================================
# ETL Logging
# ============================================

def log_etl_event(db: DatabaseConnection, crawl_id: Optional[int], site_id: Optional[int], 
                  level: str, message: str, file_path: Optional[str] = None):
    """Log ETL events to the database"""
    query = """
        INSERT INTO etl_logs (crawl_id, site_id, log_level, message, file_path)
        VALUES (%s, %s, %s, %s, %s)
    """
    try:
        db.execute(query, (crawl_id, site_id, level, message, file_path))
    except Exception as e:
        print(f"⚠ Failed to log event: {e}")

# ============================================
# Site and Crawl Management
# ============================================

def get_or_create_site(db: DatabaseConnection, domain: str, label: str = None) -> int:
    """Get existing site_id or create new site record"""
    # Try to get existing site
    query = "SELECT site_id FROM sites WHERE domain = %s"
    result = db.execute(query, (domain,)).fetchone()
    
    if result:
        return result[0]
    
    # Create new site
    insert_query = """
        INSERT INTO sites (domain, label, status)
        VALUES (%s, %s, 'active')
        RETURNING site_id
    """
    site_id = db.execute(insert_query, (domain, label or domain)).fetchone()[0]
    print(f"  ✓ Created new site record for: {domain}")
    return site_id

def get_or_create_crawl(db: DatabaseConnection, site_id: int, crawl_date: str) -> int:
    """Get existing crawl_id or create new crawl record"""
    # Try to get existing crawl
    query = "SELECT crawl_id FROM crawls WHERE site_id = %s AND crawl_date = %s"
    result = db.execute(query, (site_id, crawl_date)).fetchone()
    
    if result:
        return result[0]
    
    # Create new crawl
    insert_query = """
        INSERT INTO crawls (site_id, crawl_date, crawl_started_at, crawl_status)
        VALUES (%s, %s, %s, 'completed')
        RETURNING crawl_id
    """
    crawl_id = db.execute(insert_query, (site_id, crawl_date, datetime.now())).fetchone()[0]
    print(f"  ✓ Created new crawl record for: {crawl_date}")
    return crawl_id

# ============================================
# CSV Processing
# ============================================

def process_internal_all_csv(db: DatabaseConnection, crawl_id: int, csv_path: Path) -> int:
    """Process the internal_all.csv file and load pages"""
    print(f"  Processing: {csv_path.name}")
    
    pages_data = []
    
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                # Extract relevant fields (adjust based on actual Screaming Frog export columns)
                page_data = (
                    crawl_id,
                    row.get('Address', ''),
                    int(row.get('Status Code', 0)) if row.get('Status Code', '').isdigit() else None,
                    row.get('Indexability', ''),
                    row.get('Indexability Status', ''),
                    row.get('Title 1', ''),
                    int(row.get('Title 1 Length', 0)) if row.get('Title 1 Length', '').isdigit() else None,
                    row.get('Meta Description 1', ''),
                    int(row.get('Meta Description 1 Length', 0)) if row.get('Meta Description 1 Length', '').isdigit() else None,
                    row.get('H1-1', ''),
                    int(row.get('H1-1 length', 0)) if row.get('H1-1 length', '').isdigit() else None,
                    int(row.get('Word Count', 0)) if row.get('Word Count', '').isdigit() else None,
                    int(row.get('Response Time', 0)) if row.get('Response Time', '').isdigit() else None,
                    int(row.get('Size (bytes)', 0)) if row.get('Size (bytes)', '').isdigit() else None,
                    row.get('Canonical Link Element 1', ''),
                    row.get('robots.txt', ''),
                    row.get('X-Robots-Tag 1', '')
                )
                pages_data.append(page_data)
        
        # Batch insert pages
        if pages_data:
            insert_query = """
                INSERT INTO pages (
                    crawl_id, url, status_code, indexability, indexability_status,
                    title, title_length, meta_description, meta_description_length,
                    h1, h1_count, word_count, response_time_ms, size_bytes,
                    canonical_link, robots_txt_status, x_robots_tag
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """
            db.execute_many(insert_query, pages_data)
            print(f"  ✓ Loaded {len(pages_data)} pages")
        
        return len(pages_data)
    
    except Exception as e:
        print(f"  ✗ Error processing CSV: {e}")
        raise

def update_crawl_summary(db: DatabaseConnection, crawl_id: int, total_pages: int):
    """Update crawl record with summary statistics"""
    query = """
        UPDATE crawls
        SET total_pages = %s,
            crawl_completed_at = %s
        WHERE crawl_id = %s
    """
    db.execute(query, (total_pages, datetime.now(), crawl_id))
    print(f"  ✓ Updated crawl summary")

# ============================================
# File Management
# ============================================

def archive_processed_files(source_path: Path, archive_base: Path):
    """Move processed files to archive directory"""
    try:
        # Create archive path maintaining date/domain structure
        relative_path = source_path.relative_to(source_path.parent.parent)
        archive_path = archive_base / relative_path
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        
        shutil.move(str(source_path), str(archive_path))
        print(f"  ✓ Archived to: {archive_path}")
    except Exception as e:
        print(f"  ⚠ Failed to archive files: {e}")

# ============================================
# Main ETL Process
# ============================================

def process_export_directory(db: DatabaseConnection, export_dir: Path, config: Dict):
    """Process all CSV exports in a directory"""
    
    # Look for date-based directories (YYYY_MM_DD format)
    date_dirs = [d for d in export_dir.iterdir() if d.is_dir() and len(d.name) == 10]
    
    if not date_dirs:
        print("⚠ No date directories found in export path")
        return
    
    for date_dir in sorted(date_dirs):
        crawl_date = date_dir.name.replace('_', '-')
        print(f"\n📅 Processing crawl date: {crawl_date}")
        
        # Look for domain directories
        domain_dirs = [d for d in date_dir.iterdir() if d.is_dir()]
        
        for domain_dir in domain_dirs:
            domain = domain_dir.name
            print(f"\n🌐 Processing domain: {domain}")
            
            try:
                # Get or create site and crawl records
                site_id = get_or_create_site(db, domain)
                crawl_id = get_or_create_crawl(db, site_id, crawl_date)
                
                # Find the internal_all.csv file
                csv_files = list(domain_dir.glob("*internal_all*.csv"))
                
                if not csv_files:
                    msg = f"No internal_all.csv found for {domain}"
                    print(f"  ⚠ {msg}")
                    log_etl_event(db, crawl_id, site_id, 'WARNING', msg, str(domain_dir))
                    continue
                
                # Process the CSV file
                csv_file = csv_files[0]
                total_pages = process_internal_all_csv(db, crawl_id, csv_file)
                
                # Update crawl summary
                update_crawl_summary(db, crawl_id, total_pages)
                
                # Log success
                log_etl_event(db, crawl_id, site_id, 'INFO', 
                            f'Successfully processed {total_pages} pages', str(csv_file))
                
                # Archive processed files if configured
                if config.get('archive_processed_files', True):
                    archive_base = Path(config.get('base_export_path')).parent / 'exports_archive'
                    archive_processed_files(domain_dir, archive_base)
                
            except Exception as e:
                msg = f"Failed to process {domain}: {str(e)}"
                print(f"  ✗ {msg}")
                try:
                    log_etl_event(db, None, None, 'ERROR', msg, str(domain_dir))
                except:
                    pass

# ============================================
# Main Entry Point
# ============================================

def main():
    print("\n" + "="*50)
    print("SEO Audit Pipeline - ETL Process")
    print("="*50 + "\n")
    
    # Load configuration
    config = load_config()
    
    # Get database credentials
    credentials = get_db_credentials(config)
    
    # Connect to database and process exports
    with DatabaseConnection(credentials) as db:
        export_path = Path(config['base_export_path'])
        
        if not export_path.exists():
            print(f"✗ Export directory not found: {export_path}")
            sys.exit(1)
        
        process_export_directory(db, export_path, config)
    
    print("\n" + "="*50)
    print("ETL Process Completed")
    print("="*50 + "\n")

if __name__ == "__main__":
    main()
