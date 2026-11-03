function S = render_raw_iq_strip_v24(captureDir,rfMHz,outPng)
%RENDER_RAW_IQ_STRIP_V24 Make an honest short raster from a 32768-point I/Q capture.
% The file covers only ~0.504 ms, roughly 24 VGA lines. It cannot represent
% a full frame. No known checkerboard pattern is used in this transformation.
R=read_raw_iq_v23(captureDir);
lineSamples=1344;
rows=floor(numel(R.x)/lineSamples);
assert(rows>=2,'Capture is too short for line folding');
x=double(R.x(:))-mean(double(R.x(:)));
n=numel(x); t=(0:n-1)'/R.fs;
offsetHz=rfMHz*1e6-R.rfCenter;
mixed=x.*exp(-1i*2*pi*offsetHz*t);
% Keep 3 MHz around the candidate, wide enough for the 16-pixel pattern's
% nominal 2.03125 MHz spatial component. This is a display diagnostic.
freq=(-floor(n/2):ceil(n/2)-1)'*R.fs/n;
pass=abs(freq)<=3e6;
z=ifft(ifftshift(fftshift(fft(mixed)).*pass));
raw=reshape(abs(z(1:rows*lineSamples)),lineSamples,rows)';
% Remove per-line baseline only for the contrast view. Preserve raw data
% and both normalizations in the MAT file so artifacts can be audited.
contrast=raw-median(raw,2);
lo=prctile(contrast(:),1); hi=prctile(contrast(:),99);
view=min(max((contrast-lo)/max(hi-lo,eps),0),1);
img=uint8(round(255*view));
imwrite(img,outPng);
imwrite(repelem(img,8,1),replace(outPng,'.png','_8x.png'));
S=struct('raw',raw,'contrast',contrast,'rfMHz',rfMHz,'rows',rows, ...
    'lineSamples',lineSamples,'spanMs',1000*numel(R.x)/R.fs, ...
    'outPng',string(outPng));
save(replace(outPng,'.png','.mat'),'S','-v7.3');
fprintf('SHORT_RASTER_SAVED %s rows=%d span_ms=%.6f rf_mhz=%.6f\n', ...
    outPng,rows,S.spanMs,rfMHz);
end
