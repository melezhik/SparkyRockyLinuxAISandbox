set -e

minimum_version="${MINIMUM_MARIADB_VERSION:-10.11}"

sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb

config_file=/etc/my.cnf.d/mariadb-server.cnf
test -f "$config_file"
printf 'MariaDB configuration file: %s\n' "$config_file"
grep -E '^\[mysqld\]|^[[:space:]]*datadir[[:space:]]*=' "$config_file"

version_output=$(mariadb --version)
printf '%s\n' "$version_output"

installed_version=$(printf '%s\n' "$version_output" | sed -nE 's/^.*[[:space:]]Ver[[:space:]]([0-9]+\.[0-9]+).*/\1/p')

if [ -z "$installed_version" ]; then
  echo "Unable to determine MariaDB version from: $version_output" >&2
  exit 1
fi

if ! awk -v installed="$installed_version" -v minimum="$minimum_version" 'BEGIN { exit !(installed >= minimum) }'; then
  echo "MariaDB version $installed_version is lower than minimum required version $minimum_version" >&2
  exit 1
fi

printf 'MariaDB version %s is higher than or equal to %s\n' "$installed_version" "$minimum_version"
systemctl is-active mariadb
