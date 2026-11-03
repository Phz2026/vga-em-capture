function D = decode_capture_v22(captureDir,fixedLinePeriod)
%DECODE_CAPTURE_V22 Decode magnitude/I/Q/interleaved hardware modes.
C=assemble_capture_stream(captureDir); mode=C.feature_mode;
if mode==3
    i=double(C.stream(1:2:end))-128; q=double(C.stream(2:2:end))-128;
    complexStream=complex(i,q);
    % Each complex sample is exported as two consecutive bytes, but the
    % underlying complex sample clock remains 65 MS/s.  Therefore a VGA line
    % is still about 1344 complex samples.  The fixed byte buffer contains
    % half as many complete scan lines in IQ mode (403 instead of 806).
    iqLines=floor(numel(complexStream)/C.line_samples);
    if nargin>=2
        P=fixed_period_result(abs(complexStream),fixedLinePeriod,C.sample_rate_hz);
    else
        P=estimate_line_period(abs(complexStream),C.line_samples);
    end
    D.image=fractional_raster(complexStream,P.period,C.line_samples,iqLines,0);
    D.sample_rate_hz=C.sample_rate_hz;
    D.frame_lines=iqLines;
else
    if nargin>=2
        P=fixed_period_result(double(C.stream),fixedLinePeriod,C.sample_rate_hz);
    else
        P=estimate_line_period(double(C.stream),C.line_samples);
    end
    D.image=fractional_raster(double(C.stream),P.period,C.line_samples,C.frame_lines,0);
    D.sample_rate_hz=C.sample_rate_hz;
    D.frame_lines=C.frame_lines;
end
D.capture=C; D.period=P; D.feature_mode=mode;
end

function P=fixed_period_result(stream,period,fs)
s=double(stream(:));n=min(350000,numel(s)-ceil(period)-2);
base=(1:n).'; grid=(1:numel(s)).';a=s(base);a=a-mean(a);
b=interp1(grid,s,base+period,'linear');b=b-mean(b);
P.period=period;P.correlation=(a.'*b)/(norm(a)*norm(b)+eps);
P.line_frequency_hz=fs/period;P.periods=period;P.scores=P.correlation;
P.integer_periods=round(period);P.integer_scores=P.correlation;
end
