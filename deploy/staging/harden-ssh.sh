#!/usr/bin/env bash
# Turns off password logins over SSH and allows local tunnels (ssh -L) for Portainer and Mailpit.
# Run as root only after logging in with your key works, and keep the current session open
# until a new key login succeeds.

set -euo pipefail

# Files in sshd_config.d apply in name order and the first value wins, so 00- beats what
# the provider's image sets (some turn off TCP forwarding, cloud images turn on passwords)
rm -f /etc/ssh/sshd_config.d/10-hardening.conf
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
AllowTcpForwarding local
EOF

# With socket activation sshd may not be running, and the config test needs its runtime directory
mkdir -p /run/sshd
sshd -t

effective=$(sshd -T)
for setting in 'passwordauthentication no' 'permitrootlogin without-password' 'allowtcpforwarding local'; do
  if ! grep -qx "$setting" <<< "$effective"; then
    echo "Not applied: '$setting'. Look for an earlier value in /etc/ssh/sshd_config." >&2
    exit 1
  fi
done

systemctl restart ssh
echo "Password logins are off; only SSH keys are accepted. Local tunnels (ssh -L) are allowed."
