param(
  [Parameter(Mandatory=$true)][string]$ReferenceDir,
  [Parameter(Mandatory=$true)][string]$TestDir,
  [int]$LineSamples=1344,
  [int]$FrameLines=806
)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Text;
public static class BlindSyncEstimate {
  static byte Parse(string s){int p=-1;for(int i=0;i<3;i++)p=s.IndexOf(',',p+1);int q=s.IndexOf(',',p+1);return byte.Parse(s.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);}
  static byte[] Load(string d,int n){string[] fs=Directory.GetFiles(d,"segment_*.csv");Array.Sort(fs,StringComparer.OrdinalIgnoreCase);byte[] a=new byte[n];int k=0;foreach(string f in fs)using(var r=new StreamReader(f)){r.ReadLine();r.ReadLine();string s;while(k<n&&(s=r.ReadLine())!=null)a[k++]=Parse(s);if(k==n)break;}if(k!=n)throw new Exception("Incomplete capture");return a;}
  static void Norm(double[] a){double m=0;foreach(double v in a)m+=v;m/=a.Length;double q=0;for(int i=0;i<a.Length;i++){a[i]-=m;q+=a[i]*a[i];}q=Math.Sqrt(q);for(int i=0;i<a.Length;i++)a[i]/=q;}
  static double Best(double[] a,double[] b,out int shift,out double second){shift=0;double best=-2;second=-2;for(int d=0;d<a.Length;d++){double c=0;for(int i=0;i<a.Length;i++)c+=a[i]*b[(i+d)%a.Length];if(c>best){second=best;best=c;shift=d;}else if(c>second)second=c;}return best;}
  public static string Run(string ad,string bd,int w,int h){byte[] a=Load(ad,w*h),b=Load(bd,w*h);double[] ax=new double[w],bx=new double[w],ay=new double[h],by=new double[h];for(int y=0;y<h;y++)for(int x=0;x<w;x++){ax[x]+=a[y*w+x];bx[x]+=b[y*w+x];ay[y]+=a[y*w+x];by[y]+=b[y*w+x];}Norm(ax);Norm(bx);Norm(ay);Norm(by);int dx,dy;double sx,sy;double cx=Best(ax,bx,out dx,out sx),cy=Best(ay,by,out dy,out sy);var r=new StringBuilder();r.AppendLine("BLIND_SYNC_ESTIMATE");r.AppendLine("x_shift="+dx);r.AppendLine("x_correlation="+cx.ToString("F6"));r.AppendLine("x_second="+sx.ToString("F6"));r.AppendLine("y_shift="+dy);r.AppendLine("y_correlation="+cy.ToString("F6"));r.AppendLine("y_second="+sy.ToString("F6"));return r.ToString();}
}
'@
$a=(Resolve-Path -LiteralPath $ReferenceDir).Path;$b=(Resolve-Path -LiteralPath $TestDir).Path
[BlindSyncEstimate]::Run($a,$b,$LineSamples,$FrameLines)
