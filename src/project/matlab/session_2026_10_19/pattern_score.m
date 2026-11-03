function result = pattern_score(frame,kind)
%PATTERN_SCORE Phase-independent score for the known validation patterns.
f=double(frame); kind=string(kind);
switch kind
    case "vertical_stripe16"
        period=32; p=mean(f,1); folded=fold1(p,period);
        template=[ones(1,16) -ones(1,16)];
        [corr,phase,contrast]=scan1(folded,template);
    case "horizontal_stripe8"
        period=16; p=mean(f,2).'; folded=fold1(p,period);
        template=[ones(1,8) -ones(1,8)];
        [corr,phase,contrast]=scan1(folded,template);
    case "checker16"
        period=32; folded=zeros(period); counts=zeros(period);
        [h,w]=size(f);
        for y=1:h, for x=1:w
            yy=mod(y-1,period)+1; xx=mod(x-1,period)+1;
            folded(yy,xx)=folded(yy,xx)+f(y,x); counts(yy,xx)=counts(yy,xx)+1;
        end, end
        folded=folded./max(counts,1);
        q=[ones(1,16) -ones(1,16)]; template=q.'*q;
        corr=-Inf; phase=[0 0]; contrast=0;
        z=folded-mean(folded(:));
        for dy=0:period-1, for dx=0:period-1
            t=circshift(template,[dy dx]); c=sum(z(:).*t(:))/(norm(z(:))*norm(t(:))+eps);
            if abs(c)>abs(corr) || isinf(corr), corr=c; phase=[dx dy]; contrast=abs(mean(z(t>0))-mean(z(t<0)))/2; end
        end, end
        corr=abs(corr);
    otherwise
        corr=NaN; phase=NaN; contrast=NaN; period=NaN; folded=[];
end
result.kind=kind; result.period=period; result.correlation=abs(corr);
result.phase=phase; result.contrast=contrast; result.folded=folded;
end

function folded=fold1(p,period)
folded=zeros(1,period); counts=zeros(1,period);
for k=1:numel(p), j=mod(k-1,period)+1; folded(j)=folded(j)+p(k); counts(j)=counts(j)+1; end
folded=folded./max(counts,1);
end
function [best,phase,contrast]=scan1(folded,template)
z=folded-mean(folded); best=-Inf; phase=0; contrast=0;
for s=0:numel(template)-1
    t=circshift(template,[0 s]); c=sum(z.*t)/(norm(z)*norm(t)+eps);
    if abs(c)>abs(best) || isinf(best), best=c; phase=s; contrast=abs(mean(z(t>0))-mean(z(t<0)))/2; end
end
best=abs(best);
end
