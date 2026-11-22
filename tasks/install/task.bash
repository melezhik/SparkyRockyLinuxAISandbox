set -e

sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb

config_file=/etc/my.cnf.d/mariadb-server.cnf
test -f "$config_file"
printf 'MariaDB configuration file: %s\n' "$config_file"
grep -E '^\[mysqld\]|^[[:space:]]*datadir[[:space:]]*=' "$config_file"

mariadb --version
systemctl is-active mariadb
