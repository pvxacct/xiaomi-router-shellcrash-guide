# 第 6 步：常见问题排查

排查通用套路，先跑这三条：

```sh
# 1) 进程在不在
ps w | grep -E 'CrashCore|shellcrash' | grep -v grep

# 2) 日志说什么
tail -50 /tmp/ShellCrash/ShellCrash.log

# 3) 内核自己怎么说（最有用）
/tmp/ShellCrash/CrashCore -d /data/ShellCrash -f /tmp/ShellCrash/config.yaml -t
```

第 3 条会直接告诉你配置哪一行有问题。

---

## SSH 相关

**`no matching host key type found`**

新版 OpenSSH 默认不再协商 `ssh-rsa`。加参数：

```sh
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.31.1
```

**`Permission denied (publickey,password)`**

老固件的 dropbear 有时只吃 `ssh-rsa`，也可能是你本地有 `~/.ssh/id_*` 但服务器不认。强制用密码：

```sh
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password root@192.168.31.1
```

**重启后 SSH 又没了**

说明"永久 SSH"没写成功，重跑 xmir-patcher 的 `2` → `6`。也可能固件自动升级后把 `/etc/init.d/dropbear` 还原了——建议关掉自动升级。

**忘记 root 密码**

xmir-patcher 主菜单 `8` → `2 - Change root password`。

---

## ShellCrash 安装 / 启动

**安装脚本下载失败 / 证书报错**

换源重试（见 [第 2 步](02-install-shellcrash.md) 的源列表）。老设备（BusyBox 的 wget 太旧）用 HTTP 源：

```sh
export url='http://t.jwsc.eu.org'
mkdir -p /tmp/SCtmp && cd /tmp/SCtmp && \
  wget -O shellcrash.tar.gz "$url/bin/ShellCrash.tar.gz" && \
  tar -zxf shellcrash.tar.gz -C /data/ && \
  . /data/ShellCrash/init.sh
```

**`检测到不可用的内核文件！可能是文件受损或CPU架构不匹配`**

内核和 CPU 架构不匹配，或者下载没下完。检查：

```sh
uname -m                              # aarch64 / armv7l / mips ...
grep '^cpucore=' /data/ShellCrash/configs/ShellCrash.cfg
ls -l /data/ShellCrash/CrashCore.tar.gz
```

常见对应关系：`aarch64` → `arm64`，`armv7l` → `armv7`，`mipsel` → `mipsle-softfloat`。

修好后回主菜单 `9 → 2` 重装内核。手工放内核的目录必须是：

```text
/data/ShellCrash/CrashCore.tar.gz      （tar.gz 包，里面文件名建议为 CrashCore）
/data/ShellCrash/CrashCore.gz          （纯 gzip 的裸二进制）
/data/ShellCrash/CrashCore.raw         （未压缩裸二进制）
/data/ShellCrash/CrashCore.upx         （UPX 压缩）
```

放进去后进主菜单 `9` 加载，或 `start.sh restart`。

**`当前目录剩余空间较低`**

```sh
df -h /data /tmp
du -sh /data/ShellCrash/*
```

能腾就腾（删旧内核包、删不用的面板），腾不出来就在初始向导里开**小闪存模式**。

**服务起来了但立刻死**

大概率是端口冲突：

```sh
netstat -tlnp | grep -E '7890|7891|7892|7893|9999'
```

端口被小米自带服务占用的话，去主菜单 `2 功能设置` 改端口。

**定时任务 / 开机后服务没有起来**

日志里出现这一行，就是它没启动：

```text
2026-10-08_03:01:09~当前设备无法连接网络，已停止启动！
```

原因：ShellCrash 在启动前会做一次**联网自检**。如果你设置了"每天定时重启服务"，路由器刚起来时上游（光猫 / PPPoE）往往还没就绪，自检失败脚本就直接放弃启动，而且不会自己补跑一次。

处理：

```text
主菜单 4 启动设置
   → 6 自启网络检查   改为 OFF
```

关掉后 ShellCrash 会跳过启动时的网络检查，直接按配置启动。改完手动重启一次确认：

```sh
/data/ShellCrash/start.sh restart
sleep 8
curl -s http://127.0.0.1:9999/version
```

---

## 面板相关

**`http://192.168.31.1:9999/ui/` 打不开**

```sh
# 内核里 external-controller 监听的是不是 0.0.0.0:9999
grep -E 'external-controller|external-ui' /tmp/ShellCrash/config.yaml

# 本地通不通
curl -s http://127.0.0.1:9999/version

# ui 目录在不在
ls /data/ShellCrash/ui/index.html
```

- `external-controller: :9999` 是"监听所有地址"，如果被改成了 `127.0.0.1:9999` 就只能本机访问
- 小米固件自带防火墙可能挡 9999，去 `防火墙/安全` 里放行，或改成局域网可访问

**面板打开是空白 / 样式错乱**

`ui/` 目录没装全。回主菜单 `9 → 4` 重装面板。

**面板里看不到我的自建节点**

节点没进配置。见 [第 3 步 3.3.4](03-nodes-and-subscription.md#334-让自建节点活过配置重新生成)——多半是配置被重新生成后手写节点丢了。

---

## 节点 / 网络相关

**面板显示节点是绿的，但浏览器还是上不了外网**

先用命令行确认：

```sh
curl -x http://127.0.0.1:7890 --max-time 20 https://api.ipify.org
```

- 这条**能通** → 代理本身没问题，是**客户端/规则/DNS**的问题：看电脑的网关是不是指向路由器、DNS 有没有被劫持、规则是不是把目标域名走了 `DIRECT`
- 这条**不通** → 节点或分流有问题：换个节点试，或看 `/tmp/ShellCrash/ShellCrash.log`

**DNS 解析异常 / 打开网页很慢**

`config.yaml` 里默认是 `fake-ip` 模式。局域网设备若没把 DNS 指到路由器，会解析不到。检查：

```sh
cat /etc/resolv.conf
nslookup www.google.com 192.168.31.1
```

**某些域名必须直连（国内网站、NAS、打印机）**

在规则里加 `DIRECT`：

```yaml
rules:
  - DOMAIN-SUFFIX,example.com,DIRECT
  # ... 原有规则
  - MATCH,Proxy
```

改完必须 `start.sh restart`。

**想要"只让某些设备走代理"**

用 ShellCrash 的**访问控制 / 黑白名单**（主菜单 `7 访问与控制`），按设备 MAC 或来源网段过滤。

---

**订阅导入后节点全是 `blocked`，或者名称看着正常但一个都连不上**

有些机场会按 `User-Agent` 下发不同内容：识别成 Clash 客户端就给正常节点，识别不出来就给**占位节点**（常见名字就是 `blocked`、`官网`、`剩余流量` 之类），防止订阅链接被随意抓取。

处理：给这个提供者单独指定常用的客户端 UA。

```text
主菜单 6 配置文件管理
   → 选中你的提供者
      → 设置 UA        # 例如 clash-verge/v2.2.3 或 Clash.Meta/mihomo
   → 返回后重新生成配置文件
主菜单 1 启动/重启服务
```

也可以在"在线生成配置文件"里改全局 UA：

```text
主菜单 6 配置文件管理 → c 在线生成配置文件 → 6 自定义浏览器UA
```

改完这样确认拿到的是真节点：

```sh
grep -c '^  - ' /data/ShellCrash/yamls/config.yaml     # 节点条目数量，应该接近你订阅里的数量
grep -i 'blocked' /data/ShellCrash/yamls/config.yaml  # 期望没有任何输出
```

**节点延迟是绿的，但浏览器照样打不开网页**

面板的"延迟测试"只要拿到**任意 HTTP 响应**就算通过，所以它不能证明这个节点真的能翻墙。尤其是 TUIC / Hysteria2 这类走 **UDP(QUIC)** 的协议：

- 服务端是**自签证书**时必须加 `skip-cert-verify: true`，否则根本连不上（见 [第 3 步](03-nodes-and-subscription.md)）
- 运营商对 UDP 限速 / 阻断时，会出现"小请求能通、HTTPS 握手超时"：延迟好看，实际用不了

判断方法见 [第 3 步 3.4](03-nodes-and-subscription.md#34-验证节点真的能用) 的端到端测试，关键是**出口 IP 要变成节点 IP**：

```sh
curl -x http://127.0.0.1:7890 --max-time 20 https://api.ipify.org; echo
```

## ⚠️ 内存不足会导致路由器直接重启（OOM panic）

**现象**：SSH 突然断开、路由器自己重启，`uptime` 显示的运行时长比预期短很多。

**原因**：小米原厂固件普遍设置了

```sh
cat /proc/sys/vm/panic_on_oom
# 2
```

`panic_on_oom=2` 表示"一旦 OOM，内核直接 panic 重启"，而不是杀掉占用内存的进程。
AX3000T 只有 256 MB 内存，mihomo 常驻后空闲内存常年只有 15 MB 左右，
再跑任何**大内存操作**（在路由器上 `tar` 打包大目录、解压大文件、下载大文件到 `/tmp`）都可能触发。

**怎么确认**：

```sh
uptime                      # 看开机时长，比预期短就是被重启了
ls -l /tmp/panic.tar.gz     # 小米固件会把 panic 现场留在这里
mkdir -p /tmp/px && tar -xzf /tmp/panic.tar.gz -C /tmp/px && \
  grep -iE "out of memory|oom-killer|Kernel panic" /tmp/px/*
```

典型输出：

```text
tar invoked oom-killer: gfp_mask=0x500cc2, order=0, oom_score_adj=0
Kernel panic - not syncing: Out of memory: compulsory panic_on_oom is enabled
```

**怎么避免**：

- **不要**在路由器上做大文件 `tar` / `gzip`。要打包就先 `free` 看一眼空闲内存
- 需要传大文件时，让**电脑主动推**（`wget` 从电脑拉），而不是在路由器上边下边解压
- 用 `top -b -n 1` 看谁在吃内存；mihomo 的 `VSZ` 显示很大是正常的（Go 的虚拟地址），看 RSS 才有意义
- 想更稳可以：
  - 主菜单 `2 功能设置` 关掉用不到的 TUN / IPv6
  - 减少订阅节点数量（提供者里设"排除节点正则"）
  - 换更小的面板

**如果真的重启了**：只要 `/data` 没坏，ShellCrash 会开机自启，等 1～2 分钟即可恢复。
恢复后 `df -h /data`、`curl -s http://127.0.0.1:9999/version` 确认一下状态。

---

## 空间与性能

**内存吃紧（AX3000T 只有 256 MB）**

```sh
free
```

mihomo 在 `unified-delay`、fake-ip、TUN 全开时会占比较多。可以：

- 主菜单 `2 功能设置` 里关掉用不到的 TUN / IPv6
- 换占用更小的面板（基础面板约 500 KB）
- 减少订阅里的节点数量（在提供者里设置"排除节点正则"）

**规则文件太大拖慢启动**

`Country.mmdb` + `geosite` 全集在低配设备上加载慢。用主菜单 `9 → 3` 换成**精简版数据库**，或者使用 `mrs` 格式的规则集（本教程实测的配置用的就是 `mrs`）。

---

## 完全卸载

```text
主菜单 9 → 8 卸载ShellCrash
```

手工清理（确认不再需要时）：

```sh
/data/ShellCrash/start.sh stop
rm -rf /data/ShellCrash
rm -f /etc/init.d/shellcrash
sed -i '/crash/d;/CRASHDIR/d' /etc/profile
```

还要把 `crontab -e` 里 ShellCrash 添加的更新任务删掉，并恢复电脑/手机的网关与 DNS 设置。
