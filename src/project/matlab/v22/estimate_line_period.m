function R = estimate_line_period(stream,nominal)
%ESTIMATE_LINE_PERIOD Blind integer search followed by fractional refinement.
s=double(stream(:)); s=s-mean(s);
% Real monitor/pixel clocks can differ enough that a +/-1-sample search around
% the nominal 1344 value misses the peak completely.  Search +/-6 percent at
% integer resolution first, then refine only around the winning lag.
span=max(4,ceil(0.06*nominal));
integerPeriods=max(2,floor(nominal-span)):ceil(nominal+span);
maxN=min(350000,numel(s)-max(integerPeriods)-2);
assert(maxN>10000,'Stream is too short for line-period estimation.');
integerScore=score_integer_periods(s,integerPeriods,maxN);
[~,ii]=max(integerScore); integerCenter=integerPeriods(ii);
coarse=(integerCenter-1.0):0.02:(integerCenter+1.0);
coarseScore=score_periods(s,coarse,maxN);
[~,i]=max(coarseScore); center=coarse(i);
fine=(center-0.03):0.001:(center+0.03);
fineScore=score_periods(s,fine,maxN);
[best,j]=max(fineScore);
R.period=fine(j); R.correlation=best; R.line_frequency_hz=65e6/R.period;
R.periods=fine; R.scores=fineScore;
R.integer_periods=integerPeriods; R.integer_scores=integerScore;
end

function scores=score_integer_periods(s,periods,n)
a=s(1:n); a=a-mean(a); na=norm(a); scores=zeros(size(periods));
for k=1:numel(periods)
    lag=periods(k); b=s((1:n)+lag); b=b-mean(b);
    scores(k)=(a.'*b)/(na*norm(b)+eps);
end
end

function scores=score_periods(s,periods,n)
base=(1:n).'; grid=(1:numel(s)).'; a=s(base); a=a-mean(a); na=norm(a);
scores=zeros(size(periods));
for k=1:numel(periods)
    b=interp1(grid,s,base+periods(k),'linear'); b=b-mean(b);
    scores(k)=(a.'*b)/(na*norm(b)+eps);
end
end
