function selftest_v22
%SELFTEST_V22 Runtime checks for the V2.2 MATLAB synchronization pipeline.

rng(22);

truePeriod = 1344.37;
n = 360000;
t = (0:n-1).';
phase = mod(t,truePeriod)/truePeriod;
harmonics = [3 7 13 29 53 89 137 211];
stream = zeros(n,1);
for k = 1:numel(harmonics)
    stream = stream + (1/sqrt(harmonics(k))) ...
        * sin(2*pi*harmonics(k)*phase + 0.37*k);
end
stream = stream + 0.02*randn(n,1);
periodResult = estimate_line_period(stream,1344);
assert(abs(periodResult.period-truePeriod)<=0.02, ...
    'Line-period estimate is outside tolerance: %.6f',periodResult.period);
assert(periodResult.correlation>=0.95, ...
    'Line-period correlation is unexpectedly low: %.6f',periodResult.correlation);

raster = fractional_raster(stream,periodResult.period,1344,64,0);
assert(isequal(size(raster),[64 1344]) && all(isfinite(raster(:))), ...
    'Fractional rasterization failed.');

[x,y] = meshgrid(1:192,1:96);
reference = 2.0*exp(-((x-43).^2+(y-24).^2)/220) ...
          + 1.4*exp(-((x-137).^2+(y-69).^2)/380) ...
          + 0.30*sin(2*pi*x/37) + 0.24*cos(2*pi*y/23);
dx = 17;
dy = 9;
test = circshift(reference,[dy dx]) + 0.01*randn(size(reference));
alignment = profile_align_quality(reference,test);
assert(alignment.dx==dx && alignment.dy==dy, ...
    'Profile alignment returned dx=%d, dy=%d.',alignment.dx,alignment.dy);
assert(alignment.accepted && alignment.image_correlation>=0.99, ...
    'Alignment quality gate unexpectedly failed.');

fprintf(['V22_MATLAB_SELFTEST_PASS period=%.3f correlation=%.6f ' ...
    'dx=%d dy=%d image_correlation=%.6f\n'], ...
    periodResult.period,periodResult.correlation,alignment.dx,alignment.dy, ...
    alignment.image_correlation);
end
