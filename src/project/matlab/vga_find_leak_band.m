function F = vga_find_leak_band(signalDirs,backgroundDirs,outDir,makePlot)
%VGA_FIND_LEAK_BAND Rank repeatable content-dependent RF candidates.
% This is a software search aid, not proof that a peak originates in VGA.
signalDirs=string(signalDirs); backgroundDirs=string(backgroundDirs);
assert(numel(signalDirs)>=2 && numel(backgroundDirs)>=2, ...
    'At least two captures per condition are required');
if nargin<4, makePlot=true; end
if ~isfolder(outDir), mkdir(outDir); end
[sigDb,rf]=spectra(signalDirs);
[bgDb,rfBg]=spectra(backgroundDirs);
assert(isequal(rf,rfBg),'Capture groups have different sample geometry');
delta=median(sigDb,2)-median(bgDb,2);
spread=max(sigDb,[],2)-min(sigDb,[],2) + ...
       max(bgDb,[],2)-min(bgDb,[],2);
% A local median reduces single-bin noise while preserving narrow peaks.
score=movmedian(delta,9)-0.5*movmedian(spread,9);
score(abs(rf-200e6)<0.10e6)=-inf; % Exclude the DC spur.
score(rf<135e6 | rf>265e6)=-inf;
maxCandidates=10; exclusionHz=0.25e6;
rows=zeros(0,4); available=score;
for k=1:maxCandidates
    [best,idx]=max(available);
    if ~isfinite(best), break; end
    % Report the unsmoothed local peak frequency; smoothing is only used to
    % rank the band and can shift a narrow tone by several FFT bins.
    local=abs(rf-rf(idx))<=0.10e6;
    localIdx=find(local);
    [~,peakAt]=max(delta(local));
    peakIdx=localIdx(peakAt);
    rows(end+1,:)=[rf(peakIdx)/1e6,delta(peakIdx),spread(peakIdx),best]; %#ok<AGROW>
    available(abs(rf-rf(peakIdx))<=exclusionHz)=-inf;
end
F=struct('rfHz',rf,'deltaDb',delta,'scoreDb',score, ...
    'candidates',array2table(rows,'VariableNames', ...
    {'rf_mhz','median_delta_db','repeat_spread_db','score_db'}));
F.promising=~isempty(rows) && rows(1,4)>=3;
writetable(F.candidates,fullfile(outDir,'ranked_candidates.csv'));
if makePlot
    fig=figure('Visible','off','Color','w');
    plot(rf/1e6,delta,'Color',[0.65 0.65 0.65]); hold on;
    plot(rf/1e6,score,'b'); grid on;
    xlabel('RF frequency (MHz)'); ylabel('Content-dependent difference (dB)');
    legend('Median difference','Repeatability-adjusted score','Location','best');
    exportgraphics(fig,fullfile(outDir,'candidate_spectrum.png'),'Resolution',180);
    close(fig);
end
save(fullfile(outDir,'candidate_analysis.mat'),'F','-v7.3');
if F.promising
    fprintf('LEAK_BAND_CANDIDATE %.6f MHz score %.2f dB; confirm with independent A/B controls\n', ...
        rows(1,1),rows(1,4));
else
    fprintf('LEAK_BAND_NOT_CONFIRMED: no repeatable candidate above 3 dB\n');
end
end

function [db,rf]=spectra(dirs)
db=[]; rf=[];
for k=1:numel(dirs)
    R=read_raw_iq_v23(dirs(k));
    x=R.x(:)-mean(R.x);
    n=numel(x);
    if isempty(rf)
        nfft=2^nextpow2(n);
        rf=R.rfCenter+(-nfft/2:nfft/2-1)'*R.fs/nfft;
        db=zeros(nfft,numel(dirs));
    else
        assert(n==firstN && R.fs==firstFs && R.rfCenter==firstCenter, ...
            'All raw-IQ captures must use the same sample count and configuration');
    end
    if k==1, firstN=n; firstFs=R.fs; firstCenter=R.rfCenter; end
    w=0.5-0.5*cos(2*pi*(0:n-1)'/max(n-1,1));
    p=abs(fftshift(fft(x.*w,nfft))).^2/(sum(w.^2)+eps);
    db(:,k)=10*log10(p+eps);
end
end
