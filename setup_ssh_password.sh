#!/bin/bash

# --- Google Cloud VM SSH 密码认证及 Root 密码一键设置脚本 ---
#
# 该脚本将修改SSH配置文件，确保PasswordAuthentication和PermitRootLogin设置为yes，
# 并为root用户设置指定的密码。
#
# !! 警告 !!：允许root用户通过密码登录具有高安全风险。
#            通过命令行参数传递密码也存在安全风险（如被记录在shell历史）。
#            请在了解风险后谨慎使用。
#
# 用法：./setup_root_password_ssh.sh [你的Root密码]
# 示例：./setup_root_password_ssh.sh MySuperStrongPa$$w0rd123
# -----------------------------------------------------------------

echo "--- 正在开始 SSH 密码认证及 Root 密码一键设置 ---"

# 检查是否传入了密码参数
if [ -z "$1" ]; then
    echo "错误：请提供一个密码作为命令行参数。"
    echo "用法：./setup_root_password_ssh.sh [你的Root密码]"
    exit 1
fi

NEW_ROOT_PASSWORD="$1"

# 检查当前用户是否具有sudo权限 (在root用户下运行此脚本通常不需要，但为了兼容性保留)
if ! sudo -v &>/dev/null; then
    echo "错误：当前用户没有sudo权限。请确保使用具有sudo权限的用户运行此脚本，或直接以root身份运行。"
    exit 1
fi

# 1. 备份原始 SSHD 配置文件
echo "备份原始 SSHD 配置文件..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
if [ $? -eq 0 ]; then
    echo "配置文件备份成功至 /etc/ssh/sshd_config.bak"
else
    echo "警告：配置文件备份失败，请手动检查。"
fi

# 2. 修改 SSHD 配置文件，允许密码认证和Root密码登录
echo "修改 /etc/ssh/sshd_config 文件..."

# 确保 PermitRootLogin 为 yes
sudo sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config # 删除所有现有的PermitRootLogin行
echo "PermitRootLogin yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null # 在文件末尾添加 PermitRootLogin yes

# 确保 PasswordAuthentication 为 yes
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i '/^#PasswordAuthentication yes/s/^#//' /etc/ssh/sshd_config # 取消注释已注释的PasswordAuthentication yes行

# 如果文件中根本没有 PasswordAuthentication 行，就添加一个
if ! grep -q "PasswordAuthentication" /etc/ssh/sshd_config; then
    echo "在 /etc/ssh/sshd_config 文件末尾添加 PasswordAuthentication yes..."
    echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi


# 检查修改是否成功
if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config && \
   grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
    echo "SSHD 配置文件修改成功：PasswordAuthentication 和 PermitRootLogin 都已设置为 yes。"
else
    echo "错误：SSHD 配置文件修改失败。请手动检查 /etc/ssh/sshd_config。"
    echo "请确保文件中包含 'PasswordAuthentication yes' 和 'PermitRootLogin yes'。"
    exit 1
fi

# 3. 设置 Root 用户的密码 (使用echo管道)
echo "正在为 'root' 用户设置密码..."
echo -e "$NEW_ROOT_PASSWORD\n$NEW_ROOT_PASSWORD" | sudo passwd root

if [ $? -eq 0 ]; then
    echo "用户 'root' 的密码设置成功。"
else
    echo "错误：root 密码设置失败。请检查。"
    exit 1
fi

# 4. 重启 SSH 服务
echo "重启 SSH 服务..."
sudo systemctl restart sshd
if [ $? -eq 0 ]; then
    echo "SSH 服务重启成功。"
else
    echo "错误：SSH 服务重启失败。请手动尝试 'sudo systemctl restart sshd'。"
    exit 1
fi

echo "--- 设置完成！你现在应该可以通过 SSH 密码登录 root 用户。---"
echo "你可以尝试使用以下命令从本地电脑连接："
echo "ssh root@你的_VM_外部IP地址"
echo "请将 '你的_VM_外部IP地址' 替换为你的虚拟机实例的实际IP地址。"
echo "请记住：SSH 密钥登录通常更安全，请谨慎使用root密码登录。"
