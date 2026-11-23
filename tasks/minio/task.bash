set -euo pipefail

minio_user=minio-user
minio_home=/opt/minio
minio_data=/var/lib/minio
minio_config=/etc/minio/minio.conf
minio_port=9000
minio_console_port=9001

sudo dnf install -y curl policycoreutils-python-utils

if ! getent passwd "$minio_user" >/dev/null; then
  sudo useradd --system --home-dir "$minio_home" --shell /usr/sbin/nologin "$minio_user"
fi
sudo install -d -o "$minio_user" -g "$minio_user" -m 0750 "$minio_home" "$minio_data" /etc/minio

if [ ! -x /usr/local/bin/minio ]; then
  sudo curl -fL https://dl.min.io/server/minio/release/linux-amd64/minio -o /usr/local/bin/minio
  sudo chmod 0755 /usr/local/bin/minio
fi

root_user="sparky-minio-admin"
root_password=$(openssl rand -base64 32 | tr -d '\n')
if [ -z "$root_password" ]; then
  root_password="SparkyMinIO$(date +%s)!A7"
fi

sudo tee "$minio_config" >/dev/null <<EOF
MINIO_ROOT_USER=${root_user}
MINIO_ROOT_PASSWORD=${root_password}
MINIO_VOLUMES="${minio_data}"
MINIO_OPTS="--address :${minio_port} --console-address :${minio_console_port}"
EOF
sudo chown root:"$minio_user" "$minio_config"
sudo chmod 0640 "$minio_config"

sudo tee /etc/systemd/system/minio.service >/dev/null <<EOF
[Unit]
Description=MinIO object storage
Documentation=https://min.io/docs/minio/linux/index.html
After=network.target

[Service]
User=${minio_user}
Group=${minio_user}
EnvironmentFile=${minio_config}
ExecStart=/usr/local/bin/minio server $MINIO_VOLUMES $MINIO_OPTS
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now minio

version_output=$(/usr/local/bin/minio --version)
printf 'MinIO version: %s\n' "$version_output"
printf 'MinIO configuration: %s\n' "$minio_config"
printf 'MinIO data directory: %s\n' "$minio_data"
printf 'MinIO API address: http://127.0.0.1:%s\n' "$minio_port"
printf 'MinIO console address: http://127.0.0.1:%s\n' "$minio_console_port"

for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${minio_port}/minio/health/live" >/dev/null; then
    printf 'MinIO health: live\n'
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:${minio_port}/minio/health/live" >/dev/null
systemctl is-active minio
