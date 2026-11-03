param(
  [Parameter(Mandatory=$true)][string]$ReferenceDir,
  [Parameter(Mandatory=$true)][string]$TestDir,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [int]$LineSamples=1344,[int]$FrameLines=806,
  [int]$ActiveWidth=1024,[int]$ActiveHeight=768,
  [int]$RadiusX=32,[int]$RadiusY=16
)
$ErrorActionPreference='Stop';New-Item -ItemType Directory -Force -Path $OutDir|Out-Null
Add-Type -TypeDefinition @'
using System;using System.Globalization;using System.IO;using System.Text;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
public static class BlindAlignAverage{
static byte Parse(string s){int p=-1;for(int i=0;i<3;i++)p=s.IndexOf(',',p+1);int q=s.IndexOf(',',p+1);return byte.Parse(s.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);}
static byte[] Load(string d,int n){string[] fs=Directory.GetFiles(d,"segment_*.csv");Array.Sort(fs,StringComparer.OrdinalIgnoreCase);byte[] a=new byte[n];int k=0;foreach(string f in fs)using(var r=new StreamReader(f)){r.ReadLine();r.ReadLine();string s;while(k<n&&(s=r.ReadLine())!=null)a[k++]=Parse(s);if(k==n)break;}if(k!=n)throw new Exception("Incomplete capture");return a;}
static void Norm(double[] a){double m=0;foreach(double v in a)m+=v;m/=a.Length;double q=0;for(int i=0;i<a.Length;i++){a[i]-=m;q+=a[i]*a[i];}q=Math.Sqrt(q);for(int i=0;i<a.Length;i++)a[i]/=q;}
static double Best(double[] a,double[] b,out int sh){sh=0;double best=-2;for(int d=0;d<a.Length;d++){double c=0;for(int i=0;i<a.Length;i++)c+=a[i]*b[(i+d)%a.Length];if(c>best){best=c;sh=d;}}return best;}
static double[] Blur(double[] src,int w,int h,int rx,int ry){double[] t=new double[src.Length],d=new double[src.Length];int nx=2*rx+1,ny=2*ry+1;for(int y=0;y<h;y++){double s=0;for(int k=-rx;k<=rx;k++)s+=src[y*w+(k+w)%w];for(int x=0;x<w;x++){t[y*w+x]=s/nx;s-=src[y*w+(x-rx+w)%w];s+=src[y*w+(x+rx+1)%w];}}for(int x=0;x<w;x++){double s=0;for(int k=-ry;k<=ry;k++)s+=t[((k+h)%h)*w+x];for(int y=0;y<h;y++){d[y*w+x]=s/ny;s-=t[((y-ry+h)%h)*w+x];s+=t[((y+ry+1)%h)*w+x];}}return d;}
static int Win(double[] e,int n){double s=0;for(int i=0;i<n;i++)s+=e[i];double b=s;int bi=0;for(int i=1;i<e.Length;i++){s-=e[i-1];s+=e[(i+n-1)%e.Length];if(s>b){b=s;bi=i;}}return bi;}
static void Save(double[] a,int sw,int sh,int x0,int y0,int w,int h,string path,double lo,double hi){var m=new Bitmap(w,h,PixelFormat.Format24bppRgb);var bd=m.LockBits(new Rectangle(0,0,w,h),ImageLockMode.WriteOnly,PixelFormat.Format24bppRgb);try{byte[] q=new byte[bd.Stride*h];for(int y=0;y<h;y++)for(int x=0;x<w;x++){double z=(a[((y+y0)%sh)*sw+(x+x0)%sw]-lo)/(hi-lo);byte v=(byte)Math.Max(0,Math.Min(255,Math.Round(255*z)));int p=y*bd.Stride+3*x;q[p]=v;q[p+1]=v;q[p+2]=v;}Marshal.Copy(q,0,bd.Scan0,q.Length);}finally{m.UnlockBits(bd);}try{m.Save(path,ImageFormat.Png);}finally{m.Dispose();}}
public static string Run(string ad,string bd,string od,int w,int h,int aw,int ah,int rx,int ry){byte[] a=Load(ad,w*h),b=Load(bd,w*h);double[] ax=new double[w],bx=new double[w],ay=new double[h],by=new double[h];for(int y=0;y<h;y++)for(int x=0;x<w;x++){ax[x]+=a[y*w+x];bx[x]+=b[y*w+x];ay[y]+=a[y*w+x];by[y]+=b[y*w+x];}Norm(ax);Norm(bx);Norm(ay);Norm(by);int dx,dy;double cx=Best(ax,bx,out dx),cy=Best(ay,by,out dy);double[] avg=new double[a.Length];for(int y=0;y<h;y++)for(int x=0;x<w;x++)avg[y*w+x]=(a[y*w+x]+b[((y+dy)%h)*w+(x+dx)%w])/2.0;double[] sm=Blur(avg,w,h,rx,ry),gx=new double[w],gy=new double[h];for(int y=0;y<h;y++)for(int x=0;x<w;x++){gx[x]+=Math.Abs(sm[y*w+(x+1)%w]-sm[y*w+x]);gy[y]+=Math.Abs(sm[((y+1)%h)*w+x]-sm[y*w+x]);}int x0=Win(gx,aw),y0=Win(gy,ah);double[] sort=(double[])sm.Clone();Array.Sort(sort);double lo=sort[(int)(sort.Length*.02)],hi=sort[(int)(sort.Length*.98)];string full=Path.Combine(od,"blind_aligned_average_full.png"),crop=Path.Combine(od,"blind_aligned_average_crop.png");Save(sm,w,h,0,0,w,h,full,lo,hi);Save(sm,w,h,x0,y0,aw,ah,crop,lo,hi);var r=new StringBuilder();r.AppendLine("BLIND_ALIGN_AVERAGE_PASS");r.AppendLine("shift="+dx+","+dy);r.AppendLine("x_correlation="+cx.ToString("F6"));r.AppendLine("y_correlation="+cy.ToString("F6"));r.AppendLine("filter="+(2*rx+1)+"x"+(2*ry+1));r.AppendLine("crop_offset="+x0+","+y0);r.AppendLine("full="+full);r.AppendLine("crop="+crop);return r.ToString();}
}
'@ -ReferencedAssemblies System.Drawing
$a=(Resolve-Path -LiteralPath $ReferenceDir).Path;$b=(Resolve-Path -LiteralPath $TestDir).Path;$o=[IO.Path]::GetFullPath($OutDir)
[BlindAlignAverage]::Run($a,$b,$o,$LineSamples,$FrameLines,$ActiveWidth,$ActiveHeight,$RadiusX,$RadiusY)
