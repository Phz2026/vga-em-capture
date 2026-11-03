param(
  [Parameter(Mandatory=$true)][string]$ReferenceDir,
  [Parameter(Mandatory=$true)][string]$TestDir,
  [int]$LineSamples=1344,
  [int]$FrameLines=806,
  [int]$BlockX=16,
  [int]$BlockY=13
)
$ErrorActionPreference='Stop'

Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Text;
public static class BlindFrameCorrelation {
  static byte ParseData(string line){int p=-1;for(int i=0;i<3;i++)p=line.IndexOf(',',p+1);int q=line.IndexOf(',',p+1);return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);}
  static byte[] Load(string dir,int n){string[] fs=Directory.GetFiles(dir,"segment_*.csv");Array.Sort(fs,StringComparer.OrdinalIgnoreCase);byte[] a=new byte[n];int k=0;foreach(string f in fs)using(var sr=new StreamReader(f)){sr.ReadLine();sr.ReadLine();string line;while(k<n&&(line=sr.ReadLine())!=null)a[k++]=ParseData(line);if(k==n)break;}if(k!=n)throw new Exception("Expected "+n+" samples, read "+k);return a;}
  static double[] Blocks(string dir,int w,int h,int bx,int by,out int cw,out int ch){if(w%bx!=0||h%by!=0)throw new Exception("Block dimensions must divide raster dimensions");cw=w/bx;ch=h/by;byte[] a=Load(dir,w*h);double[] d=new double[cw*ch];for(int yy=0;yy<ch;yy++)for(int xx=0;xx<cw;xx++){double s=0;for(int y=0;y<by;y++)for(int x=0;x<bx;x++)s+=a[(yy*by+y)*w+xx*bx+x];d[yy*cw+xx]=s/(bx*by);}double m=0;foreach(double v in d)m+=v;m/=d.Length;double q=0;for(int i=0;i<d.Length;i++){d[i]-=m;q+=d[i]*d[i];}q=Math.Sqrt(q);for(int i=0;i<d.Length;i++)d[i]/=q;return d;}
  public static string Run(string refDir,string testDir,int w,int h,int bx,int by){int cw1,ch1,cw2,ch2;double[] a=Blocks(refDir,w,h,bx,by,out cw1,out ch1),b=Blocks(testDir,w,h,bx,by,out cw2,out ch2);if(cw1!=cw2||ch1!=ch2)throw new Exception("Shape mismatch");int bestX=0,bestY=0;double best=-2,second=-2;for(int dy=0;dy<ch1;dy++)for(int dx=0;dx<cw1;dx++){double c=0;for(int y=0;y<ch1;y++){int sy=(y+dy)%ch1;for(int x=0;x<cw1;x++)c+=a[y*cw1+x]*b[sy*cw1+(x+dx)%cw1];}if(c>best){second=best;best=c;bestX=dx;bestY=dy;}else if(c>second)second=c;}var r=new StringBuilder();r.AppendLine("BLIND_FRAME_CORRELATION");r.AppendLine("coarse_grid="+cw1+"x"+ch1);r.AppendLine("block="+bx+"x"+by);r.AppendLine("best_shift_blocks="+bestX+","+bestY);r.AppendLine("best_shift_samples="+(bestX*bx)+","+(bestY*by));r.AppendLine("best_correlation="+best.ToString("F6"));r.AppendLine("second_correlation="+second.ToString("F6"));return r.ToString();}
}
'@
$a=(Resolve-Path -LiteralPath $ReferenceDir).Path;$b=(Resolve-Path -LiteralPath $TestDir).Path
[BlindFrameCorrelation]::Run($a,$b,$LineSamples,$FrameLines,$BlockX,$BlockY)
