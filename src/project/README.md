# VGA 电磁泄漏恢复工程 V2.4（V2.1 事件触发补全版）

该工程从 V2.3 工程独立派生，不覆盖原工程。版本寄存器为 `0x00020700`。

本版按《总体方案 V2.1（完整版）》补齐了此前没有落到 RTL 的事件触发导出：每帧行能量 profile、跨增益变化的归一化差分、循环行移位搜索、2/3 帧去抖、双帧导出期间的补帧挂起，以及主机 ACK 后的参考 profile 更新。帧缓存采用方案允许的 900 行回退容量，每块为 1344×900 样本；1024 行目标容量尚未实现。

本版针对 2026-10-20 实测暴露的首要问题：固定 195 MHz 解调缺乏证据，而且现有8位特征数据不足以判断候选频带是否随画面内容变化。

《总体方案 V2.1》与本工程的逐项差异及验收边界见 `docs/05_V21_GAP_AUDIT.md`。
实际上板的逐步验收与应保存的证据见 `docs/06_V24_TEST_STEPS.md`。
2026-10-21 的 BIT/LTX 离线签核、时序和哈希见 `docs/07_V24_RELEASE_STATUS.md`。

## 本版新增内容

- 65 MS/s 复数据域的32位可编程DDC相位增量。
- JTAG AXI可设置目标RF频率，范围135–265 MHz。
- DDC混频和两级8点复移动平均滤波均可旁路。
- 32768点、每点16位I+16位Q的解调前原始复样本缓存。
- 独立 `raw_iq_ila` 回放通道，不占用1344×900双帧URAM。
- MATLAB原始I/Q读取、单次频谱分析以及画面/黑屏差分频带排序。
- 原频谱、幅度帧、I/Q帧和质量门限链路继续保留。
- 静态画面在首帧确认后不再重复上传；事件状态可由 JTAG AXI 读取。
- 新寄存器：`0x54` 事件阈值 Q16，`0x58` 事件控制，`0x5c` 事件状态，`0x60` 差分指标，`0x64` 最佳循环移位。

原始I/Q记录点位于半带抽取之后、可编程DDC之前，采样率65 MS/s。一次32768点采集约覆盖0.504 ms，适合频段归因与几十行范围的同步分析，不等同于完整视频帧。

## 构建

```powershell
cd D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V24_V21_COMPLETE
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1 -Action check
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1 -Action create
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1 -Action build
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1 -Action verify
```

输出文件：

- `output/bitstream/full_v24.bit`
- `output/bitstream/full_v24.ltx`
- `output/reports/build_status.txt`

本版的实际构建状态以 `output/reports/build_status.txt` 和
`output/reports/timing.rpt` 为准；V2.3 的历史时序数字不能用于 V2.4。
只有 BIT、LTX、时序和 DRC 检查都完成后才能上板。上板测试结果需单独记录。

MATLAB解析及差分频谱可执行回归测试：

```matlab
addpath('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V24_V21_COMPLETE\matlab');
selftest_v24
```

期望最后一行包含 `V24_MATLAB_SELFTEST_PASS`。该测试使用合成数据，不能代替实测泄漏频点验证。

## 上板初始化

在Vivado Hardware Manager加载BIT和LTX，按原流程初始化PS/PL时钟。随后在Tcl Console执行：

```tcl
source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/session.tcl}
source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/capture_raw_iq.tcl}
source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/capture_frame.tcl}
vga_attach
vga_check
vga_rfdc_start
vga_get_ddc
```

必须看到版本 `0x00020700`、`VGA_REGISTER_TEST_PASS`、`RFDC_TILE_READY`，并确认
Hardware Manager中是1个JTAG AXI和4个ILA。BIT 与 LTX 必须来自同一次 V2.4 构建。

事件模式：

```tcl
vga_set_feature_mode magnitude
vga_set_event_mode 1 2048
vga_get_event_status
# 等待待导出帧，导出全部分段后自动 ACK；后续调用可导出补帧
capture_event_frame {D:/capture/v24_event_01}
capture_event_frame {D:/capture/v24_event_02}
vga_get_event_status

# 需要连续记录多次变化时，也可使用新的前缀批量等待和导出：
capture_event_series {D:/capture/v24_event_batch} 3
```

## 首轮采集

保持探头、线缆和显示位置不动。每条命令必须使用新目录。

```tcl
# 先显示全黑，连续采3次
capture_raw_iq {D:/capture/v24_black_r1}
capture_raw_iq {D:/capture/v24_black_r2}
capture_raw_iq {D:/capture/v24_black_r3}

# 切换16像素棋盘，连续采3次
capture_raw_iq {D:/capture/v24_checker16_r1}
capture_raw_iq {D:/capture/v24_checker16_r2}
capture_raw_iq {D:/capture/v24_checker16_r3}
```

MATLAB：

```matlab
addpath('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V24_V21_COMPLETE\matlab');
signalDirs = ["D:\capture\v24_checker16_r1","D:\capture\v24_checker16_r2","D:\capture\v24_checker16_r3"];
blackDirs  = ["D:\capture\v24_black_r1","D:\capture\v24_black_r2","D:\capture\v24_black_r3"];
C = compare_raw_iq_v23(signalDirs,blackDirs,"D:\capture\v24_compare_checker_black");
F = vga_find_leak_band(signalDirs,blackDirs,"D:\capture\v24_ranked_bands");
```

`F.candidates` 会把相距 0.25 MHz 以上的候选频段分开排序，并把重复采集的离散程度计入分数。它只是筛选依据，不能替代断开 VGA、关闭显示输出等独立 A/B 归因。只有候选频率在重复采集中稳定、并且画面/黑屏差值显著时，才进入窄带成像：

```tcl
capture_frame_target 205.212 iq 2 {D:/capture/v24_205p212_checker_iq_r1}
```

候选频点仍需通过白屏、条纹、断开VGA或关闭显示输出等A/B实验完成归因，不能仅凭单次峰值认定为泄漏。

