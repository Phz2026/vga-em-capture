function run_session_analysis()
%RUN_SESSION_ANALYSIS Reproduce the 2026-10-19 MATLAB-side analysis.
here=fileparts(mfilename('fullpath'));
outDir=fullfile(here,'results'); if ~exist(outDir,'dir'), mkdir(outDir); end
S=load_session(fullfile(here,'data','all_captures_2026_10_19.mat'));
n=numel(S.names);
analyze_spectra(outDir);

meanCode=zeros(n,1); totalStd=zeros(n,1); rowStd=zeros(n,1); colStd=zeros(n,1);
residualStd=zeros(n,1); zeroFraction=zeros(n,1); saturatedFraction=zeros(n,1);
for k=1:n
    x=double(S.frames(:,:,k)); m=mean(x(:));
    r=mean(x,2)-m; c=mean(x,1)-m; residual=x-m-r-c;
    meanCode(k)=m; totalStd(k)=std(x(:),1); rowStd(k)=std(r,1);
    colStd(k)=std(c,1); residualStd(k)=std(residual(:),1);
    zeroFraction(k)=mean(x(:)==0); saturatedFraction(k)=mean(x(:)==255);
end
metrics=table(S.names,S.patterns,S.design_groups,S.gain,S.frame_id,meanCode,totalStd,rowStd,colStd, ...
    residualStd,zeroFraction,saturatedFraction,'VariableNames', ...
    {'capture','pattern','design_group','gain','frame_id','mean_code','std_code','row_component_std', ...
    'column_component_std','residual_std','zero_fraction','saturated_fraction'});
writetable(metrics,fullfile(outDir,'capture_metrics.csv'));

knownKinds=["vertical_stripe16","horizontal_stripe8","checker16"];
scoreRows=cell(0,6);
for k=1:n
    if any(S.patterns(k)==knownKinds)
        p=pattern_score(S.frames(:,:,k),S.patterns(k));
        scoreRows(end+1,:)={S.names(k),S.patterns(k),S.gain(k),p.period,p.correlation,p.contrast}; %#ok<AGROW>
    end
end
scores=cell2table(scoreRows,'VariableNames',{'capture','pattern','gain','period','template_correlation','contrast'});
writetable(scores,fullfile(outDir,'known_pattern_scores.csv'));

% Repeatability: align repeats of the same pattern and gain in the continuous stream.
pairs={"v203_checker16_g1_r1","v203_checker16_g1_r2"; ...
       "v203_vstripe16_g1_r1","v203_vstripe16_g1_r2"; ...
       "v203_hstripe8_g4_r1","v203_hstripe8_g4_r2"; ...
       "v203_checker16_g4_r1","v203_checker16_g4_r2"; ...
       "v203_asymmetric_g4_r1","v203_asymmetric_g4_r2"};
repeatRows=cell(size(pairs,1),4);
for p=1:size(pairs,1)
    ia=find(S.names==pairs{p,1},1); ib=find(S.names==pairs{p,2},1);
    a=align_repeat_stream(S.frames(:,:,ia),S.frames(:,:,ib));
    repeatRows(p,:)={pairs{p,1},pairs{p,2},a.sample_shift,a.correlation};
end
repeatTable=cell2table(repeatRows,'VariableNames',{'reference','test','sample_shift','correlation'});
writetable(repeatTable,fullfile(outDir,'repeat_alignment.csv'));

% Blind asymmetric reconstruction. The available black frame predates the probe
% move, so the subtraction is diagnostic/provisional and is labelled as such.
ia=find(S.names=="v203_asymmetric_g4_r1",1); ib=find(S.names=="v203_asymmetric_g4_r2",1);
iblack=find(S.names=="v203_black_g4_r1",1);
rep=align_repeat_stream(S.frames(:,:,ia),S.frames(:,:,ib));
target=(double(S.frames(:,:,ia))+rep.aligned)/2;
sync=profile_sync(target,S.frames(:,:,iblack));
delta=target-sync.aligned;
[cleaned,background]=robust_destripe(delta,3);
kernel=ones(33,65)/(33*65); lowpass=conv2(cleaned,kernel,'same');
imwrite(robust_uint8(target),fullfile(outDir,'asymmetric_repeat_average.png'));
imwrite(robust_uint8(delta),fullfile(outDir,'asymmetric_minus_old_black_provisional.png'));
imwrite(robust_uint8(cleaned),fullfile(outDir,'asymmetric_destriped_provisional.png'));
imwrite(robust_uint8(lowpass),fullfile(outDir,'asymmetric_lowpass_provisional.png'));
imwrite(robust_uint8(background),fullfile(outDir,'estimated_row_column_background.png'));

% Human-readable report produced from the same variables.
fid=fopen(fullfile(outDir,'analysis_summary.txt'),'w'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'VGA EM session 2026-10-19\n');
fprintf(fid,'captures=%d, raster=%dx%d, image_sample_rate=%.0f Hz\n',n,S.width,S.height,S.sample_rate_hz);
fprintf(fid,'asymmetric repeat sample shift=%d, correlation=%.6f\n',rep.sample_shift,rep.correlation);
fprintf(fid,'old-black profile alignment dx=%d dy=%d xcorr=%.6f ycorr=%.6f\n', ...
    sync.dx,sync.dy,sync.x_correlation,sync.y_correlation);
fprintf(fid,'WARNING: v203_black_g4_r1 was captured before the probe move. Background-subtracted images are provisional.\n');
fprintf(fid,'Use a post-asymmetric black capture before claiming blind image recovery.\n');
fprintf(fid,'The raw 8-bit feature is magnitude after two 8-sample moving averages; phase was discarded in PL.\n');
fprintf(fid,'Destriping suppresses additive row/column structure but can also remove broad real image content.\n');

figure('Color','w','Name','Capture metrics');
tiledlayout(2,1); nexttile; bar(categorical(S.names),meanCode); ylabel('Mean code'); grid on;
nexttile; bar(categorical(S.names),[rowStd colStd residualStd]); ylabel('Standard deviation');
legend('row','column','residual'); grid on; xtickangle(45);
exportgraphics(gcf,fullfile(outDir,'capture_metrics.png'),'Resolution',150);
fprintf('SESSION_ANALYSIS_PASS\nResults: %s\n',outDir);
end
