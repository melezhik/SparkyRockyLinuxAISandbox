set -euo pipefail

# Assess nginx against security advisories published by the enabled Rocky repositories.
# This does not alter nginx or certify the absence of undisclosed vulnerabilities.
if ! rpm -q nginx >/dev/null 2>&1; then
  echo 'nginx is not installed; cannot assess its security advisories' >&2
  exit 1
fi

nginx_package=$(rpm -q --qf '%{NAME}\n' nginx)
printf 'Checking installed package: %s\n' "$(rpm -q nginx)"

# Refresh advisory metadata so the result reflects currently configured repositories.
sudo dnf -y makecache --refresh

if ! command -v dnf >/dev/null 2>&1; then
  echo 'dnf is required to query Rocky Linux security advisories' >&2
  exit 1
fi

security_updates=$(sudo dnf -q repoquery --security --available --qf '%{name}-%{version}-%{release}.%{arch}' "$nginx_package")
if [ -n "$security_updates" ]; then
  printf 'Applicable nginx security updates are available:\n%s\n' "$security_updates" >&2
  echo 'nginx has outstanding security advisories; update the package and rerun this test' >&2
  exit 1
fi

printf 'nginx security status: no applicable security updates in enabled Rocky repositories\n'
printf 'nginx version: %s\n' "$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' nginx)"
