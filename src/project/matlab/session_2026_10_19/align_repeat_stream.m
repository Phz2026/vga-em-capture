function result = align_repeat_stream(reference,test)
%ALIGN_REPEAT_STREAM Align two captures of the same displayed pattern.
% A one-dimensional circular shift matches the continuously captured raster.
sz=size(reference);
% Recover hardware order (x changes fastest) before estimating one stream lag.
refStream=reshape(reference.',[],1); testStream=reshape(test.',[],1);
a=double(refStream); b=double(testStream);
a=a-mean(a); b=b-mean(b);
c=real(ifft(conj(fft(a)).*fft(b)));
[~,i]=max(c); lag=i-1;
 b1=circshift(double(testStream),-lag);
 b2=circshift(double(testStream), lag);
r1=normalized_dot(double(refStream),b1);
r2=normalized_dot(double(refStream),b2);
if r2>r1, lag=-lag; aligned=b2; corr=r2; else, aligned=b1; corr=r1; end
result.sample_shift=lag;
result.correlation=corr;
result.aligned=reshape(aligned,[sz(2) sz(1)]).';
end

function r=normalized_dot(a,b)
a=a-mean(a); b=b-mean(b);
r=(a.'*b)/max(norm(a)*norm(b),eps);
end
