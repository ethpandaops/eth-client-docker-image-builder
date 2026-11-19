#!/usr/bin/env bash
# Checks a built image against the upstream controller image it replaces.
# Usage: ingress-nginx/test.sh <image>
set -euo pipefail

image=$1
upstream=registry.k8s.io/ingress-nginx/controller:v1.12.1@sha256:d2fbc4ec70d8aa2050dd91a91506e998765e86c96f32cffb56c503c9c34eed5b
expected_nginx_sha256=c6a479340d6332126261610f7b713d6fe576077dda932c5ede141f6b7c1158b9

run() { docker run --rm --entrypoint "$1" "${@:2}"; }

echo "== configure arguments match upstream"
diff <(run nginx "$upstream" -V 2>&1 | grep '^configure arguments') \
     <(run nginx "$image" -V 2>&1 | grep '^configure arguments')
run nginx "$image" -V 2>&1 | head -3

echo "== nginx binary"
run sh --user 0 "$image" -c "
  sha256sum /usr/local/nginx/sbin/nginx
  echo '$expected_nginx_sha256  /usr/local/nginx/sbin/nginx' | sha256sum -c -
  apk add -q --no-cache libcap-getcap >/dev/null
  getcap /usr/local/nginx/sbin/nginx | grep -q cap_net_bind_service=ep
  ls -l /usr/local/nginx/sbin/nginx"

echo "== only the nginx binary differs from upstream"
# /etc/hostname, /etc/hosts and /etc/resolv.conf are written by docker run.
list='find / -xdev -type f ! -path "/proc/*" ! -path /etc/hostname ! -path /etc/hosts ! -path /etc/resolv.conf -exec sha256sum {} + 2>/dev/null | sort -k2'
tmp=$(mktemp -d)
run sh --user 0 "$upstream" -c "$list" > "$tmp/upstream"
run sh --user 0 "$image" -c "$list" > "$tmp/image"
wc -l < "$tmp/image"
changed=$({ diff "$tmp/upstream" "$tmp/image" || true; } | awk '/^[<>]/ {print $3}' | sort -u)
echo "$changed"
rm -rf "$tmp"
test "$changed" = /usr/local/nginx/sbin/nginx

echo "== dynamic modules load and HTTP/2 over TLS proxies to a backend"
run sh "$image" -c '
  set -e
  cd /tmp
  openssl req -x509 -newkey rsa:2048 -nodes -subj /CN=test -keyout k.pem -out c.pem -days 1 2>/dev/null
  mods=""
  for m in /etc/nginx/modules/*.so; do mods="$mods load_module $m;"; done
  cat > t.conf <<EOF
pid /tmp/t.pid;
error_log /tmp/error.log info;
$mods
events {}
http {
  access_log off;
  client_body_temp_path /tmp/b; proxy_temp_path /tmp/p; fastcgi_temp_path /tmp/f;
  server { listen 127.0.0.1:8081; location / { return 200 "backend\n"; } }
  server {
    listen 127.0.0.1:8443 ssl;
    http2 on;
    ssl_certificate /tmp/c.pem; ssl_certificate_key /tmp/k.pem;
    location / { proxy_pass http://127.0.0.1:8081; }
  }
}
EOF
  nginx -t -p /tmp -c /tmp/t.conf
  nginx -p /tmp -c /tmp/t.conf
  sleep 1
  out=$(curl -sk --http2 -o - -w "%{http_version} %{http_code}" https://127.0.0.1:8443/)
  echo "$out"
  case "$out" in *backend*"2 200") ;; *) exit 1 ;; esac
  nginx -p /tmp -c /tmp/t.conf -s quit
  ! grep -E "\[(alert|crit|emerg)\]" /tmp/error.log
'
echo "OK"
