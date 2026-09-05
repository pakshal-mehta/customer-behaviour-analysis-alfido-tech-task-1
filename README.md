# Customer Behavior Analysis — Alfido Tech (Task 1)

## Overview

This project delivers a comprehensive customer behavior analysis for an e-commerce platform. By leveraging a multi-step analytical pipeline involving Python for data manipulation, SQL for relational database querying, and exploratory data analysis (EDA), the project uncovers key purchasing patterns, customer segmentation traits, and actionable business insights to drive targeted marketing and inventory strategies.

---

## Dataset

* **Source Files:** `ecommerce_customer_data_custom_ratios.csv`, `Alfido_Tech_Customer_Data_Clean.xlsx`
* **Content:** Contains granular e-commerce transaction details, including customer demographics, purchase frequency, product category preferences, custom financial/behavioral ratios, and monetary value metrics.

---

## Tools & Technologies

* **Programming Language:** Python
* **Libraries:** Pandas, NumPy, Matplotlib, Seaborn
* **Database & Querying:** MySQL (`alfido_tech_analysis.sql`)
* **Environment:** Jupyter Notebook (`Alfido_Tech_Customer_Analytics.ipynb`)
* **Spreadsheet Analysis:** Microsoft Excel

---

## Project Workflow & Steps

1. **Data Loading & Inspection:** Loaded the raw e-commerce dataset into Python via Pandas to check data structures, missing values, and data types.
2. **Exploratory Data Analysis (EDA):** Visualized distributions and correlations to identify high-value customer segments and seasonal purchasing trends.
3. **Data Cleaning & Preprocessing:** Handled missing data, standardized formats, and engineered custom feature ratios, exporting the refined dataset (`Alfido_Tech_Customer_Data_Clean.xlsx`).
4. **SQL Analysis:** Migrated data or mirrored queries in MySQL (`alfido_tech_analysis.sql`) to extract aggregated metrics, ranking top customers and evaluating product performance through database queries.
5. **Insight Generation & Reporting:** Synthesized findings to formulate data-driven business recommendations.

---

## Dashboard & Visualizations

* Generated exploratory plots illustrating customer lifetime value (CLV), purchase distributions across demographics, and product category demand.
* *Note: Interactive summaries or visual exports can be integrated into a BI tool (like Tableau or Power BI) using the cleaned dataset.*

---

## Key Results & Insights

* **High-Value Segments:** Identified a core cohort of repeat buyers who account for a disproportionate share of total revenue.
* **Product Preferences:** Highlighted top-performing merchandise categories that drive peak seasonal transaction volumes.
* **Behavioral Ratios:** Custom ratio analysis revealed distinct purchasing velocity patterns, enabling more accurate customer lifetime value estimation.

---

## How to Run

1. **Clone the Repository:**
```bash
git clone <repository-url>

```


2. **Run the Python Analysis:**
* Open `Alfido_Tech_Customer_Analytics.ipynb` in Jupyter Notebook or JupyterLab.
* Ensure required libraries (`pandas`, `numpy`, `matplotlib`, `seaborn`) are installed.
* Run all cells sequentially to view the EDA and data cleaning pipeline.


3. **Execute SQL Queries:**
* Open your MySQL client or workbench.
* Import the dataset into your local database.
* Execute the scripts provided in `alfido_tech_analysis.sql` to verify aggregated business metrics.
