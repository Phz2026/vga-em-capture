param(
    [Parameter(Mandatory=$true)][string]$CaptureDir,
    [Parameter(Mandatory=$true)][double]$LinePitch,
    [string]$OutDir,
    [int]$OutputWidth=1365
)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($OutDir)){$OutDir=Join-Path $CaptureDir 'fractional_recovery'}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class FractionalRasterRecovery {
  static byte ParseData(string line) {
    int p=-1; for(int i=0;i<3;i++) p=line.IndexOf(',',p+1);
    int q=line.IndexOf(',',p+1);
    return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
  }
  static byte[] Load(string dir) {
    string[] files=Directory.GetFiles(dir,"segment_*.csv");
    Array.Sort(files,StringComparer.OrdinalIgnoreCase);
    int total=1344*806; byte[] a=new byte[total]; int pos=0;
    foreach(string f in files) using(var sr=new StreamReader(f)) {
      sr.ReadLine();sr.ReadLine();string line;
      while(pos<total && (line=sr.ReadLine())!=null) a[pos++]=ParseData(line);
      if(pos==total) break;
    }
    if(pos!=total) throw new Exception("Expected "+total+" samples, read "+pos);
    return a;
  }
  static void Save(byte[] gray,int w,int h,string path) {
    var bmp=new Bitmap(w,h,PixelFormat.Format24bppRgb);
    var rect=new Rectangle(0,0,w,h);
    var bd=bmp.LockBits(rect,ImageLockMode.WriteOnly,PixelFormat.Format24bppRgb);
    try {
      byte[] rgb=new byte[bd.Stride*h];
      for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
        byte v=gray[y*w+x];int p=y*bd.Stride+3*x;
        rgb[p]=v;rgb[p+1]=v;rgb[p+2]=v;
      }
      Marshal.Copy(rgb,0,bd.Scan0,rgb.Length);
    } finally { bmp.UnlockBits(bd); }
    try { bmp.Save(path,ImageFormat.Png); } finally { bmp.Dispose(); }
  }
  public static string Run(string captureDir,double pitch,string outDir,int width) {
    byte[] src=Load(captureDir);
    int h=(int)Math.Floor((src.Length-width)/pitch)+1;
    byte[] raster=new byte[width*h]; double[] rowMean=new double[h];
    int[] hist=new int[256];
    for(int y=0;y<h;y++) {
      double start=y*pitch; double sum=0;
      for(int x=0;x<width;x++) {
        double s=start+x; int i=(int)Math.Floor(s); double f=s-i;
        double v=(i+1<src.Length)?src[i]*(1-f)+src[i+1]*f:src[i];
        byte b=(byte)Math.Max(0,Math.Min(255,Math.Round(v)));
        raster[y*width+x]=b;hist[b]++;sum+=b;
      }
      rowMean[y]=sum/width;
    }
    int total=width*h,acc=0,lo=0,hi=255;
    int loTarget=(int)Math.Ceiling(total*.01),hiTarget=(int)Math.Ceiling(total*.99);
    for(int i=0;i<256;i++){acc+=hist[i];if(acc>=loTarget){lo=i;break;}}
    acc=0;for(int i=0;i<256;i++){acc+=hist[i];if(acc>=hiTarget){hi=i;break;}}
    if(hi<=lo){lo=0;hi=255;}
    for(int i=0;i<raster.Length;i++) raster[i]=(byte)Math.Max(0,Math.Min(255,Math.Round(255.0*(raster[i]-lo)/(hi-lo))));
    double rm=0;for(int y=0;y<h;y++)rm+=rowMean[y];rm/=h;
    double rv=0;for(int y=0;y<h;y++){double d=rowMean[y]-rm;rv+=d*d;}double rs=Math.Sqrt(rv/h);
    byte[] profile=new byte[width*h];
    for(int y=0;y<h;y++) {
      byte v=(byte)Math.Max(0,Math.Min(255,Math.Round(128+32*(rowMean[y]-rm)/Math.Max(rs,1e-9))));
      for(int x=0;x<width;x++)profile[y*width+x]=v;
    }
    double[] fold=new double[16];int[] foldN=new int[16];
    for(int y=0;y<h;y++){int p=y&15;fold[p]+=rowMean[y];foldN[p]++;}
    double foldMean=0;for(int p=0;p<16;p++){fold[p]/=foldN[p];foldMean+=fold[p];}foldMean/=16;
    double foldVar=0;for(int p=0;p<16;p++){double d=fold[p]-foldMean;foldVar+=d*d;}double foldStd=Math.Sqrt(foldVar/16);
    string raw=Path.Combine(outDir,"fractional_raw.png"),rows=Path.Combine(outDir,"row_average.png");
    Save(raster,width,h,raw);Save(profile,width,h,rows);
    var result=new System.Text.StringBuilder();
    result.AppendLine("FRACTIONAL_RASTER_PASS");
    result.AppendLine("line_pitch="+pitch.ToString("F6"));
    result.AppendLine("width="+width);result.AppendLine("lines="+h);
    result.AppendLine("row_mean="+rm.ToString("F6"));result.AppendLine("row_std="+rs.ToString("F6"));
    result.AppendLine("fold16_std="+foldStd.ToString("F6"));
    for(int p=0;p<16;p++)result.AppendLine("fold16["+p+"]="+fold[p].ToString("F6"));
    result.AppendLine("raw="+raw);result.AppendLine("row_average="+rows);
    return result.ToString();
  }
}
'@ -ReferencedAssemblies System.Drawing

$capture=(Resolve-Path -LiteralPath $CaptureDir).Path
$out=[IO.Path]::GetFullPath($OutDir)
[FractionalRasterRecovery]::Run($capture,$LinePitch,$out,$OutputWidth)
