#!/bin/ash
# ShellCrash 启动前钩子：每次启动都把自建节点和「自建节点」选择组注入配置
#
# 安装位置: /data/ShellCrash/configs/task/bfstart
# 生效方式: /data/ShellCrash/start.sh restart
#
# 作用: ShellCrash 重新生成 yamls/config.yaml 时会覆盖手写的节点，
#       这个钩子在每次启动前把它们补回去。
#
# 使用前请把下面的节点名改成你自己的（和 yamls/config.yaml 里 proxies 的 name 一致）。

CFG="$CRASHDIR"/yamls/config.yaml
GRP="自建节点"
N1="my-vless-reality"
N2="my-tuic"
N3="my-hysteria2"

[ -f "$CFG" ] || exit 0

# 主策略组里是否已经引用了这个组
has_ref=$(grep -c "^      - $GRP$" "$CFG")

awk -v has_ref="$has_ref" -v grp="$GRP" -v n1="$N1" -v n2="$N2" -v n3="$N3" '
  function emit_group() {
    print "  - "
    print "    name: " grp
    print "    type: select"
    print "    proxies:"
    print "      - " n1
    print "      - " n2
    print "      - " n3
  }
  {
    line = $0
    if (line ~ /^proxy-groups:[ \t]*$/) {
      print
      emit_group()
      inpg = 1; cur = ""; plist = 0; hold = 0; pend = ""; skip = 0
      next
    }
    if (skip) {
      if (line ~ /^  -/ || line ~ /^[^ ]/) { skip = 0 } else { next }
    }
    if (inpg && line ~ /^[^ ]/) { inpg = 0; plist = 0 }
    if (inpg && line ~ /^  -[ \t]*$/) { pend = line; hold = 1; next }
    if (inpg && line ~ /^  - name: /) {
      cur = substr(line, 11)
      if (cur == grp) { hold = 0; skip = 1; next }
      if (hold) { print pend; hold = 0 }
      print; next
    }
    if (inpg && line ~ /^    name: /) {
      cur = substr(line, 11)
      if (cur == grp) { hold = 0; skip = 1; next }
      if (hold) { print pend; hold = 0 }
      print; next
    }
    if (inpg && line ~ /^    proxies:[ \t]*$/) {
      if (hold) { print pend; hold = 0 }
      plist = 1; print; next
    }
    if (plist && line ~ /^      - /) {
      if (hold) { print pend; hold = 0 }
      if ((cur == "Proxy" || cur == "Auto") && line ~ ("^      - (" n1 "|" n2 "|" n3 ")[ \t]*$")) next
      print; next
    }
    if (plist) {
      if (hold) { print pend; hold = 0 }
      if (cur == "Proxy" && has_ref + 0 == 0) print "      - " grp
      plist = 0; print; next
    }
    if (hold) { print pend; hold = 0 }
    print
  }
  END { if (plist && cur == "Proxy" && has_ref + 0 == 0) print "      - " grp }
' "$CFG" > "$CFG.new"

# 只有结构完整时才替换，避免把配置写坏
if grep -q "^proxy-groups:" "$CFG.new" && \
   grep -q "^rules:" "$CFG.new" && \
   grep -q "^    name: Proxy$" "$CFG.new" && \
   [ "$(wc -c < "$CFG.new")" -gt 1000 ]; then
    cp -f "$CFG" "$CFG.bak"
    mv -f "$CFG.new" "$CFG"
else
    rm -f "$CFG.new"
fi
