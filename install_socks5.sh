#!/bin/bash

# --- SOCKS5 代理安装 & 检测脚本 ---
# 作者：Gemini (基于 n0a 的脚本修改)
# 日期：2025年7月9日
# 适用系统：Debian/Ubuntu 系列 Linux 发行版
#
# 使用方法：
# 1. 登录你的 VPS。
# 2. 将此脚本内容复制粘贴到 VPS 命令行中。
# 3. 执行脚本。

# --- 配置信息 (可在此处修改) ---
# SOCKS5 代理端口
SOCKS5_PORT="1080"
# SOCKS5 代理用户名 (固定)
PROXY_USERNAME="123123"      # <--- 请务必修改为你自己的用户名！
# SOCKS5 代理密码 (固定)
PROXY_PASSWORD="123123" # <--- 请务必修改为你自己的强密码！

# --- 检查当前用户是否为 root ---
if [ "$EUID" -ne 0 ]; then
  echo "此脚本需要 root 权限运行。正在尝试使用 sudo。"
  exec sudo bash "$0" "$@" # 使用 sudo 重新执行脚本
  exit $? # 确保在 sudo 失败时退出
fi

echo "--- 正在开始 SOCKS5 代理安装 ---"

# --- 1. 更新系统包并安装所需软件 ---
echo "--- 1. 更新系统软件包并安装 dante-server 和 curl ---"
apt update -y
apt install -y dante-server curl
if [ $? -ne 0 ]; then
    echo "软件包安装失败，请检查网络或源配置。正在退出。"
    exit 1
fi

# --- 2. 自动检测默认主网卡 ---
echo "--- 2. 检测默认主网卡 ---"
# `ip route get 8.8.8.8` 是一个更可靠的方式来获取用于默认路由的接口
IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
if [ -z "$IFACE" ]; then
    echo "无法自动检测到主网卡接口。请手动检查并修改脚本中的 'external: \$IFACE' 和 'internal: \$IFACE' 行。"
    echo "您可以使用 'ip a' 命令查看网卡名称。"
    exit 1
fi
echo "已检测到主网卡接口：$IFACE"

# --- 3. 配置 PAM 认证 (Dante 使用) ---
echo "--- 3. 配置 PAM 认证 ---"
cat <<EOL | tee /etc/pam.d/sockd > /dev/null
auth required pam_unix.so
account required pam_unix.so
EOL
if [ $? -ne 0 ]; then
    echo "PAM 配置文件写入失败。正在退出。"
    exit 1
fi
echo "PAM 配置文件 /etc/pam.d/sockd 已创建。"


# --- 4. 配置 Dante Server 主文件 ---
echo "--- 4. 配置 Dante Server 主文件 (/etc/danted.conf) ---"
cat <<EOL | tee /etc/danted.conf > /dev/null
logoutput: syslog /var/log/danted.log
internal: $IFACE port = $SOCKS5_PORT
external: $IFACE
method: username none # 允许用户名认证，且不需要PAM外部认证
user.privileged: root
user.notprivileged: nobody
user.libwrap: nobody

# 客户端规则：允许所有客户端连接到代理服务器本身
client pass {
 from: 0.0.0.0/0 to: 0.0.0.0/0
 log: connect disconnect
}

# SOCKS 规则：允许通过用户名认证的用户进行代理连接
# protocol: tcp udp 是默认且安全的设置
pass {
 from: 0.0.0.0/0 to: 0.0.0.0/0
 socksmethod: username
 log: connect disconnect error
}
EOL
if [ $? -ne 0 ]; then
    echo "Dante 配置文件写入失败。正在退出。"
    exit 1
fi
echo "Dante 配置文件 /etc/danted.conf 已创建/更新。"


# --- 5. 创建或更新代理用户 ---
echo "--- 5. 创建或更新代理用户 ---"
# 检查用户是否存在，如果不存在则创建
if ! id -u "$PROXY_USERNAME" >/dev/null 2>&1; then
    echo "创建用户 '$PROXY_USERNAME'..."
    useradd --shell /usr/sbin/nologin --no-create-home "$PROXY_USERNAME"
    if [ $? -ne 0 ]; then
        echo "用户 '$PROXY_USERNAME' 创建失败。正在退出。"
        exit 1
    fi
else
    echo "用户 '$PROXY_USERNAME' 已存在，正在更新密码..."
fi

# 设置用户密码
echo "$PROXY_USERNAME:$PROXY_PASSWORD" | chpasswd
if [ $? -ne 0 ]; then
    echo "用户 '$PROXY_USERNAME' 密码设置失败。正在退出。"
    exit 1
fi
echo "用户 '$PROXY_USERNAME' 密码已设置为固定密码。"


# --- 6. 启用并重启 Dante 服务 ---
echo "--- 6. 启用并重启 Dante 服务 ---"
# 确保服务启用 (开机自启)
systemctl enable danted
# 重启服务以应用配置更改
systemctl restart danted
# 检查服务状态
systemctl is-active --quiet danted
if [ $? -ne 0 ]; then
    echo "Dante 服务启动失败。请手动检查 'systemctl status danted' 获取详细信息。"
    exit 1
fi
echo "Dante 服务已成功启动并设置为开机自启。"

# --- 7. 配置防火墙 (UFW) ---
echo "--- 7. 配置防火墙 (UFW) ---"
if command -v ufw &> /dev/null; then
    echo "UFW 已安装，正在配置防火墙规则..."
    ufw allow "$SOCKS5_PORT"/tcp comment "Allow SOCKS5 Proxy"
    ufw reload
    # 再次检查防火墙状态确保规则生效
    ufw status | grep "$SOCKS5_PORT"
    echo "防火墙端口 $SOCKS5_PORT/TCP 已打开。"
else
    echo "UFW 未安装或未检测到。请手动配置您的服务器防火墙或云服务商的安全组/入站规则，开放 TCP 端口 $SOCKS5_PORT。"
fi

# --- 8. 获取公网 IP 并生成连接信息 ---
echo "--- 8. 获取公网 IP 并生成连接信息 ---"
PROXY_IP=$(curl -s ifconfig.me)
if [ -z "$PROXY_IP" ]; then
    echo "无法获取公网 IP。请手动获取你的 VPS 公网 IP。"
    PROXY_IP="你的VPS公网IP"
fi

CONNECTION_STRING="socks5://$PROXY_USERNAME:$PROXY_PASSWORD@$PROXY_IP:$SOCKS5_PORT"

# --- 9. 输出结果并测试连接 ---
echo -e "\n--- SOCKS5 代理安装完成！---"
echo "请记住以下代理信息："
echo "------------------------------------"
echo "代理类型: SOCKS5 (带认证)"
echo "IP 地址 : $PROXY_IP"
echo "端口    : $SOCKS5_PORT"
echo "用户名  : $PROXY_USERNAME"
echo "密码    : $PROXY_PASSWORD"
echo "连接字符串: $CONNECTION_STRING"
echo "------------------------------------"
echo "您现在可以将此连接字符串复制到 Telegram 或其他应用中使用了。"
echo -e "\n--- 正在尝试使用代理测试连接 (可能会稍等片刻) ---"

# 将测试结果保存到文件并输出
curl_output_file="socks5_test_result.txt"
echo "测试命令: curl --socks5 \"$PROXY_USERNAME:$PROXY_PASSWORD@$PROXY_IP:$SOCKS5_PORT\" http://ipinfo.io -m 15" > "$curl_output_file" 2>&1
# -m 15 设置15秒超时，避免长时间等待
curl --socks5 "$PROXY_USERNAME:$PROXY_PASSWORD@$PROXY_IP:$SOCKS5_PORT" http://ipinfo.io -m 15 >> "$curl_output_file" 2>&1

echo -e "\n--- 测试结果 (位于 ${curl_output_file}，也在此处显示)：---"
cat "$curl_output_file"

echo -e "\n--- 最终检查 ---"
echo "1. 确保您的云服务商防火墙/安全组已开放端口 $SOCKS5_PORT/TCP。"
echo "2. 如果测试失败，请检查用户名、密码、端口是否正确，并确保代理服务器已启动。"
echo "祝您使用愉快！"
