#!/usr/bin/env bash
# board.sh — 公告牌 v3 多隧道写入器（所有保活 run 共用）
# 用法: board.sh "k=v|k2=v2" "<VERSION>"
#   第一参: 本 run 负责的字段行（用 | 分隔多个 k=v），只改自己的行，保留其他隧道的行（pull/rebase 合并）
#   第二参: 版本号；留空表示不改 version 行（备用 run 传空）
set -u
KEYS="$1"
VER="${2:-}"
GH_TOKEN="${GH_TOKEN:-}"

cd /tmp/addr 2>/dev/null || { git clone "https://oauth2:${GH_TOKEN}@github.com/1759717772/dept-cloud-addr.git" /tmp/addr; cd /tmp/addr; }
git config user.email "dept-cloud@users.noreply.github.com"
git config user.name "dept-cloud-keepalive"
git pull --rebase origin main 2>/dev/null || git reset --hard origin/main 2>/dev/null || true

apply_keys() {
  printf '%s' "$1" | tr '|' '\n' | while IFS= read -r kv; do
    [ -z "$kv" ] && continue
    K="${kv%%=*}"
    V="${kv#*=}"
    if grep -q "^${K}=" addr.txt; then
      sed -i "s|^${K}=.*|${K}=${V}|" addr.txt
    else
      if grep -q '^version=' addr.txt; then
        sed -i "s|^version=|${K}=${V}\nversion=|" addr.txt
      else
        printf '%s=%s\n' "$K" "$V" >> addr.txt
      fi
    fi
  done
}

apply_keys "$KEYS"
if [ -n "$VER" ]; then
  if grep -q '^version=' addr.txt; then
    sed -i "s|^version=.*|version=${VER}|" addr.txt
  else
    printf 'version=%s\n' "$VER" >> addr.txt
  fi
fi

NOW=$(date '+%Y-%m-%d %H:%M:%S')
git add addr.txt && git commit -m "board $NOW" || true
git pull --rebase origin main 2>/dev/null || true
if git push origin main 2>/dev/null; then
  echo "公告牌推送成功: $KEYS"
  exit 0
fi

echo "公告牌推送失败，兜底重推…"
git reset --hard origin/main 2>/dev/null || true
apply_keys "$KEYS"
if [ -n "$VER" ]; then
  if grep -q '^version=' addr.txt; then
    sed -i "s|^version=.*|version=${VER}|" addr.txt
  else
    printf 'version=%s\n' "$VER" >> addr.txt
  fi
fi
git add addr.txt && git commit -m "board retry $NOW" || true
git push origin main 2>/dev/null && echo "公告牌兜底推送成功" || echo "公告牌推送失败(兜底后)，15分钟后看门狗再同步"
exit 0
