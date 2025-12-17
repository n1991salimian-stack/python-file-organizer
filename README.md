# Experimental Data Organizer & Converter (Python)

This repository contains a **Python script** designed to automate the preprocessing, organization, renaming, and conversion of raw experimental data files. It is optimized for handling large datasets from sensor tests, electrochemical experiments (EIS, IV curves), and stress tests.

## Key Features

* **Automated Organization:** Recursively scans directories to identify raw data files and sorts them into a structured hierarchy (`TestName/Variable`).
* **Smart Metadata Extraction:** Uses **Regex** to parse filenames and file content to extract:
    * `CellID` (e.g., Cell-1, MF1-2)
    * `TestName` (e.g., Redox, Starvation, Thermal)
    * `Variable` (e.g., Flow, Temperature, IV, EIS)
    * `TestSpec` & `Operating Conditions`
* **Data Cleaning & Conversion:** * Detects the start of tabular data automatically.
    * Converts raw formats into clean, tab-delimited `.txt` files using **Pandas**.
    * Removes empty directories to keep the workspace clean.

##  Prerequisites

To run this script, you need Python installed along with the `pandas` library.

```bash
pip install pandas
