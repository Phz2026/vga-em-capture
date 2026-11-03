param(
    [Parameter(Mandatory=$true)][string]$CaptureDir,
    [int]$LineSamples=1344,
    [int]$FrameLines=806
)
$ErrorActionPreference='Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

public static class FramePeriodAnalyzer {
  static byte ParseData(string line) {
    int p=-1;
    for(int i=0;i<3;i++) p=line.IndexOf(',',p+1);
    int q=line.IndexOf(',',p+1);
    return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
  }
  static double Corr(byte[] a,int lag,int count) {
    count=Math.Min(count,a.Length-lag);
    double sx=0,sy=0,sxx=0,syy=0,sxy=0;
    for(int i=0;i<count;i++) {
      double x=a[i],y=a[i+lag]; sx+=x;sy+=y;sxx+=x*x;syy+=y*y;sxy+=x*y;
    }
    double n=count,num=sxy-sx*sy/n,dx=sxx-sx*sx/n,dy=syy-sy*sy/n;
    return (dx<=0||dy<=0)?0:num/Math.Sqrt(dx*dy);
  }
  static double FoldContrast(byte[] a,int period) {
    double[] sum=new double[period]; int[] n=new int[period];
    for(int i=0;i<a.Length;i++){int p=i%period;sum[p]+=a[i];n[p]++;}
    double mean=0;for(int p=0;p<period;p++){sum[p]/=n[p];mean+=sum[p];}mean/=period;
    double v=0;for(int p=0;p<period;p++){double d=sum[p]-mean;v+=d*d;}return Math.Sqrt(v/period);
  }
  public static string Analyze(string dir,int total) {
    string[] files=Directory.GetFiles(dir,"segment_*.csv");Array.Sort(files,StringComparer.OrdinalIgnoreCase);
    byte[] a=new byte[total];int pos=0;
    foreach(string f in files) using(var sr=new StreamReader(f)) {
      sr.ReadLine();sr.ReadLine();string line;
      while(pos<total && (line=sr.ReadLine())!=null) a[pos++]=ParseData(line);
    }
    if(pos!=total) throw new Exception("Expected "+total+" samples, read "+pos);
    double mean=0;for(int i=0;i<total;i++)mean+=a[i];mean/=total;
    double var=0;for(int i=0;i<total;i++){double d=a[i]-mean;var+=d*d;}double sd=Math.Sqrt(var/total);
    var sb=new System.Text.StringBuilder();
    sb.AppendLine("FRAME_PERIOD_ANALYSIS");sb.AppendLine("samples="+total);sb.AppendLine("mean="+mean.ToString("F6"));sb.AppendLine("stddev="+sd.ToString("F6"));
    int[] lags={1,2,4,8,16,31,32,33,48,63,64,65,96,128};
    foreach(int lag in lags) sb.AppendLine("corr["+lag+"]="+Corr(a,lag,500000).ToString("F6"));
    int bestLag=0;double best=-2;
    for(int lag=1280;lag<=1400;lag++){double c=Corr(a,lag,300000);if(c>best){best=c;bestLag=lag;}}
    sb.AppendLine("best_line_lag="+bestLag);sb.AppendLine("best_line_corr="+best.ToString("F6"));
    int[] periods={16,31,32,33,64};foreach(int p in periods)sb.AppendLine("fold_std["+p+"]="+FoldContrast(a,p).ToString("F6"));
    return sb.ToString();
  }
}
'@

$dir=(Resolve-Path -LiteralPath $CaptureDir).Path
[FramePeriodAnalyzer]::Analyze($dir,$LineSamples*$FrameLines)
