function out = robust_uint8(image,lowPercent,highPercent)
%ROBUST_UINT8 Percentile scaling without Statistics/Image Processing Toolbox.
if nargin<2, lowPercent=1; end
if nargin<3, highPercent=99; end
x=double(image); v=sort(x(isfinite(x)));
assert(~isempty(v),'Image has no finite samples.');
lo=v(max(1,min(numel(v),round(1+(numel(v)-1)*lowPercent/100))));
hi=v(max(1,min(numel(v),round(1+(numel(v)-1)*highPercent/100))));
if hi<=lo, hi=lo+1; end
out=uint8(255*min(1,max(0,(x-lo)/(hi-lo))));
end
