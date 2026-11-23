set -euo pipefail

minimum_version="${MINIMUM_POSTGRESQL_VERSION:-13.0}"

sudo dnf install -y postgresql-server

if [ ! -s /var/lib/pgsql/data/PG_VERSION ]; then
  sudo postgresql-setup --initdb
fi

sudo systemctl enable --now postgresql

# Restrict PostgreSQL to local connections and require SCRAM for TCP clients.
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET listen_addresses = 'localhost'"
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256'"
hba_file=$(sudo -u postgres psql -Atqc 'SHOW hba_file')
sudo tee "$hba_file" >/dev/null <<'HBA'
# Local Unix socket access uses peer credentials.
local   all             all                                     peer
# TCP connections are limited to loopback and require SCRAM authentication.
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
HBA
sudo chown postgres:postgres "$hba_file"
sudo chmod 600 "$hba_file"
sudo systemctl restart postgresql

version_output=$(psql --version)
installed_version=$(printf '%s\n' "$version_output" | sed -nE 's/^.* ([0-9]+\.[0-9]+).*$/\1/p')
if [ -z "$installed_version" ]; then
  echo "Unable to determine PostgreSQL version from: $version_output" >&2
  exit 1
fi
printf 'PostgreSQL version: %s (minimum: %s)\n' "$installed_version" "$minimum_version"
systemctl is-active postgresql

listen_addresses=$(sudo -u postgres psql -Atqc 'SHOW listen_addresses')
password_encryption=$(sudo -u postgres psql -Atqc 'SHOW password_encryption')
[ "$listen_addresses" = 'localhost' ] || { echo "Unexpected listen_addresses: $listen_addresses" >&2; exit 1; }
[ "$password_encryption" = 'scram-sha-256' ] || { echo "Unexpected password_encryption: $password_encryption" >&2; exit 1; }
printf 'Security listen_addresses: %s\n' "$listen_addresses"
printf 'Security password_encryption: %s\n' "$password_encryption"

host_rule_count=$(sudo -u postgres psql -Atqc "SELECT count(*) FROM pg_hba_file_rules WHERE type = 'host'")
scram_loopback_count=$(sudo -u postgres psql -Atqc "SELECT count(*) FROM pg_hba_file_rules WHERE type = 'host' AND auth_method = 'scram-sha-256' AND address IN ('127.0.0.1', '::1')")
[ "$host_rule_count" = '2' ] && [ "$scram_loopback_count" = '2' ] || {
  echo 'PostgreSQL host authentication must allow only loopback connections using SCRAM' >&2
  exit 1
}
printf 'Security host_auth: scram-sha-256 (loopback only)\n'
