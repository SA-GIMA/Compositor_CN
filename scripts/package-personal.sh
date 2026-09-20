#!/bin/zsh
# 个人/内部使用的 Compositor 汉化版打包脚本。
# 不需要 Apple Developer 证书，也不做公证；产物仅供本机/受信任环境安装。
#
# 前提：
#   1. 已安装完整 Xcode（App Store 或 developer.apple.com），并执行过一次：
#        xcode-select -s /Applications/Xcode.app/Contents/Developer
#   2. 首次构建会联网拉取 Sparkle 等 Swift Package
#
# 用法（在 Compositor-main 目录）：
#   ./scripts/package-personal.sh
#
# 产物：
#   dist/Compositor-个人版.dmg
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP=Compositor
WORK="$HOME/Library/Caches/CompositorPersonalBuild"
DIST="$PROJECT_DIR/dist"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "错误：未检测到完整 Xcode（仅有 Command Line Tools 无法编译 macOS App）。"
  echo "请先安装 Xcode，然后执行："
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -license accept"
  echo "再重新运行本脚本。"
  exit 1
fi

echo "==> 清理并构建 Release（ad-hoc 签名）"
rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

# 个人使用：跳过原作者的 Developer ID / 公证，使用 ad-hoc 签名。
# 沙盒 entitlements 保留，便于与原工程行为一致。
xcodebuild build -quiet \
  -project "$PROJECT_DIR/$APP.xcodeproj" \
  -scheme "$APP" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" \
  CODE_SIGNING_ALLOWED=YES \
  ENABLE_HARDENED_RUNTIME=NO

APP_PATH=$(find "$WORK/DerivedData/Build/Products/Release" -maxdepth 1 -name "$APP.app" -print -quit)
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "错误：未找到构建产物 $APP.app"
  exit 1
fi
echo "==> 应用路径: $APP_PATH"

# Sparkle 等嵌套框架原带其他 Team ID，与 ad-hoc 主程序在 runtime 校验下不兼容。
# 个人包：由内到外全部改为 ad-hoc 签名。
echo "==> 重签嵌套组件为 ad-hoc"
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -o -name "*.xpc" -o -name "*.app" -o -name "*.dylib" 2>/dev/null | while read -r item; do
  codesign --force --sign - --timestamp=none "$item" 2>/dev/null || true
done
# framework 内部可执行文件也需重签
find "$APP_PATH/Contents/Frameworks" -type f -perm -111 2>/dev/null | while read -r bin; do
  if file "$bin" | grep -q "Mach-O"; then
    codesign --force --sign - --timestamp=none "$bin" 2>/dev/null || true
  fi
done
codesign --force --sign - --timestamp=none "$APP_PATH"

echo "==> 验证 ad-hoc 签名"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" || true
codesign -dv "$APP_PATH" 2>&1 | head -20 || true
otool -L "$APP_PATH/Contents/MacOS/$APP" 2>/dev/null | head -10 || true

echo "==> 生成 DMG"
STAGE="$WORK/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
# ditto 保留签名与资源分叉
ditto "$APP_PATH" "$STAGE/$APP.app"

DMG="$DIST/Compositor-个人版.dmg"
rm -f "$DMG"
# 读写临时镜像 → 压缩为只读 DMG
RW="$WORK/$APP-rw.dmg"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDRW "$RW"
hdiutil convert "$RW" -format UDZO -o "$DMG"
rm -f "$RW"

echo "==> 完成"
echo "DMG: $DMG"
echo "大小: $(du -h "$DMG" | awk '{print $1}')"
echo ""
echo "在新电脑上安装："
echo "  1. 把该 DMG 拷到目标 Mac（系统需 macOS 26.5+）"
echo "  2. 打开 DMG，将 Compositor.app 拖入「应用程序」"
echo "  3. 首次打开若提示无法验证开发者：在 App 上「右键 → 打开」，再点「打开」"
echo "     （或：系统设置 → 隐私与安全性 → 仍要打开）"
echo ""
echo "说明：本包为个人/内部使用，未做 Apple 公证；分发给他人可能触发更多安全提示。"
