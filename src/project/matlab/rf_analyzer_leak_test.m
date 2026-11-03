function result = rf_analyzer_leak_test(rootDir, fsHz, makePlot)
% Compare five RF Analyzer RF-ADC LVM exports in acquisition order:
% black_1, coded_16px, black_2, five_shapes, black_3.
% Example: R = rf_analyzer_leak_test('D:\capture\rf_analyzer_20261023', 1.04e9);
% fsHz is the EFFECTIVE exported sample rate (ADC Fs / decimation).
% This reads raw ADC data, never FFT/metrics exports. Output is relative dB,
% not calibrated dBm. Requires MATLAB R2021a or newer.

if nargin < 2, error('Provide rootDir and effective sample rate fsHz.'); end
if nargin < 3, makePlot = true; end
assert(isfolder(rootDir), 'Capture folder does not exist: %s', rootDir);
assert(isscalar(fsHz) && isfinite(fsHz) && fsHz > 0, 'Invalid fsHz');
names = {'black_1','coded_16px','black_2','five_shapes','black_3'};
files = cell(1,5); samples = cell(1,5); allLengths = [];
for k = 1:5
    folder = fullfile(rootDir,names{k});
    assert(isfolder(folder),'Missing folder: %s',folder);
    files{k} = dir(fullfile(folder,'**','*.lvm'));
    assert(~isempty(files{k}),'No .lvm raw capture in %s',folder);
    samples{k} = cell(numel(files{k}),1);
    for j = 1:numel(files{k})
        samples{k}{j} = read_adc_lvm(fullfile(files{k}(j).folder,files{k}(j).name));
        allLengths(end+1) = numel(samples{k}{j}); %#ok<AGROW>
    end
end
nfft = 2^floor(log2(min([allLengths 65536])));
assert(nfft >= 4096,'Need at least 4096 samples in each capture');
df = fsHz/nfft;
assert(df <= 0.25e6,'Frequency resolution %.0f Hz is insufficient for 2.03125 MHz sidebands',df);
freq = (0:nfft/2)' * df;
spectra = cell(1,5);
peakCode = zeros(1,5);
for k = 1:5
    spectra{k} = zeros(numel(freq),numel(samples{k}));
    for j = 1:numel(samples{k})
        x = samples{k}{j}(1:nfft);
        railHits = nnz(x>=32764 | x<=-32768);
        if railHits>1
            error('ADC full-scale samples (%d) in %s. Resolve clipping before spectral comparison.', ...
                railHits,fullfile(files{k}(j).folder,files{k}(j).name));
        end
        peakCode(k) = max(peakCode(k),max(abs(x)));
        x = x - mean(x);
        w = 0.5 - 0.5*cos(2*pi*(0:nfft-1)'/(nfft-1));
        X = fft(x.*w,nfft);
        spectra{k}(:,j) = abs(X(1:nfft/2+1)).^2 / sum(w.^2);
    end
end
p = cellfun(@(s)mean(s,2),spectra,'UniformOutput',false);
harmonicsMHz = [65 130 195 260 325 390 455];
harmonicsMHz = harmonicsMHz(harmonicsMHz*1e6 + 10e6 < fsHz/2);
assert(~isempty(harmonicsMHz),'Effective sample rate too low; cannot inspect 65 MHz and higher harmonics');

rows = cell(numel(harmonicsMHz)*3,8); r = 0;
for h = harmonicsMHz
    f0 = h*1e6;
    bands = {[f0-0.20e6 f0+0.20e6], ...
             [f0-2.03125e6-0.25e6 f0-2.03125e6+0.25e6], ...
             [f0+2.03125e6-0.25e6 f0+2.03125e6+0.25e6]};
    labels = {'carrier','sideband_minus_2p03125','sideband_plus_2p03125'};
    for b = 1:3
        mask = freq>=bands{b}(1) & freq<=bands{b}(2);
        assert(any(mask),'No FFT bins in measurement band');
        vals = zeros(1,5);
        for k = 1:5, vals(k) = sum(p{k}(mask)); end
        % Linear-power interpolation of adjacent black controls.
        refCoded = (vals(1)+vals(3))/2;
        refShapes = (vals(3)+vals(5))/2;
        db = @(a,b) 10*log10(max(a,realmin)/max(b,realmin));
        r=r+1;
        rows(r,:) = {h,labels{b},db(vals(2),refCoded), ...
            db(vals(4),refShapes),db(vals(3),vals(1)), ...
            db(vals(5),vals(3)),db(vals(2),vals(1)),db(vals(4),vals(3))};
    end
end
result = cell2table(rows,'VariableNames',{'RF_MHz','Band','Coded_vs_adjacent_black_dB', ...
    'Shapes_vs_adjacent_black_dB','Black2_vs_black1_dB', ...
    'Black3_vs_black2_dB','Coded_vs_black1_dB','Shapes_vs_black2_dB'});
outDir = fullfile(rootDir,'analysis');
if ~isfolder(outDir), mkdir(outDir); end
writetable(result,fullfile(outDir,'harmonic_comparison.csv'));
if makePlot
    fig = figure('Visible','off','Color','w','Position',[100 100 1100 600]);
    hold on;
    colors = lines(5);
    for k = 1:5
        plot(freq/1e6,10*log10(max(p{k},realmin)), ...
            'DisplayName',names{k},'Color',colors(k,:));
    end
    xlim([30 min(500,fsHz/2e6)]); xlabel('RF frequency (MHz)');
    ylabel('Power per FFT bin (relative dB)'); legend('Location','best'); grid on;
    title(sprintf('RF Analyzer raw ADC; Fs=%.3f MHz, N=%d, bin=%.1f kHz',fsHz/1e6,nfft,df/1e3));
    exportgraphics(fig,fullfile(outDir,'spectrum_comparison.png'),'Resolution',150);
    close(fig);
end
fprintf('Analysis saved: %s\n',outDir);
fprintf('N=%d, bin=%.1f kHz, maximum absolute ADC codes: %s\n', ...
    nfft,df/1e3,mat2str(peakCode,5));
disp(result);
end

function x = read_adc_lvm(path)
% Header-tolerant reader for one real ADC channel. Rejects ambiguous exports.
fid=fopen(path,'rt'); assert(fid>=0,'Cannot open %s',path);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
lines={};
while true
    line=fgetl(fid); if ~ischar(line), break; end
    lines{end+1}=line; %#ok<AGROW>
end
lastHeader=find(contains(lines,'***End_of_Header***'),1,'last');
if isempty(lastHeader), lastHeader=0; end
rows = zeros(0,2); columns = 0;
for lineIndex=lastHeader+1:numel(lines)
    line=strtrim(lines{lineIndex});
    if isempty(line) || startsWith(line,'*') || startsWith(line,'#'), continue; end
    parts=regexp(line,'[\t,; ]+','split');
    nums=str2double(parts);
    if isempty(nums) || any(~isfinite(nums)), continue; end
    if columns==0
        columns=numel(nums);
        assert(columns==1 || columns==2, ...
            'Expected one ADC column or time+ADC columns in %s; got %d',path,columns);
    end
    if numel(nums)==columns
        if columns==1, rows(end+1,1)=nums(1); %#ok<AGROW>
        else, rows(end+1,1:2)=nums(1:2); end %#ok<AGROW>
    end
end
assert(~isempty(rows),'No numeric samples in %s',path);
if columns==2
    t=rows(:,1);
    assert(all(diff(t)>0),'First LVM column is not increasing time in %s',path);
    x=rows(:,2);
else, x=rows(:,1); end
assert(all(isfinite(x)),'Nonfinite ADC data in %s',path);
end
