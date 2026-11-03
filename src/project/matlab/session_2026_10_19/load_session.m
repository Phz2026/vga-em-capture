function S = load_session(matFile)
%LOAD_SESSION Load the validated 2026-10-19 capture bundle.
if nargin < 1 || strlength(string(matFile)) == 0
    here = fileparts(mfilename('fullpath'));
    matFile = fullfile(here,'data','all_captures_2026_10_19.mat');
end
d = load(matFile);
required = {'streams','capture_names','pattern_names','design_groups','gain','frame_id', ...
    'line_samples','frame_lines','frame_sample_count'};
for k = 1:numel(required)
    assert(isfield(d,required{k}),'Missing MAT variable: %s',required{k});
end

S.names = string(strtrim(cellstr(d.capture_names)));
S.patterns = string(strtrim(cellstr(d.pattern_names)));
S.design_groups = string(strtrim(cellstr(d.design_groups)));
S.gain = double(d.gain(:));
S.frame_id = double(d.frame_id(:));
S.width = double(d.line_samples);
S.height = double(d.frame_lines);
S.sample_rate_hz = double(d.image_sample_rate_hz);
S.streams = d.streams;
n = numel(S.names);
assert(size(S.streams,2)==n,'Capture-name count does not match stream count.');
assert(size(S.streams,1)>=S.width*S.height,'Streams are shorter than one frame.');

S.frames = zeros(S.height,S.width,n,'uint8');
for k = 1:n
    v = S.streams(1:S.width*S.height,k);
    % Hardware stream is row-major (x changes fastest); MATLAB is column-major.
    S.frames(:,:,k) = reshape(v,[S.width S.height]).';
end
S.mat_file = string(matFile);
end
