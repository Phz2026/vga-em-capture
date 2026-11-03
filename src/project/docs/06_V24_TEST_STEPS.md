# V2.4 上板验收步骤

本文件记录实际可执行的测试；离线 BIT 签核不等于电磁泄漏归因或图像恢复成功。每一步保留原始输出与 CSV，不把预期结果写成实测结果。

1. 在 PowerShell 中先进入工程目录 `D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V24_V21_COMPLETE`，核对 `output/bitstream/sha256.txt`、`full_v24.bit` 和 `full_v24.ltx`。在 Hardware Manager 只使用这一对文件编程器件。若调试核不可见，断开 Hardware Manager 与 hw_server，在 PowerShell 中执行 `powershell -ExecutionPolicy Bypass -File .\scripts\prepare_opt_hardware.ps1`；返回 Hardware Manager 重新连接，**不要再次编程**。
2. 在 Vivado Hardware Manager 的 Tcl Console 中逐行执行：

   ```tcl
   source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/session.tcl}
   source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/capture_raw_iq.tcl}
   source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/capture_frame.tcl}
   vga_attach
   vga_check
   vga_rfdc_start
   vga_rfdc_diag
   ```

   应读到 `version=0x00020700`、`VGA_REGISTER_TEST_PASS`、`RFDC_TILE_READY`，并识别 1 个 JTAG AXI、4 个 ILA。任一不符合则停止采集并保存完整日志。
   如需连续频谱快照，另行 `source {D:/ChatGPT/2026-09-13/new-chat-2/VGA_EM_V24_V21_COMPLETE/scripts/hardware/capture_spectrum.tcl}`，再执行 `capture_spectrum_series {D:/capture/v24_spectrum} 3 3000`。每次输出 `CAPTURE_ELAPSED_MS`；JTAG 导出若超过 3 秒，实际刷新间隔也会超过 3 秒。
3. 固定探头、VGA 线与显示器位置。依次显示全黑和 16 像素棋盘，每种各执行 3 次 `capture_raw_iq {D:/capture/新的独立目录}`。用 `vga_find_leak_band` 比较画面与黑屏，记录候选频率、重复性和差值；断开 VGA 或关闭显示输出后复测，只有内容相关且重复稳定的候选进入成像测试。
4. 将通过归因的实测频率写入 `capture_frame_target <频率MHz> magnitude <增益倍数> {D:/capture/新的独立目录}`。检查 metadata、全部分段和 MATLAB 重建结果；黑屏、白屏、棋盘、非周期未知图像均须保留原始数据。已知棋盘的周期叠加图不能充当未知图像恢复验收。
5. 事件模式先用实际静态画面噪声测量标定阈值，再执行 `vga_set_event_mode 1 <阈值Q16>`。静态画面应只导出首帧；改变画面后调用 `capture_event_frame {D:/capture/新的独立目录}`，确认事件、完整分段和 ACK；在导出期间再次变更画面，确认可导出补帧。仅改变增益时应验证不误触发。每次记录 `vga_get_event_status` 与 metadata 的 `event_metric_q16`。

硬件指标只有在以上步骤获得原始数据和日志后才能填入验收表。双 bank 只保证当前冻结帧与至多一个补帧，导出期间多次变化可能合并为最新状态，不能宣称逐次零丢失。
