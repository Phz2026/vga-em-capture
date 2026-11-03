function selftest_v23()
%SELFTEST_V23 End-to-end parser and differential-spectrum regression test.
root=fullfile(tempdir,'vga_em_v23_selftest');
if isfolder(root),rmdir(root,'s');end
mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
fs=65e6;n=4096;t=(0:n-1)'/fs;
sig=12000*exp(1j*2*pi*5e6*t);
bg=80*exp(1j*2*pi*1.25e6*t);
sigDirs=strings(1,2);bgDirs=strings(1,2);
for k=1:2
    sigDirs(k)=fullfile(root,"signal_"+k);bgDirs(k)=fullfile(root,"background_"+k);
    writeCapture(sigDirs(k),sig.*exp(1j*0.2*k));
    writeCapture(bgDirs(k),bg.*exp(1j*0.3*k));
end
R=read_raw_iq_v23(sigDirs(1));
assert(numel(R.x)==n && all(R.addr(:)==(0:n-1).'),'Raw-IQ parser regression failed');
A=analyze_raw_iq_v23(sigDirs(1),fullfile(root,'single'),false);
assert(abs(A.peakRfHz-205e6)<=fs/n,'Single-capture frequency estimate is wrong');
C=compare_raw_iq_v23(sigDirs,bgDirs,fullfile(root,'compare'),false);
assert(min(abs(C.topRfHz-205e6))<=fs/n,'Differential candidate ranking missed 205 MHz');
F=vga_find_leak_band(sigDirs,bgDirs,fullfile(root,'ranked'),false);
assert(F.promising && min(abs(F.candidates.rf_mhz*1e6-205e6))<=fs/n, ...
    'Repeatable-band search missed 205 MHz');
fprintf('V23_MATLAB_SELFTEST_PASS samples=%d peak_rf=%.6f MHz\n',n,A.peakRfHz/1e6);
end

function writeCapture(folder,x)
mkdir(folder);fid=fopen(fullfile(folder,'raw_iq.csv'),'wt');
assert(fid>=0,'Cannot create synthetic capture');c=onCleanup(@()fclose(fid));
fprintf(fid,'Sample in Buffer,Sample in Window,TRIGGER,processing_raw_replay_i[15:0],processing_raw_replay_q[15:0],processing_raw_replay_addr[14:0],processing_raw_replay_valid,processing_raw_replay_trigger\n');
fprintf(fid,'Radix - UNSIGNED,UNSIGNED,UNSIGNED,HEX,HEX,HEX,HEX,HEX\n');
i=round(real(x));q=round(imag(x));
for k=1:numel(x)
    fprintf(fid,'%d,%d,%d,%04X,%04X,%04X,1,%d\n',k-1,k-1,k==1,mod(i(k),65536),mod(q(k),65536),k-1,k==1);
end
end
