# 第 1 步：解锁并开启永久 SSH

小米原厂固件默认关闭 SSH。这一步用 **xmir-patcher** 利用固件自身的能力，把 `ssh_en` 打开、把 dropbear 设为开机自启，并给你设置一个 root 密码。做完之后 SSH **重启依然保留**。

> 这一步会写路由器系统配置（`nvram` + `/etc/init.d/dropbear`），不会刷固件、不会动 Bootloader。但请仍然先确认自己接受风险。

---

## 1.1 准备工作

- 电脑用**网线**接路由器 **LAN 口**（不要走 WiFi，也不要用路由器 WAN 口的上级网络）
- 确认路由器后台地址，通常是 `192.168.31.1`
- 记下路由器的**后台管理密码**（网页登录用的那个）
- **先关掉电脑上的代理 / VPN / 虚拟网卡**，避免 `192.168.31.1` 被路由到别处

确认默认网关就是路由器：

```powershell
# Windows
ipconfig | findstr /i "网关 Gateway"
# Linux / macOS
ip route | grep default      # 或 netstat -rn | grep default
```

---

## 1.2 下载并运行 xmir-patcher

项目地址：<https://github.com/openwrt-xiaomi/xmir-patcher>

下载仓库 ZIP 并解压，然后：

| 系统 | 运行方式 |
| --- | --- |
| Windows | 双击 `run.bat`（自带便携版 Python，无需另装） |
| Linux / macOS | 需要 `python3` + `openssl`，执行 `./run.sh` |

启动后会看到主菜单：

```text
==========================================================
Xiaomi MiR Patcher
==========================================================
 1 - Set IP-address (current value: 192.168.31.1)
 2 - Connect to device (install exploit)
 3 - Read full device info
 4 - Create full backup
 5 - Install EN/RU languages
 6 - Install permanent SSH
 7 - Install firmware (from directory "firmware")
 8 - {{{ Other functions }}}
 9 - [[ Reboot device ]]
 0 - Exit
```

---

## 1.3 按顺序操作

### ① 选 `1` 设定 IP

默认就是 `192.168.31.1`，只在你改过 LAN 网段时才需要改。

### ② 选 `4` 创建整机备份（强烈建议）

会导出各分区到 `outdir/` 目录。以后要恢复原厂状态就靠它。
这一步耗时稍长（几分钟），中途不要断电。

### ③ 选 `2` 连接设备并植入临时利用

会提示输入路由器后台密码：

```text
Enter device WEB password:
```

输入后工具会用该漏洞在路由器上拿到一个临时 root shell（`/tmp` 里的 kmod + patch）。
看到类似 `Device is connected` / `SSH is ready` 的输出就成功了。

> **这一步的权限是临时的**，重启就没了，所以必须继续做第 ④ 步。

### ④ 选 `6` 安装永久 SSH

工具会问你**想给 root 设置的密码**（输入时不回显 / 只显示 `*`）：

```text
Enter new password for root user:
```

设置完之后，它会：

- `nvram set ssh_en=1` 并 `nvram commit`
- 把 `/etc/init.d/dropbear` 里的版本判断改掉，让 dropbear 在正式固件上也启动
- `/etc/init.d/dropbear enable && restart`

看到 `SSH patch OK` / `All done` 之类提示即完成。

### ⑤（可选）选 `8` → `2` 之后再改 root 密码

以后想换密码：主菜单 `8`（其他功能）→ 二级菜单 `2 - Change root password`。

### ⑥ 选 `9` 重启设备验证

重启后 SSH 应该依然可用。如果重启后连不上，说明第 ④ 步没写进持久化配置，回到第 ③ ④ 步重做。

---

## 1.4 验证 SSH

```sh
ssh root@192.168.31.1
```

**新版本 OpenSSH（9.x+）会拒绝老式 `ssh-rsa` 主机密钥**，报 `no matching host key type found`。加上这两个参数即可：

```sh
ssh -o HostKeyAlgorithms=+ssh-rsa \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o PubkeyAuthentication=no \
    root@192.168.31.1
```

嫌麻烦就写进 `~/.ssh/config`：

```text
Host xiaomi
    HostName 192.168.31.1
    User root
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    PubkeyAuthentication no
    PreferredAuthentications password
```

之后直接 `ssh xiaomi` 即可。仓库里也附了一个包装脚本 [`scripts/ssh-router.sh`](../scripts/ssh-router.sh)。

登录成功后应该能看到：

```text
BusyBox v1.25.1 (2025-xx-xx) built-in shell (ash)
root@XiaoQiang:~#
```

---

## 1.5 顺手看一下设备信息

```sh
cat /proc/xiaoqiang/model            # 型号，例如 RD03
uname -a                             # aarch64 / armv7 / mips ...
cat /etc/openwrt_release             # 固件分支与架构
df -h /data /tmp                     # 可用空间，后面装 ShellCrash 要看
cat /proc/mtd                        # 分区表
```

本教程实测的 AX3000T（`RD03`）输出：

```text
Linux XiaoQiang 5.4.171 aarch64 GNU/Linux
DISTRIB_TARGET='mediatek/mt7981'
DISTRIB_ARCH='aarch64_cortex-a53'
ubi1:cfg   24.3M   15.1M   8.0M  65% /data
tmpfs     119.5M   34.0M  85.5M  28% /tmp
```

**记下 `/data` 的可用空间**。Xiaomi 原厂固件的 `/data` 通常只有 20～30 MB，这个数字会直接决定第 4 步能装哪个内核。

---

## 1.6 常见问题

**连不上 `192.168.31.1`**
- 电脑是否接了 LAN 口（不是 WAN）
- 是否开了代理 / VPN；关掉后重试
- 路由器是不是改过 LAN 网段（比如改成 `192.168.2.1`）

**`Connect to device` 报 `WEB password is not correct`**
- 后台密码错了。注意这是路由器**网页登录**密码，不是 WiFi 密码
- 有些固件改了加密方式，确认路由器后台能正常登录

**装完 SSH 后重启又连不上**
- 第 ④ 步没成功，或固件更新后 dropbear 配置被还原，重做第 ③ ④ 步

**`Install firmware` 千万别乱点**
- 主菜单 `7` 会刷写你放在 `firmware/` 目录下的固件，那是另一件事，和本教程无关

---

下一步 → [安装 ShellCrash](02-install-shellcrash.md)
