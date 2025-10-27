"""
main_loader.py - Main data loading script
Purpose: Load CSV files and clean them using our cleaner module
Usage: python main_loader.py
"""

import pandas as pd
import cleaner as cl  # Import our cleaning module
from sqlalchemy import create_engine, text
import os

DATA_FILE_PATH = "../data/"
engine = create_engine('postgresql://postgres:postgres123@localhost:5432/Marketing_BW')

def load_and_clean_file(csv_filename):
    """
    Load a CSV file and clean it using our standard cleaner
    """
    print(f"Starting to process: {csv_filename}")
    print("=" * 50)
    
    # Step 1: Read the CSV file
    print("Reading CSV file...")
    try:
        raw_data = pd.read_csv(csv_filename)
        print(f"Successfully read {len(raw_data)} rows")
    except Exception as error:
        print(f"Failed to read file: {error}")
        return None, None
    
    # Step 2: Clean the data using our standard cleaner
    print("Cleaning data...")
    
    # Determine which numeric columns to use based on file type
    if "google_ads" in csv_filename:
        numeric_columns = ['Impressions', 'Clicks', 'Average CPC', 'Cost', 'Conversions', 'Conversion value', 'CTR']
    elif "sap" in csv_filename:
        numeric_columns = ['Amount in local currency', 'Budget', 'Variance']
    elif "hubspot" in csv_filename:
        numeric_columns = ['Recent deal amount']
    else:
        numeric_columns = None
    
    clean_data, problem_data = cl.clean_data(raw_data, numeric_columns=numeric_columns)
    
    # Step 3: Save the problem data for review
    if not problem_data.empty:
        cl.save_problem_data(problem_data, csv_filename) 
    
    # Step 4: Show results
    print("RESULTS:")
    print(f"Clean data: {len(clean_data)} rows")
    print(f"Problem data: {len(problem_data)} rows")
    print(f"Clean percentage: {(len(clean_data)/len(raw_data))*100:.1f}%")
    
    return clean_data, problem_data

# Main execution
if __name__ == "__main__":
    print("DATA LOADING SYSTEM STARTED")
    print("=" * 50)
    
    # Process each of our data files
    files_to_process = [
        os.path.join(DATA_FILE_PATH, "google_ads_campaign_performance_2025.csv"),
        os.path.join(DATA_FILE_PATH, "hubspot_contacts_export_2025.csv"), 
        os.path.join(DATA_FILE_PATH, "sap_co_actuals_vs_budget_2025.csv")
    ]

    all_clean_data = {}
    
    for file_name in files_to_process:
        print(f"PROCESSING: {file_name}")
        clean_data, problem_data = load_and_clean_file(file_name)
        
        if clean_data is not None:
            all_clean_data[file_name] = clean_data
        
        print("=" * 50)
    
    print("ALL FILES PROCESSED COMPLETELY!")
    print(f"Cleaned {len(all_clean_data)} files successfully")

    # Check if all data is clean before proceeding
    all_clean = True
    for file_name, clean_data in all_clean_data.items():
        original_rows = len(pd.read_csv(file_name))
        clean_rows = len(clean_data)
        if clean_rows < original_rows:
            print(f"WARNING: {file_name} has {original_rows - clean_rows} problem rows")
            all_clean = False

    if all_clean:
        print("ALL DATA 100% CLEAN - PROCEEDING TO DATABASE LOAD")
        # Step 5: Load clean data to PostgreSQL
        try:
            for file_name, clean_data in all_clean_data.items():
                if 'google_ads' in file_name:
                    clean_data.to_sql('stg_google_ads', engine, if_exists='replace', index=False)
                elif 'hubspot' in file_name:
                    clean_data.to_sql('stg_hubspot_contacts', engine, if_exists='replace', index=False)
                elif 'sap' in file_name:
                    clean_data.to_sql('stg_sap_financials', engine, if_exists='replace', index=False)
            
            print("DATA LOADED TO POSTGRESQL SUCCESSFULLY")
        
        # Step 6: Run ETL to populate data warehouse
            print("RUNNING ETL TO POPULATE DATA WAREHOUSE...")
            with engine.connect() as connection:
                connection.execute(text("CALL run_full_etl()"))
                connection.commit()
            print("DATA WAREHOUSE POPULATED SUCCESSFULLY!")

        except Exception as error:
            print(f"DATABASE LOAD FAILED: {error}")
    else:
        print("DATA NOT CLEAN - CHECK PROBLEM FILES BEFORE PROCEEDING")