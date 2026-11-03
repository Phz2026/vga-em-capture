// Same 512x384 rectangle as the center test, translated +128 in x and y.
const fs=require('fs'),path=require('path'),zlib=require('zlib');
const W=1024,H=768,raw=Buffer.alloc(H*(W+1));
for(let y=320;y<704;y++)raw.fill(255,y*(W+1)+1+384,y*(W+1)+1+896);
function crc32(a){let c=-1;for(const b of a){c^=b;for(let k=0;k<8;k++)c=(c>>>1)^(0xedb88320&-(c&1));}return(c^-1)>>>0;}
function chunk(t,a){const b=Buffer.from(t),n=Buffer.alloc(4),c=Buffer.alloc(4);n.writeUInt32BE(a.length);c.writeUInt32BE(crc32(Buffer.concat([b,a])));return Buffer.concat([n,b,a,c]);}
const h=Buffer.alloc(13);h.writeUInt32BE(W,0);h.writeUInt32BE(H,4);h[8]=8;
const file=path.join(__dirname,'white_rectangle_shifted_128_128_1024x768.png');
fs.writeFileSync(file,Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',h),chunk('IDAT',zlib.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]));
console.log(file);
