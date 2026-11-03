% Deterministic 1024 x 768, exact black/white pixels for VGA tests.
out = fileparts(mfilename('fullpath'));
width = 1024; height = 768;
x = 0:width-1;
bars = repmat(uint8(255*mod(floor(x/64),2)),height,1);
assert(all(size(bars)==[height width]));
imwrite(bars,fullfile(out,'vertical_bars_64px_1024x768.png'));
y = (0:height-1)';
horizontalBars = repmat(uint8(255*mod(floor(y/64),2)),1,width);
assert(all(size(horizontalBars)==[height width]));
imwrite(horizontalBars,fullfile(out,'horizontal_bars_64px_1024x768.png'));
rectangle = zeros(height,width,'uint8');
rectangle(193:576,257:768) = 255;
imwrite(rectangle,fullfile(out,'white_rectangle_512x384_1024x768.png'));
shiftedRectangle = zeros(height,width,'uint8');
shiftedRectangle(321:704,385:896) = 255; % +128 px in both axes
imwrite(shiftedRectangle,fullfile(out,'white_rectangle_shifted_128_128_1024x768.png'));
checker32 = uint8(255 * mod(floor((0:height-1)'/32) + floor(x/32),2));
assert(all(size(checker32)==[height width]));
imwrite(checker32,fullfile(out,'checkerboard_32px_1024x768.png'));
imwrite(zeros(height,width,'uint8'),fullfile(out,'full_black_1024x768.png'));
% Repeated asymmetric 2D shape: 128-pixel tile, 32-pixel-wide L strokes.
% Unlike a checker, both the horizontal and vertical shape are needed.
tileL = zeros(128,128,'uint8');
tileL(25:104,25:56) = 255;
tileL(73:104,25:104) = 255;
repeatedL = repmat(tileL,6,8);
assert(all(size(repeatedL)==[height width]));
imwrite(repeatedL,fullfile(out,'repeated_L_128px_1024x768.png'));
% Large non-repeating L with 32-pixel checker texture inside its silhouette.
% The local checker component can be measured in 128×128 capture windows.
[xx,yy] = meshgrid(0:width-1,0:height-1);
maskL = (xx>=192 & xx<448 & yy>=128 & yy<640) | ...
        (xx>=192 & xx<832 & yy>=512 & yy<640);
carrierL = uint8(255 * (maskL & (mod(floor(xx/32)+floor(yy/32),2)==1)));
imwrite(carrierL,fullfile(out,'checker_carrier_L_32px_1024x768.png'));
fprintf('EASY_PATTERNS_READY=%s\n',out);
