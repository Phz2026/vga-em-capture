function recovered = recover_frame(captureDir, outPng)
%RECOVER_FRAME Assemble ILA segments, estimate cyclic VGA phase, and enhance.
if nargin<2, outPng=fullfile(captureDir,'recovered.png'); end
files=dir(fullfile(captureDir,'segment_*.csv'));
assert(~isempty(files),'No segment CSV files found');
lineSamples=1344; frameLines=806;
metaFile=fullfile(captureDir,'metadata.txt');
if isfile(metaFile)
    meta=readlines(metaFile);
    lineEntry=meta(startsWith(meta,'line_samples='));
    frameEntry=meta(startsWith(meta,'frame_lines='));
    if ~isempty(lineEntry), lineSamples=str2double(extractAfter(lineEntry(1),'=')); end
    if ~isempty(frameEntry), frameLines=str2double(extractAfter(frameEntry(1),'=')); end
end
assert(isfinite(lineSamples)&&isfinite(frameLines)&&lineSamples>=1024&&frameLines>=768, ...
    'Invalid frame geometry in metadata');
n=lineSamples*frameLines;
pixels=zeros(n,1,'uint8'); seen=false(n,1);
for k=1:numel(files)
    [a,d,v]=read_ila_numeric(fullfile(files(k).folder,files(k).name));
    a=a(v)+1; d=d(v); keep=a>=1 & a<=n;
    pixels(a(keep))=uint8(d(keep)); seen(a(keep))=true;
end
assert(all(seen),'Frame has %d missing pixels; repeat the missing segment capture',sum(~seen));
raw=double(reshape(pixels,[lineSamples,frameLines])');
raw=(raw-prctile(raw(:),1))/max(eps,prctile(raw(:),99)-prctile(raw(:),1));
raw=min(max(raw,0),1);
% Command start is not VGA phase locked. Find the cyclic 1024x768 window with
% the largest horizontal and vertical gradient energy.
gx=mean(abs(diff(raw,1,2)),1); gy=mean(abs(diff(raw,1,1)),2)';
x0=bestCircularWindow(gx,1024); y0=bestCircularWindow(gy,768);
xidx=mod((x0-1)+(0:1023),lineSamples)+1;
yidx=mod((y0-1)+(0:767),frameLines)+1;
recovered=raw(yidx,xidx);
if exist('medfilt2','file'), recovered=medfilt2(recovered,[3 3],'symmetric'); end
if exist('adapthisteq','file'), recovered=adapthisteq(recovered,'ClipLimit',0.01); end
imwrite(recovered,outPng); save(fullfile(captureDir,'recovery.mat'),'raw','recovered','x0','y0');
figure('Color','w'); imagesc(recovered); axis image off; colormap gray;
title(sprintf('Recovered leakage image, cyclic offset=(%d,%d)',x0,y0));
end
function start=bestCircularWindow(v,w)
n=numel(v); vv=[v(:);v(:)]; cs=[0;cumsum(vv)];
s=cs((1:n)+w)-cs(1:n); [~,start]=max(s);
end
