# FocusLoop 验证记录

这份记录只列已经完成并可复现的结果。设备依赖项单独标注，避免把编译通过写成真机运行通过。

## 一键检查

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .claude/skills/focusloop-verify/scripts/verify_focusloop.ps1
```

WSL / Linux：

```bash
bash .claude/skills/focusloop-verify/scripts/verify_focusloop.sh
```

脚本依次检查工作区差异、Shell 语法、QuickApp 测试、构建、生产依赖漏洞、RPK、疑似凭证和过期文案，不会清理、提交或上传文件。

## 2026-09-16 复测结果

环境：Windows 11、Node.js 24.14.1、AIoT Toolkit 2.0.5。应用源码与主办方 dev-ai-contest-2026 分支提交 64c703c 一致。本轮调整技术报告与交付证据，未改动应用逻辑。

    node scripts/collect_verification.cjs

| 检查项 | 结果 | 证据位置 |
| --- | --- | --- |
| QuickApp 逻辑与集成约束 | 28 项 × 20 轮，共 560 项通过 | verification/2026-09-16/test-01.txt 至 test-20.txt |
| 测试进程用时 | 平均 63 ms，最大 79 ms | verification/2026-09-16/summary.json |
| QuickApp 构建 | 连续 5/5 次成功 | verification/2026-09-16/build-1.txt 至 build-5.txt |
| 构建进程用时 | 平均 3839 ms，最大 3970 ms | 同上 |
| 原参赛 RPK | 72,703 字节 | artifacts/FocusLoop-0.1.0-debug.rpk |
| 原参赛 RPK SHA-256 | e781ef8e02b63de9456babb9f010db6580ba4d5cfcbdc61937c67bdd1d942a88 | artifacts/FocusLoop-0.1.0-debug.sha256 |
| 生产依赖漏洞 | 0，不含开发依赖 | verification/2026-09-16/audit-production.txt |

测试包含纯函数断言与源码结构约束，不等同于真实设备操作。计时覆盖子进程完整执行，包括 Node/npm 启动等宿主机开销；不得解释为模型响应延迟、设备帧率或续航。生成的 RPK 可能因打包时间而有不同哈希，报告引用 artifacts/ 中已提交的制品。

summary.json 逐项记录命令、退出码、耗时和输出文件 SHA-256。每次复测建立独立证据目录，保留之前的结果。本轮未重新测量 Goldfish 系统构建时间、设备内存、功耗、ASR 准确率或提醒误报率。

## 运行边界

- `xiaomi_watch_s1` Goldfish 已跑通页面导航、离线计划、专注、答题、进度保存以及 QuickApp 到 `ai_agent` 的请求链路。
- 语音桥已经完成系统编译和链接；端到端语音识别仍需要可用的录音设备与 ASR 服务。
- 智能复习窗口按照大赛 `service.health` 接口实现；压力数据运行验收需要使用带健康服务的 miwear 镜像或兼容设备。
- 应用进程在后台保留时，应用级监测器会继续接收压力和加速度采样。进程被系统结束后，时间型复习仍由 Agent 的持久定时任务负责；情境判断会在应用下次运行后恢复。

## 官方模板与交付

正式报告直接填写官方模板，覆盖 3.1–3.7。源码和 AI Coding 日志保留在专属仓库；正式 ZIP 只放 PDF 与 MP4。演示视频录制于 2026-08-01，技术报告中的测试结果更新为本轮复测数据。技术报告生成入口为 scripts/build_official_report.ps1。
