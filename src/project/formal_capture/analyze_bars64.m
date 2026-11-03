function R = analyze_bars64(captureDir, outDir, showFigure)
% Known 64-pixel bars diagnostic from one unchanged-screen frame.
% Period 128 is supplied by the selected test pattern, not inferred pixels.
if nargin < 3, showFigure = true; end
captureDir = char(captureDir); outDir = char(outDir);
root = fullfile(fileparts(mfilename('fullpath')),'..');
addpath(fullfile(root,'matlab'),fullfile(root,'matlab','v22'));
assert(~isfolder(outDir),'Output folder already exists: %s',outDir);
C = assemble_capture_stream(captureDir);
assert(C.feature_mode == 0 && C.line_samples == 1344 && C.frame_lines == 900, ...
    'Expected 1344x900 magnitude capture');
A = reshape(double(C.stream),1344,900).';
active = A(1:806,:);
profile = trimmedRows(active,0.10);
half1 = trimmedRows(active(1:403,:),0.10);
half2 = trimmedRows(active(404:806,:),0.10);
signal = bandResidual(profile);
h1 = bandResidual(half1); h2 = bandResidual(half2);
splitCorr = correlation(h1,h2);
periods = 80:180; scores = zeros(size(periods));
for j=1:numel(periods), scores(j) = lagCorrelation(signal,periods(j)); end
[peakScore,j] = max(scores); peakPeriod = periods(j);
folded = zeros(1,128);
for phase=1:128, folded(phase) = mean(signal(phase:128:end)); end
folded = folded-mean(folded);
projected = repmat(folded,1,ceil(numel(signal)/128));
projected = projected(1:numel(signal));
harmonic = abs(mean(signal.*exp(-2i*pi*(0:numel(signal)-1)/128)));
shape = squareScore(signal,128);

mkdir(outDir);
lim = max(1,percentile(abs(signal(:)),99));
toGray = @(x) uint8(round(max(0,min(255,127.5+110*x/lim))));
directImage = repmat(toGray(signal),768,1);
imwrite(directImage,fullfile(outDir,'bars_measured_profile.png'));
R = struct('capture_dir',captureDir,'out_dir',outDir, ...
    'split_half_correlation',splitCorr,'period_peak',peakPeriod, ...
    'period_peak_score',peakScore,'harmonic_128',harmonic, ...
    'square_shape_score',shape,'saturated_fraction',mean(C.stream(:)>=255), ...
    'uses_black_control',false,'known_pattern_period',128);
save(fullfile(outDir,'result.mat'),'R','signal','folded','projected', ...
    'periods','scores');
fid=fopen(fullfile(outDir,'metrics.txt'),'w');
assert(fid>0,'Cannot write metrics.txt');
fprintf(fid,['meaning=known_64px_bars_period_diagnostic_not_blind_image_recovery\n' ...
    'uses_black_control=0\nperiod_peak=%d\nperiod_peak_score=%.5f\n' ...
    'split_half_correlation=%.5f\nharmonic_128=%.6g\n' ...
    'square_shape_score=%.5f\nsaturated_fraction=%.6g\n'], ...
    peakPeriod,peakScore,splitCorr,harmonic,shape,R.saturated_fraction);
fclose(fid);
fprintf(['MANUAL_BARS_ANALYSIS_DONE=%s period=%d peak=%.4f ' ...
    'split=%.4f harmonic=%.6f shape=%.4f\n'], ...
    outDir,peakPeriod,peakScore,splitCorr,harmonic,shape);
if showFigure
    f=figure('Name','Single-frame known 64-pixel bars','NumberTitle','off', ...
        'Color','white');
    monitors=get(groot,'MonitorPositions'); primary=monitors(1,:);
    fw=min(1500,max(850,primary(3)-120));
    fh=min(750,max(500,primary(4)-160));
    f.Position=[primary(1)+40,primary(2)+max(40,primary(4)-fh-80),fw,fh];
    imagesc(directImage); axis image off; colormap(gray(256));
    title(sprintf('Measured horizontal profile | peak %d | half corr %.2f | unvalidated', ...
        peakPeriod,splitCorr));
    drawnow;
end
end

function p=trimmedRows(a,fraction)
s=sort(double(a),1); n=size(s,1); trim=floor(n*fraction);
p=mean(s(trim+1:n-trim,:),1);
end
function y=bandResidual(x)
y=movmean(x,9,2)-movmean(x,256,2);
end
function r=correlation(a,b)
a=a-mean(a); b=b-mean(b);
r=sum(a.*b)/(sqrt(sum(a.^2)*sum(b.^2))+eps);
end
function r=lagCorrelation(a,lag)
x=a(1:end-lag); y=a(1+lag:end);
r=sum(x.*y)/(sqrt(sum(x.^2)*sum(y.^2))+eps);
end
function c=squareScore(x,period)
x=x-mean(x); den=sqrt(sum(x.^2)*numel(x))+eps; c=0;
for phase=0:period-1
    template=2*(mod((0:numel(x)-1)+phase,period)<period/2)-1;
    value=sum(x.*template)/den;
    if abs(value)>abs(c), c=value; end
end
end
function value=percentile(x,p)
x=sort(double(x(:)));
value=x(max(1,min(numel(x),ceil(numel(x)*p/100))));
end
