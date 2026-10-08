# 第 5 步：备份与恢复

路由器上做任何升级前，先备份。ShellCrash 的关键东西就三样：**配置、内核、面板**。`/data` 是 UBI 卷、`/tmp` 是内存盘（重启清空），所以备份要落到电脑上，不要只存在 `/tmp`。

---

## 5.1 一键打包

在路由器上执行：

```sh
tar -czf /tmp/sc-backup-$(date +%Y%m%d).tgz \
  -C /data \
  ShellCrash/configs \
  ShellCrash/yamls \
  ShellCrash/version \
  ShellCrash/servers.list \
  ShellCrash/CrashCore.tar.gz \
  ShellCrash/ui \
  ShellCrash/ruleset \
  ShellCrash/task

ls -lh /tmp/sc-backup-*.tgz
```

> `ShellCrash/CrashCore.tar.gz` 有 10～12 MB，是包里最大的部分。如果只想留配置，可以去掉这一行。

仓库里也提供了 [`scripts/backup-shellcrash.sh`](../scripts/backup-shellcrash.sh)。

---

## 5.2 下载到电脑

```sh
scp -O \
  -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  root@192.168.31.1:/tmp/sc-backup-20261008.tgz .
```

`-O` 是为了兼容老设备的 sftp-server；新版 OpenSSH 默认走 SFTP 协议，老 dropbear 可能不支持，加上 `-O` 退回旧 scp 协议即可。

如果路由器没有 `scp` 服务端，用"电脑起服务、路由器主动拉/推"的办法（仓库脚本就是这么做的）：

```sh
# 电脑上（Python 3）
python -m http.server 8899

# 路由器上（下载 = 电脑的文件推到路由器；上传 = 路由器主动 POST）
#   下载：wget -O /tmp/core.tar.gz http://<电脑IP>:8899/core.tar.gz
#   上传：curl -T /tmp/sc-backup.tgz http://<电脑IP>:8899/   （需服务端支持 PUT）
```

最简单的兜底是 **base64 走 SSH**：

```sh
# 路由器
base64 /tmp/sc-backup-20261008.tgz
# 把输出粘到本地文件再解码：
#   certutil -decode backup.b64 backup.tgz        (Windows)
#   base64 -d backup.b64 > backup.tgz             (Linux/macOS)
```

---

## 5.3 还要备份什么

| 内容 | 怎么备份 | 备注 |
| --- | --- | --- |
| 路由器整机分区 | xmir-patcher 主菜单 `4 Create full backup` | 导出到电脑 `outdir/`，恢复原厂用 |
| 启动前钩子 | 包含在上面的 `ShellCrash/configs` 里 | |
| 定时任务 | `crontab -l > /tmp/cron.bak` | ShellCrash 会写订阅更新任务 |
| 面板设置 | 面板里改过的分组/策略在 `yamls/config.yaml` 里 | |

---

## 5.4 恢复

```sh
# 1) 先停服务
/data/ShellCrash/start.sh stop

# 2) 解包覆盖（注意 -C 到 /data）
tar -zxf /tmp/sc-backup-20261008.tgz -C /data

# 3) 修权限
chmod 755 /data/ShellCrash/*.sh /data/ShellCrash/configs/task/* 2>/dev/null

# 4) 起服务
/data/ShellCrash/start.sh start
sleep 8
curl -s http://127.0.0.1:9999/version
```

如果连 ShellCrash 脚本本身都坏了：

```sh
# 重装脚本（不会删你的 configs/yamls）
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile
crash
```

---

## 5.5 恢复到原厂

xmir-patcher 备份出来的分区镜像可以用 `7 - Install firmware` 或 `install_bl.py` 之类的入口刷回去；**刷机前务必先 `4 Create full backup`，并确认自己清楚每个分区的用途**。这一步超出本教程范围，风险自负。

---

下一步 → [常见问题排查](05-troubleshooting.md)
