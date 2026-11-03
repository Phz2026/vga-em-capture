function R = analyze_current_image(captureDir, outDir, showFigure)
% One displayed image, one RF-magnitude capture, no stimulus control.
% This is a measured RF response. It is not synchronized VGA or RGB recovery.
if nargin < 3, showFigure = true; end
captureDir = char(captureDir); outDir = char(outDir);
root = fullfile(fileparts(mfilename('fullpath')),'..');
addpath(fullfile(root,'matlab'),fullfile(root,'matlab','v22'));
assert(isfolder(captureDir) && isfile(fullfile(captureDir,'metadata.txt')), ...
    'Capture folder is incomplete: %s',captureDir);
assert(~isfolder(outDir),'Output folder already exists: %s',outDir);
C = assemble_capture_stream(captureDir);
assert(C.feature_mode == 0,'Expected magnitude feature mode');
assert(C.line_samples == 1344 && C.frame_lines == 900, ...
    'Unexpected frame geometry: %d x %d',C.line_samples,C.frame_lines);
raw = reshape(double(C.stream),C.line_samples,C.frame_lines).';

% Fixed, stimulus-independent processing. The memory origin is not locked
% to HSYNC/VSYNC, so pixel position is not a calibrated screen coordinate.
p01 = percentile(raw(:),1);
p99 = percentile(raw(:),99);
rowResidual = raw - median(raw,2);
detail = rowResidual - movmean(rowResidual,129,2);
detail = movmean(movmean(detail,5,1),5,2);
scale = max(1,percentile(abs(detail(:)),99));
detail8 = uint8(round(max(0,min(255,127.5 + 110*detail/scale))));

mkdir(outDir);
imwrite(detail8,fullfile(outDir,'rf_response.png'));
R = struct('capture_dir',captureDir,'out_dir',outDir, ...
    'rf_mhz',C.metadata.ddc_target_mhz, ...
    'gain_q8',C.metadata.feature_gain_q8, ...
    'frame_counter',C.metadata.frame_counter_at_export, ...
    'saturated_fraction',mean(C.stream(:)>=255), ...
    'p01',p01,'p99',p99,'is_rgb_reconstruction',false, ...
    'has_hsync_vsync_reference',false);
save(fullfile(outDir,'result.mat'),'R','raw','detail');
fid = fopen(fullfile(outDir,'metrics.txt'),'w');
assert(fid>0,'Cannot create metrics.txt');
fprintf(fid,['source=SINGLE_UNCHANGED_DISPLAY\n' ...
    'meaning=RF_magnitude_response_not_RGB_reconstruction\n' ...
    'rf_mhz=%.6f\ngain_q8=%d\nframe_counter=%d\n' ...
    'saturated_fraction=%.8f\nraw_p01=%.6g\nraw_p99=%.6g\n'], ...
    R.rf_mhz,R.gain_q8,R.frame_counter,R.saturated_fraction,p01,p99);
fclose(fid);
fprintf('MANUAL_SINGLE_ANALYSIS_DONE=%s sat=%.6f\n', ...
    outDir,R.saturated_fraction);

if showFigure
    f = figure('Name','Single-image RF acquisition','NumberTitle','off', ...
        'Color','white');
    monitors = get(groot,'MonitorPositions');
    primary = monitors(1,:);
    fw = min(1500,max(850,primary(3)-120));
    fh = min(750,max(500,primary(4)-160));
    f.Position = [primary(1)+40, primary(2)+max(40,primary(4)-fh-80), fw, fh];
    imagesc(detail8); axis image off; colormap(gray(256));
    title('Single unchanged screen | fixed-filter RF response | no RGB or VGA sync');
    drawnow;
end
end

function value = percentile(x,p)
x = sort(double(x(:)));
value = x(max(1,min(numel(x),ceil(numel(x)*p/100))));
end
