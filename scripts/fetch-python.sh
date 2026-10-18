#!/bin/bash
# 下载并裁剪 python-build-standalone（arm64），供打包内置运行时使用。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${ROOST_VENDOR:-$HOME/Library/Application Support/roost/vendor}/python-arm64"
PY_VERSION="3.12.15"
BUILD_TAG="20261013"
URL="https://github.com/astral-sh/python-build-standalone/releases/download/${BUILD_TAG}/cpython-${PY_VERSION}%2B${BUILD_TAG}-aarch64-apple-darwin-install_only.tar.gz"

if [ -x "$DEST/bin/python3" ]; then
  echo "✓ 已存在 $DEST"
  exit 0
fi

echo "▸ 下载 CPython $PY_VERSION (arm64)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/py.tar.gz"
tar xzf "$TMP/py.tar.gz" -C "$TMP"

echo "▸ 裁剪运行时"
rm -rf "$TMP/python"/{include,share} \
       "$TMP/python/lib/python3.12"/{test,idlelib,tkinter,turtledemo,ensurepip,lib2to3,venv,site-packages,config-3.12-darwin} \
       "$TMP/python/bin"/{pip,pip3,pip3.12,2to3,2to3-3.12,idle3,idle3.12,pydoc3,pydoc3.12,python3-config,python3.12-config} 2>/dev/null || true
find "$TMP/python/lib/python3.12" -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
# 静态链接，动态库不需要（删掉省 18 MB）
rm -f "$TMP/python/lib/libpython3.12.dylib"

mkdir -p "$(dirname "$DEST")"
mv "$TMP/python" "$DEST"
du -sh "$DEST"
"$DEST/bin/python3" -c "import json,urllib.request,http.server,plistlib,hashlib;print('runtime ok')"
