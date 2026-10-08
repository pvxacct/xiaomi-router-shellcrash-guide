# 小米路由器：解锁 SSH → 部署 ShellCrash → 节点落地 全流程

> **实测设备**：小米路由器 **AX3000T**（型号 `RD03`，SoC `MT7981` / Filogic 820，`aarch64 Cortex-A53`，256 MB RAM / 128 MB 闪存）
> **实测固件**：小米原厂固件（`OpenWrt 18.06-SNAPSHOT` 衍生，BusyBox 1.25.1，内核 5.4.171）
> **实测版本**：ShellCrash `1.9.5beta3` + Mihomo `v1.19.28` + Zashboard `v3.29.1`

本仓库是一条**从白机到能用**的完整链路，所有命令都在真机上跑通并按实际输出核过。它不是官方文档的搬运，而是把踩过的坑、每步的**预期输出**和**失败回退**都写清楚了。

---

## 目录

| 步骤 | 内容 | 文档 |
| --- | --- | --- |
| 0 | 准备与风险提示 | 本页 |
| 1 | 解锁并开启**永久 SSH** | [docs/01-unlock-ssh.md](docs/01-unlock-ssh.md) |
| 2 | 安装 ShellCrash（含初始化向导） | [docs/02-install-shellcrash.md](docs/02-install-shellcrash.md) |
| 3 | 导入订阅 + 添加自建节点 | [docs/03-nodes-and-subscription.md](docs/03-nodes-and-subscription.md) |
| 4 | 升级 **Dashboard 面板** 与 **内核** | [docs/04-panel-and-core-upgrade.md](docs/04-panel-and-core-upgrade.md) |
| 5 | 备份与整机恢复 | [docs/06-backup-restore.md](docs/06-backup-restore.md) |
| 6 | 常见问题排查 | [docs/05-troubleshooting.md](docs/05-troubleshooting.md) |

配套脚本在 [`scripts/`](scripts/) 目录。

---

## 0. 准备与风险提示

**你需要的东西**

- 一台电脑（Windows / macOS / Linux 都行），用**网线**接到路由器的 LAN 口
- 路由器已知的**后台管理密码**（小米路由器初始设置时设的那个）
- 一个能用的机场订阅链接，或者自己的 VPS 节点信息（vless / trojan / hysteria2 / tuic 等）

**开始前必须知道的四件事**

1. **解锁 SSH 需要利用固件漏洞并写入系统分区**。请先确认路由器**已过保**或你接受变砖风险；刷机操作不受官方保修保护。
2. **教程里的自定义节点参数（地址 / UUID / 密码）都是占位符**。公开仓库里千万不要提交自己的真实节点信息。
3. **改完网络配置后，本机可能短暂断网**。建议先在本机保存好路由器后台的登录方式，出问题可以直接捅复位孔恢复。
4. **路由器内存很小，别在上面跑大内存操作**。小米原厂固件把 `panic_on_oom` 设成 `2`，一次 OOM 就会**直接重启路由器**（不是杀进程）。最常见的踩雷方式是在路由器上 `tar` 打包大目录——实测就会触发。详见 [第 6 步：OOM](docs/05-troubleshooting.md#️-内存不足会导致路由器直接重启oom-panic)。

**全程大致耗时**：解锁 SSH 约 5 分钟，装 ShellCrash 约 5 分钟，导入订阅 2 分钟，升级内核约 10 分钟。

---

## 快速开始（TL;DR）

```sh
# 1) 电脑上先跑解锁工具，装好永久 SSH
#    见 docs/01-unlock-ssh.md

# 2) 登录路由器
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.31.1

# 3) 装 ShellCrash
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile

# 4) 进入菜单（首次进入会走一遍初始化向导）
crash        # 或执行 ShellCrash

# 5) 菜单路径
#    6 配置文件管理 -> a 添加提供者 -> 粘贴订阅链接
#    1 启动/重启服务
#    9 更新与支持 -> 2 切换/更新内核文件 -> 1 Meta内核
#    9 更新与支持 -> 4 安装/更新本地 Dashboard面板 -> 1 Zashboard
```

面板地址：`http://192.168.31.1:9999/ui/`

---

## 实测版本记录

真机升级前后对照（2026-10 实测）：

| 组件 | 升级前 | 升级后 | 说明 |
| --- | --- | --- | --- |
| ShellCrash | `1.9.5beta3` | `1.9.5beta3` | 已是最新公测版，无需更新 |
| 内核 Mihomo | `v1.19.17` | **`v1.19.28`** | 走 ShellCrash 官方镜像，详见第 4 步 |
| 面板 Zashboard | `v3.29.1` | `v3.29.1` | 已是最新 |

> ⚠️ **一个重要坑**：Mihomo 官方 GitHub Release 的 `linux-arm64` 二进制从 v1.19.31 起体积膨胀到 **57 MB（gz 20.8 MB）**，而本机 `/data` 分区总共只有 24 MB（可用 8 MB），**放不下**。ShellCrash 官方镜像里针对小闪存设备编译的精简版才是正确选择（`v1.19.28`，gz 仅 12 MB）。详见 [docs/04](docs/04-panel-and-core-upgrade.md)。

---

## 本教程覆盖的设备范围

**直接适用**：小米 / Redmi 采用 MT7621、MT7981（AX3000T、AX3000、AX6000 等）、MT7986 等联发科方案的型号，且运行原厂固件。

**流程有差异**：

- 高通 IPQ 方案机型（如 AX9000、AX3600 部分批次）：xmir-patcher 支持，但刷机和分区布局不同
- 已经是 OpenWrt / Padavan / Merlin 的机器：跳过第 1 步，直接从第 2 步开始
- 已刷 Breed / 不死鸟等第三方 Bootloader：注意不要覆盖 `bootloader` 分区

---

## 相关项目

- [ShellCrash](https://github.com/juewuy/ShellCrash) — 路由器上的 Clash/mihomo 管理脚本
- [mihomo](https://github.com/MetaCubeX/mihomo) — 内核
- [zashboard](https://github.com/Zephyruso/zashboard) — Web 面板
- [xmir-patcher](https://github.com/openwrt-xiaomi/xmir-patcher) — 小米路由器固件解锁 / 永久 SSH 工具

## 许可

本教程以 MIT 许可发布，见 [LICENSE](LICENSE)。脚本与命令按"现状"提供，刷机风险自负。
