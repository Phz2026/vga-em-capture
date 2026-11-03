function S=load_spectra(matFile)
if nargin<1
    here=fileparts(mfilename('fullpath'));
    matFile=fullfile(here,'data','all_spectra_2026_10_19.mat');
end
d=load(matFile);
S.spectra=d.spectra;
S.names=string(strtrim(cellstr(d.capture_names)));
S.kinds=string(strtrim(cellstr(d.measurement_kinds)));
S.baseband_hz=double(d.baseband_frequency_hz(:));
S.rf_hz=double(d.rf_center_hz)+S.baseband_hz;
S.sample_rate_hz=double(d.sample_rate_hz);
end
