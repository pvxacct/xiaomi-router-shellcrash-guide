#!/bin/sh
# 在【路由器上】执行：打包 ShellCrash 的关键文件
#
# 用法:
#   sh backup-shellcrash.sh            # 打到 /tmp
#   sh backup-shellcrash.sh /userdisk  # 指定输出目录
#
# 打完记得用 scp / wget 把它拉到电脑上，/tmp 是内存盘，重启就没了。

CRASHDIR="${CRASHDIR:-/data/ShellCrash}"
OUTDIR="${1:-/tmp}"
STAMP="$(date +%Y%m%d-%H%M)"
OUT="${OUTDIR}/sc-backup-${STAMP}.tgz"

if [ ! -d "$CRASHDIR" ]; then
    echo "找不到 $CRASHDIR，ShellCrash 装了吗？" >&2
    exit 1
fi

echo "== 备份前状态 =="
cat "$CRASHDIR/version" 2>/dev/null | sed 's/^/ShellCrash 版本: /'
"$CRASHDIR"/start.sh 2>/dev/null >/dev/null
[ -x /tmp/ShellCrash/CrashCore ] && /tmp/ShellCrash/CrashCore -v 2>/dev/null | head -1
grep -E '^(crashcore|core_v|cpucore)=' "$CRASHDIR/configs/ShellCrash.cfg" 2>/dev/null

FILES=""
for p in configs yamls version servers.list CrashCore.tar.gz ui ruleset task; do
    [ -e "$CRASHDIR/$p" ] && FILES="$FILES ShellCrash/$p"
done

echo
echo "== 打包 =="
# shellcheck disable=SC2086
tar -czf "$OUT" -C "$(dirname "$CRASHDIR")" $FILES

echo "完成: $OUT"
ls -lh "$OUT"
echo
echo "拉到电脑:"
echo "  scp -O -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \\"
echo "      root@\$(nvram get lan_ipaddr 2>/dev/null || echo 192.168.31.1):$OUT ."
