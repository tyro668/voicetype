#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# ----------------------------------------------------------------------------
# 稳定代码签名
#   macOS 隐私权限（TCC：辅助功能 / 麦克风 / 输入监听等）以代码签名身份为索引。
#   ad-hoc 签名每次构建 cdhash 都不同，所以每次重新打包都需要再次授权。
#   这里使用一个固定身份对 .app 进行重新签名，让授权在重复打包间保留。
#
#   优先级：
#     1. 环境变量 OFFHAND_SIGN_IDENTITY（例如 Developer ID Application: ... (TEAMID)）。
#     2. 默认身份 "Offhand Local Signing"：若钥匙串里不存在，则自动生成一份
#        自签名的代码签名证书并导入登录钥匙串。
# ----------------------------------------------------------------------------
DEFAULT_SIGN_IDENTITY="Offhand Local Signing"
sign_identity="${OFFHAND_SIGN_IDENTITY:-$DEFAULT_SIGN_IDENTITY}"

ensure_self_signed_identity() {
  local cn="$1"
  if security find-identity -v -p codesigning | grep -F "\"$cn\"" >/dev/null 2>&1; then
    return 0
  fi

  echo "Code signing identity \"$cn\" not found, creating a self-signed one..."

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  local key_path="$tmp_dir/key.pem"
  local cert_path="$tmp_dir/cert.pem"
  local p12_path="$tmp_dir/cert.p12"
  local cfg_path="$tmp_dir/openssl.cnf"

  cat > "$cfg_path" <<EOF
[ req ]
distinguished_name = dn
prompt             = no
x509_extensions    = v3_ext
[ dn ]
CN = $cn
[ v3_ext ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
EOF

  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$key_path" \
    -out "$cert_path" \
    -days 3650 \
    -config "$cfg_path" >/dev/null 2>&1

  local p12_pass="offhand"
  openssl pkcs12 -export \
    -inkey "$key_path" \
    -in "$cert_path" \
    -name "$cn" \
    -out "$p12_path" \
    -passout "pass:$p12_pass" >/dev/null 2>&1

  local login_keychain
  login_keychain="$(security default-keychain | tr -d ' "')"

  # 允许 codesign / security 等工具无需密码使用该私钥
  security import "$p12_path" \
    -k "$login_keychain" \
    -P "$p12_pass" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productsign >/dev/null

  # 设为本机信任（用户域），否则 codesign 验签时会报无法构建证书链
  security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$login_keychain" \
    "$cert_path" >/dev/null 2>&1 || true

  # 放开分区列表，避免后续 codesign 弹钥匙串密码框
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "" "$login_keychain" >/dev/null 2>&1 || true

  rm -rf "$tmp_dir"

  if ! security find-identity -v -p codesigning | grep -F "\"$cn\"" >/dev/null 2>&1; then
    echo "Failed to create self-signed code signing identity \"$cn\"." >&2
    exit 1
  fi
  echo "Self-signed identity \"$cn\" created."
}

# 仅当使用默认（自签名）身份时才尝试自动创建；显式指定的身份要求已存在。
if [[ "$sign_identity" == "$DEFAULT_SIGN_IDENTITY" ]]; then
  ensure_self_signed_identity "$sign_identity"
fi

flutter build macos --release

app_path="$(find "$repo_root/build/macos/Build/Products/Release" -maxdepth 1 -name "*.app" -print -quit)"
if [[ -z "${app_path}" ]]; then
  echo "No .app found in build output." >&2
  exit 1
fi

echo "Signing app with identity: ${sign_identity}"
codesign --force --deep --options runtime \
  --sign "${sign_identity}" \
  --entitlements "$repo_root/macos/Runner/Release.entitlements" \
  "${app_path}"
codesign --verify --verbose=2 "${app_path}" || true

app_name="$(basename "$app_path" .app)"
version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
if [[ -z "${version}" ]]; then
  version="0.0.0"
fi

out_dir="$repo_root/dmg"
mkdir -p "$out_dir"

dmg_path="$out_dir/${app_name}-${version}.dmg"
rm -f "$dmg_path"

hdiutil create -volname "$app_name" -srcfolder "$app_path" -ov -format UDZO "$dmg_path"

echo "DMG created: $dmg_path"
