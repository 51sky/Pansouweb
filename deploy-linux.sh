#!/bin/bash

# PanSou Web Linux 部署脚本
# 适用于 Ubuntu/CentOS/Debian 等主流 Linux 发行版

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统类型
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log_info "检测到系统: $OS $VERSION"
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget git build-essential
            ;;
        centos|rhel|fedora)
            yum update -y
            yum install -y curl wget git gcc-c++ make
            ;;
        *)
            log_error "不支持的Linux发行版: $OS"
            exit 1
            ;;
    esac
}

# 安装 Node.js
install_nodejs() {
    log_info "检查 Node.js 安装..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_info "Node.js 已安装: $NODE_VERSION"
    else
        log_info "安装 Node.js 18 LTS..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
        
        # 验证安装
        if command -v node &> /dev/null; then
            log_success "Node.js 安装成功"
        else
            log_error "Node.js 安装失败"
            exit 1
        fi
    fi
}

# 安装 PM2
install_pm2() {
    log_info "安装 PM2 进程管理器..."
    npm install -g pm2
    
    # 创建 PM2 启动脚本
    cat > /etc/systemd/system/pm2.service << EOF
[Unit]
Description=PM2 Process Manager
Documentation=https://pm2.keymetrics.io/
After=network.target

[Service]
Type=forking
User=root
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Environment=PATH=/usr/bin:/bin:/usr/local/bin:/usr/sbin
Environment=PM2_HOME=/root/.pm2
PIDFile=/root/.pm2/pm2.pid
Restart=on-failure

ExecStart=/usr/bin/pm2 resurrect
ExecReload=/usr/bin/pm2 reload all
ExecStop=/usr/bin/pm2 save && /usr/bin/pm2 kill

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable pm2
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 3000/tcp
        ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --reload
    else
        log_warning "未找到防火墙工具，跳过防火墙配置"
    fi
}

# 安装 Nginx
install_nginx() {
    log_info "安装 Nginx..."
    
    case $OS in
        ubuntu|debian)
            apt-get install -y nginx
            ;;
        centos|rhel|fedora)
            yum install -y nginx
            ;;
    esac
    
    # 启动 Nginx
    systemctl enable nginx
    systemctl start nginx
}

# 配置 Nginx
configure_nginx() {
    log_info "配置 Nginx 反向代理..."
    
    cat > /etc/nginx/sites-available/pansouweb << EOF
server {
    listen 80;
    server_name _;
    
    # 前端静态文件
    location / {
        root /var/www/pansouweb/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # 缓存设置
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API 代理
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # 安全头设置
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/pansouweb /etc/nginx/sites-enabled/
    
    # 测试配置
    nginx -t
    
    # 重启 Nginx
    systemctl restart nginx
}

# 部署应用
deploy_application() {
    log_info "部署 PanSou Web 应用..."
    
    # 创建应用目录
    mkdir -p /var/www/pansouweb
    cd /var/www/pansouweb
    
    # 克隆代码（如果是从Git部署）
    if [ ! -d ".git" ]; then
        log_info "从Git仓库克隆代码..."
        git clone https://github.com/51sky/Pansouweb.git .
    else
        log_info "更新代码..."
        git pull origin main
    fi
    
    # 安装依赖
    log_info "安装项目依赖..."
    npm install
    
    # 构建项目
    log_info "构建前端应用..."
    npm run build
    
    # 检查构建结果
    if [ -d "dist" ]; then
        log_success "前端构建成功"
    else
        log_error "前端构建失败"
        exit 1
    fi
}

# 配置 PM2 应用
configure_pm2_app() {
    log_info "配置 PM2 应用..."
    
    cd /var/www/pansouweb
    
    # 创建 PM2 配置文件
    cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'pansouweb',
    script: 'npm',
    args: 'run preview',
    cwd: '/var/www/pansouweb',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/pm2/pansouweb-error.log',
    out_file: '/var/log/pm2/pansouweb-out.log',
    log_file: '/var/log/pm2/pansouweb-combined.log',
    time: true
  }]
}
EOF
    
    # 启动应用
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup
}

# 配置 SSL（可选）
configure_ssl() {
    log_info "配置 SSL 证书（可选）..."
    
    read -p "是否安装 SSL 证书？(y/n): " install_ssl
    
    if [[ $install_ssl =~ ^[Yy]$ ]]; then
        # 安装 Certbot
        case $OS in
            ubuntu|debian)
                apt-get install -y certbot python3-certbot-nginx
                ;;
            centos|rhel|fedora)
                yum install -y certbot python3-certbot-nginx
                ;;
        esac
        
        # 获取域名
        read -p "请输入域名: " domain_name
        
        if [ -n "$domain_name" ]; then
            # 获取证书
            certbot --nginx -d $domain_name
            
            # 设置自动续期
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            
            log_success "SSL 证书配置完成"
        else
            log_warning "未输入域名，跳过 SSL 配置"
        fi
    fi
}

# 系统优化
system_optimization() {
    log_info "进行系统优化..."
    
    # 优化文件描述符限制
    echo "* soft nofile 65536" >> /etc/security/limits.conf
    echo "* hard nofile 65536" >> /etc/security/limits.conf
    
    # 优化内核参数
    cat >> /etc/sysctl.conf << EOF
# PanSou Web 优化参数
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
EOF
    
    sysctl -p
}

# 创建监控脚本
create_monitoring() {
    log_info "创建系统监控脚本..."
    
    cat > /usr/local/bin/monitor-pansouweb.sh << EOF
#!/bin/bash

# PanSou Web 监控脚本

check_service() {
    service_name=\$1
    if systemctl is-active --quiet \$service_name; then
        echo "✓ \$service_name 运行正常"
    else
        echo "✗ \$service_name 服务异常"
        systemctl restart \$service_name
    fi
}

echo "=== PanSou Web 系统监控 ==="
echo "检查时间: \$(date)"

# 检查服务状态
check_service nginx
check_service pm2

# 检查磁盘空间
echo "磁盘使用情况:"
df -h /var/www/pansouweb | tail -1

# 检查内存使用
echo "内存使用情况:"
free -h

# 检查应用状态
if pm2 list | grep -q "online"; then
    echo "✓ PM2 应用运行正常"
else
    echo "✗ PM2 应用异常"
    pm2 restart all
fi

echo "=== 监控完成 ==="
EOF
    
    chmod +x /usr/local/bin/monitor-pansouweb.sh
    
    # 添加定时任务
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/monitor-pansouweb.sh >> /var/log/pansouweb-monitor.log 2>&1") | crontab -
}

# 主函数
main() {
    log_info "开始部署 PanSou Web..."
    
    # 检查权限
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
    
    # 执行部署步骤
    check_system
    install_dependencies
    install_nodejs
    install_pm2
    configure_firewall
    install_nginx
    configure_nginx
    deploy_application
    configure_pm2_app
    system_optimization
    create_monitoring
    
    # 可选 SSL 配置
    configure_ssl
    
    log_success "PanSou Web 部署完成！"
    log_info "访问地址: http://你的服务器IP"
    log_info "PM2 管理: pm2 list"
    log_info "Nginx 状态: systemctl status nginx"
    log_info "应用日志: tail -f /var/log/pm2/pansouweb-out.log"
}

# 执行主函数
main "$@"
