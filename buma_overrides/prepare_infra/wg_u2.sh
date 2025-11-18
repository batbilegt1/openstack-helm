####server 
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo apt update
sudo apt install wireguard -y
umask 077; wg genkey | tee /etc/wireguard/pri | wg pubkey > /etc/wireguard/pub
umask 077; wg genkey | tee /etc/wireguard/pri_1 | wg pubkey > /etc/wireguard/pub_1
cat /etc/wireguard/pub

cat > /etc/wireguard/wg1.conf <<EOF
[Interface]
Address = 10.22.22.11/24
ListenPort = 50323
PrivateKey = $(cat /etc/wireguard/pri)
PostUp = ufw allow from 10.22.22.0/24;ufw reload
PostUp = ufw allow 50323/udp;ufw reload
PostUp = iptables -I FORWARD 1 -i eth-s0 -o wg1 -j ACCEPT
PostUp = iptables -I FORWARD 1 -i wg1 -o eth-s0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth-s0 -j MASQUERADE

PostDown = ufw delete allow from 10.22.22.0/24;ufw reload
PostDown = ufw delete allow 50323/udp;ufw reload
PostDown = iptables -D FORWARD -i eth-s0 -o wg1 -j ACCEPT
PostDown = iptables -D FORWARD  -i wg1 -o eth-s0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth-s0 -j MASQUERADE
[Peer]
PublicKey = PvPzDlBWfiROMmWbbYzJD17iEe/fBg0yHxBRM4Ynaio=
AllowedIPs = 10.22.22.0/24
EOF

PostUp = iptables -A FORWARD -i wg1 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth-s0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg1 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth-s0 -j MASQUERADE

sudo systemctl enable wg-quick@wg1
sudo systemctl start wg-quick@wg1
sudo ufw allow 50323/udp

sudo systemctl restart wg-quick@wg1

sudo systemctl stop wg-quick@wg1
sudo systemctl disable wg-quick@wg1

##default route
iptables -I FORWARD 1 -i eth-s0 -o wg1 -j ACCEPT
iptables -I FORWARD 1 -i wg1 -o eth-s0 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth-s0 -j MASQUERADE


##bridge
iptables -I FORWARD 1 -i wg1 -o manage-br -j ACCEPT
iptables -I FORWARD 1 -i manage-br -o wg1 -j ACCEPT