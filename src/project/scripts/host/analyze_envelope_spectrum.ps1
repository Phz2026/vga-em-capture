param(
    [Parameter(Mandatory=$true)][string]$CaptureDir,
    [double]$SampleRateHz=65000000.0,
    [int]$FftLength=1048576,
    [double]$MinHz=1000.0,
    [double]$MaxHz=10000.0,
    [double]$FineStepHz=1.0,
    [int]$FineDecimation=64
)
$ErrorActionPreference='Stop'

Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.IO;
using System.Text;

public static class EnvelopeSpectrumAnalyzer {
  static byte ParseData(string line) {
    int p=-1;
    for(int i=0;i<3;i++) p=line.IndexOf(',',p+1);
    int q=line.IndexOf(',',p+1);
    return byte.Parse(line.Substring(p+1,q-p-1),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
  }
  static double[] Load(string dir,int n) {
    string[] files=Directory.GetFiles(dir,"segment_*.csv");
    Array.Sort(files,StringComparer.OrdinalIgnoreCase);
    double[] a=new double[n]; int pos=0;
    foreach(string f in files) using(var sr=new StreamReader(f)) {
      sr.ReadLine(); sr.ReadLine(); string line;
      while(pos<n && (line=sr.ReadLine())!=null) a[pos++]=ParseData(line);
      if(pos==n) break;
    }
    if(pos!=n) throw new Exception("Expected "+n+" samples, read "+pos);
    return a;
  }
  static void Fft(double[] re,double[] im) {
    int n=re.Length;
    for(int i=1,j=0;i<n;i++) {
      int bit=n>>1;
      for(; (j&bit)!=0; bit>>=1) j^=bit;
      j^=bit;
      if(i<j) { double t=re[i];re[i]=re[j];re[j]=t; t=im[i];im[i]=im[j];im[j]=t; }
    }
    for(int len=2;len<=n;len<<=1) {
      double ang=-2.0*Math.PI/len, wlr=Math.Cos(ang), wli=Math.Sin(ang);
      for(int i=0;i<n;i+=len) {
        double wr=1,wi=0;
        for(int j=0;j<len/2;j++) {
          int u=i+j,v=u+len/2;
          double vr=re[v]*wr-im[v]*wi, vi=re[v]*wi+im[v]*wr;
          re[v]=re[u]-vr; im[v]=im[u]-vi; re[u]+=vr; im[u]+=vi;
          double nw=wr*wlr-wi*wli; wi=wr*wli+wi*wlr; wr=nw;
        }
      }
    }
  }
  static double FineAmplitude(double[] x,double fs,double hz,int decimation) {
    int m=x.Length/decimation;
    double mean=0; for(int i=0;i<x.Length;i++) mean+=x[i]; mean/=x.Length;
    double wr=Math.Cos(-2*Math.PI*hz*decimation/fs), wi=Math.Sin(-2*Math.PI*hz*decimation/fs);
    double pr=1,pi=0,sr=0,si=0,ws=0;
    for(int b=0;b<m;b++) {
      double v=0; int baseIndex=b*decimation;
      for(int j=0;j<decimation;j++) v+=x[baseIndex+j]-mean;
      v/=decimation;
      double w=0.5-0.5*Math.Cos(2*Math.PI*b/(m-1));
      sr+=v*w*pr; si+=v*w*pi; ws+=w;
      double nr=pr*wr-pi*wi; pi=pr*wi+pi*wr; pr=nr;
    }
    return 2.0*Math.Sqrt(sr*sr+si*si)/ws;
  }
  public static string Analyze(string dir,double fs,int n,double minHz,double maxHz,double fineStep,int fineDecimation) {
    if((n&(n-1))!=0) throw new Exception("FftLength must be a power of two");
    double[] original=Load(dir,n), re=(double[])original.Clone(), im=new double[n];
    double mean=0; for(int i=0;i<n;i++) mean+=re[i]; mean/=n;
    double windowSum=0;
    for(int i=0;i<n;i++) {
      double w=0.5-0.5*Math.Cos(2*Math.PI*i/(n-1));
      re[i]=(re[i]-mean)*w; windowSum+=w;
    }
    Fft(re,im);
    int lo=Math.Max(1,(int)Math.Ceiling(minHz*n/fs));
    int hi=Math.Min(n/2-1,(int)Math.Floor(maxHz*n/fs));
    int[] top=new int[10]; double[] topAmp=new double[10];
    for(int k=lo;k<=hi;k++) {
      double amp=2.0*Math.Sqrt(re[k]*re[k]+im[k]*im[k])/windowSum;
      for(int j=0;j<top.Length;j++) if(amp>topAmp[j]) {
        for(int m=top.Length-1;m>j;m--){topAmp[m]=topAmp[m-1];top[m]=top[m-1];}
        topAmp[j]=amp;top[j]=k;break;
      }
    }
    var sb=new StringBuilder();
    sb.AppendLine("ENVELOPE_SPECTRUM_ANALYSIS");
    sb.AppendLine("fft_length="+n);
    sb.AppendLine("resolution_hz="+(fs/n).ToString("F6"));
    sb.AppendLine("mean_code="+mean.ToString("F6"));
    double fineBest=-1,fineHz=0;
    for(double hz=minHz;hz<=maxHz+fineStep*0.1;hz+=fineStep) {
      double a=FineAmplitude(original,fs,hz,fineDecimation);
      if(a>fineBest){fineBest=a;fineHz=hz;}
    }
    sb.AppendLine("fine_peak="+fineHz.ToString("F3")+" Hz, amplitude="+fineBest.ToString("F6")+" code");
    for(int j=0;j<top.Length;j++) {
      double hz=top[j]*fs/n;
      double dbfs=20*Math.Log10(Math.Max(topAmp[j]/255.0,1e-15));
      sb.AppendLine("peak["+j+"]="+hz.ToString("F3")+" Hz, amplitude="+topAmp[j].ToString("F6")+" code, "+dbfs.ToString("F3")+" dBFS");
    }
    return sb.ToString();
  }
}
'@

$dir=(Resolve-Path -LiteralPath $CaptureDir).Path
[EnvelopeSpectrumAnalyzer]::Analyze($dir,$SampleRateHz,$FftLength,$MinHz,$MaxHz,$FineStepHz,$FineDecimation)
