# PanSou Web Linux 部署指南

## 功能特性

- ✅ 网盘链接有效性检测（支持百度、阿里云、115、夸克、123、UC、天翼等主流网盘）
- ✅ 前端搜索结果失效标识
- ✅ 自动批量检测和手动重新检测
- ✅ 高性能反向代理配置
- ✅ 完整的监控和日志系统
- ✅ Docker 容器化部署

## 快速部署

### 方法一：自动化脚本部署（推荐）

```bash
# 下载部署脚本
wget https://raw.githubusercontent.com/your-repo/pansou-web/main/deploy-linux.sh

# 赋予执行权限
chmod +x deploy-linux.sh

# 执行部署（需要root权限）
sudo ./deploy-linux.sh
```

### 方法二：Docker Compose 部署

```bash
# 克隆项目
git clone https://github.com/your-repo/pansou-web.git
cd pansou-web

# 启动服务
docker-compose -f docker-compose.linux.yml up -d

# 查看服务状态
docker-compose -f docker-compose.linux.yml ps
```

### 方法三：手动部署

1. **安装依赖**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y nodejs npm nginx git

# CentOS/RHEL
sudo yum install -y nodejs npm nginx git
```

2. **部署应用**
```bash
# 克隆代码
git clone https://github.com/your-repo/pansou-web.git
cd pansou-web

# 安装依赖
npm install

# 构建前端
npm run build

# 配置 Nginx
sudo cp nginx.conf /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

## 网盘链接检测功能

### 支持的网盘类型

| 网盘类型 | 检测方式 | 支持状态 |
|---------|---------|---------|
| 百度网盘 | 页面内容分析 | ✅ |
| 阿里云盘 | API 接口 | ✅ |
| 115网盘 | API 接口 | ✅ |
| 夸克网盘 | API 接口 | ✅ |
| 123网盘 | API 接口 | ✅ |
| UC网盘 | 页面内容分析 | ✅ |
| 天翼云盘 | API 接口 | ✅ |

### 检测状态说明

- **🔵 检测中**：正在检查链接有效性
- **🟢 链接有效**：资源可以正常访问
- **🔴 资源失效**：链接已失效或不存在
- **🟡 需要提取码**：链接有效但需要密码
- **⚪ 未知状态**：检测失败或无法判断

## 系统要求

### 最低配置
- CPU：2核
- 内存：2GB
- 硬盘：20GB
- 系统：Ubuntu 18.04+ / CentOS 7+

### 推荐配置
- CPU：4核
- 内存：4GB
- 硬盘：50GB
- 系统：Ubuntu 20.04+ / CentOS 8+

## 端口配置

| 服务 | 端口 | 说明 |
|------|------|------|
| Nginx | 80/443 | Web 服务端口 |
| 前端应用 | 3000 | Vue.js 开发服务器 |
| PM2 管理 | 3000 | 生产环境应用端口 |
| Grafana | 3001 | 监控面板 |
| Prometheus | 9090 | 指标收集 |
| Elasticsearch | 9200 | 日志存储 |
| Kibana | 5601 | 日志查询 |

## 监控和日志

### 系统监控
```bash
# 查看应用状态
pm2 list

# 查看应用日志
pm2 logs pansouweb

# 系统资源监控
/usr/local/bin/monitor-pansouweb.sh
```

### Web 监控面板
- Grafana: http://your-server:3001 (admin/admin123)
- Kibana: http://your-server:5601

## 故障排除

### 常见问题

1. **Node.js 版本问题**
```bash
# 检查 Node.js 版本
node --version

# 如果版本过低，使用 nvm 安装新版本
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18
```

2. **端口冲突**
```bash
# 检查端口占用
netstat -tulpn | grep :80

# 停止冲突服务
sudo systemctl stop apache2
```

3. **SSL 证书问题**
```bash
# 测试 SSL 配置
sudo nginx -t

# 重新生成证书（如果使用 Let's Encrypt）
sudo certbot renew --force-renewal
```

4. **网盘检测失败**
```bash
# 检查网络连接
curl -I https://pan.baidu.com

# 查看检测日志
tail -f /var/log/pm2/pansouweb-out.log
```

### 性能优化建议

1. **启用 Gzip 压缩**
```nginx
# 在 nginx.conf 中确保 gzip 开启
gzip on;
gzip_types text/plain application/javascript application/css;
```

2. **配置缓存策略**
```nginx
# 静态资源长期缓存
location ~* \.(js|css|png|jpg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

3. **数据库优化**（如果使用数据库）
```sql
-- 定期优化表
OPTIMIZE TABLE search_results;
```

## 更新和维护

### 定期维护任务
```bash
# 更新代码
cd /var/www/pansouweb
git pull origin main
npm install
npm run build
pm2 restart all

# 清理日志
sudo logrotate -f /etc/logrotate.d/nginx
pm2 flush
```

### 备份策略
```bash
# 备份配置文件
tar -czf pansouweb-backup-$(date +%Y%m%d).tar.gz \
    /etc/nginx/nginx.conf \
    /var/www/pansouweb \
    /root/.pm2

# 定期备份（添加到 crontab）
0 2 * * * /root/backup-pansouweb.sh
```

## 安全建议

1. **防火墙配置**
```bash
# 只开放必要端口
sudo ufw allow 80,443,22
sudo ufw enable
```

2. **定期更新**
```bash
# 系统更新
sudo apt update && sudo apt upgrade

# 安全补丁
sudo unattended-upgrade
```

3. **监控安全事件**
```bash
# 查看失败登录尝试
sudo grep "Failed password" /var/log/auth.log

# 检查可疑进程
ps aux | grep -v grep | grep -E "(miner|backdoor)"
```

## 技术支持

如果遇到问题，请：

1. 查看日志文件：`/var/log/nginx/error.log` 和 `/var/log/pm2/pansouweb-out.log`
2. 检查系统资源：`top`, `free -h`, `df -h`
3. 测试网络连接：`ping pan.baidu.com`
4. 提交 Issue：https://github.com/your-repo/pansou-web/issues

## 许可证

本项目采用 MIT 许可证。详情请查看 LICENSE 文件。

---
*最后更新：2024年12月*