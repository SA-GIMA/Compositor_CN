#!/bin/zsh
# 从上游最新 release 同步汉化源码 → 构建 DMG → 推送 SA-GIMA/Compositor_CN → 创建同版本号 Release。
# 用法：./scripts/sync-upstream.sh [tag]
# 不带参数时自动取 robbietilton/Compositor 的 latest release。
set -euo pipefail

DEST="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(dirname "$DEST")"
UP_REPO="robbietilton/Compositor"
MY_REPO="SA-GIMA/Compositor_CN"
UP_TAG="${1:-}"

if [[ -z "$UP_TAG" ]]; then
  UP_TAG=$(gh api "repos/$UP_REPO/releases/latest" --jq .tag_name)
fi
UP_VERSION="${UP_TAG#v}"
echo "==> 上游版本: $UP_TAG ($UP_VERSION)"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "错误：需要完整 Xcode。请先安装并执行 sudo xcodebuild -license accept"
  exit 1
fi

mkdir -p "$WORK/upstream"
ZIP="$WORK/upstream/Compositor-$UP_TAG.zip"
if [[ ! -f "$ZIP" ]]; then
  echo "==> 下载上游源码"
  curl -L --fail --connect-timeout 20 --max-time 180 \
    -o "$ZIP" \
    "https://codeload.github.com/$UP_REPO/zip/refs/tags/$UP_TAG" \
    || curl -L --fail --connect-timeout 20 --max-time 180 \
      -o "$ZIP" \
      "https://codeload.github.com/$UP_REPO/zip/refs/heads/main"
fi
rm -rf "$WORK/upstream/Compositor-$UP_VERSION" "$WORK/upstream/Compositor-main"
unzip -q -o "$ZIP" -d "$WORK/upstream"
SRC=""
for cand in "$WORK/upstream/Compositor-$UP_VERSION" "$WORK/upstream/Compositor-main"; do
  [[ -d "$cand" && -f "$cand/Compositor.xcodeproj/project.pbxproj" ]] && SRC="$cand" && break
done
[[ -n "$SRC" ]] || { echo "错误：未找到上游源码目录"; exit 1; }
echo "==> 上游源码: $SRC"

echo "==> 同步源码到 $DEST（保留 .git / dist / .mimocode / scripts/l10n）"
rsync -a --delete \
  --exclude '.git' --exclude 'dist' --exclude '.mimocode' \
  --exclude 'scripts/l10n' --exclude 'scripts/package-personal.sh' \
  "$SRC/" "$DEST/"
# 确保个人打包与汉化工具仍在
[[ -f "$DEST/scripts/package-personal.sh" ]] || cp -n "$WORK/Compositor_CN/scripts/package-personal.sh" "$DEST/scripts/" 2>/dev/null || true
[[ -d "$DEST/scripts/l10n" ]] || { echo "错误：缺少 scripts/l10n；请保留汉化工具后再同步"; exit 1; }

PY="${MIMO_PYTHON:-python3}"
echo "==> 应用汉化"
"$PY" "$DEST/scripts/l10n/apply_l10n.py" --root "$DEST" --map "$DEST/scripts/l10n/l10n-map.json"

echo "==> 构建个人版 DMG"
cd "$DEST"
./scripts/package-personal.sh

ASSET="$DEST/dist/Compositor-CN-$UP_VERSION.dmg"
cp -f "$DEST/dist/Compositor-个人版.dmg" "$ASSET"

echo "==> 提交并推送源码"
cd "$DEST"
git add .
if ! git diff --cached --quiet; then
  git commit -m "同步上游 $UP_TAG 并更新中文汉化"
fi
git push -u origin main

echo "==> 创建/更新 Release $UP_TAG（与上游版本号一致）"
NOTES="同步自 https://github.com/$UP_REPO/releases/tag/$UP_TAG

- 界面已汉化；版本号与上游一致：$UP_VERSION
- 安装包 ad-hoc 签名、未 Apple 公证
- 系统要求：macOS 26.5+
- 首次打开：右键 App → 打开
- 附件：Compositor-CN-$UP_VERSION.dmg"

if gh release view "$UP_TAG" --repo "$MY_REPO" >/dev/null 2>&1; then
  gh release upload "$UP_TAG" --repo "$MY_REPO" --clobber "$ASSET"
  gh release edit "$UP_TAG" --repo "$MY_REPO" \
    --title "Compositor 中文汉化版 $UP_VERSION" \
    --notes "$NOTES"
else
  gh release create "$UP_TAG" --repo "$MY_REPO" \
    --title "Compositor 中文汉化版 $UP_VERSION" \
    --notes "$NOTES" \
    "$ASSET"
fi

echo "==> 完成"
echo "Release: https://github.com/$MY_REPO/releases/tag/$UP_TAG"
echo "下载:    https://github.com/$MY_REPO/releases/download/$UP_TAG/Compositor-CN-$UP_VERSION.dmg"
