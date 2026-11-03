# RF Analyzer 五状态泄漏频段实验

原理：从 ADC **原始实数采样**比较 `全黑1 → 16像素图 → 全黑2 → 五图形 → 全黑3`。同一连接、探头位置、LNA 供电及 ADC 配置固定。程序比较 65/130/195/260/325/390/455 MHz 载频和 ±2.03125 MHz 边带；同时把黑屏之间的变化列出来。载频峰强不等于图像内容强。

## 硬件和 RF Analyzer

1. 先保存当前 V24 测试状态。使用 RF Analyzer 的兼容 bit 会替换 FPGA 中的 `full_v24.bit`。桌面上的 `<local-desktop>/usp_rf_data_converter_0_example_design.bit` 文件头虽为 `xczu27dr-ffve1156-2-i`，但尚未验证其与 RF Analyzer 通信、ADC 引脚和板上时钟兼容。不要把 V24 的 `.bit` 直接加载到 RF Analyzer。
2. 确认 ADC 采样时钟/参考时钟已稳定，才在 RF Analyzer 中 Connect → 选择 JTAG 目标 → 选择兼容 RFDC 示例 bit → 程序下载 → 选 MicroBlaze。如果无法出现通信正常及 ADC tile ready，此 bit/时钟链未验证成功，停止，不采信空图。
3. 只选用连接探头的 RF-ADC 通道（Tile 1 ADC01）。目标是 **Real、Mixer Type=Bypass、Decimation=1×**。无需强制使用 V24 工程的 1.04 GS/s：若当前示例 bit 的 ADC Tile 1 PLL 显示 2000 MHz，且 Acquisition 页的 **Fs 和 Eff.Fs 均确认是 2000 MHz**、PLL 锁定及原始波形正常，则保持现状；2 GS/s 同样覆盖 65–455 MHz。脚本第二参数必须填实际 Eff.Fs（此例为 `2e9`）。若实际 Fs/Eff.Fs 不一致或数据异常，停止并检查 Overview → Clock Distribution 中 Tile 1 的输入参考和采样时钟；RF Analyzer 的显示初值来自 bit 的 IP 配置，不能仅凭绿色状态判定外部参考时钟正确。不同采样配置的数据不可混合比较。ADC 内部 NCO 若非 bypass，脚本频率轴将不是物理 RF，不能使用。
4. RF Analyzer 的 RF-ADC FFT/Acquisition 页面选择至少 **8192 个原始样本**，建议 16384 或更多。先在全黑状态做一次试采并核对导出格式，再开始五状态实验。**16384 点在 2 GS/s 下仅覆盖 8.192 µs，远短于约 16.7 ms 的一帧 VGA**；三次重复只能用来检查流程，不能保证五图形被采到。正式比较应增加独立采样次数并查看结果是否稳定，特别是五图形状态。选择 Settings → Data File Format → `.lvm` 且导出 **Data**。每次 Acquire 后 File → Export ADC Data。五个文件夹各放本状态的原始 ADC `.lvm`：`black_1`, `coded_16px`, `black_2`, `five_shapes`, `black_3`。仅放同一 ADC 通道且设置一致的导出文件。不要使用 FFT 图或 metrics LVM 代替原始波形。
5. RF Analyzer 2024.1 实测会把导出文件放进一个同名 `.lvm` 文件夹，例如 `black_1\adc_01.lvm\ADC Tile 1 - ADC 01.lvm`；分析程序现已支持这一层文件夹。若有强峰或波形顶端削平，暂停测量并处理增益/衰减；仅靠 LNA 输出在 195/325 MHz 的频谱仪读数无法证明其它频率没有强信号。

文件夹例子：

```text
D:\capture\rf_analyzer_20261023\
  black_1\adc_01.lvm  adc_02.lvm  adc_03.lvm
  coded_16px\adc_01.lvm  adc_02.lvm  adc_03.lvm
  black_2\adc_01.lvm  adc_02.lvm  adc_03.lvm
  five_shapes\adc_01.lvm  adc_02.lvm  adc_03.lvm
  black_3\adc_01.lvm  adc_02.lvm  adc_03.lvm
```

在 MATLAB 命令窗口执行：

```matlab
addpath('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V24_V21_COMPLETE\matlab');
R = rf_analyzer_leak_test('D:\capture\rf_analyzer_20261023', 2e9); % 仅当 Eff.Fs 确认为 2000 MHz
```

输出在采集根目录 `analysis\harmonic_comparison.csv` 和 `analysis\spectrum_comparison.png`。`Coded_vs_adjacent_black_dB` 与 `Shapes_vs_adjacent_black_dB` 应与同频段两次黑屏漂移比较：只有图案增量可重复、明显超过黑屏漂移，并且边带频率符合画面结构时，才能认为检测到图案相关泄漏。脚本只给**相对 dB**，未校准 ADC 与 LNA，因此不能称为 dBm 或最终图像信噪比。
