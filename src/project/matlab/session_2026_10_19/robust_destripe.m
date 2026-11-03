function [corrected,estimatedBackground] = robust_destripe(image,iterations)
%ROBUST_DESTRIPE Remove additive row/column common-mode components.
% Broad real structures can also be attenuated, so keep the uncorrected result.
if nargin<2, iterations=3; end
x=double(image); baseline=median(x(:)); corrected=x;
for k=1:iterations
    r=median(corrected,2); corrected=corrected-(r-median(r));
    c=median(corrected,1); corrected=corrected-(c-median(c));
end
corrected=corrected-median(corrected(:))+baseline;
estimatedBackground=x-corrected;
end
