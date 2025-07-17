# 部署socke5
socke5 默认账号：123123 密码：123123
# 下载脚本
sudo -i

wget https://raw.githubusercontent.com/auihi/socke5/main/install_socks5.sh

chmod +x install_socks5.sh

sudo ./install_socks5.sh

# 谷歌vps设置密码
wget https://raw.githubusercontent.com/auihi/socke5/main/setup_ssh_password.sh

chmod +x setup_ssh_password.sh

./setup_ssh_password.sh [设置密码]
