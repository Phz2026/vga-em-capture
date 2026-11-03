function C = compare_raw_iq_v23(signalDirs,backgroundDirs,outDir,makePlots)
%COMPARE_RAW_IQ_V23 Rank bands that change with displayed content.
signalDirs=string(signalDirs);backgroundDirs=string(backgroundDirs);
assert(~isempty(signalDirs)&&~isempty(backgroundDirs),'Both capture groups are required');
if nargin<4,makePlots=true;end
if ~isfolder(outDir),mkdir(outDir);end
[ps,rf]=groupPsd(signalDirs);[pb,~]=groupPsd(backgroundDirs);
delta=ps-pb;mask=abs(rf-200e6)>0.1e6;
[sorted,order]=sort(delta(mask),'descend');allIdx=find(mask);top=allIdx(order(1:min(20,numel(order))));
C.rfHz=rf;C.signalDb=ps;C.backgroundDb=pb;C.deltaDb=delta;
C.topRfHz=rf(top);C.topDeltaDb=delta(top);
T=table(C.topRfHz/1e6,C.topDeltaDb,'VariableNames',{'rf_mhz','delta_db'});
writetable(T,fullfile(outDir,'candidate_bands.csv'));
if makePlots
 fig=figure('Color','w','Visible','off');plot(rf/1e6,delta,'LineWidth',0.9);grid on;
 xlabel('RF candidate (MHz)');ylabel('Signal minus background (dB)');
 title('Content-dependent raw-IQ spectrum difference');ylim([-30 30]);
 exportgraphics(fig,fullfile(outDir,'difference_spectrum.png'),'Resolution',180);close(fig);
end
save(fullfile(outDir,'difference_analysis.mat'),'C','-v7.3');
fprintf('RAW_IQ_COMPARE_PASS strongest_candidate=%.6f MHz delta=%.3f dB\n',C.topRfHz(1)/1e6,C.topDeltaDb(1));
end
function [avgDb,rf]=groupPsd(dirs)
acc=[];for k=1:numel(dirs)
 R=read_raw_iq_v23(dirs(k));x=R.x-mean(R.x);n=numel(x);
 w=0.5-0.5*cos(2*pi*(0:n-1)'/max(n-1,1));nfft=2^nextpow2(n);
 lin=abs(fftshift(fft(x.*w,nfft))).^2/(sum(w.^2)+eps);
 if isempty(acc),acc=zeros(size(lin));end;acc=acc+lin;
end
acc=acc/numel(dirs);avgDb=10*log10(acc+eps);
f=(-nfft/2:nfft/2-1)'*R.fs/nfft;rf=R.rfCenter+f;
end

