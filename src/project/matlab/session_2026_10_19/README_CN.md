# 2026-10-19 MATLAB 分析包

本目录把当天 19 组完整图像通道采集和 7 组频谱采集分别合并为 MATLAB 5 MAT 文件，并提供不依赖显示图案模板的同步、重复帧配准、背景扣除、去条纹和低通恢复算法。周期条纹和棋盘只用于验收链路，非周期图像恢复不会读取参考 PNG。

## 直接运行

安装 MATLAB 后，在命令窗口执行：

```matlab
cd('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V22_SYNC_IQ\matlab\session_2026_10_19')
run_session_analysis
```

脚本只使用 MATLAB 基础函数，不要求 Signal Processing Toolbox、Image Processing Toolbox 或 Statistics Toolbox。结果写入 `results`。

## 数据文件

`data/all_captures_2026_10_19.mat` 包含 19 组图像流：

- `streams`：`1179648 × 19 uint8`，每列是一组完整的 9 段 ILA 回放流；
- `capture_names`、`pattern_names`：采集名和实验图案；
- `gain`、`gain_q8`、`repeat_index`、`frame_id`：实验元数据；
- `line_samples=1344`、`frame_lines=806`；
- `frame_sample_count=1083264`：每列前这么多点组成图像帧；
- `image_sample_rate_hz=65000000`、RFDC/NCO/载波频率。

其中 5 组 `opt_img_*` 属于 Q8 修复前的诊断数据，14 组 `v203_*` 属于 `0x00020300` 增益修复版。`design_groups` 和 `manifest.csv` 已明确区分，不能直接混合比较码值。

`data/all_spectra_2026_10_19.mat` 包含 7 组 `65536×1` 频谱码流、采集名称、测量类型、基带频率轴、65 MHz 采样率和 200 MHz RF 中心频率。`spectrum_manifest.csv` 同时记录全带最强峰和 195 MHz ±50 kHz 目标带峰值。

`load_session.m` 把硬件的行优先流转换成 MATLAB 的 `806×1344×14 uint8` 数组。`manifest.csv` 记录每组的均值、标准差、行列分量、校验结果、SHA-256 和原始目录。`profile_sync_pairs.csv` 记录同图案重复采集的盲行列同步结果。

原始 CSV 仍保存在 `D:\capture\opt_*` 和 `D:\capture\v203_*`，两个 MAT 文件保存了当天全部有效图像特征样本和频谱 bin。CSV 中地址、valid、trigger 和 frame_id 等调试列经一致性检查后转为清单元数据，因此 MAT 文件更紧凑。

## 算法入口

- `load_session.m`：加载和恢复硬件帧；
- `estimate_fractional_line_period.m`：从数据本身估计非整数行周期；
- `fractional_rasterize.m`：按非整数行周期重采样，修正逐行斜漂；
- `align_repeat_stream.m`：对同一画面的重复帧做一维循环流配准；
- `profile_sync.m`：用行、列统计轮廓进行无模板帧间同步；
- `robust_destripe.m`：迭代中值估计行列固定背景；
- `pattern_score.m`：对条纹和棋盘验收图进行相位无关检测；
- `run_session_analysis.m`：批量生成指标、对齐表和诊断图。

当前数据没有“探头移动后的同位置黑场”。因此脚本仍会给出旧黑场扣除图用于诊断，但文件名带有 `provisional`，不能据此宣称非周期图像已经恢复成功。

本机目前没有 MATLAB，因此没有伪造 MATLAB 运行结果。两个 MAT 文件已按 MATLAB Level-5 结构逐记录检查，并从 MAT 负载逐列重新计算 SHA-256，与原始解析结果完全一致；MATLAB 脚本完成了静态检查，首次安装 MATLAB 后仍应执行一次 `run_session_analysis` 做运行时验收。
