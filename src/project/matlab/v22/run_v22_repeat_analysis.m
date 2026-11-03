function result = run_v22_repeat_analysis(captureDirs,outDir)
%RUN_V22_REPEAT_ANALYSIS Align, quality-gate and average repeated captures.
% captureDirs is a string/cell array. All captures must use the same mode.
captureDirs=string(captureDirs(:)); assert(numel(captureDirs)>=2,'Use at least two repeats.');
if nargin<2, outDir=fullfile(char(captureDirs(1)),'v22_analysis'); end
if ~exist(outDir,'dir'), mkdir(outDir); end
n=numel(captureDirs); D=cell(n,1);
for k=1:n, D{k}=decode_capture_v22(captureDirs(k)); end
modes=cellfun(@(x)x.feature_mode,D); assert(all(modes==modes(1)),'Feature modes must match.');
ref=D{1}.image; aligned=cell(n,1); aligned{1}=ref; accepted=true(n,1);
dx=zeros(n,1); dy=zeros(n,1); xcorr=ones(n,1); ycorr=ones(n,1); imagecorr=ones(n,1);
period=zeros(n,1); periodScore=zeros(n,1);
for k=1:n
    period(k)=D{k}.period.period; periodScore(k)=D{k}.period.correlation;
    if k==1, continue; end
    A=profile_align_quality(ref,D{k}.image); aligned{k}=A.aligned;
    dx(k)=A.dx; dy(k)=A.dy; xcorr(k)=A.x_correlation; ycorr(k)=A.y_correlation;
    imagecorr(k)=A.image_correlation; accepted(k)=A.accepted;
end
assert(sum(accepted)>=2,'No repeat passed the synchronization quality gate. Do not average this set.');
stack=cat(3,aligned{accepted}); average=mean(stack,3);
diagnostics=table(captureDirs,period,periodScore,dx,dy,xcorr,ycorr,imagecorr,accepted, ...
    'VariableNames',{'capture','line_period','period_correlation','dx','dy','x_profile_correlation', ...
    'y_profile_correlation','image_correlation','accepted'});
writetable(diagnostics,fullfile(outDir,'sync_diagnostics.csv'));
if isreal(average)
    preview=scale_uint8(average);
else
    save(fullfile(outDir,'complex_average.mat'),'average','diagnostics');
    preview=scale_uint8(abs(average));
end
imwrite(preview,fullfile(outDir,'accepted_repeat_average.png'));
save(fullfile(outDir,'analysis_result.mat'),'average','diagnostics','accepted','captureDirs');
result.average=average; result.diagnostics=diagnostics; result.accepted=accepted;
fprintf('V22_REPEAT_ANALYSIS_PASS accepted=%d/%d\nResults: %s\n',sum(accepted),n,outDir);
end

function y=scale_uint8(x)
x=double(x); lo=prctile(x(:),1); hi=prctile(x(:),99); y=uint8(255*min(max((x-lo)/max(eps,hi-lo),0),1));
end
