# V2.2 MATLAB 同步与复数分析

本目录处理 V2.2 `capture_frame` 导出的原始分段 CSV。算法不使用已知测试图周期来拼图：它从每次采集本身估计小数行周期，再用行、列投影做循环同步，最后通过相关质量门限决定某帧是否允许进入平均。

幅度/I/Q 单通道模式按约 1344 样点/行处理。`iq` 模式先将奇偶字节还原为同步的 I、Q 复采样；复采样时钟仍为 65 MS/s，所以仍按约 1344 个复采样/行重排。由于每个复采样占两个导出字节，固定帧缓存一次可覆盖 403 条完整扫描线。`recover_v205_checker` 会自动采用这一几何关系，并完成重复帧对齐、黑屏相减和恢复图导出。

示例：

```matlab
addpath('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V22_SYNC_IQ\matlab');
addpath('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V22_SYNC_IQ\matlab\v22');
dirs = ["D:\capture\asym_iq_r1", "D:\capture\asym_iq_r2", "D:\capture\asym_iq_r3"];
R = run_v22_repeat_analysis(dirs,"D:\capture\asym_iq_result");
```

首次安装 MATLAB 后，可先运行不依赖硬件采集文件的运行时自检：

```matlab
addpath('D:\ChatGPT\2026-09-13\new-chat-2\VGA_EM_V22_SYNC_IQ\matlab\v22');
selftest_v22
```

只有 `sync_diagnostics.csv` 中 `accepted=true` 的帧参与平均。门限失败表示探头、显示状态、时钟漂移或信噪比不满足恢复条件，脚本不会强行制造平均图。背景扣除只能使用探头位置完全不变、并且在目标采集之后立即采集的黑屏数据。
