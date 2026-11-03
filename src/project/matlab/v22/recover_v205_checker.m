function R = recover_v205_checker(outDir)
%RECOVER_V205_CHECKER Best-effort checker recovery from V2.05 captures.
% Uses three checker frames and three black frames in both magnitude and IQ
% modes.  The result is quality-gated: output images are always written, but
% quality_pass is true only when at least two target repeats contain stable
% two-dimensional content.

if nargin<1
    outDir='D:\capture\v205_matlab_reconstruction';
end
if ~exist(outDir,'dir'), mkdir(outDir); end

captureRoot='D:\capture';
magTarget=fullfile(captureRoot,["v205_checker16_mag_r1"; ...
    "v205_checker16_mag_r2";"v205_checker16_mag_r3"]);
magBlack=fullfile(captureRoot,["v205_black_mag_r1"; ...
    "v205_black_mag_r2";"v205_black_mag_r3"]);
iqTarget=fullfile(captureRoot,["v205_checker16_iq_r1"; ...
    "v205_checker16_iq_r2";"v205_checker16_iq_r3"]);
iqBlack=fullfile(captureRoot,["v205_black_iq_r1"; ...
    "v205_black_iq_r2";"v205_black_iq_r3"]);

[magT,diagMT]=load_align_average(magTarget,"checker_magnitude");
[magB,diagMB]=load_align_average(magBlack,"black_magnitude");
[iqT,diagIT]=load_align_average(iqTarget,"checker_iq");
[iqB,diagIB]=load_align_average(iqBlack,"black_iq");

[magB,magBackgroundAlignment]=align_pair(magT,magB);
[iqB,iqBackgroundAlignment]=align_pair(iqT,iqB);

magDifference=remove_row_column(magT-magB);
iqDifference=iqT-iqB;
iqEnvelope=remove_row_column(abs(iqDifference));

% Mild separable smoothing suppresses isolated ADC noise while retaining
% 16-pixel blocks.  No image-processing toolbox is required.
kernel=[1 2 3 2 1]/9;
magFiltered=conv2(conv2(magDifference,kernel,'same'),kernel.','same');
iqFiltered=conv2(conv2(iqEnvelope,kernel,'same'),kernel.','same');

magCrop=cyclic_energy_crop(magFiltered,768,1024);
iqCrop=cyclic_energy_crop(iqFiltered,size(iqFiltered,1),1024);

imwrite(scale_signed(magDifference),fullfile(outDir,'magnitude_difference_full.png'));
imwrite(scale_signed(magCrop),fullfile(outDir,'magnitude_restored_1024x768.png'));
imwrite(scale_unsigned(iqEnvelope),fullfile(outDir,'iq_difference_full.png'));
imwrite(scale_unsigned(iqCrop),fullfile(outDir,'iq_restored_403x1024.png'));

diagnostics=[diagMT;diagMB;diagIT;diagIB];
writetable(diagnostics,fullfile(outDir,'capture_diagnostics.csv'));
qualityPass=(sum(diagMT.accepted)>=2) || (sum(diagIT.accepted)>=2);

save(fullfile(outDir,'reconstruction.mat'),'magT','magB','magDifference', ...
    'magFiltered','magCrop','iqT','iqB','iqDifference','iqEnvelope', ...
    'iqFiltered','iqCrop','diagnostics','qualityPass', ...
    'magBackgroundAlignment','iqBackgroundAlignment','-v7.3');

magPreview=scale_signed(magCrop);iqPreview=scale_unsigned(iqCrop);
imwrite([magPreview;uint8(255*ones(12,size(magPreview,2)));iqPreview], ...
    fullfile(outDir,'reconstruction_overview.png'));
% Interactive plots are useful in the MATLAB desktop, but a batch session
% may not have a graphics connector.  All numerical and PNG outputs above
% are deliberately independent of figure creation.
if usejava('desktop')
    f=figure('Color','w','Name','V2.05 MATLAB reconstruction');
    tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
    nexttile; imagesc(magT); axis image off; title('Checker magnitude average');
    nexttile; imagesc(magB); axis image off; title('Black magnitude average');
    nexttile; imagesc(magCrop); axis image off; title('Magnitude: checker - black');
    nexttile; imagesc(abs(iqT)); axis image off; title('Checker I/Q envelope');
    nexttile; imagesc(abs(iqB)); axis image off; title('Black I/Q envelope');
    nexttile; imagesc(iqCrop); axis image off; title('I/Q: checker - black');
    colormap gray;
end

R.output_directory=string(outDir);
R.magnitude=magCrop; R.iq=iqCrop; R.diagnostics=diagnostics;
R.quality_pass=qualityPass;
fprintf('V205_RECONSTRUCTION_COMPLETE quality_pass=%d\n',qualityPass);
fprintf('Results: %s\n',outDir);
if ~qualityPass
    fprintf(['QUALITY_GATE_REJECTED: images were exported for inspection, ' ...
        'but repeated-frame spatial correlation is below the evidence threshold.\n']);
end
end

function [average,diagnostics]=load_align_average(dirs,label)
n=numel(dirs); D=cell(n,1);
for k=1:n
    assert(isfolder(dirs(k)),'Missing capture directory: %s',dirs(k));
    % The line period was measured independently during V2.1 validation.
    % Locking it here avoids fitting a different noise peak in every weak
    % frame and makes target/background subtraction deterministic.
    D{k}=decode_capture_v22(dirs(k),1343.975);
end
ref=D{1}.image; stack=zeros([size(ref) n],'like',ref); stack(:,:,1)=ref;
dx=zeros(n,1);dy=zeros(n,1);xcorr=ones(n,1);ycorr=ones(n,1);
imagecorr=ones(n,1);accepted=true(n,1);period=zeros(n,1);periodScore=zeros(n,1);
for k=1:n
    period(k)=D{k}.period.period; periodScore(k)=D{k}.period.correlation;
    if k==1, continue; end
    A=profile_align_quality(ref,D{k}.image);
    aligned=A.aligned;
    if ~isreal(aligned)
        phase=angle(sum(conj(ref(:)).*aligned(:)));
        aligned=aligned*exp(-1j*phase);
    end
    stack(:,:,k)=aligned;
    dx(k)=A.dx;dy(k)=A.dy;xcorr(k)=A.x_correlation;ycorr(k)=A.y_correlation;
    imagecorr(k)=A.image_correlation;accepted(k)=A.accepted;
end
% Keep all three frames for the diagnostic image.  accepted remains an
% evidence flag and is never used to turn rejected data into a success.
average=mean(stack,3);
capture=dirs(:); group=repmat(string(label),n,1);
diagnostics=table(group,capture,period,periodScore,dx,dy,xcorr,ycorr, ...
    imagecorr,accepted,'VariableNames',{'group','capture','line_period', ...
    'period_correlation','dx','dy','x_profile_correlation', ...
    'y_profile_correlation','image_correlation','accepted'});
end

function [aligned,A]=align_pair(reference,test)
A=profile_align_quality(reference,test); aligned=A.aligned;
if ~isreal(aligned)
    phase=angle(sum(conj(reference(:)).*aligned(:)));
    aligned=aligned*exp(-1j*phase);
end
end

function z=remove_row_column(x)
x=double(x); z=x-median(x,1)-median(x,2)+median(x(:));
end

function crop=cyclic_energy_crop(x,height,width)
[h,w]=size(x); height=min(height,h);width=min(width,w);
gx=mean(abs(x-circshift(x,[0 1])),1);
gy=mean(abs(x-circshift(x,[1 0])),2);
x0=best_window(gx(:),width); y0=best_window(gy(:),height);
xi=mod((x0-1)+(0:width-1),w)+1;
yi=mod((y0-1)+(0:height-1),h)+1;
crop=x(yi,xi);
end

function start=best_window(v,len)
n=numel(v); extended=[v;v]; cs=[0;cumsum(extended)];best=-inf;start=1;
for k=1:n
    score=cs(k+len)-cs(k);
    if score>best,best=score;start=k;end
end
end

function y=scale_unsigned(x)
x=double(x);v=sort(x(:));lo=v(max(1,round(0.01*numel(v))));
hi=v(min(numel(v),round(0.99*numel(v))));
y=uint8(255*min(max((x-lo)/max(eps,hi-lo),0),1));
end

function y=scale_signed(x)
x=double(x);v=sort(abs(x(:)));lim=v(min(numel(v),round(0.99*numel(v))));
y=uint8(255*min(max(0.5+0.5*x/max(eps,lim),0),1));
end
