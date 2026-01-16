#!/usr/bin/env bash
set -euo pipefail

# CloudMasters Installer
# Downloads the binary to ~/.cloudmasters/bin and installs a launcher wrapper to PATH
# The wrapper handles auto-updates on each run

GITHUB_REPO="${CLOUDMASTERS_REPO:-BrowserBox/CloudMasters-Marketplace}"
GITHUB_TOKEN="${CLOUDMASTERS_GITHUB_TOKEN:-}"
RELEASE_TAG="${CLOUDMASTERS_RELEASE_TAG:-latest}"
INSTALL_DIR="${CLOUDMASTERS_INSTALL_DIR:-/usr/local/bin}"
BINARY_DIR="${CLOUDMASTERS_BINARY_DIR:-$HOME/.cloudmasters/bin}"
FORCE_INSTALL="${CLOUDMASTERS_INSTALL_FORCE:-}"

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
  asset="cloudmasters_linux_amd64"
else
  echo "Unsupported platform: $os $arch" >&2
  exit 1
fi

# Create binary directory
mkdir -p "$BINARY_DIR"

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
  # For private repos, use API to find asset URL
  release_json=""
  if [[ "$RELEASE_TAG" == "latest" ]]; then
    release_json=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null || echo "")
  else
    release_json=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${RELEASE_TAG}" 2>/dev/null || echo "")
    
    if [[ -z "$release_json" || "$release_json" == *'"message":'* ]]; then
      all_releases=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=30" 2>/dev/null || echo "[]")
      
      if command -v jq >/dev/null 2>&1; then
        release_id=$(echo "$all_releases" | jq -r ".[] | select(.tag_name == \"${RELEASE_TAG}\") | .id" | head -1)
      else
        release_id=$(echo "$all_releases" | grep -B20 "\"tag_name\":[ ]*\"${RELEASE_TAG}\"" | grep -o '"id":[ ]*[0-9]*' | head -1 | grep -o '[0-9]*')
      fi
      
      if [[ -n "$release_id" ]]; then
        release_json=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/repos/${GITHUB_REPO}/releases/${release_id}" 2>/dev/null || echo "")
      fi
    fi
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
  curl_opts+=(-H "Authorization: token $GITHUB_TOKEN")
  curl_opts+=(-H "Accept: application/octet-stream")
fi

# Download
(curl "${curl_opts[@]}" "$url" -o "$TMP_FILE" 2>/dev/null) &
download_pid=$!
spin $download_pid
wait $download_pid || {
  echo "Download failed." >&2
  exit 1
}

chmod +x "$TMP_FILE"

# Move binary to binary directory
binary_target="$BINARY_DIR/cloudmasters"
if [[ "$os" == "macos" ]]; then
  # For macOS pkg, we install it properly
  echo "Running installer (requires sudo)..."
  sudo installer -pkg "$TMP_FILE" -target /
  # The pkg installs to /usr/local/bin/cloudmasters, so we symlink or just use it
  if [[ -f "/usr/local/bin/cloudmasters" ]]; then
    ln -sf "/usr/local/bin/cloudmasters" "$binary_target"
  fi
else
  # Linux binary
  if [[ -f "$binary_target" ]]; then
    rm -f "$binary_target"
  fi
  mv "$TMP_FILE" "$binary_target"
fi

# Create launcher wrapper script
launcher_script='#!/usr/bin/env bash
# CloudMasters Launcher - auto-updates and runs the binary

GITHUB_REPO="BrowserBox/CloudMasters-Marketplace"
BINARY_DIR="$HOME/.cloudmasters/bin"
CACHE_FILE="$HOME/.cloudmasters/.version-cache"
CACHE_TTL=10800  # 3 hours

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
  binary="/usr/local/bin/cloudmasters"
else
  asset="cloudmasters_linux_amd64"
  binary="$BINARY_DIR/cloudmasters"
fi

get_current_version() {
  if [[ -x "$binary" ]]; then
    "$binary" --version 2>/dev/null | grep -oE '\''v?[0-9]+\.[0-9]+\.[0-9]+'\'' | head -1 || echo ""
  fi
}

get_latest_version() {
  # Check cache first
  if [[ -f "$CACHE_FILE" ]]; then
    cache_age=$(($(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [[ $cache_age -lt $CACHE_TTL ]]; then
      cat "$CACHE_FILE"
      return
    fi
  fi
  
  # Fetch from GitHub API
  latest=$(curl -fsSL --max-time 5 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null | grep -o '\''"tag_name":[ ]*"[^"]*"'\'' | head -1 | grep -o '\''v[0-9.]*'\'')
  
  if [[ -n "$latest" ]]; then
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "$latest" > "$CACHE_FILE"
    echo "$latest"
  fi
}

download_binary() {
  local version="$1"
  local url="https://github.com/$GITHUB_REPO/releases/download/$version/$asset"
  local tmp="$BINARY_DIR/download.tmp"
  
  mkdir -p "$BINARY_DIR"
  
  echo "Updating CloudMasters to $version..." >&2
  if curl -fsSL "$url" -o "$tmp" 2>/dev/null; then
    if [[ "$os" == "macos" ]]; then
      echo "Installing update (requires sudo)..." >&2
      sudo installer -pkg "$tmp" -target /
      rm -f "$tmp"
    else
      chmod +x "$tmp"
      mv "$tmp" "$binary"
    fi
  else
    rm -f "$tmp"
    echo "Update failed, using existing version." >&2
  fi
}

# Check for updates (background-friendly)
current=$(get_current_version)
current_normalized="${current#v}"

if [[ -z "$current" ]]; then
  # No binary, must download
  latest=$(get_latest_version)
  if [[ -z "$latest" ]]; then
    echo "Error: Could not determine latest version and no binary installed." >&2
    exit 1
  fi
  download_binary "$latest"
else
  # Check for update (non-blocking - only if cache expired)
  latest=$(get_latest_version)
  latest_normalized="${latest#v}"
  
  if [[ -n "$latest" && "$latest_normalized" != "$current_normalized" ]]; then
    download_binary "$latest"
  fi
fi

# Run binary
exec "$binary" "$@"
'

# Install launcher to PATH
install_target="$INSTALL_DIR/cloudmasters"
use_sudo=""

if [[ ! -d "$INSTALL_DIR" ]]; then
  mkdir -p "$INSTALL_DIR" 2>/dev/null || true
fi

if [[ ! -w "$INSTALL_DIR" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    use_sudo="sudo"
  else
    INSTALL_DIR="$HOME/.local/bin"
    install_target="$INSTALL_DIR/cloudmasters"
    mkdir -p "$INSTALL_DIR"
  fi
fi

if [[ -f "$install_target" ]]; then
  if [[ -n "$use_sudo" ]]; then
    $use_sudo rm -f "$install_target"
  else
    rm -f "$install_target"
  fi
fi

if [[ -n "$use_sudo" ]]; then
  echo "$launcher_script" | $use_sudo tee "$install_target" > /dev/null
  $use_sudo chmod +x "$install_target"
else
  echo "$launcher_script" > "$install_target"
  chmod +x "$install_target"
fi

# Check PATH
path_ok=false
case ":$PATH:" in
  *":$INSTALL_DIR:"*) path_ok=true ;;
esac

if [[ "$path_ok" == "true" ]]; then
  echo "cloudmasters installed to $INSTALL_DIR"
else
  echo "cloudmasters installed."
  echo ""
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
fi

echo ""
if [[ "$os" == "macos" ]]; then
  echo "Binary: /usr/local/bin/cloudmasters"
else
  echo "Binary: $binary_target"
fi
echo "Launcher: $install_target (auto-updates on run)"
echo ""
echo "Run: cloudmasters"

echo ""
echo "Tip: Run 'cloudmasters' to launch the TUI."
