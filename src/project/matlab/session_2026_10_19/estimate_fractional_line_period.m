function result = estimate_fractional_line_period(stream,nominal,radius,step,maxSamples)
%ESTIMATE_FRACTIONAL_LINE_PERIOD Blind fractional line-period search.
% The score is normalized correlation between the stream and a fractional
% one-line delayed copy. It does not use a known displayed pattern.
if nargin<2, nominal=1344; end
if nargin<3, radius=0.15; end
if nargin<4, step=0.002; end
if nargin<5, maxSamples=300000; end
s=double(stream(:)); s=s-mean(s);
n=min(maxSamples,numel(s)-ceil(nominal+radius)-2);
base=(1:n).'; a=s(base); a=a-mean(a); na=norm(a);
periods=(nominal-radius):step:(nominal+radius); scores=zeros(size(periods));
grid=(1:numel(s)).';
for k=1:numel(periods)
    pos=base+periods(k);
    b=interp1(grid,s,pos,'linear'); b=b-mean(b);
    scores(k)=(a.'*b)/(na*norm(b)+eps);
end
[best,k]=max(scores);
result.period=periods(k); result.correlation=best;
result.periods=periods; result.scores=scores;
result.line_frequency_hz=65e6/result.period;
end
