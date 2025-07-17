#!/bin/bash

# --- Google Cloud VM SSH 密码登录一键设置脚本 (带密码参数) ---
#
# 该脚本将修改SSH配置文件，允许密码认证，并为指定用户设置密码。
# 密码通过命令行参数传入。
#
# !! 警告 !!：通过命令行参数传递密码存在安全风险。密码可能会被记录在
# shell历史或进程列表中。请在了解风险后谨慎使用，仅限非敏感环境。
#
# 用法：./setup_ssh_password.sh [你的密码]
# -----------------------------------------------------------------

echo "--- 正在开始 SSH 密码登录设置 ---"

# 检查是否传入了密码参数
if [ -z "$1" ]; then
    echo "错误：请提供一个密码作为命令行参数。"
    echo "用法：./setup_ssh_password.sh [你的密码]"
    exit 1
fi

NEW_PASSWORD="$1"
CURRENT_USER=$(whoami)

# 检查当前用户是否具有sudo权限
if ! sudo -v &>/dev/null; then
    echo "错误：当前用户没有sudo权限。请确保使用具有sudo权限的用户运行此脚本。"
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

# 2. 修改 SSHD 配置文件，允许密码认证
echo "修改 /etc/ssh/sshd_config 文件..."
sudo sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config # 确保root不直接密码登录
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i '/^#PasswordAuthentication yes/s/^#//' /etc/ssh/sshd_config # 取消注释已注释的PasswordAuthentication yes行

# 检查修改是否成功
if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config && ! grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "SSHD 配置文件修改成功：PasswordAuthentication 已设置为 yes"
else
    echo "错误：SSHD 配置文件修改失败。请手动检查 /etc/ssh/sshd_config。"
    exit 1
fi

# 3. 设置当前用户的密码 (使用echo管道)
echo "为当前用户 '$CURRENT_USER' 设置密码..."
echo -e "$NEW_PASSWORD\n$NEW_PASSWORD" | sudo passwd "$CURRENT_USER"

if [ $? -eq 0 ]; then
    echo "用户 '$CURRENT_USER' 的密码设置成功。"
else
    echo "错误：密码设置失败。请检查。"
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

echo "--- 设置完成！你现在应该可以通过 SSH 密码登录。---"
echo "你可以尝试使用以下命令从本地电脑连接："
echo "ssh $CURRENT_USER@你的_VM_外部IP地址"
echo "请将 '你的_VM_外部IP地址' 替换为你的虚拟机实例的实际IP地址。"
echo "请记住：SSH 密钥登录更安全。"
