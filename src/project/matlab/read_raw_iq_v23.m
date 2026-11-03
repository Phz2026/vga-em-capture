function R = read_raw_iq_v23(captureDir)
%READ_RAW_IQ_V23 Load a V2.3 post-halfband, pre-DDC raw-IQ capture.
csvFile=fullfile(captureDir,'raw_iq.csv');
assert(isfile(csvFile),'Missing raw_iq.csv: %s',captureDir);
fid=fopen(csvFile,'rt'); assert(fid>=0,'Cannot open %s',csvFile);
cleanup=onCleanup(@()fclose(fid));
header=fgetl(fid); names=split(string(header),',').'; low=lower(names);
iCol=find(contains(low,'raw_replay_i')|contains(low,'probe0'),1);
qCol=find(contains(low,'raw_replay_q')|contains(low,'probe1'),1);
aCol=find(contains(low,'raw_replay_addr')|contains(low,'probe2'),1);
vCol=find(contains(low,'raw_replay_valid')|contains(low,'probe3'),1);
assert(~isempty(iCol)&&~isempty(qCol)&&~isempty(aCol)&&~isempty(vCol), ...
    'Raw-IQ ILA columns were not found. Columns: %s',strjoin(names,', '));
fgetl(fid);
selected=sort([iCol qCol aCol vCol]);
formats=repmat("%*s",1,numel(names)); formats(selected)="%s";
c=textscan(fid,char(join(formats,"")),'Delimiter',',','EndOfLine','\n','ReturnOnError',false);
ival=parseHex(c{find(selected==iCol,1)});
qval=parseHex(c{find(selected==qCol,1)});
addr=parseHex(c{find(selected==aCol,1)});
valid=parseHex(c{find(selected==vCol,1)});
keep=isfinite(ival)&isfinite(qval)&isfinite(addr)&isfinite(valid)&valid~=0;
ival=ival(keep);qval=qval(keep);addr=addr(keep);
% V2.4's replay registers data, address and valid on the same edge.  ILA
% observes the new address alongside the previous data: CSV labels are
% 1,2,...,N-1,N-1 for N valid replay words in buffer order.  Relabel only
% this exact measured pattern; this does not certify that the first RAM word
% contains a genuine ADC sample, and arbitrary gaps still raise an error.
n=numel(addr);
if n>1 && all(addr(:)==min((1:n)',n-1))
    addr=(0:n-1)';
    addressMode='ila_address_one_cycle_ahead';
else
    [addr,order]=sort(addr);ival=ival(order);qval=qval(order);
    [addr,uniqueIndex]=unique(addr,'stable');ival=ival(uniqueIndex);qval=qval(uniqueIndex);
    addressMode='address_column';
end
assert(all(addr(:)==(0:numel(addr)-1).'),'Raw-IQ addresses are incomplete or non-contiguous');
ival(ival>=32768)=ival(ival>=32768)-65536;
qval(qval>=32768)=qval(qval>=32768)-65536;
R.i=ival(:); R.q=qval(:); R.x=complex(R.i,R.q); R.addr=addr(:);
R.fs=65e6; R.rfCenter=200e6; R.csvFile=csvFile; R.addressMode=addressMode;
end
function y=parseHex(x)
x=strip(string(x));x=regexprep(x,'^0[xX]','');x=regexprep(x,'[hH]$','');x=erase(x,'_');
good=matches(x,regexpPattern('^[0-9A-Fa-f]+$'));y=nan(size(x));y(good)=hex2dec(x(good));
end

