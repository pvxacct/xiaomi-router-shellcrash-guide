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
