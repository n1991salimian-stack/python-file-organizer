% This script organizes experimental data files, renames them based on test criteria,
% and converts them to .txt format for easier data management.

% Define folder paths (same as Python script)
inputFolder = 'C:\ExperimentalDataProject\ExperimentalData'; % Where the raw data files are stored
organizedFolder = 'C:\ExperimentalDataProject\OrganizedData'; % Where renamed .CSV files will be saved
txtFolder = 'C:\ExperimentalDataProject\TxtData'; % Where .txt files will be saved

% Create output folders if they don’t exist
if ~exist(organizedFolder, 'dir')
    mkdir(organizedFolder);
end
if ~exist(txtFolder, 'dir')
    mkdir(txtFolder);
end

% List of possible test types and variables
testNames = {'redox', 'starvation', 'short', 'thermal', 'healthy'};
variables = {'flow', 'temperature', 'iv', 'eis', 'polar'};

% Function to extract date from file content
function dateStr = extractDateFromContent(filePath)
    try
        fileID = fopen(filePath, 'r', 'n', 'UTF-8');
        while ~feof(fileID)
            line = fgetl(fileID);
            if contains(line, 'Date:')
                dateMatch = regexp(line, 'Date:\s*(\d{2}-\d{2}-\d{4})', 'tokens');
                if ~isempty(dateMatch)
                    dateStr = datestr(datenum(dateMatch{1}{1}, 'mm-dd-yyyy'), 'yyyymmdd');
                    fclose(fileID);
                    return;
                end
            end
        end
        fclose(fileID);
        dateStr = '';
    catch
        dateStr = '';
    end
end

% Function to determine variable from file content
function var = determineVariableFromContent(filePath)
    try
        fileID = fopen(filePath, 'r', 'n', 'UTF-8');
        content = fread(fileID, '*char')';
        fclose(fileID);
        content = lower(content);
        if contains(content, 'frequency') || contains(content, 'zplot') || contains(content, 'sweep')
            var = 'eis';
        elseif contains(content, 'current') && contains(content, 'voltage')
            var = 'iv';
        elseif contains(content, 'ocv') || contains(content, 'polar')
            var = 'polar';
        elseif contains(content, 'temp') || contains(content, 'temperature')
            var = 'temperature';
        elseif contains(content, 'flow') || contains(content, 'flw')
            var = 'flow';
        else
            var = 'misc';
        end
    catch
        var = 'misc';
    end
end

% Function to parse filename and extract details
function [cellID, testName, variable, testSpec, operatingCondition, date] = parseFilename(filename, folderPath)
    name = lower(extractBefore(filename, '.'));
    cellID = 'UNKNOWN';
    testName = 'unknown';
    variable = determineVariableFromContent(fullfile(folderPath, filename));
    testSpec = 'T750Air100V07';
    operatingCondition = 'OC';
    date = '20241218';
    
    % Extract date
    dateMatch = regexp(name, '\d{8}|\d{4}\.\d{2}\.\d{2}', 'match');
    if ~isempty(dateMatch)
        date = strrep(dateMatch{1}, '.', '');
    else
        dateContent = extractDateFromContent(fullfile(folderPath, filename));
        if ~isempty(dateContent)
            date = dateContent;
        end
    end
    
    % Extract CellID
    cellMatch = regexp(name, '(sh\d+(-?\d+)?|mf\d+-\d+|b\d+|d\d+|ss\d+|c\d+|x\d+|t\d+|cell-?\d+|\d+)', 'match');
    if ~isempty(cellMatch)
        cellID = upper(strrep(cellMatch{1}, '-', ''));
    else
        pathParts = strsplit(folderPath, filesep);
        for i = length(pathParts):-1:1
            cellMatch = regexp(pathParts{i}, '(sh\d+(-?\d+)?|mf\d+-\d+|b\d+|d\d+|ss\d+|c\d+|x\d+|t\d+|cell-?\d+|\d+)', 'match');
            if ~isempty(cellMatch)
                cellID = upper(strrep(cellMatch{1}, '-', ''));
                break;
            end
        end
    end
    
    if strcmp(cellID, 'UNKNOWN')
        nameParts = strsplit(name, '_');
        if ~isempty(nameParts)
            cellID = upper(nameParts{1});
        else
            nameParts = strsplit(name, ' ');
            if ~isempty(nameParts)
                cellID = upper(nameParts{1});
            end
        end
    end
    fprintf('Info: CellID for file ''%s'' determined as ''%s''\n', filename, cellID);
    
    % Determine TestName
    folderLower = lower(folderPath);
    if contains(folderLower, 'hydrogen starvation') || contains(folderLower, 'air starvation') || contains(name, 'starvation')
        testName = 'starvation';
    elseif contains(folderLower, 'short circuit') || contains(name, 'short')
        testName = 'short';
    elseif contains(folderLower, 'thermal shock') || contains(folderLower, 'thermal gradient') || contains(name, 'thermal') || contains(folderLower, 'steady state')
        testName = 'thermal';
    elseif contains(folderLower, 'redox') || contains(name, 'redox')
        testName = 'redox';
    elseif contains(name, 'healthy')
        testName = 'healthy';
    end
    
    % If variable not determined from content, try from filename
    if strcmp(variable, 'misc')
        if contains(name, 'flow') || contains(name, 'flw')
            variable = 'flow';
        elseif contains(name, 'temp') || contains(name, 'temperature') || ~isempty(regexp(name, '\d{2,3}\s*t|\d{2,3}c', 'once'))
            variable = 'temperature';
        elseif contains(name, 'iv') || contains(name, 'vcte')
            variable = 'iv';
        elseif contains(name, 'eis') || contains(name, 'icte') || contains(name, 'zplot') || contains(name, 'sweep frequency')
            variable = 'eis';
        elseif contains(name, 'polar') || contains(name, 'ocv')
            variable = 'polar';
        end
    end
    fprintf('Info: For file ''%s'', TestName: ''%s'', Variable: ''%s''\n', filename, testName, variable);
    
    % Extract TestSpec
    tempMatch = regexp(name, '(\d{2,3})c|\d{2,3}\s*t', 'tokens');
    airMatch = regexp(name, 'air\s*(\d+)|a\s*(\d+)', 'tokens');
    h2Match = regexp(name, 'h2\s*(\d+)|h\s*(\d+)', 'tokens');
    n2Match = regexp(name, 'n2\s*(\d+)|n\s*(\d+)', 'tokens');
    vMatch = regexp(name, 'v\s*(\d+\.\d+)|e\s*=\s*(\d+\.\d+)', 'tokens');
    
    testSpecParts = {};
    if ~isempty(tempMatch)
        testSpecParts{end+1} = ['T' tempMatch{1}{1}];
    end
    if ~isempty(airMatch)
        airValue = airMatch{1}{1};
        testSpecParts{end+1} = ['Air' airValue];
    end
    if ~isempty(h2Match)
        h2Value = h2Match{1}{1};
        testSpecParts{end+1} = ['H' h2Value];
    end
    if ~isempty(n2Match)
        n2Value = n2Match{1}{1};
        testSpecParts{end+1} = ['N' n2Value];
    end
    if ~isempty(vMatch)
        vValue = vMatch{1}{1};
        testSpecParts{end+1} = ['V' strrep(vValue, '.', '')];
    end
    
    if ~isempty(testSpecParts)
        testSpec = strjoin(testSpecParts, '');
    end
    
    % Extract OperatingCondition
    if contains(name, 'ocv') || contains(name, 'oc')
        operatingCondition = 'OC';
    elseif contains(name, 'iv')
        operatingCondition = 'IV';
    elseif contains(name, 'vcte') || contains(name, 'cycle')
        operatingCondition = 'VCTE';
    elseif contains(name, 'icte') || contains(name, 'eis') || contains(name, 'zplot') || contains(name, 'sweep frequency')
        operatingCondition = 'ICTE';
    elseif contains(name, 'heating') || contains(name, 'heat')
        operatingCondition = 'HEAT';
    elseif strcmp(variable, 'temperature') && ~any(contains(name, {'ocv', 'oc', 'iv', 'vcte', 'cycle', 'icte', 'eis', 'zplot', 'sweep frequency', 'heating', 'heat'}))
        operatingCondition = 'TEMP';
    end
end

% Process all files
fileList = dir(fullfile(inputFolder, '**\*.*')); % Include all files in subfolders
for i = 1:length(fileList)
    if fileList(i).isdir || endsWith(lower(fileList(i).name), {'.jpg', '.png', '.jpeg'})
        continue;
    end
    
    filePath = fullfile(fileList(i).folder, fileList(i).name);
    [cellID, testName, variable, testSpec, operatingCondition, date] = parseFilename(fileList(i).name, fileList(i).folder);
    
    newFilename = [cellID '_' testName '_' variable '_' testSpec '_' operatingCondition '_' date '.CSV'];
    destFolder = fullfile(organizedFolder, testName, variable);
    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end
    
    destPath = fullfile(destFolder, newFilename);
    copyfile(filePath, destPath);
    fprintf('File %s renamed and moved to %s\n', fileList(i).name, destPath);
    
    % Convert to .txt
    try
        data = readtable(filePath, 'Delimiter', '\s+|\t|,', 'HeaderLines', 0, 'ReadVariableNames', false);
        startLine = 1;
        dataFound = false;
        for j = 1:size(data, 1)
            if contains(string(data{j,1}), {'E(Volts)', 'Time'}) || ~isempty(regexp(string(data{j,1}), '[\d\s,.E+\-]+\s*,|[\d\s,.E+\-]+\s+[\d\s,.E+\-]'))
                startLine = j;
                dataFound = true;
                break;
            end
        end
        
        if dataFound
            data = data(startLine:end, :);
            if ~isempty(data)
                txtDestFolder = fullfile(txtFolder, testName, variable);
                if ~exist(txtDestFolder, 'dir')
                    mkdir(txtDestFolder);
                end
                txtPath = fullfile(txtDestFolder, strrep(newFilename, '.CSV', '.txt'));
                writetable(data, txtPath, 'Delimiter', '\t', 'WriteVariableNames', false);
                fprintf('Converted %s to %s\n', newFilename, txtPath);
            else
                fprintf('Warning: No valid data extracted from %s. Skipping conversion.\n', fileList(i).name);
            end
        else
            fprintf('Warning: No tabular data found in %s. Skipping conversion.\n', fileList(i).name);
        end
    catch e
        fprintf('Error converting %s: %s\n', fileList(i).name, e.message);
    end
end

% Remove empty folders
function removeEmptyFolders(path)
    dirs = dir(path);
    for i = length(dirs):-1:1
        if dirs(i).isdir && ~strcmp(dirs(i).name, '.') && ~strcmp(dirs(i).name, '..')
            subPath = fullfile(path, dirs(i).name);
            removeEmptyFolders(subPath);
            if isempty(dir(subPath))
                rmdir(subPath);
                fprintf('Removed empty folder: %s\n', subPath);
            end
        end
    end
end

removeEmptyFolders(organizedFolder);
removeEmptyFolders(txtFolder);