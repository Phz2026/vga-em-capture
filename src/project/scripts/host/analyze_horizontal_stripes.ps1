param(
    [Parameter(Mandatory=$true)][string]$CaptureDir,
    [int]$TotalSamples=1083264,
    [int]$StripeHeight=8,
    [int]$MinLineSamples=1280,
    [int]$MaxLineSamples=1400,
    [int]$CorrelationStep=8
)
$ErrorActionPreference='Stop'

Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Collections.Generic;
using System.Text;

public static class HorizontalStripeAnalyzer {
  static byte ParseData(string line) {
    int p=-1;
    for(int i=0;i<3;i++) p=line.IndexOf(',',p+1);
    int q=line.IndexOf(',',p+1);
    return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
  }
  static byte[] Load(string dir,int total) {
    string[] files=Directory.GetFiles(dir,"segment_*.csv");
    Array.Sort(files,StringComparer.OrdinalIgnoreCase);
    byte[] a=new byte[total]; int pos=0;
    foreach(string f in files) using(var sr=new StreamReader(f)) {
      sr.ReadLine(); sr.ReadLine(); string line;
      while(pos<total && (line=sr.ReadLine())!=null) a[pos++]=ParseData(line);
    }
    if(pos!=total) throw new Exception("Expected "+total+" samples, read "+pos);
    return a;
  }
  static double Corr(byte[] a,int lag,int step) {
    double sx=0,sy=0,sxx=0,syy=0,sxy=0; long n=0;
    for(int i=0;i+lag<a.Length;i+=step) {
      double x=a[i],y=a[i+lag];
      sx+=x; sy+=y; sxx+=x*x; syy+=y*y; sxy+=x*y; n++;
    }
    double num=sxy-sx*sy/n,dx=sxx-sx*sx/n,dy=syy-sy*sy/n;
    return (dx<=0||dy<=0)?0:num/Math.Sqrt(dx*dy);
  }
  public static string Analyze(string dir,int total,int stripeHeight,int minLine,int maxLine,int step) {
    byte[] a=Load(dir,total);
    var results=new List<Tuple<int,double,double,double>>();
    int minPeriod=2*stripeHeight*minLine, maxPeriod=2*stripeHeight*maxLine;
    for(int period=minPeriod;period<=maxPeriod;period++) {
      int halfPeriod=(int)Math.Round(period/2.0);
      double half=Corr(a,halfPeriod,step);
      double full=Corr(a,period,step);
      double score=full-half;
      results.Add(Tuple.Create(period,score,half,full));
    }
    results.Sort((u,v)=>v.Item2.CompareTo(u.Item2));
    var b=results[0]; var sb=new StringBuilder();
    sb.AppendLine("HORIZONTAL_STRIPE_ANALYSIS");
    sb.AppendLine("stripe_height_lines="+stripeHeight);
    sb.AppendLine("best_line_samples="+(b.Item1/(2.0*stripeHeight)).ToString("F6"));
    sb.AppendLine("half_period_samples="+(int)Math.Round(b.Item1/2.0));
    sb.AppendLine("full_period_samples="+b.Item1);
    sb.AppendLine("half_period_corr="+b.Item3.ToString("F6"));
    sb.AppendLine("full_period_corr="+b.Item4.ToString("F6"));
    sb.AppendLine("inversion_score="+b.Item2.ToString("F6"));
    for(int i=0;i<Math.Min(12,results.Count);i++) {
      var r=results[i];
      sb.AppendLine("candidate["+i+"]="+r.Item1+","+r.Item2.ToString("F6")+","+r.Item3.ToString("F6")+","+r.Item4.ToString("F6"));
    }
    return sb.ToString();
  }
}
'@

$dir=(Resolve-Path -LiteralPath $CaptureDir).Path
[HorizontalStripeAnalyzer]::Analyze($dir,$TotalSamples,$StripeHeight,$MinLineSamples,$MaxLineSamples,$CorrelationStep)
