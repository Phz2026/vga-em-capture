param(
  [Parameter(Mandatory=$true)][string]$CaptureDir,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [int]$LineSamples=1344,
  [int]$FrameLines=806,
  [int]$ActiveWidth=1024,
  [int]$ActiveHeight=768,
  [int]$RadiusX=16,
  [int]$RadiusY=8
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir|Out-Null

Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class BlindLargeShapeRecovery {
  static byte ParseData(string line){int p=-1;for(int i=0;i<3;i++)p=line.IndexOf(',',p+1);int q=line.IndexOf(',',p+1);return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);}
  static byte[] Load(string dir,int total){string[] fs=Directory.GetFiles(dir,"segment_*.csv");Array.Sort(fs,StringComparer.OrdinalIgnoreCase);byte[] a=new byte[total];int n=0;foreach(string f in fs)using(var sr=new StreamReader(f)){sr.ReadLine();sr.ReadLine();string line;while(n<total&&(line=sr.ReadLine())!=null)a[n++]=ParseData(line);if(n==total)break;}if(n!=total)throw new Exception("Expected "+total+" samples, read "+n);return a;}
  static double[] Blur(byte[] src,int w,int h,int rx,int ry){double[] tmp=new double[w*h],dst=new double[w*h];int nx=2*rx+1,ny=2*ry+1;for(int y=0;y<h;y++){double s=0;for(int k=-rx;k<=rx;k++)s+=src[y*w+(k+w)%w];for(int x=0;x<w;x++){tmp[y*w+x]=s/nx;s-=src[y*w+(x-rx+w)%w];s+=src[y*w+(x+rx+1)%w];}}for(int x=0;x<w;x++){double s=0;for(int k=-ry;k<=ry;k++)s+=tmp[((k+h)%h)*w+x];for(int y=0;y<h;y++){dst[y*w+x]=s/ny;s-=tmp[((y-ry+h)%h)*w+x];s+=tmp[((y+ry+1)%h)*w+x];}}return dst;}
  static int BestWindow(double[] e,int size){int n=e.Length;double s=0;for(int i=0;i<size;i++)s+=e[i];double best=s;int bi=0;for(int i=1;i<n;i++){s-=e[(i-1)%n];s+=e[(i+size-1)%n];if(s>best){best=s;bi=i;}}return bi;}
  static void Save(double[] a,int sw,int sh,int x0,int y0,int w,int h,string path,double lo,double hi){var bmp=new Bitmap(w,h,PixelFormat.Format24bppRgb);var bd=bmp.LockBits(new Rectangle(0,0,w,h),ImageLockMode.WriteOnly,PixelFormat.Format24bppRgb);try{byte[] rgb=new byte[bd.Stride*h];for(int y=0;y<h;y++)for(int x=0;x<w;x++){double z=(a[((y+y0)%sh)*sw+(x+x0)%sw]-lo)/(hi-lo);byte b=(byte)Math.Max(0,Math.Min(255,Math.Round(255*z)));int p=y*bd.Stride+3*x;rgb[p]=b;rgb[p+1]=b;rgb[p+2]=b;}Marshal.Copy(rgb,0,bd.Scan0,rgb.Length);}finally{bmp.UnlockBits(bd);}try{bmp.Save(path,ImageFormat.Png);}finally{bmp.Dispose();}}
  public static string Run(string dir,string outDir,int w,int h,int aw,int ah,int rx,int ry){byte[] raw=Load(dir,w*h);double[] a=Blur(raw,w,h,rx,ry);double[] gx=new double[w],gy=new double[h];for(int y=0;y<h;y++)for(int x=0;x<w;x++){gx[x]+=Math.Abs(a[y*w+(x+1)%w]-a[y*w+x]);gy[y]+=Math.Abs(a[((y+1)%h)*w+x]-a[y*w+x]);}int x0=BestWindow(gx,aw),y0=BestWindow(gy,ah);double[] sorted=(double[])a.Clone();Array.Sort(sorted);double lo=sorted[(int)(sorted.Length*.02)],hi=sorted[(int)(sorted.Length*.98)];if(hi<=lo){lo=sorted[0];hi=sorted[sorted.Length-1];}string full=Path.Combine(outDir,"blind_smoothed_full.png"),crop=Path.Combine(outDir,"blind_recovered_crop.png");Save(a,w,h,0,0,w,h,full,lo,hi);Save(a,w,h,x0,y0,aw,ah,crop,lo,hi);double mean=0;foreach(double v in a)mean+=v;mean/=a.Length;double var=0;foreach(double v in a){double d=v-mean;var+=d*d;}var/=a.Length;var r=new StringBuilder();r.AppendLine("BLIND_RECOVERY_PASS");r.AppendLine("filter="+(2*rx+1)+"x"+(2*ry+1));r.AppendLine("smoothed_mean="+mean.ToString("F6"));r.AppendLine("smoothed_std="+Math.Sqrt(var).ToString("F6"));r.AppendLine("display_range="+lo.ToString("F6")+".."+hi.ToString("F6"));r.AppendLine("crop_offset="+x0+","+y0);r.AppendLine("full="+full);r.AppendLine("crop="+crop);return r.ToString();}
}
'@ -ReferencedAssemblies System.Drawing

$dir=(Resolve-Path -LiteralPath $CaptureDir).Path
$out=[IO.Path]::GetFullPath($OutDir)
[BlindLargeShapeRecovery]::Run($dir,$out,$LineSamples,$FrameLines,$ActiveWidth,$ActiveHeight,$RadiusX,$RadiusY)
