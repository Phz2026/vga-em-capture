# V2.3 历史发布构建记录（不适用于 V2.4）

## 结论

`full_v23.bit` 与 `full_v23.ltx` 已生成并通过离线签核。该版本加入可编程 DDC、16 位 I/Q 原始采样缓存及频段分析路径。本记录汇总 V2.3 的构建和 MATLAB 回归结果；V2.4 发布数据见 `07_V24_RELEASE_STATUS.md`。

## 已完成优化

- 65 MS/s复数域32位可编程DDC，覆盖135–265 MHz目标RF范围。
- 混频器和两级复移动平均滤波可独立使能或旁路。
- 32768点、16位I+16位Q、DDC前原始复样本缓存及独立第四个ILA。
- MATLAB原始I/Q解析、质量检查、单次频谱和画面/背景差分排名。
- DDC乘加链加入显式流水线；构建入口在每次build前重新打包本地IP，避免旧RTL混入BIT。
- 负时序仅为23 ps时自动执行布线后物理优化，仍按WNS/WHS非负的严格标准发布。

## 签核结果

| 项目 | 结果 |
|---|---:|
| Vivado | 2026.1 |
| Device | xczu27dr-ffve1156-2-i |
| VERSION寄存器 | 0x00020600 |
| Setup WNS | +0.008 ns |
| Setup TNS | 0 ns |
| Hold WHS | +0.004 ns |
| Hold THS | 0 ns |
| DRC Error | 0 |
| DRC Critical Warning | 0 |
| BRAM Tile | 710 / 1080（65.74%） |
| URAM | 67 / 80（83.75%） |
| DSP | 42 / 4272（0.98%） |

`check_timing`中的两个无时钟提示属于未启用的RFDC DAC0/DAC1内部数字时钟；当前工程只使用ADC Tile 1，不影响接收链签核。总线偏斜检查全部为MET。

## MATLAB回归

`selftest_v23`使用合成原始I/Q CSV做端到端测试，结果为：

```text
RAW_IQ_ANALYSIS_PASS peak_rf=204.998779 MHz clipped=0
RAW_IQ_COMPARE_PASS strongest_candidate=204.998779 MHz
V23_MATLAB_SELFTEST_PASS
```

## 发布文件校验

```text
BEE1AC41F7531924EB814D83D199965951B924467C051A0DFF9397DC075662DF  full_v23.bit
CC39260E7BFA1F780BF7AE07AE1813D34FD53274F485CED68154FDB18532778F  full_v23.ltx
650EB980C4DC52C770AB7F99AB8FD20AFF35F4ECABE9199ADEB433BDD2668545  implemented.dcp
```
