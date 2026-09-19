#!/usr/bin/env bash
# 把 Tauri 直出的 liveagent 二进制打包成 Arch Linux 原生 tar.gz。
#
# 用法: package-linux-arch-tarball.sh [binary] [output-tarball]
#   binary  缺省时按 verify-linux-glibc-baseline.sh 同款候选路径自动查找
#   output  缺省为 dist/LiveAgent-<tag|dev>-Linux-x86_64-Arch.tar.gz
#
# 说明:
# - 包内是原生二进制 + .desktop + hicolor 图标 + 安装说明，走系统
#   WebKitGTK/输入法模块，这正是 AppImage 难修 IME bug 而原生包不需要修的原因。
# - 不签名、不进 updater manifest（create-tauri-updater-manifest.mjs 会忽略
#   未知目标），用户靠 GitHub Releases 手动更新。
# - Arch 是滚动系，glibc 远新于 2.35，此包不跑 glibc 基线检查，仅面向 Arch 类发行版。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ICON_DIR="$REPO_ROOT/crates/agent-gui/src-tauri/icons"

fail() {
  echo "package-linux-arch-tarball: $*" >&2
  exit 1
}

find_binary() {
  for candidate in \
    "crates/agent-gui/src-tauri/target/x86_64-unknown-linux-gnu/release/liveagent" \
    "target/x86_64-unknown-linux-gnu/release/liveagent" \
    "crates/agent-gui/src-tauri/target/release/liveagent" \
    "target/release/liveagent"; do
    if [ -x "$REPO_ROOT/$candidate" ]; then
      echo "$REPO_ROOT/$candidate"
      return 0
    fi
  done
  return 1
}

binary="${1:-$(find_binary || fail "no liveagent release binary found (build it first or pass a path)")}"
tag="${LIVEAGENT_RELEASE_TAG:-${RELEASE_TAG:-dev}}"
output="${2:-$REPO_ROOT/dist/LiveAgent-${tag}-Linux-x86_64-Arch.tar.gz}"

test -x "$binary" || fail "binary not found or not executable: $binary"
for icon in 32x32.png 128x128.png icon.png; do
  test -f "$ICON_DIR/$icon" || fail "icon missing: $ICON_DIR/$icon"
done

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
stage="$work/liveagent"
mkdir -p \
  "$stage/icons/hicolor/32x32/apps" \
  "$stage/icons/hicolor/128x128/apps" \
  "$stage/icons/hicolor/512x512/apps"

cp "$binary" "$stage/liveagent"
chmod +x "$stage/liveagent"
cp "$ICON_DIR/32x32.png" "$stage/icons/hicolor/32x32/apps/liveagent.png"
cp "$ICON_DIR/128x128.png" "$stage/icons/hicolor/128x128/apps/liveagent.png"
cp "$ICON_DIR/icon.png" "$stage/icons/hicolor/512x512/apps/liveagent.png"

cat > "$stage/liveagent.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LiveAgent
Comment=Your Local-First AI Agent Desktop
Exec=liveagent
Icon=liveagent
Terminal=false
Categories=Utility;Development;
StartupWMClass=liveagent
EOF

cat > "$stage/README-ArchLinux.txt" <<EOF
LiveAgent ${tag} - Arch Linux 原生包(非 AppImage)

原生构建直接链接系统 WebKitGTK 与输入法模块,因此 fcitx/ibus 等输入法
开箱即用,不存在 AppImage 自带库与系统 IME 冲突的问题。

1. 安装系统依赖:
     sudo pacman -S webkit2gtk-4.1 gtk3 libayatana-appindicator librsvg
2. 安装(任选其一):
     个人:  cp liveagent ~/.local/bin/ ; cp liveagent.desktop ~/.local/share/applications/
            cp -r icons/hicolor/* ~/.local/share/icons/hicolor/
     全系统: sudo cp liveagent /usr/local/bin/ ; sudo cp liveagent.desktop /usr/share/applications/
            sudo cp -r icons/hicolor/* /usr/share/icons/hicolor/
3. 从应用菜单启动 LiveAgent,或终端直接运行 liveagent。

更新:此包不参与内置自动更新,每次发版到 GitHub Releases 手动下载新包覆盖即可。
EOF

mkdir -p "$(dirname "$output")"
tar -czf "$output" -C "$work" liveagent
echo "Arch tarball ready: $output"
