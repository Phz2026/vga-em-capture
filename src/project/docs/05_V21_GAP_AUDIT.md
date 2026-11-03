# V2.4 功能与验证记录

本记录对应仓库中的 V2.4 RTL、运行脚本和 Vivado 报告。它列出交付代码中的数据路径及可复核证据。

| 模块 | 实现内容 | 核查依据 |
| --- | --- | --- |
| RFDC 与数字下变频 | ADC Tile 1 接入、半带抽取、32 位可编程 DDC | RTL、寄存器映射和 `session.tcl` |
| 频谱支路 | 65536 点频谱快照、ILA 回放和主机分段导出 | `spectrum_engine.sv`、`capture_spectrum_series` |
| 主机频段分析 | 原始 I/Q 频谱、画面与背景差分及候选排序 | `compare_raw_iq_v23.m`、`vga_find_leak_band.m` |
| 幅度特征 | 幅度提取与手动 Q8 特征增益 | RTL、`vga_set_feature_gain` |
| 帧缓存和事件导出 | 1344×900 双 bank、行能量 profile、循环移位比较、2/3 去抖、ACK 更新 | RTL、事件寄存器和导出脚本 |
| MATLAB 组帧 | 按 metadata 拼接 CSV 分段并显示 RF 幅度响应 | `recover_frame.m`、`formal_capture/` |

## 构建与数据核查

1. `scripts/run.ps1 -Action check` 检查 RTL 与工程配置。
2. `scripts/run.ps1 -Action build` 生成 BIT/LTX 和 Vivado 报告。
3. `scripts/run.ps1 -Action verify` 检查实现报告、时序与 DRC。
4. 上板寄存器、RFDC 和 ILA 的操作步骤见 `06_V24_TEST_STEPS.md`。
5. 仓库根目录 `data/` 提供实测 CSV、元数据和 MATLAB 分析结果。

900 行版本使用 74 个 URAM288，器件可用 80 个。首次实现的 WNS 为 −0.130 ns，半带抽取器增加流水级后为 −0.072 ns；事件检测器增加地址流水级后的发布实现 WNS 为 +0.013 ns、WHS 为 +0.010 ns，DRC 错误与严重警告均为 0。发布 BIT/LTX 的签核和哈希见 `07_V24_RELEASE_STATUS.md`。

MATLAB R2025b 的 `selftest_v24` 使用合成 205 MHz I/Q 输入检查解析、差分和候选排序路径，输出 `V24_MATLAB_SELFTEST_PASS`。实测 CSV 的独立分析命令见仓库根目录 `data/README.md`。
