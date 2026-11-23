set -euo pipefail

if [ ! -r /etc/os-release ]; then
  echo 'Cannot identify operating system: /etc/os-release is missing' >&2
  exit 1
fi
. /etc/os-release
if [ "${ID:-}" != rocky ]; then
  echo "This test targets Rocky Linux; detected ID=${ID:-unknown}" >&2
  exit 1
fi

if ! rpm -q curl-minimal >/dev/null 2>&1; then
  echo 'Expected curl-minimal to be installed as the starting package for this swap test' >&2
  exit 1
fi

swap_attempted=0
restore_curl_minimal() {
  if [ "$swap_attempted" -eq 1 ]; then
    echo 'Restoring the original curl-minimal package...'
    sudo dnf swap -y curl curl-minimal || {
      echo 'WARNING: failed to restore curl-minimal after the DNF swap test' >&2
      return 1
    }
  fi
}
trap restore_curl_minimal EXIT

# Set before invoking dnf so the exit trap also attempts recovery if the command
# fails after making package changes.
swap_attempted=1
sudo dnf swap -y curl-minimal curl

if ! rpm -q curl >/dev/null 2>&1 || rpm -q curl-minimal >/dev/null 2>&1; then
  echo 'DNF swap did not replace curl-minimal with curl as expected' >&2
  exit 1
fi
curl --version
printf 'DNF swap check: curl-minimal -> curl succeeded\n'

sudo dnf swap -y curl curl-minimal
swap_attempted=0
if ! rpm -q curl-minimal >/dev/null 2>&1 || rpm -q curl >/dev/null 2>&1; then
  echo 'DNF swap did not restore the original curl-minimal package state' >&2
  exit 1
fi
printf 'DNF swap check: curl -> curl-minimal restored\n'
