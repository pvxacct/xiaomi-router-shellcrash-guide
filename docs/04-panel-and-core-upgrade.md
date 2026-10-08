# 第 4 步：升级 Dashboard 面板与内核

ShellCrash 把这两件事都放在**主菜单 `9` 更新与支持**里：

```text
 1) 更新管理脚本
 2) 切换/更新内核文件          ← 内核
 3) 安装/更新本地数据库文件
 4) 安装/更新本地 Dashboard面板  ← 面板
 5) 安装/更新本地根证书文件
 6) PAC 自动代理查看
 7) 切换安装源及版本分支
 8) 卸载ShellCrash
```

升级前先记录现状：

```sh
cat /data/ShellCrash/version                       # 脚本版本
/tmp/ShellCrash/CrashCore -v                       # 内核版本
grep -E '^(crashcore|core_v|cpucore)=' /data/ShellCrash/configs/ShellCrash.cfg
ls -l /data/ShellCrash/ui/assets/ | head            # 面板资源（文件名里带 hash）
df -h /data
```

---

## 4.1 更新 ShellCrash 脚本本身

```text
主菜单 9 → 1 更新管理脚本
```

脚本会先检查版本。当前版本与最新版一致时会直接提示"已是最新"，不会重复下载。

> ⚠️ 更新脚本会**先停止服务**，升级完成后记得回主菜单 `1` 重新启动。

---

## 4.2 更新内核

```text
主菜单 9
   → 2 切换/更新内核文件
      → 1 Meta内核（mihomo，推荐）
```

脚本会：

1. 从它的镜像仓库下载 `bin/meta/clash-linux-arm64.tar.gz`
2. 解压并按 `-v` 校验是不是合法的 mihomo 二进制
3. 备份/替换 `/data/ShellCrash/CrashCore.tar.gz`
4. 把 `core_v` 写进 `configs/ShellCrash.cfg`

完成后重启服务并验证：

```sh
/data/ShellCrash/start.sh restart
sleep 8
/tmp/ShellCrash/CrashCore -v
curl -s http://127.0.0.1:9999/version
```

---

## 4.3 ⚠️ 关于"要不要用 mihomo 官方最新版"

**结论：这台 24 MB 的 `/data` 装不下 mihomo 官方 GitHub Release 的 arm64 包，请用 ShellCrash 镜像版。**

实测数据（2026-10）：

| 来源 | 版本 | 压缩包 | 解压后 |
| --- | --- | --- | --- |
| ShellCrash 镜像 `@update/bin/meta/` | `v1.19.28` | **12.0 MB** | 32.7 MB |
| mihomo 官方 GitHub Release | `v1.19.32` | **20.8 MB** | 57.4 MB |

而设备上：

```text
ubi1:cfg   24.3M   15.1M   8.0M  65% /data
```

`/data` 可用只有 8 MB，官方包光压缩包就要 20.8 MB，**替换都会失败**。

原因是官方 Release 的构建带了完整符号和更多组件（`.text` 21.3 MB + `.gopclntab` 19.5 MB），而 ShellCrash 镜像针对小闪存设备重新编译并 strip 过。既然镜像版能跑通你的订阅和协议，**优先用它**。

> 想验证某个压缩包到底多大、能不能放下，先看 `df -k /data` 的可用 KB，再和包大小比较，并留出 2 MB 余量（运行时还要写 `cache.db` 和规则缓存）。

---

## 4.4 更新面板（Dashboard）

```text
主菜单 9
   → 4 安装/更新本地 Dashboard面板
      → 1 安装 Zashboard（推荐）
```

其他面板选项：

| 选项 | 体积 | 说明 |
| --- | --- | --- |
| 1) Zashboard | 约 5 MB | 功能最全，**推荐**（当前默认） |
| 2) Meta-XD | 约 3 MB | 另一个 mihomo 面板 |
| 3) Meta-Yacd | 中 | |
| 4) 基础面板 | 约 500 KB | 极简，空间紧张时用 |
| 5) Meta 基础面板 | 约 800 KB | |
| 6) Yacd | 约 1.1 MB | 老牌面板 |

安装后脚本会：

- 解压到 `/data/ShellCrash/ui/`
- 把 `assets/*.js` 里的 `127.0.0.1:9090` 批量替换成当前设备 IP 和端口
- 在 `configs/ShellCrash.cfg` 里写入 `hostdir=': 9999/ui'`

**面板地址**：

```text
http://192.168.31.1:9999/ui/
```

验证：

```sh
curl -s -o /dev/null -w 'ui http=%{http_code}\n' http://127.0.0.1:9999/ui/
# ui http=200
```

### 怎么判断面板是不是最新

Zashboard 的资源文件名里带内容 hash。把设备上的 `ui/assets/index-*.js` 与上游 release 的产物比一下就知道：

```sh
# 设备上
ls /data/ShellCrash/ui/assets/ | grep '^index-'
```

再到 <https://github.com/Zephyruso/zashboard/releases> 下载 `dist-cdn-fonts.zip`，解压后对比 `index.html` 里引用的 `assets/index-*.js` 名字；名字一致就是最新版。

---

## 4.5 手动升级内核（不想走菜单时）

菜单偶尔会因为源地址不可达而失败，这时可以手动做同样的事。

**① 在电脑上下载 ShellCrash 镜像里的内核包**

```sh
# ShellCrash 的镜像分支是 update（注意不是 master）
curl -L -o core.tar.gz \
  https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@update/bin/meta/clash-linux-arm64.tar.gz
```

**② 传到路由器**（见 [scripts/](../scripts/) 里的传输说明，或直接用 `scp`）

**③ 在路由器上先验证再替换**

```sh
mkdir -p /tmp/testcore
tar -zxf /tmp/core.tar.gz -C /tmp/testcore/
chmod +x /tmp/testcore/CrashCore

# 版本对不对
/tmp/testcore/CrashCore -v

# 现有配置能不能被新内核解析（这一步很关键，别跳过）
/tmp/testcore/CrashCore -t -d /data/ShellCrash -f /tmp/ShellCrash/config.yaml
```

第二条命令末尾应该出现：

```text
configuration file /tmp/ShellCrash/config.yaml test is successful
```

**④ 替换并重启**

```sh
# 备份旧内核
cp -f /data/ShellCrash/CrashCore.tar.gz /tmp/CrashCore.old.tar.gz

# 替换（先删再写，避免空间不够）
rm -f /data/ShellCrash/CrashCore.tar.gz
cp /tmp/core.tar.gz /data/ShellCrash/CrashCore.tar.gz
chmod 644 /data/ShellCrash/CrashCore.tar.gz

# 更新脚本记录的版本号
sed -i 's/^core_v=.*/core_v=v1.19.28/' /data/ShellCrash/configs/ShellCrash.cfg

# 重启
/data/ShellCrash/start.sh restart
sleep 10

# 验证
/tmp/ShellCrash/CrashCore -v
curl -s http://127.0.0.1:9999/version
df -h /data
```

**⑤ 出问题怎么回滚**

```sh
rm -f /data/ShellCrash/CrashCore.tar.gz
cp /tmp/CrashCore.old.tar.gz /data/ShellCrash/CrashCore.tar.gz
/data/ShellCrash/start.sh restart
```

> `/tmp` 是内存盘，重启就没了。真要保险，回滚包请用 [第 5 步](06-backup-restore.md) 的方法存到电脑上。

---

## 4.6 本次实测结果

设备：小米 AX3000T（`RD03`）

| 组件 | 升级前 | 升级后 |
| --- | --- | --- |
| ShellCrash | `1.9.5beta3` | `1.9.5beta3`（已最新） |
| Mihomo | `v1.19.17` | **`v1.19.28`** |
| Zashboard | `v3.29.1` | `v3.29.1`（已最新） |
| `/data` 可用 | 8.0 MB | 6.3 MB |

升级后验证：

```text
/tmp/ShellCrash/CrashCore -v
→ Mihomo Meta v1.19.28 linux arm64 with go1.26.5

curl -s http://127.0.0.1:9999/version
→ {"meta":true,"version":"v1.19.28"}

curl -x http://127.0.0.1:7890 --max-time 20 https://api.ipify.org
→ 198.51.100.23        （出口已是节点 IP）
```

---

下一步 → [备份与恢复](06-backup-restore.md)
