function image = fractional_raster(stream,linePeriod,width,height,startPhase)
%FRACTIONAL_RASTER Rasterize real or complex samples without cumulative skew.
if nargin<5, startPhase=0; end
s=double(stream(:)); n=numel(s); image=zeros(height,width,'like',s);
grid=(0:n).'; extended=[s;s(1)];
for y=0:height-1
    pos=mod(startPhase+y*linePeriod+(0:width-1),n);
    image(y+1,:)=interp1(grid,extended,pos,'linear');
end
end
