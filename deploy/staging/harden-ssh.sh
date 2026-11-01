#!/usr/bin/env bash
# Turns off password logins over SSH. Run as root only after logging in with your key works,
# and keep the current session open until a new key login succeeds.

set -euo pipefail

# Files in sshd_config.d apply in name order and the first value wins, so 10- beats the cloud image's 50-
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF

# With socket activation sshd may not be running, and the config test needs its runtime directory
mkdir -p /run/sshd
sshd -t
systemctl restart ssh
echo "Password logins are off; only SSH keys are accepted."
