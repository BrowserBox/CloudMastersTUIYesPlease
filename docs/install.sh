#!/usr/bin/env bash
set -euo pipefail

# CloudMasters Installer
# Installs cloudmasters-cli binary and cloudmasters wrapper that handles auto-updates
# Pattern: cloudmasters (wrapper) -> cloudmasters-cli (binary)

GITHUB_REPO="${CLOUDMASTERS_REPO:-BrowserBox/CloudMasters-Marketplace}"
GITHUB_TOKEN="${CLOUDMASTERS_GITHUB_TOKEN:-}"
RELEASE_TAG="${CLOUDMASTERS_RELEASE_TAG:-latest}"
INSTALL_DIR="${CLOUDMASTERS_INSTALL_DIR:-/usr/local/bin}"

os_name="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch_name="$(uname -m | tr '[:upper:]' '[:lower:]')"

case "$os_name" in
  darwin) os="macos" ;;
  linux) os="linux" ;;
  msys*|mingw*|cygwin*|windows_nt)
    echo "Windows detected. Use: irm cloudmasters.browserbox.io/install.ps1 | iex" >&2
    exit 1
    ;;
  *) echo "Unsupported OS: $os_name" >&2; exit 1 ;;
esac

case "$arch_name" in
  arm64|aarch64) arch="arm64" ;;
  x86_64|amd64) arch="amd64" ;;
  *) echo "Unsupported architecture: $arch_name" >&2; exit 1 ;;
esac

# Build asset name
if [[ "$os" == "macos" ]]; then
  asset="cloudmasters_darwin_${arch}.pkg"
elif [[ "$os" == "linux" ]]; then
  if [[ "$arch" != "amd64" ]]; then
    echo "Linux build is currently only available for amd64/x86_64 (got: $arch)." >&2
    exit 1
  fi
  asset="cloudmasters-cli_linux_amd64"
else
  echo "Unsupported platform: $os $arch" >&2
  exit 1
fi

can_sudo() {
  command -v sudo >/dev/null 2>&1 && [[ -t 0 ]]
}

safe_rm() {
  local p="$1"
  if [[ -e "$p" || -L "$p" ]]; then
    rm -f "$p" 2>/dev/null || { can_sudo && sudo rm -f "$p" 2>/dev/null; } || true
  fi
}

# Clean old installs
safe_rm "$INSTALL_DIR/cloudmasters"
safe_rm "$INSTALL_DIR/cloudmasters-cli"

# Build download URL
if [[ "$RELEASE_TAG" == "latest" ]]; then
  url="https://github.com/${GITHUB_REPO}/releases/latest/download/${asset}"
else
  url="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${asset}"
fi

# Spinner
spin() {
  local chars='/-\|'
  local i=0
  local pid=$1
  while kill -0 "$pid" 2>/dev/null; do
    printf "\rInstalling %s " "${chars:i++%4:1}"
    sleep 0.1
  done
  printf "\r"
}

printf "Installing / "

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_FILE="$TMP_DIR/$asset"

# Download with token if provided
curl_opts=(-fsSL)
if [[ -n "$GITHUB_TOKEN" ]]; then
  release_json=""
  if [[ "$RELEASE_TAG" == "latest" ]]; then
    release_json=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null || echo "")
  else
    release_json=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${RELEASE_TAG}" 2>/dev/null || echo "")
  fi
  
  if [[ -z "$release_json" || "$release_json" == *'"message":'* ]]; then
    echo "Could not find release ${RELEASE_TAG}" >&2
    exit 1
  fi
  
  if command -v jq >/dev/null 2>&1; then
    asset_api_url=$(echo "$release_json" | jq -r ".assets[] | select(.name == \"${asset}\") | .url" | head -1)
  else
    asset_api_url=$(echo "$release_json" | grep -o "\"url\":[ ]*\"https://api.github.com/repos/${GITHUB_REPO}/releases/assets/[0-9]*\"[^}]*\"name\":[ ]*\"${asset}\"" | grep -o "https://api.github.com/[^\"]*" | head -1)
  fi
  
  if [[ -z "$asset_api_url" ]]; then
    echo "Could not find asset $asset in release ${RELEASE_TAG}" >&2
    exit 1
  fi
  
  url="$asset_api_url"
  curl_opts+=(-H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/octet-stream")
fi

# Download
(curl "${curl_opts[@]}" "$url" -o "$TMP_FILE" 2>/dev/null) &
download_pid=$!
spin $download_pid
wait $download_pid || { echo "Download failed." >&2; exit 1; }

# Determine if we need sudo for INSTALL_DIR
use_sudo=""
if [[ ! -w "$INSTALL_DIR" ]]; then
  if can_sudo; then
    use_sudo="sudo"
  else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
  fi
fi

# Install binary as cloudmasters-cli
if [[ "$os" == "macos" ]]; then
  echo "Running installer (requires admin)..."
  
  if [[ "$(id -u)" -eq 0 ]]; then
    installer -pkg "$TMP_FILE" -target /
  elif can_sudo; then
    sudo installer -pkg "$TMP_FILE" -target /
  else
    echo "Can't run sudo installer non-interactively; opening the pkg installer UI..." >&2
    open "$TMP_FILE"
    echo "After install completes, run: cloudmasters" >&2
    exit 0
  fi
  
  if [[ ! -x "/usr/local/bin/cloudmasters-cli" ]]; then
    echo "Install failed: /usr/local/bin/cloudmasters-cli not found." >&2
    exit 1
  fi
  INSTALL_DIR="/usr/local/bin"
else
  # Linux: install binary directly as cloudmasters-cli
  chmod +x "$TMP_FILE"
  if [[ -n "$use_sudo" ]]; then
    $use_sudo mv "$TMP_FILE" "$INSTALL_DIR/cloudmasters-cli"
  else
    mv "$TMP_FILE" "$INSTALL_DIR/cloudmasters-cli"
  fi
fi

# Create launcher wrapper script
launcher_script='#!/usr/bin/env bash
# CloudMasters Launcher - checks for updates and runs cloudmasters-cli

GITHUB_REPO="BrowserBox/CloudMasters-Marketplace"
CACHE_FILE="$HOME/.cloudmasters/.version-cache"
CACHE_TTL=10800  # 3 hours

# Find the binary
if [[ -x "/usr/local/bin/cloudmasters-cli" ]]; then
  binary="/usr/local/bin/cloudmasters-cli"
elif [[ -x "$HOME/.local/bin/cloudmasters-cli" ]]; then
  binary="$HOME/.local/bin/cloudmasters-cli"
else
  echo "Error: cloudmasters-cli not found. Please reinstall." >&2
  exit 1
fi

os_name="$(uname -s | tr '\''[:upper:]'\'' '\''[:lower:]'\'')"
arch_name="$(uname -m | tr '\''[:upper:]'\'' '\''[:lower:]'\'')"

case "$os_name" in
  darwin) os="macos" ;;
  linux) os="linux" ;;
  *) os="unknown" ;;
esac

case "$arch_name" in
  arm64|aarch64) arch="arm64" ;;
  x86_64|amd64) arch="amd64" ;;
  *) arch="unknown" ;;
esac

if [[ "$os" == "macos" ]]; then
  asset="cloudmasters_darwin_${arch}.pkg"
else
  asset="cloudmasters-cli_linux_amd64"
fi

get_current_version() {
  "$binary" --version 2>/dev/null | grep -oE '\''v?[0-9]+\.[0-9]+\.[0-9]+'\'' | head -1 || echo ""
}

get_latest_version() {
  if [[ -f "$CACHE_FILE" ]]; then
    cache_age=$(($(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [[ $cache_age -lt $CACHE_TTL ]]; then
      cat "$CACHE_FILE"
      return
    fi
  fi
  
  latest=$(curl -fsSL --max-time 5 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null | grep -o '\''"tag_name":[ ]*"[^"]*"'\'' | head -1 | grep -o '\''v[0-9.]*'\'')
  
  if [[ -n "$latest" ]]; then
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "$latest" > "$CACHE_FILE"
    echo "$latest"
  fi
}

do_update() {
  local version="$1"
  local url="https://github.com/$GITHUB_REPO/releases/download/$version/$asset"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local tmp_file="$tmp_dir/$asset"
  
  echo "Updating CloudMasters to $version..." >&2
  if ! curl -fsSL "$url" -o "$tmp_file" 2>/dev/null; then
    rm -rf "$tmp_dir"
    echo "Update failed, using existing version." >&2
    return 1
  fi
  
  if [[ "$os" == "macos" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      rm -f /usr/local/bin/cloudmasters-cli
      installer -pkg "$tmp_file" -target /
    elif command -v sudo >/dev/null 2>&1 && [[ -t 0 ]]; then
      sudo rm -f /usr/local/bin/cloudmasters-cli
      sudo installer -pkg "$tmp_file" -target /
    else
      echo "Cannot update non-interactively (no sudo). Run manually to update." >&2
      rm -rf "$tmp_dir"
      return 1
    fi
  else
    chmod +x "$tmp_file"
    local bin_dir
    bin_dir="$(dirname "$binary")"
    if [[ -w "$bin_dir" ]]; then
      mv "$tmp_file" "$binary"
    elif command -v sudo >/dev/null 2>&1 && [[ -t 0 ]]; then
      sudo mv "$tmp_file" "$binary"
    else
      echo "Cannot update: no write permission. Run with sudo to update." >&2
      rm -rf "$tmp_dir"
      return 1
    fi
  fi
  
  rm -rf "$tmp_dir"
  echo "Updated to $version" >&2
}

# Check for updates
current=$(get_current_version)
current_normalized="${current#v}"
latest=$(get_latest_version)
latest_normalized="${latest#v}"

if [[ -n "$latest" && -n "$current" && "$latest_normalized" != "$current_normalized" ]]; then
  do_update "$latest" || true
fi

exec "$binary" "$@"
'

# Install wrapper as cloudmasters
wrapper_target="$INSTALL_DIR/cloudmasters"
if [[ -n "$use_sudo" ]]; then
  echo "$launcher_script" | $use_sudo tee "$wrapper_target" > /dev/null
  $use_sudo chmod +x "$wrapper_target"
else
  echo "$launcher_script" > "$wrapper_target"
  chmod +x "$wrapper_target"
fi

# Check PATH
path_ok=false
case ":$PATH:" in
  *":$INSTALL_DIR:"*) path_ok=true ;;
esac

echo ""
echo "Installed:"
echo "  Binary:  $INSTALL_DIR/cloudmasters-cli"
echo "  Wrapper: $INSTALL_DIR/cloudmasters (auto-updates)"
echo ""

if [[ "$path_ok" != "true" ]]; then
  shell_name=$(basename "$SHELL")
  case "$shell_name" in
    zsh)
      echo "Add to PATH:"
      echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
      ;;
    bash)
      profile="$HOME/.bashrc"
      [[ -f "$HOME/.bash_profile" ]] && profile="$HOME/.bash_profile"
      echo "Add to PATH:"
      echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> $profile && source $profile"
      ;;
    *)
      echo "Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac
  echo ""
fi

echo "Run: cloudmasters"
