#!/bin/sh
# 在【路由器上】执行：备份 ShellCrash 的关键文件
#
# ⚠️ 内存警告（务必先读）
#   很多小米原厂固件把 /proc/sys/vm/panic_on_oom 设成 2：
#   只要内核触发一次 OOM，就会立刻 panic 并重启路由器，而不是杀掉进程。
#   实测在 AX3000T（256MB RAM、mihomo 常驻）上，
#   直接 `tar -czf` 打包 ~20MB 的内容就可能触发 OOM → 路由器当场重启。
#
#   所以本脚本默认【只打包几百 KB 的配置】，内核与面板要显式加 --all。
#
# 用法:
#   sh backup-shellcrash.sh                    # 只备份配置（安全，推荐）
#   sh backup-shellcrash.sh --all              # 连 内核 + 面板 一起打（内存紧张时慎用）
#   sh backup-shellcrash.sh --all /userdisk    # 指定输出目录（默认 /tmp）

CRASHDIR="${CRASHDIR:-/data/ShellCrash}"

WITH_BIG=0
OUTDIR="/tmp"
for a in "$@"; do
    case "$a" in
        --all) WITH_BIG=1 ;;
        *)     OUTDIR="$a" ;;
    esac
done

[ -d "$CRASHDIR" ] || { echo "找不到 $CRASHDIR，ShellCrash 装了吗？" >&2; exit 1; }
mkdir -p "$OUTDIR" || { echo "无法写入 $OUTDIR" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M)"

echo "== 设备状态 =="
echo "panic_on_oom = $(cat /proc/sys/vm/panic_on_oom 2>/dev/null)"
echo "空闲内存     = $(free -m 2>/dev/null | awk '/^Mem:/{print $4" MB"}')"
echo "目标分区可用 = $(df -k "$OUTDIR" | tail -1 | awk '{print $4" KB"}')"
echo

echo "== 版本信息 =="
cat "$CRASHDIR/version" 2>/dev/null | sed 's/^/ShellCrash: /'
/tmp/ShellCrash/CrashCore -v 2>/dev/null | head -1
grep -E '^(crashcore|core_v|cpucore)=' "$CRASHDIR/configs/ShellCrash.cfg" 2>/dev/null

# ---------- 1) 小文件：安全 ----------
SMALL=""
for p in configs yamls version servers.list task ruleset; do
    [ -e "$CRASHDIR/$p" ] && SMALL="$SMALL ShellCrash/$p"
done

SMALL_OUT="${OUTDIR}/sc-config-${STAMP}.tgz"
echo
echo "== 打包配置（小文件）=="
# shellcheck disable=SC2086
tar -czf "$SMALL_OUT" -C "$(dirname "$CRASHDIR")" $SMALL
ls -lh "$SMALL_OUT"

# ---------- 2) 大文件：可选 ----------
if [ "$WITH_BIG" = "1" ]; then
    BIG=""
    for p in CrashCore.tar.gz ui; do
        [ -e "$CRASHDIR/$p" ] && BIG="$BIG ShellCrash/$p"
    done

    FREE_KB="$(df -k "$OUTDIR" | tail -1 | awk '{print $4}')"
    echo
    echo "== 打包内核与面板（约 17MB，注意内存）=="
    if [ "$FREE_KB" -lt 25600 ]; then
        echo "空间不足（可用 ${FREE_KB} KB < 25 MB），跳过 --all" >&2
    else
        # 顺序读，tar 不缓存到内存；gzip 用 -1 降低瞬时压力
        # shellcheck disable=SC2086
        tar -czf "${OUTDIR}/sc-big-${STAMP}.tgz" -C "$(dirname "$CRASHDIR")" $BIG
        ls -lh "${OUTDIR}/sc-big-${STAMP}.tgz"
    fi
fi

echo
echo "== 拉取到电脑 =="
echo "  scp -O -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \\"
echo "      root@192.168.31.1:$SMALL_OUT ."
[ "$WITH_BIG" = "1" ] && echo "      root@192.168.31.1:${OUTDIR}/sc-big-${STAMP}.tgz ."
echo
echo "提示：/tmp 是内存盘，重启即丢，备份完请尽快拉走。"
