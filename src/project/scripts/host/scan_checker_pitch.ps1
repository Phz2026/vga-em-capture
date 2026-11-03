param(
    [Parameter(Mandatory=$true)][string]$CaptureDir,
    [int]$TotalSamples=1083264,
    [int]$MinPitch=1280,
    [int]$MaxPitch=1400
)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;

public static class CheckerPitchScanner {
  static byte ParseData(string line) {
    int p=-1; for(int i=0;i<3;i++) p=line.IndexOf(',',p+1);
    int q=line.IndexOf(',',p+1);
    return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
  }
  static byte[] Load(string dir,int total) {
    string[] files=Directory.GetFiles(dir,"segment_*.csv"); Array.Sort(files,StringComparer.OrdinalIgnoreCase);
    byte[] a=new byte[total]; int pos=0;
    foreach(string f in files) using(var sr=new StreamReader(f)) {
      sr.ReadLine();sr.ReadLine();string line;
      while(pos<total && (line=sr.ReadLine())!=null) a[pos++]=ParseData(line);
    }
    if(pos!=total) throw new Exception("Expected "+total+" samples, read "+pos);
    return a;
  }
  static double Score(byte[] a,int pitch) {
    double[] sum=new double[1024]; int[] count=new int[1024];
    int rows=a.Length/pitch;
    for(int y=0;y<rows;y++) {
      int row=y*pitch;
      for(int x=0;x<pitch;x++) {int k=((y&31)<<5)|(x&31);sum[k]+=a[row+x];count[k]++;}
    }
    for(int k=0;k<1024;k++) if(count[k]>0) sum[k]/=count[k];
    double best=0;
    for(int dy=0;dy<32;dy++) for(int dx=0;dx<32;dx++) {
      double s=0;
      for(int y=0;y<32;y++) for(int x=0;x<32;x++) {
        int sign=((((x+dx)&31)>>4)+(((y+dy)&31)>>4))%2==0?1:-1;
        s+=sign*sum[(y<<5)|x];
      }
      s=Math.Abs(s/1024.0); if(s>best) best=s;
    }
    return best;
  }
  public static string Scan(string dir,int total,int minPitch,int maxPitch) {
    byte[] a=Load(dir,total); int bestPitch=0;double best=-1;
    var scores=new System.Collections.Generic.List<Tuple<int,double>>();
    for(int p=minPitch;p<=maxPitch;p++){double s=Score(a,p);scores.Add(Tuple.Create(p,s));if(s>best){best=s;bestPitch=p;}}
    scores.Sort((u,v)=>v.Item2.CompareTo(u.Item2));
    var sb=new System.Text.StringBuilder();sb.AppendLine("CHECKER_PITCH_SCAN");
    sb.AppendLine("best_pitch="+bestPitch);sb.AppendLine("best_checker_contrast="+best.ToString("F6"));
    for(int i=0;i<Math.Min(12,scores.Count);i++)sb.AppendLine("candidate["+i+"]="+scores[i].Item1+","+scores[i].Item2.ToString("F6"));
    return sb.ToString();
  }
}
'@
$dir=(Resolve-Path -LiteralPath $CaptureDir).Path
[CheckerPitchScanner]::Scan($dir,$TotalSamples,$MinPitch,$MaxPitch)
