#!/usr/bin/env bash
# board.sh — 公告牌 v3 多隧道写入器（所有保活 run 共用）
# 用法: board.sh "k=v|k2=v2" "<VERSION>"
#   第一参: 本 run 负责的字段行（用 | 分隔多个 k=v），只改自己的行，保留其他隧道的行
#   第二参: 版本号；留空表示不改 version 行（备用 run 传空）
# 并发安全：每次以 origin/main 最新为基线（fetch+reset），只写自己的行后 push，
#          失败自动 fetch 重试（最多 3 次），不覆盖其他 run 写入的行。
set -u
KEYS="$1"
VER="${2:-}"
GH_TOKEN="${GH_TOKEN:-}"

cd /tmp/addr 2>/dev/null || { git clone "https://oauth2:${GH_TOKEN}@github.com/1759717772/dept-cloud-addr.git" /tmp/addr; cd /tmp/addr; }
git config user.email "dept-cloud@users.noreply.github.com"
git config user.name "dept-cloud-keepalive"

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

apply_ver() {
  if [ -n "$VER" ]; then
    if grep -q '^version=' addr.txt; then
      sed -i "s|^version=.*|version=${VER}|" addr.txt
    else
      printf 'version=%s\n' "$VER" >> addr.txt
    fi
  fi
}

# 以最新 origin 为基线（防过期引用覆盖他人行）
sync_base() {
  git fetch origin 2>/dev/null || true
  git reset --hard origin/main 2>/dev/null || git reset --hard HEAD 2>/dev/null || true
}

push_once() {
  NOW=$(date '+%Y-%m-%d %H:%M:%S')
  git add addr.txt
  git commit -m "board $NOW" >/dev/null 2>&1 || true
  git push origin main 2>/dev/null
}

ok=0
for attempt in 1 2 3; do
  sync_base
  apply_keys "$KEYS"
  apply_ver
  if push_once; then
    echo "公告牌推送成功: $KEYS (attempt=$attempt)"
    ok=1
    break
  fi
  echo "公告牌推送失败(attempt=$attempt)，fetch 最新后重试…"
  sleep $((attempt * 3))
done
if [ "$ok" -ne 1 ]; then
  echo "公告牌推送失败(3次重试后)，15分钟后看门狗兜底同步"
fi
exit 0
