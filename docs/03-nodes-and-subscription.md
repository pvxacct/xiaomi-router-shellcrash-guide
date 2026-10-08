# 第 3 步：导入订阅 / 部署节点

ShellCrash 里"节点"有两个来源，通常混着用：

| 来源 | 适用 | 维护方式 |
| --- | --- | --- |
| **订阅（提供者）** | 机场 / 自建订阅链接 | 脚本自动更新节点与规则 |
| **自建 / 分享链接** | 自己的 VPS（vless、hysteria2、tuic…） | 手动添加，需处理"配置被重新生成覆盖"的问题 |

---

## 3.1 方式 A：导入订阅（最常用）

```text
主菜单 6 配置文件管理
   → a 添加提供者（支持订阅/分享链接及本地文件）
      → 名称或代号：  myairport      # 不超过 4 个汉字，不能纯数字
      → 链接或路径：  https://你的机场订阅地址
      → 保存此提供者
```

保存后再生成一次配置：

```text
 6 配置文件管理
   → b 本地生成配置文件        # 用脚本本地规则，不依赖订阅转换
   → 选择刚才的提供者
```

或者 `c 在线生成配置文件`（走订阅转换服务，能自动补规则，但依赖第三方服务可用）。

生成完回到主菜单 `1 启动/重启服务`。

**订阅自动更新**：在提供者条目里可以设置"自动更新间隔"（默认 12 小时），ShellCrash 会写进 `crontab`。

---

## 3.2 方式 B：分享链接

`添加提供者` 也能直接吃分享链接，脚本内置转换：

```text
链接或路径： vless://xxxxxxxx@1.2.3.4:443?...#节点名
链接或路径： hysteria2://密码@1.2.3.4:8443?...#节点名
链接或路径： trojan://密码@1.2.3.4:443?...#节点名
```

转换依赖脚本自带的 subconverter 组件，网络不好时可能失败——失败就走下面的方式 C。

---

## 3.3 方式 C：手写节点（高级，最可控）

### 3.3.1 先搞清楚配置文件在哪

ShellCrash 的配置生成链路是：

```text
/data/ShellCrash/yamls/config.yaml    ← 你的"源"配置（生成结果也写这里）
        ↓ 启动时由 starts/clash_modify.sh 加工
/tmp/ShellCrash/config.yaml           ← 内核真正读取的运行时配置
```

**只改 `/data/ShellCrash/yamls/config.yaml`。**

### 3.3.2 添加节点

在 `proxies:` 段落下追加。三种常见自建协议的最小可用写法：

```yaml
proxies:
  # —— VLESS + REALITY ——
  - name: my-vless-reality
    type: vless
    server: node.example.com
    port: 7443
    uuid: 00000000-0000-0000-0000-000000000000
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: www.microsoft.com
    client-fingerprint: chrome
    reality-opts:
      public-key: <REALITY 公钥>
      short-id: ""

  # —— TUIC v5 ——
  - name: my-tuic
    type: tuic
    server: 203.0.113.10
    port: 443
    uuid: 00000000-0000-0000-0000-000000000000
    password: <TUIC 密码>
    congestion-controller: bbr
    udp-relay-mode: native
    sni: www.microsoft.com
    alpn: [h3, h2, http/1.1]
    udp: true
    skip-cert-verify: true

  # —— Hysteria2 ——
  - name: my-hysteria2
    type: hysteria2
    server: 203.0.113.10
    port: 8443
    password: <HY2 密码>
    sni: www.microsoft.com
    skip-cert-verify: true
    obfs: salamander
    obfs-password: <混淆密码>
```

> `skip-cert-verify: true` 只在你用的是自签证书时加；有正式证书就别加。

### 3.3.3 建一个手动选择组

只加节点还不够，要能在面板里切。在 `proxy-groups:` 段加一个 `select` 组：

```yaml
proxy-groups:
  - name: 自建节点
    type: select
    proxies:
      - my-vless-reality
      - my-tuic
      - my-hysteria2
```

再把这个组挂到主策略组 `Proxy` 的 `proxies:` 列表里（或者直接用自动测速组 `Auto`）。

### 3.3.4 让自建节点"活过"配置重新生成

**这是最容易踩的坑**：只要你再动一次订阅生成 / 换规则，`yamls/config.yaml` 会被整体重写，手写的节点和分组就没了。

ShellCrash 提供了启动前钩子，可以在每次启动时把节点重新注入：

```text
/data/ShellCrash/configs/task/bfstart    ← 启动前执行
/data/ShellCrash/configs/task/afstart    ← 启动后执行
```

把节点单独存一份（比如 `yamls/proxies.yaml`），再写一个 `bfstart` 脚本，用 `awk` 把节点和分组插进 `yamls/config.yaml`。仓库里给了一个可直接改用的模板：**[`scripts/custom-nodes-hook.sh`](../scripts/custom-nodes-hook.sh)**。

安装并生效：

```sh
# 把模板传上去
vi /data/ShellCrash/configs/task/bfstart      # 粘贴模板内容
chmod 755 /data/ShellCrash/configs/task/bfstart

# 语法检查
ash -n /data/ShellCrash/configs/task/bfstart

# 重启服务，让钩子跑一遍
/data/ShellCrash/start.sh restart

# 确认节点进去了
grep -n 'my-vless-reality' /data/ShellCrash/yamls/config.yaml
```

> 注意：钩子脚本里 `CRASHDIR` 由 ShellCrash 导出，直接用即可，不要写死成 `/data/ShellCrash`。

---

## 3.4 验证节点真的能用

### 看节点和策略组

```sh
# 所有节点数量
curl -s http://127.0.0.1:9999/proxies | tr ',' '\n' | grep -c '"type":"'

# 看某个组的候选与当前选择
curl -s http://127.0.0.1:9999/proxies/Proxy
```

URL 里有中文组名时要转义，例如"自建节点"：

```sh
curl -s "http://127.0.0.1:9999/proxies/%E8%87%AA%E5%BB%BA%E8%8A%82%E7%82%B9"
```

### 切换当前节点

```sh
curl -s -X PUT -H 'Content-Type: application/json' \
  --data '{"name":"my-hysteria2"}' \
  http://127.0.0.1:9999/proxies/Proxy
```

### 测延迟

```sh
curl -s "http://127.0.0.1:9999/proxies/my-vless-reality/delay?url=https://www.gstatic.com/generate_204&timeout=5000"
```

### 端到端实测（最关键）

```sh
# 走混合端口 7890 请求，能通 + 出口 IP 变成节点 IP，才算真的生效
curl -x http://127.0.0.1:7890 -o /dev/null -w 'http=%{http_code} time=%{time_total}\n' \
  --max-time 20 https://www.gstatic.com/generate_204

curl -x http://127.0.0.1:7890 --max-time 20 https://api.ipify.org; echo
```

本机实测成功的样子：

```text
http=204 time=0.696
198.51.100.23        ← 这是节点的出口 IP，不是你的宽带 IP
```

---

## 3.5 配置生效流程小结

```text
编辑 yamls/config.yaml / 钩子注入
        ↓
主菜单 1 启动/重启服务   （或 /data/ShellCrash/start.sh restart）
        ↓
脚本生成 /tmp/ShellCrash/config.yaml
        ↓
内核 CrashCore 读取并生效
        ↓
面板 http://192.168.31.1:9999/ui/ 看到新节点
```

改完配置**必须重启服务**才生效；只改文件不重启是没用的。

---

下一步 → [升级面板与内核](04-panel-and-core-upgrade.md)
