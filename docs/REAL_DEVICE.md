# 真机验证记录：黄山派 SF32LB52

这份记录说明 FocusLoop 在模拟器之外的一次真机验证：把 openvela 从源码构建、
烧录到一块 390×450 AMOLED 手表板上，并让五页 QuickApp 流程完整跑起来。

结论先说：**核心学习闭环已在真机验证；依赖云端模型的路径仍以 Goldfish 镜像为准。**
逐项边界见文末。

---

## 1. 为什么做这一步

初赛规则允许纯快应用方向在模拟器上验证，我们也确实是这样完成的。但模拟器不会
暴露真实面板的时序、真实文件系统的读写属性、真实镜像里缺了哪个服务。

所以补做了一次真机验证。目的不是换平台，而是回答一个问题：
**同一份代码，换到真实的屏幕和真实的系统镜像上，还成立吗？**

答案是——不成立，除非修掉八个平台侧问题。

---

## 2. 硬件与环境

| 项目 | 规格 |
| --- | --- |
| 开发板 | 立创·黄山派（SF32LB52-LCHSPI-ULP 参考设计） |
| 主控 | SF32LB52x 双核 Star-MC1（240 MHz + 24 MHz），8 MB OPI-PSRAM，16 MB QSPI-NOR |
| 显示 | 1.85" 390×450 AMOLED，CO5300 控制器，QSPI 接口 |
| 触控 | FT6146 电容触控，I2C |
| 系统 | openvela `dev-ai-contest-2026` 分支，从源码全量构建 |
| 烧录 | XIP 到 NOR 偏移 `0x12010000`，串口 1000000 8N1（RTS 直连复位） |

镜像规模：约 4.9 MB，含 QuickApp 运行时、LVGL、字体与 FocusLoop 应用。
开机自检 0 报错，五页可切换、答题流程完整。

---

## 3. 八个缺陷

全部已定位根因并验证修复。前七项属平台/框架侧，第八项是我们自己引入的。

| # | 现象 | 根因 | 修复 |
| --- | --- | --- | --- |
| 1 | 整屏只有均匀粉色，`fb` 测试报告成功但画面不动 | LCDC 配成 TE 垂直同步；该面板 TE 通路未产生可识别脉冲，帧提交永久等待，驱动的 `putarea` 一次都未执行 | 关闭 `CONFIG_LCD_CO5300_VSYNC_ENABLE` |
| 2 | 应用启动后卡死，界面始终不出现 | 板级缺少 `CONFIG_NET_LOCAL`，curl 回退到自带的阻塞式 `socketpair` 实现，永久阻塞在 `accept()` | 打开 `CONFIG_NET_LOCAL` 与 `CONFIG_NET_LOCAL_STREAM` |
| 3 | 调用栈停在 `property_connect` 反复重试 | 镜像内没有属性服务端（`CONFIG_KVDB_SERVER` 未开），`rcS` 也未启动它；`ash::DeviceInfo::init` 因此无限重试 | 打开 `CONFIG_KVDB_SERVER`，开机脚本先起 `kvdbd` |
| 4 | 应用存储报 `EROFS`，学过的卡片存不住 | `storage_impl.cpp` 把应用数据库根目录复用为 `CONFIG_HAP_APP_PATH`（本板为只读 romfs） | 改到可写数据根 `/data/quickapp` |
| 5 | 页面模块加载失败，切换页面即空白 | 工具链 2.0.5 产物的字节码与设备端运行时接口不匹配（厂商自带计算器应用同样受影响） | 改用 aiot-toolkit 2.0.3 构建，并开启预编译字节码 |
| 6 | UI 整体偏小，且横向被压扁 | 框架把设计画布硬编码为 480×480（源码内标注 `TODO`），而面板为 390×450，横纵缩放不一致 | 设计画布改为 Kconfig 可配，板级设 390×450 |
| 7 | 每次创建字体都回退到 LVGL 默认字体（极小） | 设备请求 `MiSans-Regular` / `MiSans-Demibold`，镜像内文件名不匹配，全部查找失败 | 按设备实际请求的名字安装字体，并做字形子集化 |
| 8 | 切到第三个页面时白屏 | **我们引入的回归**：把 JS 堆参数从 1 MB 调到 8 MB，堆分配失败导致运行时退化 | 回滚到板级原值；用内存采样确认 OOM 时系统仍有 6 MB 空闲，才判定是固定大小的池 |

### 排查方法（可复用）

- **二分 + 调试开关**：缺陷 1 靠打开 LCD 调试确认「`putarea` 调用次数为 0」定位到提交层。
- **NuttX `dumpstack`**：缺陷 2、3 靠抓任务调用栈，直接看到阻塞在 `accept()` 与
  `property_connect` 的重试循环里。
- **内存采样**：缺陷 8 用每 8 秒 `free` 的脚本记录切页过程，发现 OOM 时系统仍有余量，
  从而排除了「内存不够」这个直觉答案。
- **顺序对照**：把原本失败的页面放到第一个访问，确认失败与「页面」无关、与
  「累积」有关——这一步直接改掉了原来的错误假设。

完整日志、调用栈与修复前后对比保留在本地验证目录，不随仓库提交。

---

## 4. 复现步骤

```bash
# 1. 构建。本记录的环境是 CachyOS（Arch 系）+ xPack arm-none-eabi-gcc 13.3.1，
#    未使用官方构建脚本包装，而是直接调用 cmake，以便增量重编（约 40 秒）。
#    openvela 官方推荐环境为 Ubuntu 22.04，构建脚本写法可能不同。
export PATH=/path/to/xpack-arm-none-eabi-gcc-13.3.1-1.1/bin:$PATH
cmake -B cmake_out/lckfb_huangshan_pi -S nuttx -GNinja \
  -DBOARD_CONFIG=../vendor/sifli/boards/sf32lb52/lckfb_huangshan_pi/configs/nsh \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build cmake_out/lckfb_huangshan_pi -j$(nproc)

# 2. 烧录
sftool -c SF32LB52 -p /dev/ttyUSB0 -b 1000000 \
  --before default_reset --after soft_reset \
  write_flash cmake_out/lckfb_huangshan_pi/nuttx.bin@0x12010000

# 3. 构建应用（预编译字节码，体积更小、设备端无需在机上编译）
cd quickapp/focusloop && npx aiot build --enable-jsc

# 4. 串口：1000000 8N1。注意 RTS 直连 SoC 复位，必须禁用，否则一开串口就复位。
#    ser.rts = False; ser.dtr = False
```

板级启动脚本 `etc/init.d/rcS` 需先启动属性服务，再启动应用：

```sh
kvdbd &
sleep 3
vapp hap://app/com.openvela.focusloop &
```

---

## 5. 已验证 / 未验证

**已在真机验证**

- 五页 QuickApp 页面显示与导航（首页 / 计划 / 专注 / 答题 / 智能窗口）
- 触控切页与答题交互
- 断网状态下生成内置策略题卡，并完成计时、判分、间隔更新、状态保存
- 开机自检 0 报错，`kvdbd` 与 `vapp` 常驻运行

**未在真机验证（仍以 Goldfish 镜像为准）**

- 云端模型路径（`system.velaclaw` → `ai_agent`）：该板无可用网卡，真机演示走离线降级；
  模型链路已在 Goldfish `goldfish-arm64-v8a-ap` 镜像上验证
- `service.health` 压力数据：需带健康服务的镜像（如 `vela-miwear-watch-5.0`）才能验收；
  本板未引出该服务，应用自动只关闭智能窗口一页
- 语音端到端识别：语音桥已完成系统编译与链接，端到端仍需可用录音设备与 ASR 后端
- 功耗、帧率、模型延迟、ASR 准确率：均未测量

---

## 6. 顺带的图形栈验证

同一套显示通路还用于一次 390×450 视频回放验证（1-bit RLE 素材，约 7.7 fps），
用于确认 LCDC/QSPI 刷屏与内存带宽可用。这是**能力验证**，不属于作品功能。

---

## 7. 这些修复的价值

八个缺陷里有七个属平台或框架侧，意味着在此之前**这条路径没有被完整走通过**。
文档化它们的目的不是罗列问题，而是把「快应用在真实手表板上能不能用」这个问题
从猜测变成可复现的结论——包括那张已知的边界清单。
