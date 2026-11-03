function result = profile_sync(reference,test)
%PROFILE_SYNC Blind raster alignment using row and column mean profiles.
% No knowledge of the displayed image is used.
reference = double(reference); test = double(test);
assert(isequal(size(reference),size(test)),'Frame sizes must match.');
[dx,cx] = best_circular_shift(mean(reference,1),mean(test,1));
[dy,cy] = best_circular_shift(mean(reference,2),mean(test,2));
aligned = circshift(test,[-dy -dx]);
result.dx = dx; result.dy = dy;
result.x_correlation = cx; result.y_correlation = cy;
result.aligned = aligned;
end

function [shift,best] = best_circular_shift(a,b)
a = double(a(:)); b = double(b(:));
a = a-mean(a); b = b-mean(b);
na = norm(a); nb = norm(b);
if na==0 || nb==0
    shift=0; best=0; return;
end
a=a/na; b=b/nb;
n=numel(a); values=zeros(n,1);
for s=0:n-1
    values(s+1)=a.'*circshift(b,-s);
end
[best,i]=max(values); shift=i-1;
end
