function A = analyze_raw_iq_v23(captureDir,outDir,makePlots)
%ANALYZE_RAW_IQ_V23 Inspect clipping, DC and spectrum of one raw-IQ capture.
if nargin<2,outDir=fullfile(captureDir,'analysis');end
if nargin<3,makePlots=true;end
if ~isfolder(outDir),mkdir(outDir);end
R=read_raw_iq_v23(captureDir);x=R.x-mean(R.x);n=numel(x);
w=0.5-0.5*cos(2*pi*(0:n-1)'/max(n-1,1));nfft=2^nextpow2(n);
X=fftshift(fft(x.*w,nfft));p=20*log10(abs(X)+eps);p=p-max(p);
f=(-nfft/2:nfft/2-1)'*R.fs/nfft;rf=R.rfCenter+f;
mask=abs(f)>0.1e6;[~,local]=max(p(mask));idx=find(mask);idx=idx(local);
A.capture=captureDir;A.samples=n;A.iMin=min(R.i);A.iMax=max(R.i);
A.qMin=min(R.q);A.qMax=max(R.q);A.clippedFraction=mean(abs(R.i)>=32767|abs(R.q)>=32767);
A.peakBasebandHz=f(idx);A.peakRfHz=rf(idx);A.peakDb=p(idx);
if makePlots
 fig=figure('Color','w','Visible','off');plot(rf/1e6,p,'LineWidth',0.8);grid on;
 xlabel('RF candidate (MHz)');ylabel('Relative amplitude (dB)');ylim([-120 3]);
 title(sprintf('Raw I/Q spectrum, peak %.6f MHz',A.peakRfHz/1e6));
 exportgraphics(fig,fullfile(outDir,'raw_iq_spectrum.png'),'Resolution',180);close(fig);
end
save(fullfile(outDir,'raw_iq_analysis.mat'),'A','R','f','rf','p','-v7.3');
fid=fopen(fullfile(outDir,'summary.txt'),'wt');cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'samples=%d\ni_min=%g\ni_max=%g\nq_min=%g\nq_max=%g\nclipped_fraction=%.9f\npeak_baseband_mhz=%.9f\npeak_rf_mhz=%.9f\n', ...
 A.samples,A.iMin,A.iMax,A.qMin,A.qMax,A.clippedFraction,A.peakBasebandHz/1e6,A.peakRfHz/1e6);
fprintf('RAW_IQ_ANALYSIS_PASS peak_rf=%.6f MHz clipped=%.6g\n',A.peakRfHz/1e6,A.clippedFraction);
end

