#!/bin/bash
# 构建可发布的 Universal .app 并打 zip / 生成校验和。
#
# 用法：Scripts/make-release.sh [版本号]
# 产物：dist/Cap-<版本>-macos-universal.zip + .sha256
#
# 发布（需要先 gh auth login）：
#   git tag -a v0.1.0 -m "Cap v0.1.0" && git push origin v0.1.0
#   gh release create v0.1.0 dist/Cap-0.1.0-macos-universal.zip \
#     --title "Cap v0.1.0" --notes-file dist/release-notes.md
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${CODE_SIGN_IDENTITY:-Cap Local Signing}"
DERIVED_DATA="$PWD/build/ReleaseDerivedData"
APP="$DERIVED_DATA/Build/Products/Release/Cap.app"
DIST="$PWD/dist"

if [[ $# -gt 0 ]]; then
  VERSION="$1"
else
  VERSION=$(grep -m1 'MARKETING_VERSION = ' Cap.xcodeproj/project.pbxproj | sed -E 's/.*= (.*);/\1/')
fi
if [[ -z "$VERSION" ]]; then
  echo "无法确定版本号，请显式传入：Scripts/make-release.sh 0.1.0" >&2
  exit 1
fi

echo "==> 构建 Cap ${VERSION}（Universal Release）"
xcodebuild -project Cap.xcodeproj -scheme Cap -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
  build

codesign --verify --deep --strict "$APP"
ARCHS=$(lipo -info "$APP/Contents/MacOS/Cap" | sed 's/.*are: //')
echo "==> 架构：$ARCHS"

mkdir -p "$DIST"
ZIP="$DIST/Cap-${VERSION}-macos-universal.zip"
DMG="$DIST/Cap-${VERSION}-macos-universal.dmg"
SHA_FILE="$DIST/Cap-${VERSION}-macos-universal.sha256"
rm -f "$ZIP" "$DMG" "$SHA_FILE" "$ZIP.sha256"

echo "==> 打包 zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> 打包 dmg（拖进 Applications 安装）"
STAGING=$(mktemp -d /tmp/cap-dmg.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Cap.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "Cap ${VERSION}" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

shasum -a 256 "$ZIP" "$DMG" | tee "$SHA_FILE"

cat > "$DIST/release-notes.md" <<NOTES
# Cap $VERSION

macOS 菜单栏截图工具（Universal：Apple Silicon + Intel，最低 macOS 15.2）。

GitHub Actions 构建产物为 ad-hoc 签名（未公证）；本机使用请按下方「安装」操作。

## 功能

- ⌘⇧2 截图 → 就地标注 → Enter 复制 / ⌘S 保存
- 滚动长截图（⌘⇧7）、OCR（历史右键识别文字）、贴图钉屏（编辑器 ⌘T）
- 自定义全局快捷键、历史窗口、上传到自填 HTTP 端点
- 界面支持简体中文 / English / 繁體中文（跟随系统语言）

## 安装

1. 解压 zip，把 \`Cap.app\` 拖进 \`/Applications\`
2. 首次打开：右键 → 打开（未公证签名，Gatekeeper 会拦截）。若提示「已损坏」：
   `xattr -dr com.apple.quarantine /Applications/Cap.app`
3. 系统设置 → 隐私与安全性 → 录屏与系统录音：勾选 Cap；滚动截图另需辅助功能权限

## 校验

\`\`\`
$(cat "$SHA_FILE")
\`\`\`

详细验收见仓库 \`.scratch/cap-v1/acceptance-v1.1.md\`。
NOTES

echo "==> 产物：$ZIP"
echo "==> 说明：dist/release-notes.md"
echo
echo "下一步："
echo "  git tag -a v$VERSION -m \"Cap v${VERSION}\" && git push origin v$VERSION"
echo "  gh release create v$VERSION \"$ZIP\" \"$DMG\" --title \"Cap v${VERSION}\" --notes-file dist/release-notes.md"
