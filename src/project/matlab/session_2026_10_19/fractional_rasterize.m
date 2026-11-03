function image = fractional_rasterize(stream,linePeriod,width,height,startPhase)
%FRACTIONAL_RASTERIZE Form a raster while correcting accumulated line drift.
if nargin<5, startPhase=0; end
s=double(stream(:)); n=numel(s); image=zeros(height,width);
grid=(0:n).'; extended=[s;s(1)];
for y=0:height-1
    pos=mod(startPhase+y*linePeriod+(0:width-1),n);
    image(y+1,:)=interp1(grid,extended,pos,'linear');
end
end
