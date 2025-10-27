# 💼 Chiffon Cosmetics – Marketing Performance Analytics Dashboard

📑 Table of Contents  
- [Purpose & Business Value](#-purpose--business-value)  
- [Tools & Technical Approach](#-tools--technical-approach)  
- [Folder Structure](#-folder-structure)  
- [ETL / Data Pipeline](#-etl--data-pipeline)  
- [Power BI Dashboards](#-power-bi-dashboards)  
- [Summary](#-summary)  

⚠️ **Note:** This repository demonstrates a marketing analytics system. All campaign data has been replaced with mock datasets to illustrate the approach and technical design while protecting confidential business information.

---

## 🎯 Purpose & Business Value

The Marketing Performance Analytics Dashboard is a comprehensive solution built with Python, PostgreSQL, and Power BI to automate campaign performance tracking by integrating data from Google Ads (digital advertising), HubSpot CRM, and SAP ERP. It delivers key metrics including Return on Marketing Investment (ROMI), Impressions and Reach, Number of Leads Generated, Marketing Spend vs Budget, and other relevant KPIs.  

The system enables marketing teams to:  
- Consolidate marketing data from multiple platforms into a centralized, structured database  
- Automate performance calculations to evaluate campaign efficiency and ROI  
- Provide interactive dashboards for real-time marketing insights and decision support  
- Automate ETL workflows to extract, transform, and load marketing data without manual intervention  

By combining automated data pipelines, optimized database design, and interactive visualizations, the dashboard demonstrates how organizations can achieve data-driven decision-making with full visibility into marketing performance.

---

## 🛠 Tools & Technical Approach

This solution uses industry-standard technologies for data ingestion, storage, and visualization:

**Key Technologies:**  
- 🐍 Python – ETL scripting, data cleaning, and transformation  
- 🗄️ PostgreSQL – Central database for structured marketing data  
- 📊 Power BI – Interactive dashboards and reporting  
- 📁 CSV/Excel – Source data files from marketing platforms  

---

## 📂 Folder Structure

```
Chiffon-Marketing-Analytics-Dashboard/
├─ data/                     # Source CSV/Excel files
├─ python/                   # ETL and processing scripts (main.py, helpers)
├─ sql/                      # SQL queries and stored procedures
├─ chiffon_marketing_dashboard.pbix  # Power BI file
├─ README.md           
└─ videos/                   # short video capturing ETL and Dashboard Navigation
```

---

## 📊 ETL / Data Pipeline

**Data Sources:**  
- Google Ads – Campaign metrics: Impressions, Clicks, Cost, Conversions  
- HubSpot CRM – Lead generation and customer acquisition data  
- SAP ERP – Budget allocations and actual marketing spend  

**ETL Workflow:**  
1. Python scripts extract raw data from CSV/Excel exports  
2. Data is cleaned, validated, and transformed according to business rules  
3. Staging tables in PostgreSQL store transformed data temporarily  
4. Star schema database organizes data into fact and dimension tables  
5. Automated procedures refresh the reporting tables regularly, ensuring dashboards are always up-to-date  

**ETL Table (Source → Transform → Target)**

| Source System | ETL / Transformation Step | Target (PostgreSQL / Power BI) |
|---------------|--------------------------|--------------------------------|
| Google Ads    | Extract campaign metrics, clean data, calculate CTR | Staging |
| HubSpot CRM   | Extract leads/customers, remove duplicates, standardize fields | Staging |
| SAP ERP       | Extract budget/spending data, map to campaigns | Staging |
| PostgreSQL    | Join datasets, organize into star schema | Staging → Dimension → Fact |
| Power BI      | Query data, calculate KPIs (ROMI, Impressions, Leads) | Interactive dashboards |

---

### 🎥 Video of ETL / Data Pipeline → PowerBI Refresh and Navigation

[![Watch Video](https://img.youtube.com/vi/zHF1Lw1Dl8w/0.jpg)](https://youtu.be/zHF1Lw1Dl8w)

---

## ✅ Summary

This repository demonstrates a full marketing analytics workflow: from raw data extraction and automated ETL processing to interactive Power BI dashboards.  

It highlights:  
- Integration of multiple marketing and financial platforms  
- Automated data pipelines for consistent, error-free reporting  
- Real-time, interactive visualizations for data-driven decision-making  
- Clear tracking of marketing ROI and performance KPIs  

The project illustrates how organizations can transform scattered marketing data into actionable business intelligence.

---

## 📄 License

Copyright (c) 2025 Denis Ndegwa. All rights reserved.  
This work is proprietary and may not be reproduced, distributed, or used without express written permission from the author.  
Contact: dndegwa@gmail.com
