# dnf install net-tools -y
# apt install net-tools -y
apt-get update
apt-get install sudo ca-certificates apt-transport-https jq vim vim-gtk3 libnet-ifconfig-wrapper-perl socat fail2ban lrzsz python3 cron curl wget unzip unrar-free dnsutils net-tools iptables iptables-persistent psmisc ncdu sosreport lsof nmap traceroute debian-keyring debian-archive-keyring libnss3 tar -y
sed -i '/^mozilla\/DST_Root_CA_X3/s/^/!/' /etc/ca-certificates.conf && update-ca-certificates -f
wget --no-check-certificate -qO ~/go_version.html 'https://go.dev/dl/'
tmpGoSubVer=""
for ((i=1;i<=3;i++)); do
  tmpGoSubVer+=`grep .tar.gz ~/go_version.html | head -n 1 | sed "s/<//g" | sed "s/>//g" | awk -F"=" '{print $3}' | cut -d"." -f$i | sed 's/[^0-9]//g'`"."
done
GoSubVer=${tmpGoSubVer%?}
echo "$GoSubVer"
rm -rf ~/go_version.html

ArchName=`uname -m`
[[ -z "$ArchName" ]] && ArchName=$(echo `hostnamectl status | grep "Architecture" | cut -d':' -f 2`)
case $ArchName in arm64) VER="arm64";; aarch64) VER="aarch64";; x86|i386|i686) VER="i386";; x86_64) VER="x86_64";; x86-64) VER="x86-64";; amd64) VER="amd64";; *) VER="";; esac
if [[ "$VER" == "x86_64" ]] || [[ "$VER" == "x86-64" ]]; then
  VER="amd64"
elif [[ "$VER" == "aarch64" ]]; then
  VER="arm64"
fi

GoCompressFile="go$GoSubVer.linux-$VER.tar.gz"
GoDlUrl="https://go.dev/dl/$GoCompressFile"
rm -rf ~/$GoCompressFile
rm -rf ~/usr/local/go
wget --no-check-certificate -qO ~/$GoCompressFile "$GoDlUrl"
tar -zxvf ~/$GoCompressFile -C /usr/local/
echo 'export GOROOT=/usr/local/go' >> /etc/profile
echo 'export PATH=$GOROOT/bin:$PATH' >> /etc/profile
source /etc/profile
which go
go version
rm -rf ~/$GoCompressFile

rm -rf ~/go ~/caddy ~/naive.proxy
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
NaiveExe="naive.proxy"
mv ~/caddy ~/$NaiveExe
chmod +x ~/$NaiveExe
rm -rf ~/go

iptables -I INPUT -p tcp --dport 443 -j ACCEPT
netfilter-persistent save
netfilter-persistent reload

sysctl -w net.core.rmem_max=5000000

mv ~/$NaiveExe /usr/bin/
[[ ! -d /etc/caddy/ ]] && mkdir /etc/caddy/
chmod +x /etc/caddy/*
NaiveExeDir="/usr/bin/$NaiveExe"
NaiveCfg="/etc/caddy/naive.config"
NaiveServ="/etc/systemd/system/$NaiveExe.service"
NaiveMaintain="/etc/caddy/Naive_Maintain.sh"
[[ ! -f "$NaiveCfg" ]] && touch $NaiveCfg
[[ ! -f "$NaiveServ" ]] && {
  touch "$NaiveServ"
  cat >> "$NaiveServ" <<EOF
[Unit]
Description=NaïveProxy
Documentation=https://github.com/klzgrad/naiveproxy/blob/master/README.md
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$NaiveExeDir run --environ --adapter caddyfile --config $NaiveCfg
ExecReload=$NaiveExeDir reload --adapter caddyfile --config $NaiveCfg
ExecStop=$NaiveExeDir stop --adapter caddyfile --config $NaiveCfg
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable $NaiveExe
  service $NaiveExe start
}
rm -rf $NaiveMaintain
touch "$NaiveMaintain"
cat >> "$NaiveMaintain" <<EOF
#!/bin/bash
service $NaiveExe stop
service $NaiveExe restart
EOF
[[ ! `grep -i "naive_maintain" /etc/crontab` ]] && sed -i '$i 35 4    * * 0   root    bash '$NaiveMaintain'' /etc/crontab
