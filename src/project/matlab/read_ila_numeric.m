function [addr, data, valid] = read_ila_numeric(csvFile)
%READ_ILA_NUMERIC Read address, data and valid probes from Vivado ILA CSV.
fid=fopen(csvFile,'rt');
assert(fid>=0,'Cannot open ILA CSV: %s',csvFile);
cleanup=onCleanup(@()fclose(fid));
header=fgetl(fid);
assert(ischar(header),'ILA CSV is empty: %s',csvFile);
names=split(string(header),',').';
lowerNames = lower(names);
dataCol = find(contains(lowerNames,'replay_data') | ...
               contains(lowerNames,'image_data') | contains(lowerNames,'probe0'),1);
addrCol = find(contains(lowerNames,'replay_addr') | ...
               contains(lowerNames,'image_addr') | contains(lowerNames,'probe1'),1);
validCol = find(contains(lowerNames,'replay_valid') | ...
                contains(lowerNames,'image_valid') | contains(lowerNames,'probe2'),1);
assert(~isempty(dataCol)&&~isempty(addrCol)&&~isempty(validCol), ...
    'ILA data/address/valid columns were not found in %s. Columns: %s', ...
    csvFile, strjoin(names,', '));
% Skip Vivado's second "Radix" row, then scan only the three required
% columns.  This avoids constructing a million-row table for every segment.
fgetl(fid);
selected=sort([dataCol addrCol validCol]);
formats=repmat("%*s",1,numel(names));formats(selected)="%s";
columns=textscan(fid,char(join(formats,"")),'Delimiter',',', ...
    'EndOfLine','\n','ReturnOnError',false);
data = parseHex(columns{find(selected==dataCol,1)});
addr = parseHex(columns{find(selected==addrCol,1)});
validRaw = parseHex(columns{find(selected==validCol,1)});
valid = isfinite(data) & isfinite(addr) & isfinite(validRaw) & validRaw~=0;
addr=double(addr(:)); data=double(data(:)); valid=logical(valid(:));
end
function y=parseHex(x)
if isnumeric(x), y=double(x); return; end
x=strip(string(x));
x=regexprep(x,'^0[xX]','');
x=regexprep(x,'[hH]$','');
x=erase(x,'_');
good=matches(x,regexpPattern('^[0-9A-Fa-f]+$'));
y=nan(size(x));
% hex2dec accepts a string array and performs the conversion in compiled
% code.  A per-cell MATLAB loop is prohibitively slow for multi-frame ILA
% captures (more than 13 million values in the V2.05 validation set).
y(good)=hex2dec(x(good));
end
