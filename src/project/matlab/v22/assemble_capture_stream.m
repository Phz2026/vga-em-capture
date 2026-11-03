function C = assemble_capture_stream(captureDir)
%ASSEMBLE_CAPTURE_STREAM Rebuild one exported V2.2 frame from ILA segments.
captureDir = char(captureDir);
meta = read_metadata(fullfile(captureDir,'metadata.txt'));
files = dir(fullfile(captureDir,'segment_*.csv'));
assert(~isempty(files),'No segment_*.csv files in %s',captureDir);
n = meta.line_samples*meta.frame_lines;
stream = zeros(n,1,'uint8'); seen = false(n,1);
for k=1:numel(files)
    [addr,data,valid] = read_ila_numeric(fullfile(files(k).folder,files(k).name));
    addr=addr(valid)+1; data=data(valid);
    keep=addr>=1 & addr<=n;
    stream(addr(keep))=uint8(data(keep)); seen(addr(keep))=true;
end
assert(all(seen),'Capture %s has %d missing samples.',captureDir,sum(~seen));
C.directory=string(captureDir); C.stream=stream; C.metadata=meta;
C.feature_mode=meta.feature_mode; C.line_samples=meta.line_samples;
C.frame_lines=meta.frame_lines; C.sample_rate_hz=65e6;
end

function meta=read_metadata(path)
assert(isfile(path),'Missing metadata.txt: %s',path);
lines=splitlines(string(fileread(path))); meta=struct();
for k=1:numel(lines)
    line=char(strtrim(lines(k))); eq=find(line=='=',1); if isempty(eq), continue; end
    key=matlab.lang.makeValidName(strtrim(line(1:eq-1))); value=string(strtrim(line(eq+1:end)));
    number=str2double(value);
    if ~isnan(number), meta.(key)=number; else, meta.(key)=value; end
end
required={'line_samples','frame_lines','feature_gain_q8','feature_mode'};
for k=1:numel(required), assert(isfield(meta,required{k}),'Missing metadata field %s',required{k}); end
end
