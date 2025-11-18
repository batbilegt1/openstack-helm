sudo apt update
sudo apt install wireguard -y
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
umask 077; wg genkey | tee /etc/wireguard/pri | wg pubkey > /etc/wireguard/pub
cat /etc/wireguard/pub
# 7+45XbN2wm14XQArhybXnT7eWPkVGdL4rS0bhEF4CCc=
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
PublicKey = /UV3/cWU4DtXg6TN23aQWLhmVrWW6Pn7w2xVPpS9MBg=
AllowedIPs = 10.22.22.0/24
EOF

# Ene ni wireguard desktop app-aas new empty tunnel uusgeh uyd deer ni baidag key-uud
# PublicKey = /UV3/cWU4DtXg6TN23aQWLhmVrWW6Pn7w2xVPpS9MBg=
# PrivateKey = GDxAfpxvArB9UP3/UNIBEg8O73mRBcEr0/DeHaT/nG8=

# Ehnii udaa
sudo systemctl enable wg-quick@wg1
sudo systemctl start wg-quick@wg1
sudo ufw allow 50323/udp
# Dahin zasval
sudo systemctl restart wg-quick@wg1

wg show

ufw enable
ufw reload

# Garaad controll server deeree ajilluul
iptables -I FORWARD 1 -i wg1 -o manage-br -j ACCEPT
iptables -I FORWARD 1 -i manage-br -o wg1 -j ACCEPT

# sudo systemctl stop wg-quick@wg1
# sudo systemctl disable wg-quick@wg1

##default route
# iptables -I FORWARD 1 -i eth-s0 -o wg1 -j ACCEPT
# iptables -I FORWARD 1 -i wg1 -o eth-s0 -j ACCEPT
# iptables -t nat -A POSTROUTING -o eth-s0 -j MASQUERADE