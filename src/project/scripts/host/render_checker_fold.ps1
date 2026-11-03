param(
  [Parameter(Mandatory=$true)][string]$CaptureDir,
  [string]$OutPng,
  [int]$LineSamples=1344,
  [int]$FrameLines=806,
  [int]$Period=32,
  [int]$Scale=16
)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($OutPng)){$OutPng=Join-Path $CaptureDir 'checker_fold.png'}
$parent=Split-Path -Parent $OutPng;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}

Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class CheckerFoldRenderer {
  static byte ParseData(string line) {
    int p=-1;for(int i=0;i<3;i++)p=line.IndexOf(',',p+1);
    int q=line.IndexOf(',',p+1);
    return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
  }
  static byte[] Load(string dir,int total) {
    string[] fs=Directory.GetFiles(dir,"segment_*.csv");Array.Sort(fs,StringComparer.OrdinalIgnoreCase);
    byte[] a=new byte[total];int n=0;
    foreach(string f in fs)using(var sr=new StreamReader(f)){
      sr.ReadLine();sr.ReadLine();string line;
      while(n<total&&(line=sr.ReadLine())!=null)a[n++]=ParseData(line);
      if(n==total)break;
    }
    if(n!=total)throw new Exception("Expected "+total+" samples, read "+n);
    return a;
  }
  public static string Run(string dir,string path,int w,int h,int period,int scale) {
    byte[] a=Load(dir,w*h);double[] sum=new double[period*period];int[] count=new int[period*period];
    for(int y=0;y<h;y++)for(int x=0;x<w;x++){
      int k=(y%period)*period+(x%period);sum[k]+=a[y*w+x];count[k]++;
    }
    double mean=0;for(int k=0;k<sum.Length;k++){sum[k]/=count[k];mean+=sum[k];}mean/=sum.Length;
    double var=0;for(int k=0;k<sum.Length;k++){double d=sum[k]-mean;var+=d*d;}double sd=Math.Sqrt(var/sum.Length);
    int bestDx=0,bestDy=0;double bestSigned=0,bestAbs=-1;
    for(int dy=0;dy<period;dy++)for(int dx=0;dx<period;dx++){
      double s=0;
      for(int y=0;y<period;y++)for(int x=0;x<period;x++){
        int sign=(((((x+dx)%period)/(period/2))+(((y+dy)%period)/(period/2)))&1)==0?1:-1;
        s+=sign*sum[y*period+x];
      }
      s/=period*period;if(Math.Abs(s)>bestAbs){bestAbs=Math.Abs(s);bestSigned=s;bestDx=dx;bestDy=dy;}
    }
    int ow=period*scale,oh=period*scale;var bmp=new Bitmap(ow,oh,PixelFormat.Format24bppRgb);
    var bd=bmp.LockBits(new Rectangle(0,0,ow,oh),ImageLockMode.WriteOnly,PixelFormat.Format24bppRgb);
    try{
      byte[] rgb=new byte[bd.Stride*oh];
      for(int oy=0;oy<oh;oy++)for(int ox=0;ox<ow;ox++){
        int x=(ox/scale-bestDx+period)%period,y=(oy/scale-bestDy+period)%period;
        double polarity=bestSigned>=0?1.0:-1.0;
        double z=polarity*(sum[y*period+x]-mean)/Math.Max(sd,1e-12);
        byte v=(byte)Math.Max(0,Math.Min(255,Math.Round(128+42*z)));
        int p=oy*bd.Stride+3*ox;rgb[p]=v;rgb[p+1]=v;rgb[p+2]=v;
      }
      Marshal.Copy(rgb,0,bd.Scan0,rgb.Length);
    }finally{bmp.UnlockBits(bd);}
    try{bmp.Save(path,ImageFormat.Png);}finally{bmp.Dispose();}
    double[] quad=new double[4];int qn=(period/2)*(period/2);
    for(int yy=0;yy<period;yy++)for(int xx=0;xx<period;xx++){
      int x=(xx-bestDx+period)%period,y=(yy-bestDy+period)%period;
      int q=(yy>=period/2?2:0)+(xx>=period/2?1:0);quad[q]+=sum[y*period+x];
    }
    for(int q=0;q<4;q++)quad[q]/=qn;
    var r=new StringBuilder();r.AppendLine("CHECKER_FOLD_PASS");
    r.AppendLine("period="+period);r.AppendLine("fold_mean="+mean.ToString("F6"));r.AppendLine("fold_std="+sd.ToString("F6"));
    r.AppendLine("checker_contrast="+bestAbs.ToString("F6"));r.AppendLine("template_correlation="+(bestAbs/Math.Max(sd,1e-12)).ToString("F6"));
    r.AppendLine("phase_x="+bestDx);r.AppendLine("phase_y="+bestDy);r.AppendLine("polarity="+(bestSigned>=0?"positive":"negative"));
    r.AppendLine("quadrants="+quad[0].ToString("F6")+","+quad[1].ToString("F6")+","+quad[2].ToString("F6")+","+quad[3].ToString("F6"));r.AppendLine("output="+path);
    return r.ToString();
  }
}
'@ -ReferencedAssemblies System.Drawing

$dir=(Resolve-Path -LiteralPath $CaptureDir).Path
$out=[IO.Path]::GetFullPath($OutPng)
[CheckerFoldRenderer]::Run($dir,$out,$LineSamples,$FrameLines,$Period,$Scale)
