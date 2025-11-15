#!/bin/bash
set -e

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

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

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   SiteKeeper Uninstallation Script    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if installed
if [ ! -f "${INSTALL_DIR}/sitekeeper" ]; then
    warning "SiteKeeper is not installed"
    exit 0
fi

echo ""
info "Removing binaries..."

# Remove binaries
if [ -f "${INSTALL_DIR}/sitekeeper" ]; then
    rm -f "${INSTALL_DIR}/sitekeeper"
    success "Removed ${INSTALL_DIR}/sitekeeper"
fi

if [ -L "${INSTALL_DIR}/sk" ]; then
    rm -f "${INSTALL_DIR}/sk"
    success "Removed ${INSTALL_DIR}/sk"
fi

# Stop and disable systemd services
info "Checking for systemd services..."
if systemctl list-unit-files | grep -q "sitekeeper-backup"; then
    info "Stopping systemd services..."
    systemctl stop sitekeeper-backup.timer 2>/dev/null || true
    systemctl stop sitekeeper-backup.service 2>/dev/null || true
    systemctl disable sitekeeper-backup.timer 2>/dev/null || true

    if [ -f "/etc/systemd/system/sitekeeper-backup.service" ]; then
        rm -f "/etc/systemd/system/sitekeeper-backup.service"
        success "Removed systemd service file"
    fi

    if [ -f "/etc/systemd/system/sitekeeper-backup.timer" ]; then
        rm -f "/etc/systemd/system/sitekeeper-backup.timer"
        success "Removed systemd timer file"
    fi

    systemctl daemon-reload
    success "Systemd services removed"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Uninstallation Complete! ✓           ║"
echo "╚════════════════════════════════════════╝"
echo ""

info "What was NOT removed (manual cleanup if needed):"
echo "  • Database: 'backups' in MySQL"
echo "  • S3 Backups: s3://your-bucket/"
echo "  • Logs: /var/log/sitekeeper-backup.log"
echo "  • AWS Config: ~/.aws/credentials (sitekeeper-backup profile)"
echo ""

info "To completely remove database:"
echo "  mysql -e 'DROP DATABASE backups;'"
echo ""
