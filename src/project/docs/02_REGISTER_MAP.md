# V2.4 AXI4-Lite寄存器

控制基址默认为 `0xA0040000`。

| 偏移 | 名称 | 方向 | 定义 |
|---:|---|---|---|
| 0x00 | ID | R | `0x56474132` |
| 0x04 | VERSION | R | `0x00020700` |
| 0x08 | CTRL | W | bit0图像捕获；bit1帧ACK；bit2频谱；bit3图像回放；bit4频谱回放；bit5清错；bit6原始I/Q捕获；bit7原始I/Q回放 |
| 0x0C | STATUS | R | 原状态bit0–14保持；bit15 raw_pending；bit16 raw_capture_busy；bit17 raw_replay_busy；bit18 raw_replay_done；bit19 raw_range_error |
| 0x10–0x40 | 原V2.05寄存器 | R/W | 行场参数、增益、段号、特征模式等保持兼容 |
| 0x44 | DDC_PHASE_INC | R/W | 32位二补码相位增量，采样率65 MHz |
| 0x48 | DDC_CONTROL | R/W | bit0 mixer_enable；bit1 filter_enable |
| 0x4C | RAW_CAPTURE_LENGTH | R/W | 1–32768个复样本，默认32768 |
| 0x50 | RAW_CAPTURED_COUNT | R | 最近一次实际捕获的复样本数 |
| 0x54 | EVENT_THRESHOLD | R/W | 行能量归一化差分阈值，Q16；默认 `0x0800` |
| 0x58 | EVENT_CONTROL | R/W | bit0 自动事件捕获使能；写 bit1 强制导出下一帧，写后自动清零 |
| 0x5C | EVENT_STATUS | R | bit0 计算忙；bit1 判定脉冲；bit2 变化脉冲；bit3–5 最近三帧越阈值历史；bit6 参考有效；bit7 ACK 复制忙。待导出帧见 STATUS bit2 |
| 0x60 | EVENT_METRIC | R | 最小循环移位后的归一化差分，Q16 |
| 0x64 | EVENT_BEST_LAG | R | 最佳循环行移位，单位为行 |

`FRAME_LINES`（0x14）在本版复位默认值为 900，帧缓存上限也是 900 行；`LINE_SAMPLES`（0x10）默认 1344。修改几何参数时不得超过 `1344×900` 字节的单 bank 容量。

相位增量计算：

`phase_inc = round(mixer_hz / 65e6 × 2^32)`

工程的RFDC中心按200 MHz解释，因此Tcl命令 `vga_set_ddc_target rf_mhz` 使用：

`mixer_mhz = 200 - rf_mhz`

例如195 MHz对应约+5 MHz，205 MHz对应约−5 MHz。寄存器写入后DDC自动清相位和滤波器历史状态。

