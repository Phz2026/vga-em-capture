function A = profile_align_quality(reference,test)
%PROFILE_ALIGN_QUALITY Blind row/column synchronization plus quality gate.
r=abs(double(reference)); t=abs(double(test));
[dx,cx]=best_shift(mean(r,1),mean(t,1));
[dy,cy]=best_shift(mean(r,2),mean(t,2));
aligned=circshift(test,[-dy -dx]);
ra=remove_row_col(abs(double(reference))); ta=remove_row_col(abs(double(aligned)));
imageCorr=(ra(:).'*ta(:))/(norm(ra(:))*norm(ta(:))+eps);
A.dx=dx; A.dy=dy; A.x_correlation=cx; A.y_correlation=cy;
A.image_correlation=imageCorr; A.accepted=(cx>=0.55 && cy>=0.25 && imageCorr>=0.08);
A.aligned=aligned;
end

function z=remove_row_col(x)
z=x-mean(x,1)-mean(x,2)+mean(x(:));
end
function [shift,best]=best_shift(a,b)
a=double(a(:)); b=double(b(:)); a=a-mean(a); b=b-mean(b);
if norm(a)==0 || norm(b)==0, shift=0; best=0; return; end
a=a/norm(a); b=b/norm(b); n=numel(a); scores=zeros(n,1);
for s=0:n-1, scores(s+1)=a.'*circshift(b,-s); end
[best,k]=max(scores); shift=k-1;
end
