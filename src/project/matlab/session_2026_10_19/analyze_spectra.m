function peaks=analyze_spectra(outDir)
%ANALYZE_SPECTRA Plot every frequency-domain capture and extract its peak.
here=fileparts(mfilename('fullpath'));if nargin<1,outDir=fullfile(here,'results');end
if ~exist(outDir,'dir'),mkdir(outDir);end
S=load_spectra();n=numel(S.names);peakBaseband=zeros(n,1);peakRf=zeros(n,1);peakCode=zeros(n,1);carrier195Code=zeros(n,1);carrier195MHz=zeros(n,1);
for k=1:n
    y=double(S.spectra(:,k)); mask=abs(S.baseband_hz)>1e5;
    score=conv(y,ones(33,1),'same'); score(~mask)=-Inf;[~,center]=max(score);
    window=max(1,center-16):min(numel(y),center+16);[peakCode(k),j]=max(y(window));idx=window(j);
    peakBaseband(k)=S.baseband_hz(idx);peakRf(k)=S.rf_hz(idx);
    carrierMask=abs(S.rf_hz-195e6)<=50e3; candidates=find(carrierMask);
    [carrier195Code(k),j]=max(y(candidates));carrier195MHz(k)=S.rf_hz(candidates(j))/1e6;
end
peaks=table(S.names,S.kinds,peakCode,peakBaseband/1e6,peakRf/1e6,carrier195Code,carrier195MHz, ...
    'VariableNames',{'capture','kind','global_peak_code','global_peak_baseband_mhz','global_estimated_rf_mhz','carrier_195_code','carrier_195_frequency_mhz'});
writetable(peaks,fullfile(outDir,'spectrum_peaks.csv'));
figure('Color','w','Name','Spectrum captures');tiledlayout(n,1,'TileSpacing','compact');
for k=1:n,nexttile;plot(fftshift(S.baseband_hz)/1e6,fftshift(double(S.spectra(:,k))));grid on;xlim([-32.5 32.5]);ylabel(S.names(k),'Interpreter','none');end
xlabel('Baseband frequency (MHz)');exportgraphics(gcf,fullfile(outDir,'all_spectra.png'),'Resolution',150);
end
