# 部署socke5
socke5
# 下载脚本
wget https://raw.githubusercontent.com/auihi/socke5/main/install_socks5.sh
# 添加执行权限
chmod +x install_socks5.sh
# 运行脚本 (使用 sudo 以确保root权限)
sudo ./install_socks5.sh
# 谷歌vps设置密码
wget https://raw.githubusercontent.com/auihi/socke5/main/setup_ssh_password.sh
# 添加执行权限
chmod +x setup_ssh_password.sh
# 运行脚本 (使用 sudo 以确保root权限)
./setup_ssh_password.sh [设置密码]
