# 第 2 步：安装 ShellCrash

[ShellCrash](https://github.com/juewuy/ShellCrash) 是一个纯 Shell 写的 mihomo / sing-box 管理脚本，适合路由器这种"没有 systemd、只有 BusyBox"的环境。它负责下载内核、生成配置、配置转发规则、开机自启，并内置了面板安装和内核升级。

---

## 2.1 前置检查

```sh
# 1) 必须是 root
id            # 期望输出 uid=0(root)

# 2) 有可用的下载器（BusyBox 自带的 curl/wget 通常就够）
command -v curl; command -v wget

# 3) 看空间。/data 至少留 15 MB 以上比较稳
df -h /data /tmp
```

`/data` 特别小（比如只剩 5 MB）时，安装向导里的"**小闪存模式**"会把运行时文件放到 `/tmp`（内存盘），代价是重启后部分内容需要重新下载。

---

## 2.2 一键安装

官方推荐用 jsDelivr CDN 源（国内可达性最好）：

```sh
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile
```

`curl` 不可用就换 wget：

```sh
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile
```

其他可用源（CDN 被墙或证书报错时换着试）：

| 源 | 地址 |
| --- | --- |
| jsDelivr CDN（推荐） | `https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master` |
| GitHub Raw | `https://raw.githubusercontent.com/juewuy/ShellCrash/master` |
| 作者私有源 | `https://gh.jwsc.eu.org/master` |
| 老设备 HTTP 源 | `http://t.jwsc.eu.org` |

> `@master` 是公测分支。想要更稳可以换 `@stable`，想尝鲜用 `@dev`。

安装完成后 `. /etc/profile` 会把 `crash` 别名和 `CRASHDIR` 带进当前会话。

---

## 2.3 首次进入的初始化向导

```sh
crash          # 等价于 /data/ShellCrash/menu.sh
```

第一次运行会依次问你：

| 问题 | 建议选择 | 说明 |
| --- | --- | --- |
| 安装目录 | 默认（`/data/ShellCrash`） | 除非 `/data` 空间告急，否则不要改 |
| 是否使用小闪存模式 | `/data` 剩余 < 10 MB 时选是 | 运行时数据走 `/tmp` |
| 下载内核类型 | **Meta 内核（mihomo）** | 功能最全，本教程默认 |
| 启动方式 | 路由器模式 | 由路由器统一转发，局域网设备免配置 |
| 是否设置开机自启 | **是** | 不做这一步重启后要手动开 |

---

## 2.4 主菜单结构（后面都会用到）

```text
 1 - 启动/重启服务      2 - 功能设置        3 - 停止服务
 4 - 启动设置           5 - 自动任务        6 - 配置文件管理
 7 - 访问与控制         8 - 工具与优化      9 - 更新与支持
 0 - 退出脚本
```

两个最常用的分支：

- **`6` 配置文件管理** → 导入订阅、生成配置（第 3 步）
- **`9` 更新与支持** → 更新内核、安装 Dashboard 面板（第 4 步）

---

## 2.5 安装内核

如果初始化向导里已经装了内核，可以跳过；否则：

```text
主菜单 9 更新与支持
   → 2 切换/更新内核文件
      → 1 Meta内核（mihomo，推荐）
```

其它几个选择：

| 选项 | 说明 |
| --- | --- |
| 1) Meta | mihomo，功能最全，支持 vless / hysteria2 / tuic 等新协议，**推荐** |
| 2) SingBoxR | sing-box 的 DustinWin 增强分支，配置不通用 |
| 3) SingBox | 占用小，但不支持 providers |
| 4) Clash | 老内核，已停止维护，不要选 |

内核下载完成后会解压到运行目录：

```sh
/tmp/ShellCrash/CrashCore -v
# Mihomo Meta v1.19.28 linux arm64 ...
```

---

## 2.6 启动并验证

```sh
# 启动
/data/ShellCrash/start.sh start

# 看进程
ps w | grep CrashCore | grep -v grep

# 看面板接口（external-controller 默认 9999）
curl -s http://127.0.0.1:9999/version
```

期望输出类似：

```text
{"meta":true,"version":"v1.19.28"}
```

本机实测的文件分布：

| 路径 | 作用 |
| --- | --- |
| `/data/ShellCrash/` | 脚本主目录（`CRASHDIR`） |
| `/data/ShellCrash/configs/ShellCrash.cfg` | 脚本自己的配置（内核类型、端口、更新源…） |
| `/data/ShellCrash/yamls/config.yaml` | 你编辑/生成的配置源文件 |
| `/tmp/ShellCrash/config.yaml` | 运行时配置（脚本会加规则、DNS、TUN 等） |
| `/tmp/ShellCrash/CrashCore` | 运行时内核二进制 |
| `/tmp/ShellCrash/ShellCrash.log` | 运行日志 |
| `/etc/init.d/shellcrash` | procd 开机自启 |

> `/data/ShellCrash/config.yaml` 通常是一个指向 `/tmp/ShellCrash/config.yaml` 的软链，**别去改它**，改 `/data/ShellCrash/yamls/config.yaml`。

---

## 2.7 设置开机自启

```text
主菜单 4 启动设置 → 设置开机启动
```

验证：

```sh
ls -l /etc/init.d/shellcrash
ls -l /etc/rc.d/ | grep shellcrash
```

重启一次路由器，确认 `ps w | grep CrashCore` 里还有进程。

---

下一步 → [导入订阅与自建节点](03-nodes-and-subscription.md)
