param(
  [Parameter(Mandatory=$true)][string[]]$CaptureDirs,
  [Parameter(Mandatory=$true)][string]$OutPng,
  [int]$LineSamples=1344,
  [int]$FrameLines=806,
  [int]$Period=32,
  [int]$Scale=16
)
$ErrorActionPreference='Stop'
$parent=Split-Path -Parent $OutPng;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}

Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class CheckerAverageRenderer {
  static byte ParseData(string line){int p=-1;for(int i=0;i<3;i++)p=line.IndexOf(',',p+1);int q=line.IndexOf(',',p+1);return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);}
  static byte[] Load(string dir,int total){string[] fs=Directory.GetFiles(dir,"segment_*.csv");Array.Sort(fs,StringComparer.OrdinalIgnoreCase);byte[] a=new byte[total];int n=0;foreach(string f in fs)using(var sr=new StreamReader(f)){sr.ReadLine();sr.ReadLine();string line;while(n<total&&(line=sr.ReadLine())!=null)a[n++]=ParseData(line);if(n==total)break;}if(n!=total)throw new Exception("Expected "+total+" samples, read "+n);return a;}
  static double[] Fold(string dir,int w,int h,int p,out double mean){byte[] a=Load(dir,w*h);double[] f=new double[p*p];int[] n=new int[p*p];for(int y=0;y<h;y++)for(int x=0;x<w;x++){int k=(y%p)*p+x%p;f[k]+=a[y*w+x];n[k]++;}mean=0;for(int k=0;k<f.Length;k++){f[k]/=n[k];mean+=f[k];}mean/=f.Length;return f;}
  static void Phase(double[] f,int p,out int bx,out int by,out double signed){bx=by=0;signed=0;double best=-1;for(int dy=0;dy<p;dy++)for(int dx=0;dx<p;dx++){double s=0;for(int y=0;y<p;y++)for(int x=0;x<p;x++){int sign=(((((x+dx)%p)/(p/2))+(((y+dy)%p)/(p/2)))&1)==0?1:-1;s+=sign*f[y*p+x];}s/=p*p;if(Math.Abs(s)>best){best=Math.Abs(s);signed=s;bx=dx;by=dy;}}}
  public static string Run(string[] dirs,string path,int w,int h,int p,int scale){
    double[] avg=new double[p*p];var info=new StringBuilder();
    for(int d=0;d<dirs.Length;d++){double mean,s;int dx,dy;double[] f=Fold(dirs[d],w,h,p,out mean);Phase(f,p,out dx,out dy,out s);double pol=s>=0?1:-1;for(int y=0;y<p;y++)for(int x=0;x<p;x++){int sx=(x-dx+p)%p,sy=(y-dy+p)%p;avg[y*p+x]+=pol*(f[sy*p+sx]-mean);}info.AppendLine("frame["+d+"] phase="+dx+","+dy+" polarity="+(pol>0?"positive":"negative")+" contrast="+Math.Abs(s).ToString("F6"));}
    for(int k=0;k<avg.Length;k++)avg[k]/=dirs.Length;double meanA=0;for(int k=0;k<avg.Length;k++)meanA+=avg[k];meanA/=avg.Length;double v=0;for(int k=0;k<avg.Length;k++){double z=avg[k]-meanA;v+=z*z;}double sd=Math.Sqrt(v/avg.Length);double contrast=0;for(int y=0;y<p;y++)for(int x=0;x<p;x++){int sign=(((x/(p/2)+y/(p/2))&1)==0)?1:-1;contrast+=sign*avg[y*p+x];}contrast/=p*p;
    int ow=p*scale,oh=p*scale;var bmp=new Bitmap(ow,oh,PixelFormat.Format24bppRgb);var bd=bmp.LockBits(new Rectangle(0,0,ow,oh),ImageLockMode.WriteOnly,PixelFormat.Format24bppRgb);try{byte[] rgb=new byte[bd.Stride*oh];for(int y=0;y<oh;y++)for(int x=0;x<ow;x++){double z=(avg[(y/scale)*p+x/scale]-meanA)/Math.Max(sd,1e-12);byte b=(byte)Math.Max(0,Math.Min(255,Math.Round(128+42*z)));int q=y*bd.Stride+3*x;rgb[q]=b;rgb[q+1]=b;rgb[q+2]=b;}Marshal.Copy(rgb,0,bd.Scan0,rgb.Length);}finally{bmp.UnlockBits(bd);}try{bmp.Save(path,ImageFormat.Png);}finally{bmp.Dispose();}
    var r=new StringBuilder();r.AppendLine("CHECKER_AVERAGE_PASS");r.Append(info);r.AppendLine("frames="+dirs.Length);r.AppendLine("combined_fold_std="+sd.ToString("F6"));r.AppendLine("combined_checker_contrast="+contrast.ToString("F6"));r.AppendLine("combined_template_correlation="+(contrast/Math.Max(sd,1e-12)).ToString("F6"));r.AppendLine("output="+path);return r.ToString();
  }
}
'@ -ReferencedAssemblies System.Drawing

$dirs=@($CaptureDirs|ForEach-Object{(Resolve-Path -LiteralPath $_).Path})
$out=[IO.Path]::GetFullPath($OutPng)
[CheckerAverageRenderer]::Run($dirs,$out,$LineSamples,$FrameLines,$Period,$Scale)
