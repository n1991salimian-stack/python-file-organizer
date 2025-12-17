import os
import shutil
import re
import pandas as pd
from datetime import datetime

# --- Configuration ---
# Define folder paths (Use r'' for Windows paths to avoid escape errors)
INPUT_FOLDER = r'C:\ExperimentalDataProject\ExperimentalData'      # Raw data
ORGANIZED_FOLDER = r'C:\ExperimentalDataProject\OrganizedData'     # Renamed CSVs
TXT_FOLDER = r'C:\ExperimentalDataProject\TxtData'                 # Converted TXTs

# Create output folders if they don't exist
os.makedirs(ORGANIZED_FOLDER, exist_ok=True)
os.makedirs(TXT_FOLDER, exist_ok=True)

# --- Helper Functions ---

def extract_date_from_content(file_path):
    """Reads file content to find a date pattern like MM-DD-YYYY."""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                if 'Date:' in line:
                    match = re.search(r'Date:\s*(\d{2}-\d{2}-\d{4})', line)
                    if match:
                        date_str = match.group(1)
                        # Convert MM-DD-YYYY to YYYYMMDD
                        dt_obj = datetime.strptime(date_str, '%m-%d-%Y')
                        return dt_obj.strftime('%Y%m%d')
        return ''
    except Exception:
        return ''

def determine_variable_from_content(file_path):
    """Scans file content for keywords to determine the variable type."""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read().lower()
            
        if any(x in content for x in ['frequency', 'zplot', 'sweep']):
            return 'eis'
        elif 'current' in content and 'voltage' in content:
            return 'iv'
        elif 'ocv' in content or 'polar' in content:
            return 'polar'
        elif 'temp' in content or 'temperature' in content:
            return 'temperature'
        elif 'flow' in content or 'flw' in content:
            return 'flow'
        else:
            return 'misc'
    except Exception:
        return 'misc'

def parse_filename(filename, folder_path):
    """Extracts metadata (CellID, TestName, etc.) from filename and path."""
    name_lower = os.path.splitext(filename)[0].lower()
    full_path = os.path.join(folder_path, filename)
    
    # Defaults
    cell_id = 'UNKNOWN'
    test_name = 'unknown'
    variable = determine_variable_from_content(full_path)
    test_spec = 'T750Air100V07'
    operating_condition = 'OC'
    date_val = '20241218'

    # 1. Extract Date
    date_match = re.search(r'\d{8}|\d{4}\.\d{2}\.\d{2}', name_lower)
    if date_match:
        date_val = date_match.group(0).replace('.', '')
    else:
        content_date = extract_date_from_content(full_path)
        if content_date:
            date_val = content_date

    # 2. Extract CellID
    # Pattern looks for sh12, mf1-2, cell1, etc.
    cell_pattern = r'(sh\d+(-?\d+)?|mf\d+-\d+|b\d+|d\d+|ss\d+|c\d+|x\d+|t\d+|cell-?\d+|\d+)'
    cell_match = re.search(cell_pattern, name_lower)
    
    if cell_match:
        cell_id = cell_match.group(1).replace('-', '').upper()
    else:
        # Fallback: Check parent folder names
        # Split path into parts and iterate backwards
        path_parts = folder_path.replace('\\', '/').split('/')
        for part in reversed(path_parts):
            part_match = re.search(cell_pattern, part.lower())
            if part_match:
                cell_id = part_match.group(1).replace('-', '').upper()
                break
    
    if cell_id == 'UNKNOWN':
        # Try splitting filename by underscore or space
        parts = re.split(r'[_\s]', name_lower)
        if parts:
            cell_id = parts[0].upper()

    print(f"Info: CellID for file '{filename}' determined as '{cell_id}'")

    # 3. Determine TestName
    folder_lower = folder_path.lower()
    if any(x in folder_lower for x in ['hydrogen starvation', 'air starvation']) or 'starvation' in name_lower:
        test_name = 'starvation'
    elif 'short circuit' in folder_lower or 'short' in name_lower:
        test_name = 'short'
    elif any(x in folder_lower for x in ['thermal shock', 'thermal gradient', 'steady state']) or 'thermal' in name_lower:
        test_name = 'thermal'
    elif 'redox' in folder_lower or 'redox' in name_lower:
        test_name = 'redox'
    elif 'healthy' in name_lower:
        test_name = 'healthy'

    # 4. Refine Variable if 'misc'
    if variable == 'misc':
        if 'flow' in name_lower or 'flw' in name_lower:
            variable = 'flow'
        elif 'temp' in name_lower or 'temperature' in name_lower or re.search(r'\d{2,3}\s*t|\d{2,3}c', name_lower):
            variable = 'temperature'
        elif 'iv' in name_lower or 'vcte' in name_lower:
            variable = 'iv'
        elif any(x in name_lower for x in ['eis', 'icte', 'zplot', 'sweep frequency']):
            variable = 'eis'
        elif 'polar' in name_lower or 'ocv' in name_lower:
            variable = 'polar'
    
    print(f"Info: For file '{filename}', TestName: '{test_name}', Variable: '{variable}'")

    # 5. Extract TestSpec
    test_spec_parts = []
    
    temp_m = re.search(r'(\d{2,3})c|\d{2,3}\s*t', name_lower)
    if temp_m: test_spec_parts.append(f"T{temp_m.group(1) or temp_m.group(0)}") # logic simplified

    air_m = re.search(r'air\s*(\d+)|a\s*(\d+)', name_lower)
    if air_m: test_spec_parts.append(f"Air{air_m.group(1) or air_m.group(2)}")

    h2_m = re.search(r'h2\s*(\d+)|h\s*(\d+)', name_lower)
    if h2_m: test_spec_parts.append(f"H{h2_m.group(1) or h2_m.group(2)}")

    n2_m = re.search(r'n2\s*(\d+)|n\s*(\d+)', name_lower)
    if n2_m: test_spec_parts.append(f"N{n2_m.group(1) or n2_m.group(2)}")

    v_m = re.search(r'v\s*(\d+\.\d+)|e\s*=\s*(\d+\.\d+)', name_lower)
    if v_m: 
        val = v_m.group(1) or v_m.group(2)
        test_spec_parts.append(f"V{val.replace('.', '')}")

    if test_spec_parts:
        test_spec = "".join(test_spec_parts)

    # 6. Extract OperatingCondition
    if 'ocv' in name_lower or 'oc' in name_lower:
        operating_condition = 'OC'
    elif 'iv' in name_lower:
        operating_condition = 'IV'
    elif 'vcte' in name_lower or 'cycle' in name_lower:
        operating_condition = 'VCTE'
    elif any(x in name_lower for x in ['icte', 'eis', 'zplot', 'sweep frequency']):
        operating_condition = 'ICTE'
    elif 'heating' in name_lower or 'heat' in name_lower:
        operating_condition = 'HEAT'
    elif variable == 'temperature' and not any(x in name_lower for x in ['ocv', 'iv', 'eis']):
        operating_condition = 'TEMP'

    return cell_id, test_name, variable, test_spec, operating_condition, date_val

def remove_empty_folders(path):
    """Recursively removes empty folders."""
    if not os.path.isdir(path):
        return

    # Walk bottom-up
    for root, dirs, files in os.walk(path, topdown=False):
        for name in dirs:
            dir_path = os.path.join(root, name)
            try:
                # remove if empty
                if not os.listdir(dir_path): 
                    os.rmdir(dir_path)
                    print(f"Removed empty folder: {dir_path}")
            except OSError:
                pass

# --- Main Logic ---

def process_files():
    # os.walk traverses directory tree recursively
    for root, dirs, files in os.walk(INPUT_FOLDER):
        for filename in files:
            # Skip images
            if filename.lower().endswith(('.jpg', '.png', '.jpeg')):
                continue
            
            file_path = os.path.join(root, filename)
            
            # Parse filename
            cell_id, test_name, variable, test_spec, operating_condition, date_val = parse_filename(filename, root)
            
            # Construct new filename
            new_filename = f"{cell_id}_{test_name}_{variable}_{test_spec}_{operating_condition}_{date_val}.CSV"
            
            # Create destination folder
            dest_folder = os.path.join(ORGANIZED_FOLDER, test_name, variable)
            os.makedirs(dest_folder, exist_ok=True)
            
            dest_path = os.path.join(dest_folder, new_filename)
            
            # Copy file
            shutil.copy2(file_path, dest_path)
            print(f"File {filename} renamed and moved to {dest_path}")
            
            # --- Convert to .txt ---
            try:
                # Logic to skip header lines similar to MATLAB script
                # We read lines first to find where data starts
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                
                start_line = 0
                data_found = False
                
                # Simple heuristic to find header line
                for idx, line in enumerate(lines):
                    # Check for keywords or numeric data patterns
                    if 'E(Volts)' in line or 'Time' in line:
                        start_line = idx
                        data_found = True
                        break
                    # Check for lines that look like data (numbers separated by comma/space)
                    if re.search(r'[\d\s,.E+\-]+\s*,|[\d\s,.E+\-]+\s+[\d\s,.E+\-]', line):
                        # Assuming previous line might be header or this is data
                        start_line = idx 
                        data_found = True
                        break
                
                if data_found:
                    # Read using pandas
                    # sep regex handles space, tabs, or commas
                    df = pd.read_csv(file_path, skiprows=start_line, sep=r'\s+|\t|,', engine='python')
                    
                    if not df.empty:
                        txt_dest_folder = os.path.join(TXT_FOLDER, test_name, variable)
                        os.makedirs(txt_dest_folder, exist_ok=True)
                        
                        txt_filename = new_filename.replace('.CSV', '.txt')
                        txt_path = os.path.join(txt_dest_folder, txt_filename)
                        
                        # Save as tab-delimited txt without index
                        df.to_csv(txt_path, sep='\t', index=False, header=False)
                        print(f"Converted {new_filename} to {txt_path}")
                    else:
                        print(f"Warning: Empty dataframe for {filename}. Skipping conversion.")
                else:
                    print(f"Warning: No tabular data found in {filename}. Skipping conversion.")

            except Exception as e:
                print(f"Error converting {filename}: {e}")

    # Cleanup
    remove_empty_folders(ORGANIZED_FOLDER)
    remove_empty_folders(TXT_FOLDER)

if __name__ == "__main__":
    process_files()
