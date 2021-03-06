#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:  debian 9/10 one_key naiveproxy： https://github.com/klzgrad/naiveproxy
# install: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/naiveproxy/naiveproxy.sh) my.domain.com my@gmail.com
# uninstall: apt purge caddy -y
## Tips: 个人使用，仅供参考

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

########
[[ $# != 2 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com my@gmail.com && exit 1
domain="$1" && email="$2"
########

# dpkg install caddy
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
sed -i "s/caddy\/Caddyfile$/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service

# replace caddy with naive fork of forwardproxy: https://github.com/klzgrad/forwardproxy
naivecaddyURL="https://github.com/mixool/script/raw/source/naivecaddy.gz"
rm -rf /usr/bin/caddy
wget --no-check-certificate -O - $naivecaddyURL | gzip -d > /usr/bin/caddy && chmod +x /usr/bin/caddy

# secrets
username="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
password="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
probe_resistance="$(tr -dc 'a-z0-9' </dev/urandom | head -c 32).com"

# config caddy json
cat <<EOF >/etc/caddy/Caddyfile.json
{
    "admin": {"disabled": true},
    "logging": {
    "sink": {"writer": {"output": "discard"}},
    "logs": {"default": {"writer": {"output": "discard"}}}
    },
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": [":443"],
                    "routes": [{
                        "handle": [{
                            "handler": "forward_proxy",
                            "hide_ip": true,
                            "hide_via": true,
                            "upstream": "",
                            "auth_user": "$username",
                            "auth_pass": "$password",
                            "probe_resistance": {"domain": "$probe_resistance"}
                        }]
                    }, {
                    "match": [{"host": ["$domain"]}],
                    "handle": [{
                        "handler": "file_server",
                        "root": "/usr/share/caddy"
                    }],
                    "terminal": true
                    }],
                    "tls_connection_policies": [{
                        "match": {"sni": ["$domain"]}
                    }]
                }
            }
        },
        "tls": {
            "automation": {
                "policies": [{
                    "subjects": ["$domain"],
                    "issuer": {
                        "email": "$email",
                        "module": "acme"
                    }
                }]
            }
        }
    }
}
EOF

# systemctl service info
echo; echo $(date) caddy status:
systemctl daemon-reload && systemctl enable caddy && systemctl restart caddy && sleep 1 && systemctl status caddy | more | grep -A 2 "caddy.service"

# info
echo; echo $(date); echo probe_resistance: $probe_resistance; echo username: $username; echo password: $password; echo proxy: https://$username:$password@$domain

# done
