function analyze_spectrum(csvFile, outPng)
%ANALYZE_SPECTRUM Plot the PL-generated 65536-bin snapshot spectrum.
if nargin<2, outPng='spectrum.png'; end
[addr,data,valid]=read_ila_numeric(csvFile);
addr=addr(valid); data=data(valid);
[addr,order]=sort(addr); data=data(order);
assert(numel(unique(addr))==65536,'Expected 65536 unique spectrum bins');
fs=65e6; f=(-fs/2:fs/65536:fs/2-fs/65536)/1e6;
y=fftshift(data); y=y-max(y);
figure('Color','w'); plot(f,y,'LineWidth',1); grid on;
xlabel('Baseband frequency (MHz)'); ylabel('Relative PL spectrum (dB-like)');
title('Four-frame averaged leakage spectrum'); xlim([f(1),f(end)]);
exportgraphics(gcf,outPng,'Resolution',180);
end
