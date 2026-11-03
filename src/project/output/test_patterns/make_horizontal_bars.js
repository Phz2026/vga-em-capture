// Exact 1024x768, 8-bit grayscale, 64-pixel-high alternating bars.
// Top stripe is black; each row is constant across all 1024 columns.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const width = 1024, height = 768, barHeight = 64;
const target = path.join(__dirname, 'horizontal_bars_64px_1024x768.png');
const pixels = Buffer.alloc(height * (width + 1));
for (let y = 0; y < height; y++) {
  pixels.fill(Math.floor(y / barHeight) % 2 ? 255 : 0,
    y * (width + 1) + 1, (y + 1) * (width + 1));
}
function crc32(bytes) {
  let c = 0xffffffff;
  for (const b of bytes) {
    c ^= b;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ ((c & 1) ? 0xedb88320 : 0);
  }
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const name = Buffer.from(type);
  const size = Buffer.alloc(4); size.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([size, name, data, crc]);
}
const hdr = Buffer.alloc(13);
hdr.writeUInt32BE(width, 0); hdr.writeUInt32BE(height, 4);
hdr[8] = 8; hdr[9] = 0;
fs.writeFileSync(target, Buffer.concat([
  Buffer.from('89504e470d0a1a0a', 'hex'),
  chunk('IHDR', hdr), chunk('IDAT', zlib.deflateSync(pixels)),
  chunk('IEND', Buffer.alloc(0))
]));
console.log(target);
