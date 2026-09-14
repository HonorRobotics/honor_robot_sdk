#!/usr/bin/env bash
# 第一步:同步公共代码, 第二步:提交并推送代码到 Gerrit
set -euo pipefail

cd "$(dirname "$0")"

echo "=== [1/3] 同步公共代码: python3 scripts/sync_common.py ==="
before_sync="$(git status --porcelain)"
python3 scripts/sync_common.py
after_sync="$(git status --porcelain)"

# 第一步没有产生任何更新时,直接返回,不报错
if [ "$before_sync" = "$after_sync" ]; then
    echo "=== 第一步未产生更新,无需提交,直接返回 ==="
    exit 0
fi

echo "=== [2/3] 提交代码: git add . && git commit ==="
git add .
git commit -m "TicketNo: AR10BPF4E
Description: update sdk msg

Team: TOOLS
Feature or Bugfix: Feature
Binary Source:
PrivateCode(Yes/No): NO"

echo "=== [3/3] 推送代码: git push origin HEAD:refs/for/honor_release_system_omega1.0_0904 ==="
git push origin HEAD:refs/for/honor_release_system_omega1.0_0904

echo "=== 完成 ==="
