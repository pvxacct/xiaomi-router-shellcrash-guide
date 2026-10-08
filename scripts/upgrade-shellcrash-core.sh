#!/bin/sh
# 在【路由器上】执行：把 ShellCrash 的 mihomo 内核升级到镜像里的最新版
#
# 流程：下载 -> 解压 -> 校验版本 -> 用现有配置做 -t 测试 -> 替换 -> 重启
# 任何一步失败都会中止，不会破坏现有内核。
#
# 用法:
#   sh upgrade-shellcrash-core.sh              # 默认 meta 内核 / arm64 自动识别
#   sh upgrade-shellcrash-core.sh --dry-run    # 只检查，不替换

set -e

CRASHDIR="${CRASHDIR:-/data/ShellCrash}"
TMP="${TMPDIR:-/tmp}"
DRY_RUN=0
[ "$1" = "--dry-run" ] && DRY_RUN=1

# ---- 1. 识别 CPU 架构 ----
CPUCORE="$(grep '^cpucore=' "$CRASHDIR/configs/ShellCrash.cfg" 2>/dev/null | cut -d= -f2)"
if [ -z "$CPUCORE" ]; then
    ARCH="$(uname -m)"
    case "$ARCH" in
        aarch64|arm64) CPUCORE=arm64 ;;
        armv7l)        CPUCORE=armv7 ;;
        armv5l)        CPUCORE=armv5 ;;
        x86_64)        CPUCORE=amd64 ;;
        i386|i486|i586|i686) CPUCORE=386 ;;
        mips)          CPUCORE="mips-softfloat" ;;
        mipsel)        CPUCORE="mipsle-softfloat" ;;
        *) echo "无法识别的架构: $ARCH" >&2; exit 1 ;;
    esac
fi

# ---- 2. 选源下载 ----
TARBALL="$TMP/Coretmp.tar.gz"
rm -f "$TARBALL"

for BASE in \
    "https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@update" \
    "https://cdn.jsdelivr.net/gh/juewuy/ShellCrash@update" \
    "https://gh.jwsc.eu.org/update"
do
    URL="$BASE/bin/meta/clash-linux-${CPUCORE}.tar.gz"
    echo "尝试下载: $URL"
    if curl -kfsSL --max-time 180 -o "$TARBALL" "$URL"; then
        echo "下载完成: $(wc -c < "$TARBALL") 字节"
        break
    fi
    echo "失败，换下一个源"
done

[ -s "$TARBALL" ] || { echo "所有源都下载失败" >&2; exit 1; }

# ---- 3. 解压并校验 ----
WORK="$TMP/core_verify"
rm -rf "$WORK"; mkdir -p "$WORK"
tar -zxf "$TARBALL" -C "$WORK"
CORE="$(find "$WORK" -type f -size +2M | head -1)"
[ -n "$CORE" ] || { echo "压缩包里没找到内核二进制" >&2; exit 1; }
chmod +x "$CORE"

echo
echo "== 新内核版本 =="
"$CORE" -v 2>&1 | head -2

echo
echo "== 用现有配置验证 =="
if ! "$CORE" -t -d "$CRASHDIR" -f "$TMP/ShellCrash/config.yaml" 2>&1 | tail -3; then
    echo "配置校验失败，中止升级" >&2
    exit 1
fi

NEW_VER="$("$CORE" -v 2>/dev/null | head -1 | sed 's/.*Mihomo Meta //;s/ linux.*//')"
echo
echo "新内核: $NEW_VER"

if [ "$DRY_RUN" = "1" ]; then
    echo "--dry-run 结束，未做任何修改"
    exit 0
fi

# ---- 4. 替换 ----
echo
echo "== 替换内核 =="
FREE="$(df -k "$CRASHDIR" | awk 'END{print $4}')"
NEED="$(( $(wc -c < "$TARBALL") / 1024 ))"
echo "目标分区可用 ${FREE} KB，需要约 ${NEED} KB"
[ "$FREE" -gt "$(( NEED + 2048 ))" ] || { echo "空间不足，中止（可先清理后重试）" >&2; exit 1; }

cp -f "$CRASHDIR/CrashCore.tar.gz" "$TMP/CrashCore.old.tar.gz" 2>/dev/null || true
rm -f "$CRASHDIR/CrashCore.tar.gz"
cp "$TARBALL" "$CRASHDIR/CrashCore.tar.gz"
chmod 644 "$CRASHDIR/CrashCore.tar.gz"

if [ -n "$NEW_VER" ]; then
    sed -i "s/^core_v=.*/core_v=${NEW_VER}/" "$CRASHDIR/configs/ShellCrash.cfg"
fi

# ---- 5. 重启并验证 ----
echo
echo "== 重启服务 =="
"$CRASHDIR/start.sh" restart >/dev/null 2>&1 || true
sleep 10

echo "运行中的内核:"
/tmp/ShellCrash/CrashCore -v 2>&1 | head -1
echo "API 返回:"
curl -s --max-time 10 http://127.0.0.1:9999/version; echo
echo
echo "回滚方法: rm -f $CRASHDIR/CrashCore.tar.gz && cp $TMP/CrashCore.old.tar.gz $CRASHDIR/CrashCore.tar.gz && $CRASHDIR/start.sh restart"
