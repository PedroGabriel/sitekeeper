#!/bin/bash
set -e

# SiteKeeper Installation Script
# Usage: curl -fsSL https://gist.githubusercontent.com/YOUR_USERNAME/GIST_ID/raw/install.sh | bash
# Or host this file anywhere and curl it

VERSION="${SITEKEEPER_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
GITHUB_REPO="${GITHUB_REPO:-PedroGabriel/sitekeeper}"  # Public repo with releases only

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (use sudo)"
fi

# Detect OS and Architecture
detect_platform() {
    local os
    local arch

    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$os" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="darwin"
            ;;
        *)
            error "Unsupported operating system: $os"
            ;;
    esac

    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l|armv6l)
            ARCH="arm"
            ;;
        *)
            error "Unsupported architecture: $arch"
            ;;
    esac

    PLATFORM="${OS}_${ARCH}"
}

# Get latest version from GitHub
get_latest_version() {
    if [ "$VERSION" = "latest" ]; then
        info "Fetching latest version from GitHub..."
        VERSION=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
        if [ -z "$VERSION" ]; then
            error "Could not fetch latest version"
        fi
        success "Latest version: v${VERSION}"
    fi
}

# Download and install
download_and_install() {
    local download_url
    local tmp_dir

    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"

    info "Downloading SiteKeeper v${VERSION} for ${PLATFORM}..."

    # Construct download URL
    download_url="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/sitekeeper_${VERSION}_${PLATFORM}.tar.gz"

    if ! curl -fsSL "$download_url" -o "sitekeeper.tar.gz"; then
        error "Failed to download from $download_url"
    fi

    success "Downloaded successfully"

    info "Extracting..."
    tar -xzf sitekeeper.tar.gz

    info "Installing to ${INSTALL_DIR}..."
    mv sitekeeper "${INSTALL_DIR}/sitekeeper"
    chmod +x "${INSTALL_DIR}/sitekeeper"

    # Create symlink for alias
    ln -sf "${INSTALL_DIR}/sitekeeper" "${INSTALL_DIR}/sk"

    success "Installed to ${INSTALL_DIR}/sitekeeper"
    success "Created alias: sk"

    # Cleanup
    cd - > /dev/null
    rm -rf "$tmp_dir"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."

    local missing_deps=()

    # Check MySQL
    if ! command -v mysql &> /dev/null; then
        warning "MySQL client not found (required for database operations)"
        missing_deps+=("mysql-client")
    else
        success "MySQL client found"
    fi

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        warning "AWS CLI not found (required for S3 backups)"
        missing_deps+=("awscli")
    else
        success "AWS CLI found"
    fi

    # Check tar
    if ! command -v tar &> /dev/null; then
        error "tar not found (required)"
    else
        success "tar found"
    fi

    # Check gzip
    if ! command -v gzip &> /dev/null; then
        error "gzip not found (required)"
    else
        success "gzip found"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        warning "Missing dependencies: ${missing_deps[*]}"
        warning "Install them with:"
        echo "  apt-get install -y ${missing_deps[*]}  # Debian/Ubuntu"
        echo "  yum install -y ${missing_deps[*]}      # CentOS/RHEL"
        echo ""
    fi
}

# Run initialization
run_init() {
    echo ""
    info "Next step: Run 'sk init' to initialize SiteKeeper"
}

# Main installation
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   SiteKeeper Installation Script      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    detect_platform
    info "Platform detected: ${PLATFORM}"

    get_latest_version

    # Check if already installed
    if [ -f "${INSTALL_DIR}/sitekeeper" ]; then
        warning "SiteKeeper is already installed"
        info "Current version: $(${INSTALL_DIR}/sitekeeper version 2>/dev/null || echo 'unknown')"
        info "Proceeding with reinstall/upgrade..."
    fi

    download_and_install
    check_dependencies

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Installation Complete! ✓             ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "Usage:"
    echo "  sitekeeper --help       # Show all commands"
    echo "  sk --help              # Short alias"
    echo "  sitekeeper init        # Initialize system"
    echo ""

    # Ask if user wants to run init
    if [ -z "${SITEKEEPER_SKIP_INIT}" ]; then
        run_init
    fi
}

main "$@"
