# V2.4 离线发布记录（2026-10-21）

`full_v24.bit` 与 `full_v24.ltx` 已由同一次 Vivado 2026.1 实现生成，并从保存的 `implemented.dcp` 独立重新检查。工程器件为 `xczu27dr-ffve1156-2-i`，版本寄存器为 `0x00020700`。

| 检查 | 实测结果 |
| --- | ---: |
| `write_bitstream` | 完成，0 个错误 |
| 重新打开 DCP 后的 setup WNS / TNS | +0.013 ns / 0 ns |
| 重新打开 DCP 后的 hold WHS / THS | +0.010 ns / 0 ns |
| DRC Error / Critical Warning | 0 / 0 |
| URAM288 | 74 / 80 |
| RAMB36 / RAMB18 | 534 / 352 |
| DSP48E2 | 52 |

时序余量只有 13 ps；本记录适用于当前这对 BIT/LTX。更改 RTL、IP 参数或约束后必须重新实现和签核，不能沿用本版时序。

发布文件 SHA-256：

```text
D902F959B7D2ACACFB8CF9D6377844775D3DB46F09E58A0659E8F8BA2213D87F  full_v24.bit
CC39260E7BFA1F780BF7AE07AE1813D34FD53274F485CED68154FDB18532778F  full_v24.ltx
3961B5F8359D4606BA09F9EEFB00EE824A1B872F3439F9FCAF4186BAC87E7634  implemented.dcp
```

`output/reports/build_status.txt` 记录机器可读的签核状态，`output/bitstream/sha256.txt` 记录 BIT/LTX 哈希。`scripts/run.ps1 -Action verify` 已输出 `FULL_V24_POST_BUILD_VERIFIED setup_wns=0.013 hold_whs=0.010 drc_errors=0`，退出码为 0。

该版本的 RTL 包含事件触发导出路径。本文件记录 BIT/LTX 的离线实现签核；上板操作步骤、寄存器读回及数据导出方法见 `06_V24_TEST_STEPS.md`，实测样本见仓库根目录 `data/`。
