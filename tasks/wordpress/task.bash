set -euo pipefail

minimum_php_version="${MINIMUM_PHP_VERSION:-8.0}"
site_title="Sparky WordPress Test"

sudo dnf install -y httpd mariadb-server curl php php-mysqlnd php-json php-xml php-gd php-mbstring php-intl php-zip tar

php_version=$(php -r 'echo PHP_VERSION;')
printf 'PHP version: %s (minimum: %s)\n' "$php_version" "$minimum_php_version"
if ! MINIMUM_PHP_VERSION="$minimum_php_version" php -r 'exit(version_compare(PHP_VERSION, getenv("MINIMUM_PHP_VERSION"), ">") ? 0 : 1);'; then
  echo "PHP version $php_version must be greater than $minimum_php_version" >&2
  exit 1
fi

sudo systemctl enable --now mariadb httpd

# Create a disposable local database and a dedicated account for this test.
db_password=$(php -r 'echo bin2hex(random_bytes(24));')
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS wordpress_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wordpress_test'@'localhost' IDENTIFIED BY '${db_password}';
ALTER USER 'wordpress_test'@'localhost' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON wordpress_test.* TO 'wordpress_test'@'localhost';
FLUSH PRIVILEGES;
SQL

sudo install -d -o apache -g apache /var/www/html/wordpress
sudo curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
sudo chmod 0755 /usr/local/bin/wp
sudo -u apache /usr/local/bin/wp core download --path=/var/www/html/wordpress
sudo -u apache /usr/local/bin/wp config create \
  --path=/var/www/html/wordpress \
  --dbname=wordpress_test \
  --dbuser=wordpress_test \
  --dbpass="$db_password" \
  --dbhost=localhost

# Use a generated password for the temporary administrator account.
admin_password=$(php -r 'echo bin2hex(random_bytes(24));')
sudo -u apache /usr/local/bin/wp core install \
  --path=/var/www/html/wordpress \
  --url=http://127.0.0.1 \
  --title="$site_title" \
  --admin_user=sparky-test-admin \
  --admin_password="$admin_password" \
  --admin_email=wordpress-test@example.invalid \
  --skip-email

sudo tee /etc/httpd/conf.d/wordpress.conf >/dev/null <<'APACHE'
ServerName localhost
DocumentRoot /var/www/html/wordpress
<Directory /var/www/html/wordpress>
    AllowOverride All
    Require all granted
</Directory>
APACHE
sudo restorecon -RF /var/www/html
sudo systemctl restart httpd

http_status=$(curl -sS -o /tmp/sparky-wordpress-home.html -w '%{http_code}' --max-time 20 http://127.0.0.1/)
[ "$http_status" = '200' ] || {
  echo "WordPress site returned HTTP $http_status (expected 200)" >&2
  exit 1
}
grep -Fq "$site_title" /tmp/sparky-wordpress-home.html || {
  echo 'WordPress response did not contain the expected site title' >&2
  exit 1
}
printf 'WordPress site check: HTTP %s\n' "$http_status"
printf 'WordPress page title: %s\n' "$site_title"
