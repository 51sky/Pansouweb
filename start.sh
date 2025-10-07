#!/bin/sh
set -e

# 环境变量默认值
export PANSOU_PORT=${PANSOU_PORT:-8888}
export PANSOU_HOST=${PANSOU_HOST:-127.0.0.1}
export DOMAIN=${DOMAIN:-localhost}

echo "正在启动PanSou服务，配置信息如下："
echo "- 后端地址: ${PANSOU_HOST}:${PANSOU_PORT}"
echo "- 域名: ${DOMAIN}"
echo "- 前端目录: /app/frontend/dist"

# 创建必要的目录
mkdir -p /app/data
mkdir -p /app/logs
mkdir -p /var/log/nginx

# 检测SSL证书是否存在
SSL_AVAILABLE=false
if [ -f "/app/data/ssl/fullchain.pem" ] && [ -f "/app/data/ssl/privkey.pem" ]; then
    SSL_AVAILABLE=true
    echo "检测到SSL证书，将启用HTTPS"
else
    echo "未检测到SSL证书，将仅使用HTTP"
fi

# 动态生成Nginx配置
cat > /etc/nginx/conf.d/default.conf << EOF
# HTTP服务器
server {
    listen 80;
    server_name ${DOMAIN};
    
    # 设置客户端最大请求体大小
    client_max_body_size 50M;
    
    # 日志配置
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

$(if [ "$SSL_AVAILABLE" = true ]; then
    echo "    # 如果SSL可用，重定向到HTTPS"
    echo "    return 301 https://\$host\$request_uri;"
    echo "}"
    echo ""
    echo "# HTTPS服务器"
    echo "server {"
    echo "    listen 443 ssl http2;"
    echo "    server_name ${DOMAIN};"
    echo ""
    echo "    # SSL配置"
    echo "    ssl_certificate /app/data/ssl/fullchain.pem;"
    echo "    ssl_certificate_key /app/data/ssl/privkey.pem;"
    echo "    ssl_protocols TLSv1.2 TLSv1.3;"
    echo "    ssl_prefer_server_ciphers on;"
    echo "    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;"
    echo "    ssl_session_timeout 1d;"
    echo "    ssl_session_cache shared:SSL:10m;"
    echo "    ssl_session_tickets off;"
    echo ""
    echo "    # 安全头部"
    echo "    add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;"
    echo "    add_header X-Content-Type-Options nosniff;"
    echo "    add_header X-Frame-Options SAMEORIGIN;"
    echo "    add_header X-XSS-Protection \"1; mode=block\";"
    echo ""
    echo "    # 设置客户端最大请求体大小"
    echo "    client_max_body_size 50M;"
    echo ""
    echo "    # 日志配置"
    echo "    access_log /var/log/nginx/access.log;"
    echo "    error_log /var/log/nginx/error.log;"
else
    echo "    # HTTP配置"
fi)

    # API健康检查 - 优先级最高
    location = /api/health {
        proxy_pass http://${PANSOU_HOST}:${PANSOU_PORT}/api/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 10s;
        proxy_send_timeout 5s;
        proxy_buffering off;
    }

    # API搜索接口 - 优先级第二
    location = /api/search {
        proxy_pass http://${PANSOU_HOST}:${PANSOU_PORT}/api/search;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Referer \$http_referer;
        proxy_connect_timeout 15s;
        proxy_read_timeout 60s;
        proxy_send_timeout 15s;
        proxy_buffering off;
    }

    # 其他API请求 - 代理到Go后端
    location /api/ {
        proxy_pass http://${PANSOU_HOST}:${PANSOU_PORT}/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Referer \$http_referer;
        proxy_buffering off;
    }

    # 静态资源 - 启用缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /app/frontend/dist;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
        add_header X-Content-Type-Options nosniff;
    }

    # 前端应用 - SPA路由支持
    location / {
        root /app/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # 防止缓存HTML文件
        location ~* \.html$ {
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }
}
EOF

echo "Nginx配置已生成"

# 启动后端服务
echo "启动PanSou后端服务..."
cd /app
./pansou > /app/logs/pansou.log 2>&1 &

# 等待后端服务启动
echo "等待后端服务启动..."
for i in $(seq 1 30); do
    if curl -f http://${PANSOU_HOST}:${PANSOU_PORT}/api/health >/dev/null 2>&1; then
        echo "后端服务启动成功"
        break
    fi
    echo "等待后端服务... ($i/30)"
    sleep 1
done

# 检查后端服务是否启动成功
if ! curl -f http://${PANSOU_HOST}:${PANSOU_PORT}/api/health >/dev/null 2>&1; then
    echo "错误: 后端服务启动失败"
    cat /app/logs/pansou.log
    exit 1
fi

# 启动nginx
echo "启动Nginx服务..."
nginx -t && nginx -g "daemon off;"