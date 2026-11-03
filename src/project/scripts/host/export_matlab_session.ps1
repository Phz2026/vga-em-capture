param(
    [string]$SourceRoot = 'D:\capture',
    [string]$OutputRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'matlab\session_2026_10_19\data')
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$typeSource = @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

public sealed class CaptureInfo {
    public string Name;
    public string Pattern;
    public string DesignGroup;
    public string SourceDirectory;
    public int GainQ8;
    public double Gain;
    public int Repeat;
    public int FrameId;
    public int Segments;
    public int Samples;
    public int FrameSamples;
    public bool AddressContinuous;
    public bool AllValid;
    public bool FrameIdConstant;
    public int TriggerCount;
    public byte Minimum;
    public byte Maximum;
    public double Mean;
    public double StandardDeviation;
    public double RowComponentStd;
    public double ColumnComponentStd;
    public double ResidualStd;
    public double ZeroFraction;
    public double SaturatedFraction;
    public string DataSha256;
    public byte[] Stream;
}

public static class MatlabSessionExporter {
    const int Width = 1344;
    const int Height = 806;
    const int FrameCount = Width * Height;
    const int SegmentLength = 131072;
    const int ExpectedSegments = 9;
    const int StreamCount = SegmentLength * ExpectedSegments;

    static uint HexField(string line, int wanted) {
        int field = 0, start = 0;
        for (int i = 0; i <= line.Length; i++) {
            if (i == line.Length || line[i] == ',') {
                if (field == wanted) {
                    uint value = 0;
                    for (int j = start; j < i; j++) {
                        char c = line[j];
                        int d = c >= '0' && c <= '9' ? c - '0' :
                                c >= 'a' && c <= 'f' ? c - 'a' + 10 :
                                c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
                        if (d < 0) throw new InvalidDataException("Invalid hexadecimal field");
                        value = (value << 4) | (uint)d;
                    }
                    return value;
                }
                field++;
                start = i + 1;
            }
        }
        throw new InvalidDataException("CSV field not found");
    }

    static Dictionary<string,string> Metadata(string path) {
        var d = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        foreach (string line in File.ReadAllLines(path)) {
            int p = line.IndexOf('=');
            if (p > 0) d[line.Substring(0,p).Trim()] = line.Substring(p+1).Trim();
        }
        return d;
    }

    static string Pattern(string name) {
        if (name.Contains("checker16")) return "checker16";
        if (name.Contains("vstripe16")) return "vertical_stripe16";
        if (name.Contains("hstripe8")) return "horizontal_stripe8";
        if (name.Contains("asymmetric")) return "asymmetric_blind";
        if (name.Contains("white")) return "white";
        if (name.Contains("black")) return "black";
        return "unknown";
    }

    static CaptureInfo LoadCapture(string dir) {
        string name = Path.GetFileName(dir.TrimEnd(Path.DirectorySeparatorChar));
        string[] files = Directory.GetFiles(dir, "segment_*.csv");
        Array.Sort(files, StringComparer.OrdinalIgnoreCase);
        if (files.Length != ExpectedSegments) throw new InvalidDataException(name + ": expected 9 CSV segments");
        var md = Metadata(Path.Combine(dir, "metadata.txt"));
        if (int.Parse(md["line_samples"], CultureInfo.InvariantCulture) != Width ||
            int.Parse(md["frame_lines"], CultureInfo.InvariantCulture) != Height)
            throw new InvalidDataException(name + ": raster metadata mismatch");

        var c = new CaptureInfo();
        c.Name = name; c.Pattern = Pattern(name); c.SourceDirectory = dir;
        c.DesignGroup = name.StartsWith("v203_",StringComparison.OrdinalIgnoreCase) ? "v203_q8_fixed" : "pre_q8_fix";
        c.GainQ8 = int.Parse(md["feature_gain_q8"], CultureInfo.InvariantCulture);
        c.Gain = c.GainQ8 / 256.0;
        var rm = Regex.Match(name, @"_r(\d+)$");
        c.Repeat = rm.Success ? int.Parse(rm.Groups[1].Value, CultureInfo.InvariantCulture) : 0;
        c.Segments = files.Length; c.FrameSamples = FrameCount;
        c.Stream = new byte[StreamCount];
        c.AddressContinuous = true; c.AllValid = true; c.FrameIdConstant = true;
        int position = 0, firstFrameId = -1, triggers = 0;
        long sum = 0, sumSq = 0, zeros = 0, saturated = 0;

        foreach (string file in files) {
            using (var reader = new StreamReader(file)) {
                string header = reader.ReadLine();
                reader.ReadLine();
                if (header == null || !header.Contains("processing_image_data"))
                    throw new InvalidDataException(name + ": unexpected CSV header");
                string line;
                while ((line = reader.ReadLine()) != null) {
                    if (position >= StreamCount) throw new InvalidDataException(name + ": too many samples");
                    byte value = (byte)HexField(line, 3);
                    int address = (int)HexField(line, 4);
                    int valid = (int)HexField(line, 5);
                    int trigger = (int)HexField(line, 6);
                    int frameId = (int)HexField(line, 7);
                    if (address != position) c.AddressContinuous = false;
                    if (valid != 1) c.AllValid = false;
                    if (trigger != 0) triggers++;
                    if (firstFrameId < 0) firstFrameId = frameId;
                    else if (frameId != firstFrameId) c.FrameIdConstant = false;
                    c.Stream[position++] = value;
                    if (position <= FrameCount) {
                        sum += value; sumSq += (long)value * value;
                        if (value == 0) zeros++;
                        if (value == 255) saturated++;
                    }
                }
            }
        }
        if (position != StreamCount) throw new InvalidDataException(name + ": incomplete stream");
        c.Samples = position; c.FrameId = firstFrameId; c.TriggerCount = triggers;
        c.Minimum = c.Stream.Take(FrameCount).Min(); c.Maximum = c.Stream.Take(FrameCount).Max();
        c.Mean = sum / (double)FrameCount;
        c.StandardDeviation = Math.Sqrt(Math.Max(0, sumSq / (double)FrameCount - c.Mean * c.Mean));
        c.ZeroFraction = zeros / (double)FrameCount; c.SaturatedFraction = saturated / (double)FrameCount;

        double[] rows = new double[Height], cols = new double[Width];
        for (int y=0; y<Height; y++) for (int x=0; x<Width; x++) {
            byte v = c.Stream[y*Width+x]; rows[y] += v; cols[x] += v;
        }
        for (int y=0; y<Height; y++) rows[y] = rows[y]/Width - c.Mean;
        for (int x=0; x<Width; x++) cols[x] = cols[x]/Height - c.Mean;
        double rowE=0,colE=0,resE=0;
        foreach(double v in rows) rowE += v*v;
        foreach(double v in cols) colE += v*v;
        for (int y=0; y<Height; y++) for (int x=0; x<Width; x++) {
            double r = c.Stream[y*Width+x] - c.Mean - rows[y] - cols[x]; resE += r*r;
        }
        c.RowComponentStd = Math.Sqrt(rowE/Height);
        c.ColumnComponentStd = Math.Sqrt(colE/Width);
        c.ResidualStd = Math.Sqrt(resE/FrameCount);
        using (SHA256 sha = SHA256.Create()) c.DataSha256 = BitConverter.ToString(sha.ComputeHash(c.Stream)).Replace("-","");
        return c;
    }

    static int Pad8(int n) { return (n + 7) & ~7; }
    static void Tag(BinaryWriter w, int type, int bytes) { w.Write(type); w.Write(bytes); }
    static void Zeros(BinaryWriter w, int n) { for (int i=0;i<n;i++) w.Write((byte)0); }
    static byte[] Ascii(string s) { return Encoding.ASCII.GetBytes(s); }

    static void Matrix(BinaryWriter w, string name, int classId, int dataType, int[] dims, byte[] data) {
        byte[] nb = Ascii(name);
        int dimsBytes = dims.Length*4;
        int payload = 16 + 8 + Pad8(dimsBytes) + 8 + Pad8(nb.Length) + 8 + Pad8(data.Length);
        Tag(w,14,payload);
        Tag(w,6,8); w.Write((uint)classId); w.Write((uint)0);
        Tag(w,5,dimsBytes); foreach(int d in dims) w.Write(d); Zeros(w,Pad8(dimsBytes)-dimsBytes);
        Tag(w,1,nb.Length); w.Write(nb); Zeros(w,Pad8(nb.Length)-nb.Length);
        Tag(w,dataType,data.Length); w.Write(data); Zeros(w,Pad8(data.Length)-data.Length);
    }

    static void DoubleMatrix(BinaryWriter w, string name, int[] dims, double[] values) {
        byte[] data = new byte[values.Length*8]; Buffer.BlockCopy(values,0,data,0,data.Length);
        Matrix(w,name,6,9,dims,data);
    }
    static void DoubleScalar(BinaryWriter w, string name, double value) { DoubleMatrix(w,name,new[]{1,1},new[]{value}); }
    static void CharMatrix(BinaryWriter w, string name, string[] rows) {
        int nr = rows.Length, nc = rows.Max(s=>s.Length);
        ushort[] chars = new ushort[nr*nc];
        for(int col=0;col<nc;col++) for(int row=0;row<nr;row++)
            chars[col*nr+row] = col < rows[row].Length ? rows[row][col] : (ushort)' ';
        byte[] data = new byte[chars.Length*2]; Buffer.BlockCopy(chars,0,data,0,data.Length);
        Matrix(w,name,4,4,new[]{nr,nc},data);
    }

    static void WriteMat(string path, List<CaptureInfo> captures) {
        using(var fs=new FileStream(path,FileMode.Create,FileAccess.Write,FileShare.None))
        using(var w=new BinaryWriter(fs,Encoding.ASCII)) {
            string text="MATLAB 5.0 MAT-file, VGA_EM_V21_FULL session 2026-10-19, generated " + DateTime.Now.ToString("s",CultureInfo.InvariantCulture);
            byte[] tb=Ascii(text); w.Write(tb); Zeros(w,116-tb.Length); Zeros(w,8); w.Write((ushort)0x0100); w.Write((byte)'I'); w.Write((byte)'M');
            int n=captures.Count;
            byte[] streams=new byte[StreamCount*n];
            for(int k=0;k<n;k++) Buffer.BlockCopy(captures[k].Stream,0,streams,k*StreamCount,StreamCount);
            Matrix(w,"streams",9,2,new[]{StreamCount,n},streams);
            CharMatrix(w,"capture_names",captures.Select(c=>c.Name).ToArray());
            CharMatrix(w,"pattern_names",captures.Select(c=>c.Pattern).ToArray());
            CharMatrix(w,"design_groups",captures.Select(c=>c.DesignGroup).ToArray());
            CharMatrix(w,"source_directories",captures.Select(c=>c.SourceDirectory).ToArray());
            DoubleMatrix(w,"gain",new[]{1,n},captures.Select(c=>c.Gain).ToArray());
            DoubleMatrix(w,"gain_q8",new[]{1,n},captures.Select(c=>(double)c.GainQ8).ToArray());
            DoubleMatrix(w,"repeat_index",new[]{1,n},captures.Select(c=>(double)c.Repeat).ToArray());
            DoubleMatrix(w,"frame_id",new[]{1,n},captures.Select(c=>(double)c.FrameId).ToArray());
            DoubleScalar(w,"line_samples",Width); DoubleScalar(w,"frame_lines",Height);
            DoubleScalar(w,"frame_sample_count",FrameCount); DoubleScalar(w,"stream_sample_count",StreamCount);
            DoubleScalar(w,"image_sample_rate_hz",65000000); DoubleScalar(w,"rfdc_sample_rate_hz",1040000000);
            DoubleScalar(w,"rfdc_nco_hz",-200000000); DoubleScalar(w,"leakage_carrier_hz",195000000);
        }
    }

    static string Csv(string s) { return "\"" + s.Replace("\"","\"\"") + "\""; }
    static void WriteManifest(string path,List<CaptureInfo> cs) {
        using(var w=new StreamWriter(path,false,new UTF8Encoding(true))) {
            w.WriteLine("capture_name,pattern,design_group,gain,repeat,frame_id,segments,samples,frame_samples,address_continuous,all_valid,frame_id_constant,trigger_count,min,max,mean,std,row_component_std,column_component_std,residual_std,zero_fraction,saturated_fraction,data_sha256,source_directory");
            foreach(var c in cs) w.WriteLine(string.Join(",",new[]{
                Csv(c.Name),Csv(c.Pattern),Csv(c.DesignGroup),c.Gain.ToString("R",CultureInfo.InvariantCulture),c.Repeat.ToString(),c.FrameId.ToString(),c.Segments.ToString(),c.Samples.ToString(),c.FrameSamples.ToString(),
                c.AddressContinuous.ToString(),c.AllValid.ToString(),c.FrameIdConstant.ToString(),c.TriggerCount.ToString(),c.Minimum.ToString(),c.Maximum.ToString(),
                c.Mean.ToString("R",CultureInfo.InvariantCulture),c.StandardDeviation.ToString("R",CultureInfo.InvariantCulture),c.RowComponentStd.ToString("R",CultureInfo.InvariantCulture),
                c.ColumnComponentStd.ToString("R",CultureInfo.InvariantCulture),c.ResidualStd.ToString("R",CultureInfo.InvariantCulture),c.ZeroFraction.ToString("R",CultureInfo.InvariantCulture),
                c.SaturatedFraction.ToString("R",CultureInfo.InvariantCulture),Csv(c.DataSha256),Csv(c.SourceDirectory)}));
        }
    }

    public static CaptureInfo[] Run(string sourceRoot,string matPath,string manifestPath) {
        string[] dirs=Directory.GetDirectories(sourceRoot).Where(d => {
            string n=Path.GetFileName(d);
            return n.StartsWith("v203_",StringComparison.OrdinalIgnoreCase) || n.StartsWith("opt_img_",StringComparison.OrdinalIgnoreCase);
        }).ToArray();
        Array.Sort(dirs,StringComparer.OrdinalIgnoreCase);
        var cs=new List<CaptureInfo>();
        foreach(string d in dirs) {
            if(File.Exists(Path.Combine(d,"metadata.txt")) && Directory.GetFiles(d,"segment_*.csv").Length==ExpectedSegments) cs.Add(LoadCapture(d));
        }
        if(cs.Count==0) throw new InvalidOperationException("No complete v203 captures found");
        WriteMat(matPath,cs); WriteManifest(manifestPath,cs);
        return cs.ToArray();
    }
}
'@

Add-Type -TypeDefinition $typeSource -Language CSharp
$matPath = Join-Path $OutputRoot 'all_captures_2026_10_19.mat'
$manifestPath = Join-Path $OutputRoot 'manifest.csv'
$captures = [MatlabSessionExporter]::Run((Resolve-Path -LiteralPath $SourceRoot).Path, $matPath, $manifestPath)

$invalid = @($captures | Where-Object { -not $_.AddressContinuous -or -not $_.AllValid -or -not $_.FrameIdConstant })
if ($invalid.Count -ne 0) { throw "Capture validation failed: $($invalid.Name -join ', ')" }

Write-Host "MATLAB_SESSION_EXPORT_PASS"
Write-Host "captures=$($captures.Count)"
Write-Host "mat=$matPath"
Write-Host "manifest=$manifestPath"
Write-Host "mat_bytes=$((Get-Item -LiteralPath $matPath).Length)"
