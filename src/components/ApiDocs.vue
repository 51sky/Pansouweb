<template>
  <div class="api-docs">
    <div class="docs-header">
      <h1 class="docs-title">PanSou API 文档</h1>
      <p class="docs-subtitle">网盘资源搜索API服务</p>
    </div>

    <!-- API概览 -->
    <div class="api-overview">
      <div class="overview-card">
        <div class="card-icon">🔍</div>
        <div class="card-content">
          <h3>搜索API</h3>
          <p>强大的网盘资源搜索接口</p>
          <span class="endpoint">/api/search</span>
        </div>
      </div>
      <div class="overview-card">
        <div class="card-icon">🏥</div>
        <div class="card-content">
          <h3>健康检查</h3>
          <p>检查服务运行状态</p>
          <span class="endpoint">/api/health</span>
        </div>
      </div>
    </div>

    <!-- 导航选项卡 -->
    <div class="api-tabs">
      <button 
        v-for="tab in tabs" 
        :key="tab.id"
        @click="activeTab = tab.id"
        class="tab-button"
        :class="{ 'tab-active': activeTab === tab.id }"
      >
        <span class="tab-icon">{{ tab.icon }}</span>
        {{ tab.name }}
      </button>
    </div>

    <!-- 搜索API文档 -->
    <div v-if="activeTab === 'search'" class="api-section">
      <div class="api-header">
        <h2 class="api-title">🔍 搜索API</h2>
        <div class="api-methods">
          <span class="method-badge post">POST</span>
          <span class="method-badge get">GET</span>
          <span class="endpoint-url">/api/search</span>
        </div>
      </div>

      <div class="api-content">
        <!-- Authorization Header -->
        <div class="auth-header-section">
          <h3 class="section-title">{{ tokenFieldTitle }}</h3>
          <div class="auth-header-form">
            <div class="form-group">
              <label>Authorization Header:</label>
              <div class="auth-input-wrapper">
                <span class="auth-prefix">Bearer</span>
                <input 
                  v-model="authToken" 
                  class="form-input auth-input" 
                  :placeholder="effectiveToken || (authEnabled ? '请先登录或在认证API调试获取token' : '留空即可，未启用认证')"
                />
              </div>
              <p class="auth-hint">
                {{ tokenStatus }}
              </p>
              <p v-if="!authToken && effectiveToken" class="auth-hint" style="color: #2563eb;">
                💡 当前将使用: {{ effectiveToken.substring(0, 20) }}...
              </p>
            </div>
          </div>
        </div>
        
        <!-- 参数说明 -->
        <div class="params-section">
          <h3 class="section-title">📋 请求参数</h3>
          <div class="params-table">
            <div class="param-header">
              <span>参数名</span>
              <span>类型</span>
              <span>必填</span>
              <span>描述</span>
            </div>
            <div class="param-row" v-for="param in searchParams" :key="param.name">
              <span class="param-name">{{ param.name }}</span>
              <span class="param-type">{{ param.type }}</span>
              <span class="param-required" :class="{ 'required': param.required }">
                {{ param.required ? '是' : '否' }}
              </span>
              <span class="param-desc">{{ param.description }}</span>
            </div>
          </div>
        </div>

        <!-- 在线调试 -->
        <div class="debug-section">
          <h3 class="section-title">🛠️ 在线调试</h3>
          <div class="debug-form">
            <div class="form-group">
              <label>请求方法:</label>
              <select v-model="searchMethod" class="form-select">
                <option value="POST">POST</option>
                <option value="GET">GET</option>
              </select>
            </div>

            <div class="form-row">
              <div class="form-group">
                <label>结果类型:</label>
                <select v-model="searchForm.res" class="form-select">
                  <option value="merge">merge - 仅返回merged_by_type</option>
                  <option value="all">all - 返回所有结果</option>
                  <option value="results">results - 仅返回results</option>
                </select>
              </div>
              <div class="form-group">
                <label>数据来源:</label>
                <select v-model="searchForm.src" class="form-select" @change="onSourceChange">
                  <option value="all">all - 全部来源</option>
                  <option value="tg">tg - 仅Telegram</option>
                  <option value="plugin">plugin - 仅插件</option>
                </select>
              </div>
            </div>

            <div class="form-group">
              <label>关键词 *:</label>
              <input v-model="searchForm.kw" class="form-input" placeholder="输入搜索关键词" />
            </div>

            <div class="form-group">
              <label>网盘类型:</label>
              <input v-model="searchForm.cloud_types" class="form-input" placeholder="baidu,aliyun,quark等，用逗号分隔" />
            </div>
            
            <!-- 插件列表 - 只在非Telegram时显示 -->
            <div v-if="searchForm.src !== 'tg'" class="form-group conditional-field">
              <label>
                插件列表:
                <span class="field-status" v-if="searchForm.src === 'plugin'">仅插件模式</span>
              </label>
              <input v-model="searchForm.plugins" class="form-input" placeholder="插件名,用逗号分隔，留空使用默认" />
            </div>

            <!-- 频道列表 - 只在非仅插件时显示 -->
            <div v-if="searchForm.src !== 'plugin'" class="form-group conditional-field">
              <label>
                频道列表:
                <span class="field-status" v-if="searchForm.src === 'tg'">仅Telegram模式</span>
              </label>
              <input v-model="searchForm.channels" class="form-input" placeholder="频道名,用逗号分隔，留空使用默认" />
            </div>

            <div class="form-group">
              <label>扩展参数 (JSON):</label>
              <textarea v-model="searchForm.ext" class="form-textarea" placeholder='{"title_en":"English Title","is_all":true}'></textarea>
            </div>

            <div class="form-row">
              <div class="form-group">
                <label>并发数:</label>
                <input v-model.number="searchForm.conc" type="number" class="form-input" placeholder="默认自动" />
              </div>
              <div class="form-group">
                <label>强制刷新:</label>
                <input v-model="searchForm.refresh" type="checkbox" class="form-checkbox" />
              </div>
            </div>

            <div class="form-actions">
              <button @click="testSearchAPI" class="test-button" :disabled="searchLoading">
                <span class="button-icon">{{ searchLoading ? '⏳' : '🚀' }}</span>
                {{ searchLoading ? '请求中...' : '发送请求' }}
              </button>
              <button @click="clearSearchForm" class="clear-button">
                <span class="button-icon">🧹</span>
                清空表单
              </button>
            </div>
          </div>

          <!-- 请求预览 -->
          <div class="request-preview">
            <h4>请求预览:</h4>
            <div class="code-block">
              <pre><code>{{ generateSearchRequest() }}</code></pre>
              <button @click="copyToClipboard(generateSearchRequest())" class="copy-btn">📋</button>
            </div>
          </div>

          <!-- 响应结果 -->
          <div v-if="searchResponse" class="response-section">
            <h4>响应结果:</h4>
            <div class="response-status" :class="searchResponse.success ? 'success' : 'error'">
              <span class="status-icon">{{ searchResponse.success ? '✅' : '❌' }}</span>
              <span>{{ searchResponse.success ? '请求成功' : '请求失败' }}</span>
              <span class="status-code">{{ searchResponse.status }}</span>
            </div>
            <div class="code-block response-body">
              <pre><code>{{ JSON.stringify(searchResponse.data, null, 2) }}</code></pre>
              <button @click="copyToClipboard(JSON.stringify(searchResponse.data, null, 2))" class="copy-btn">📋</button>
            </div>
          </div>
        </div>

        <!-- 响应字段说明 -->
        <div class="response-fields">
          <h3 class="section-title">📊 响应字段</h3>
          <div class="params-table response-table">
            <div class="param-header response-header">
              <span>字段名</span>
              <span>类型</span>
              <span>描述</span>
            </div>
            <div class="param-row response-row" v-for="field in searchResponseFields" :key="field.name">
              <span class="param-name">{{ field.name }}</span>
              <span class="param-type">{{ field.type }}</span>
              <span class="param-desc">{{ field.description }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 认证API文档 -->
    <div v-if="activeTab === 'auth'" class="api-section">
      <div class="api-header">
        <h2 class="api-title">🔐 认证API</h2>
        <div class="api-methods">
          <span class="method-badge post">POST</span>
          <span class="endpoint-url">/api/auth/*</span>
        </div>
      </div>

      <div class="api-content">
        <!-- 在线调试 -->
        <div class="debug-section">
          <h3 class="section-title">🛠️ 在线调试</h3>
          <div class="debug-form">
            <div class="form-group">
              <label>接口类型:</label>
              <select v-model="authMethod" class="form-select">
                <option value="login">登录 - /api/auth/login</option>
                <option value="verify">验证 - /api/auth/verify</option>
                <option value="logout">登出 - /api/auth/logout</option>
              </select>
            </div>

            <div v-if="authMethod === 'login'" class="form-row">
              <div class="form-group">
                <label>用户名 *:</label>
                <input v-model="authForm.username" class="form-input" placeholder="输入用户名" />
              </div>
              <div class="form-group">
                <label>密码 *:</label>
                <input v-model="authForm.password" type="password" class="form-input" placeholder="输入密码" />
              </div>
            </div>

            <div v-if="authMethod === 'verify'" class="form-group">
              <p class="auth-hint" style="margin: 0;">
                💡 将使用调试token或当前登录token进行验证
              </p>
            </div>

            <div v-if="authMethod === 'logout'" class="form-group">
              <p class="auth-hint" style="margin: 0;">
                💡 退出登录将清除调试获取的token（不影响当前登录状态）
              </p>
            </div>

            <div class="form-actions">
              <button @click="testAuthAPI" class="test-button" :disabled="authLoading">
                <span class="button-icon">{{ authLoading ? '⏳' : '🚀' }}</span>
                {{ authLoading ? '请求中...' : '发送请求' }}
              </button>
              <button @click="clearAuthForm" class="clear-button">
                <span class="button-icon">🧹</span>
                清空
              </button>
            </div>
          </div>

          <!-- 请求预览 -->
          <div class="request-preview">
            <h4>请求预览:</h4>
            <div class="code-block">
              <pre><code>{{ generateAuthRequest() }}</code></pre>
              <button @click="copyToClipboard(generateAuthRequest())" class="copy-btn">📋</button>
            </div>
          </div>

          <!-- 响应结果 -->
          <div v-if="authResponse" class="response-section">
            <h4>响应结果:</h4>
            <div class="response-status" :class="authResponse.success ? 'success' : 'error'">
              <span class="status-icon">{{ authResponse.success ? '✅' : '❌' }}</span>
              <span>{{ authResponse.success ? '请求成功' : '请求失败' }}</span>
              <span class="status-code">{{ authResponse.status }}</span>
            </div>
            <div class="code-block response-body">
              <pre><code>{{ JSON.stringify(authResponse.data, null, 2) }}</code></pre>
              <button @click="copyToClipboard(JSON.stringify(authResponse.data, null, 2))" class="copy-btn">📋</button>
            </div>
          </div>
        </div>

        <!-- 接口说明 -->
        <div class="response-fields">
          <h3 class="section-title">📋 接口详细说明</h3>
          
          <!-- 登录接口 -->
          <div class="info-card" style="margin-bottom: 2rem;">
            <h4 style="font-size: 1.25rem; margin-bottom: 1rem;">🔓 登录接口 - /api/auth/login</h4>
            <div class="params-table">
              <div class="param-header">
                <span>参数名</span>
                <span>类型</span>
                <span>必填</span>
                <span>描述</span>
              </div>
              <div class="param-row">
                <span class="param-name">username</span>
                <span class="param-type">string</span>
                <span class="param-required required">是</span>
                <span class="param-desc">用户名</span>
              </div>
              <div class="param-row">
                <span class="param-name">password</span>
                <span class="param-type">string</span>
                <span class="param-required required">是</span>
                <span class="param-desc">密码</span>
              </div>
            </div>
            <div style="margin-top: 1rem;">
              <strong>响应示例:</strong>
              <div class="code-block" style="margin-top: 0.5rem;">
                <pre><code>{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": 1234567890,
  "username": "admin"
}</code></pre>
              </div>
            </div>
          </div>

          <!-- 验证接口 -->
          <div class="info-card" style="margin-bottom: 2rem;">
            <h4 style="font-size: 1.25rem; margin-bottom: 1rem;">✅ 验证接口 - /api/auth/verify</h4>
            <p style="margin-bottom: 1rem; color: hsl(var(--muted-foreground));">
              需要在请求头中携带 <code>Authorization: Bearer &lt;token&gt;</code>
            </p>
            <div style="margin-top: 1rem;">
              <strong>响应示例 (成功):</strong>
              <div class="code-block" style="margin-top: 0.5rem;">
                <pre><code>{
  "valid": true,
  "username": "admin"
}</code></pre>
              </div>
            </div>
            <div style="margin-top: 1rem;">
              <strong>响应示例 (失败):</strong>
              <div class="code-block" style="margin-top: 0.5rem;">
                <pre><code>{
  "error": "未授权：令牌无效或已过期",
  "code": "AUTH_TOKEN_INVALID"
}</code></pre>
              </div>
            </div>
          </div>

          <!-- 退出接口 -->
          <div class="info-card">
            <h4 style="font-size: 1.25rem; margin-bottom: 1rem;">🚪 退出接口 - /api/auth/logout</h4>
            <p style="color: hsl(var(--muted-foreground));">
              JWT是无状态的,服务端不需要处理注销。客户端删除存储的token即可。
            </p>
            <div style="margin-top: 1rem;">
              <strong>响应示例:</strong>
              <div class="code-block" style="margin-top: 0.5rem;">
                <pre><code>{
  "message": "退出成功"
}</code></pre>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 健康检查API文档 -->
    <div v-if="activeTab === 'health'" class="api-section">
      <div class="api-header">
        <h2 class="api-title">🏥 健康检查API</h2>
        <div class="api-methods">
          <span class="method-badge get">GET</span>
          <span class="endpoint-url">/api/health</span>
        </div>
      </div>

      <div class="api-content">
        <!-- 接口说明 -->
        <div class="desc-section">
          <h3 class="section-title">📝 接口说明</h3>
          <p class="api-description">检查API服务是否正常运行，返回服务状态、可用频道列表和插件信息。</p>
        </div>

        <!-- 在线调试 -->
        <div class="debug-section">
          <h3 class="section-title">🛠️ 在线调试</h3>
          <div class="debug-form">
            <div class="form-actions">
              <button @click="testHealthAPI" class="test-button" :disabled="healthLoading">
                <span class="button-icon">{{ healthLoading ? '⏳' : '🚀' }}</span>
                {{ healthLoading ? '请求中...' : '发送请求' }}
              </button>
            </div>
          </div>

          <!-- 请求预览 -->
          <div class="request-preview">
            <h4>请求预览:</h4>
            <div class="code-block">
              <pre><code>GET /api/health</code></pre>
              <button @click="copyToClipboard('GET /api/health')" class="copy-btn">📋</button>
            </div>
          </div>

          <!-- 响应结果 -->
          <div v-if="healthResponse" class="response-section">
            <h4>响应结果:</h4>
            <div class="response-status" :class="healthResponse.success ? 'success' : 'error'">
              <span class="status-icon">{{ healthResponse.success ? '✅' : '❌' }}</span>
              <span>{{ healthResponse.success ? '请求成功' : '请求失败' }}</span>
              <span class="status-code">{{ healthResponse.status }}</span>
            </div>
            <div class="code-block response-body">
              <pre><code>{{ JSON.stringify(healthResponse.data, null, 2) }}</code></pre>
              <button @click="copyToClipboard(JSON.stringify(healthResponse.data, null, 2))" class="copy-btn">📋</button>
            </div>
          </div>
        </div>

        <!-- 响应字段说明 -->
        <div class="response-fields">
          <h3 class="section-title">📊 响应字段</h3>
          <div class="params-table">
            <div class="param-header">
              <span>字段名</span>
              <span>类型</span>
              <span>描述</span>
            </div>
            <div class="param-row" v-for="field in healthResponseFields" :key="field.name">
              <span class="param-name">{{ field.name }}</span>
              <span class="param-type">{{ field.type }}</span>
              <span class="param-desc">{{ field.description }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 通用说明 -->
    <div v-if="activeTab === 'general'" class="api-section">
      <div class="api-header">
        <h2 class="api-title">📖 通用说明</h2>
      </div>

      <div class="api-content">
        <div class="general-info">
          <div class="info-card">
            <h3>🌐 支持的网盘类型</h3>
            <div class="cloud-types">
              <span v-for="type in cloudTypes" :key="type.id" class="cloud-tag">
                <span class="cloud-icon">{{ type.icon }}</span>
                {{ type.name }}
                <code>{{ type.id }}</code>
              </span>
            </div>
          </div>

          <div class="info-card">
            <h3>⚡ 性能特性</h3>
            <ul class="feature-list">
              <li>🚀 高性能并发搜索，支持同时搜索多个TG频道和插件</li>
              <li>🧠 智能排序算法，基于插件等级、时间新鲜度和关键词匹配</li>
              <li>💾 分片缓存机制，内存+磁盘双重缓存提升响应速度</li>
              <li>🔄 异步插件系统，"尽快响应，持续处理"的搜索模式</li>
              <li>📊 自动网盘类型识别和分类展示</li>
            </ul>
          </div>

          <div class="info-card">
            <h3>🛡️ 错误处理</h3>
            <div class="error-codes">
              <div class="error-item">
                <span class="error-code">400</span>
                <span>参数错误 - 关键词不能为空或参数格式错误</span>
              </div>
              <div class="error-item">
                <span class="error-code">500</span>
                <span>服务器错误 - 服务内部错误</span>
              </div>
              <div class="error-item">
                <span class="error-code">429</span>
                <span>请求过频 - 超过限流阈值</span>
              </div>
            </div>
          </div>

          <div class="info-card">
            <h3>💡 使用建议</h3>
            <div class="tips">
              <div class="tip-item">
                <span class="tip-icon">🎯</span>
                <div>
                  <strong>关键词优化：</strong>使用准确的关键词能获得更好的搜索结果
                </div>
              </div>
              <div class="tip-item">
                <span class="tip-icon">⚡</span>
                <div>
                  <strong>缓存利用：</strong>相同搜索会使用缓存，设置refresh=true可强制获取最新数据
                </div>
              </div>
              <div class="tip-item">
                <span class="tip-icon">🔄</span>
                <div>
                  <strong>异步模式：</strong>插件搜索采用异步模式，可能会有延迟返回更多结果
                </div>
              </div>
              <div class="tip-item">
                <span class="tip-icon">🎛️</span>
                <div>
                  <strong>参数调优：</strong>根据需要调整并发数、网盘类型等参数优化搜索效果
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import axios from 'axios';

// 当前激活的选项卡
const activeTab = ref('search');

// 选项卡配置
const tabs = [
  { id: 'search', name: '搜索API', icon: '🔍' },
  { id: 'auth', name: '认证API', icon: '🔐' },
  { id: 'health', name: '健康检查', icon: '🏥' },
  { id: 'general', name: '通用说明', icon: '📖' }
];

// 搜索API参数配置
const searchParams = [
  { name: 'kw', type: 'string', required: true, description: '搜索关键词' },
  { name: 'channels', type: 'string[]', required: false, description: '搜索的频道列表，不提供则使用默认配置' },
  { name: 'conc', type: 'number', required: false, description: '并发搜索数量，不提供则自动设置' },
  { name: 'refresh', type: 'boolean', required: false, description: '强制刷新，不使用缓存' },
  { name: 'res', type: 'string', required: false, description: '结果类型：all/results/merge，默认merge' },
  { name: 'src', type: 'string', required: false, description: '数据来源：all/tg/plugin，默认all' },
  { name: 'plugins', type: 'string[]', required: false, description: '指定搜索的插件列表' },
  { name: 'cloud_types', type: 'string[]', required: false, description: '指定返回的网盘类型列表' },
  { name: 'ext', type: 'object', required: false, description: '扩展参数，传递给插件的自定义参数' }
];

// 搜索API响应字段
const searchResponseFields = [
  { name: 'total', type: 'number', description: '搜索结果总数' },
  { name: 'results', type: 'object[]', description: '搜索结果数组，包含详细信息' },
  { name: 'results[].message_id', type: 'string', description: 'TG消息ID' },
  { name: 'results[].unique_id', type: 'string', description: '全局唯一ID' },
  { name: 'results[].channel', type: 'string', description: '来源频道名称' },
  { name: 'results[].datetime', type: 'string', description: '发布时间(ISO格式)' },
  { name: 'results[].title', type: 'string', description: '消息标题' },
  { name: 'results[].content', type: 'string', description: '消息内容' },
  { name: 'results[].links', type: 'object[]', description: '包含的网盘链接数组' },
  { name: 'results[].tags', type: 'string[]', description: '消息标签(可选)' },
  { name: 'results[].images', type: 'string[]', description: '图片链接(可选)' },
  { name: 'merged_by_type', type: 'object', description: '按网盘类型分组的链接' },
  { name: 'merged_by_type.{type}', type: 'object[]', description: '特定网盘类型的链接数组' },
  { name: 'merged_by_type.{type}[].url', type: 'string', description: '网盘链接地址' },
  { name: 'merged_by_type.{type}[].password', type: 'string', description: '提取码/密码' },
  { name: 'merged_by_type.{type}[].note', type: 'string', description: '资源说明/标题' },
  { name: 'merged_by_type.{type}[].datetime', type: 'string', description: '发布时间' },
  { name: 'merged_by_type.{type}[].source', type: 'string', description: '数据来源(tg:频道名 或 plugin:插件名)' },
  { name: 'merged_by_type.{type}[].images', type: 'string[]', description: '图片链接(可选)' }
];

// 健康检查响应字段
const healthResponseFields = [
  { name: 'status', type: 'string', description: '服务状态，"ok"表示正常' },
  { name: 'plugins_enabled', type: 'boolean', description: '插件是否启用' },
  { name: 'plugin_count', type: 'number', description: '可用插件数量' },
  { name: 'plugins', type: 'string[]', description: '可用插件列表' },
  { name: 'channels', type: 'string[]', description: '配置的频道列表' },
  { name: 'channels_count', type: 'number', description: '频道数量' },
  { name: 'auth_enabled', type: 'boolean', description: '是否启用认证功能（true=已启用，所有API需要token；false=未启用，不需要token）' }
];

// 网盘类型配置
const cloudTypes = [
  { id: 'baidu', name: '百度网盘', icon: '🔵' },
  { id: 'aliyun', name: '阿里云盘', icon: '🟠' },
  { id: 'quark', name: '夸克网盘', icon: '🟡' },
  { id: 'tianyi', name: '天翼云盘', icon: '🔴' },
  { id: 'uc', name: 'UC网盘', icon: '🟢' },
  { id: 'mobile', name: '移动云盘', icon: '🔵' },
  { id: '115', name: '115网盘', icon: '🟣' },
  { id: 'pikpak', name: 'PikPak', icon: '🌈' },
  { id: 'xunlei', name: '迅雷网盘', icon: '⚡' },
  { id: '123', name: '123网盘', icon: '🎯' },
  { id: 'magnet', name: '磁力链接', icon: '🧲' },
  { id: 'ed2k', name: '电驴链接', icon: '🔗' }
];

// 搜索表单数据
const searchMethod = ref('POST');
const searchForm = ref({
  kw: '',
  channels: '',
  plugins: '',
  conc: null as number | null,
  refresh: false,
  res: 'merge',
  src: 'all',
  cloud_types: '',
  ext: ''
});

// 加载状态
const searchLoading = ref(false);
const healthLoading = ref(false);

// 响应数据
const searchResponse = ref<any>(null);
const healthResponse = ref<any>(null);
const authResponse = ref<any>(null);

// 认证相关状态
const authMethod = ref<'login' | 'verify' | 'logout'>('login');
const authForm = ref({
  username: '',
  password: ''
});
const authLoading = ref(false);
const debugToken = ref(''); // 调试获取的token
const authToken = ref(''); // 用户在搜索API中手动输入的token
const authEnabled = ref<boolean>(false); // 后端是否启用认证

// 获取当前存储的token（避免在模板中直接访问localStorage）
const storedToken = computed(() => {
  if (typeof window !== 'undefined' && window.localStorage) {
    return localStorage.getItem('auth_token');
  }
  return null;
});

// 获取有效的token（按优先级）
const effectiveToken = computed(() => {
  return authToken.value || debugToken.value || storedToken.value || '';
});

// token状态提示
const tokenStatus = computed(() => {
  if (authToken.value) return '🔵 使用手动输入的token';
  if (debugToken.value) return '🟢 使用调试获取的token';
  if (storedToken.value) return '🟡 使用当前登录token';
  if (authEnabled.value) return '🔴 后端已启用认证：必须填写token（请先登录或在认证API调试获取）';
  return '⚪ 后端未启用认证：留空即可，无需填写token';
});

// token字段标题
const tokenFieldTitle = computed(() => {
  if (authEnabled.value) {
    return '🔑 认证令牌 (后端启用认证时必填)';
  }
  return '🔑 认证令牌 (后端未启用认证时不用填)';
});

// 生成搜索请求预览
const generateSearchRequest = () => {
  const token = effectiveToken.value;
  const authHeader = token ? `Authorization: Bearer ${token}\n` : '';
  
  if (searchMethod.value === 'POST') {
    const payload: any = {
      kw: searchForm.value.kw || 'example'
    };
    
    if (searchForm.value.channels) {
      payload.channels = searchForm.value.channels.split(',').map(c => c.trim());
    }
    if (searchForm.value.plugins) {
      payload.plugins = searchForm.value.plugins.split(',').map(c => c.trim());
    }
    if (searchForm.value.conc) payload.conc = searchForm.value.conc;
    if (searchForm.value.refresh) payload.refresh = searchForm.value.refresh;
    if (searchForm.value.res !== 'merge') payload.res = searchForm.value.res;
    if (searchForm.value.src !== 'all') payload.src = searchForm.value.src;
    if (searchForm.value.cloud_types) {
      payload.cloud_types = searchForm.value.cloud_types.split(',').map(c => c.trim());
    }
    if (searchForm.value.ext) {
      try {
        payload.ext = JSON.parse(searchForm.value.ext);
      } catch (e) {
        // 忽略JSON解析错误
      }
    }

    return `POST /api/search
${authHeader}Content-Type: application/json

${JSON.stringify(payload, null, 2)}`;
  } else {
    const params = new URLSearchParams();
    params.append('kw', searchForm.value.kw || 'example');
    
    if (searchForm.value.channels) params.append('channels', searchForm.value.channels);
    if (searchForm.value.plugins) params.append('plugins', searchForm.value.plugins);
    if (searchForm.value.conc) params.append('conc', searchForm.value.conc.toString());
    if (searchForm.value.refresh) params.append('refresh', 'true');
    if (searchForm.value.res !== 'merge') params.append('res', searchForm.value.res);
    if (searchForm.value.src !== 'all') params.append('src', searchForm.value.src);
    if (searchForm.value.cloud_types) params.append('cloud_types', searchForm.value.cloud_types);
    if (searchForm.value.ext) params.append('ext', searchForm.value.ext);

    return `GET /api/search?${params.toString()}
${authHeader}`;
  }
};

// 测试搜索API
const testSearchAPI = async () => {
  if (!searchForm.value.kw) {
    alert('请输入搜索关键词');
    return;
  }

  searchLoading.value = true;
  searchResponse.value = null;

  try {
    const token = effectiveToken.value;
    const headers: any = {};
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
    
    let response;
    
    if (searchMethod.value === 'POST') {
      const payload: any = {
        kw: searchForm.value.kw
      };
      
      if (searchForm.value.channels) {
        payload.channels = searchForm.value.channels.split(',').map(c => c.trim());
      }
      if (searchForm.value.plugins) {
        payload.plugins = searchForm.value.plugins.split(',').map(c => c.trim());
      }
      if (searchForm.value.conc) payload.conc = searchForm.value.conc;
      if (searchForm.value.refresh) payload.refresh = searchForm.value.refresh;
      if (searchForm.value.res !== 'merge') payload.res = searchForm.value.res;
      if (searchForm.value.src !== 'all') payload.src = searchForm.value.src;
      if (searchForm.value.cloud_types) {
        payload.cloud_types = searchForm.value.cloud_types.split(',').map(c => c.trim());
      }
      if (searchForm.value.ext) {
        try {
          payload.ext = JSON.parse(searchForm.value.ext);
        } catch (e) {
          alert('扩展参数JSON格式错误');
          return;
        }
      }

      response = await axios.post('/api/search', payload, { headers });
    } else {
      const params = new URLSearchParams();
      params.append('kw', searchForm.value.kw);
      
      if (searchForm.value.channels) params.append('channels', searchForm.value.channels);
      if (searchForm.value.plugins) params.append('plugins', searchForm.value.plugins);
      if (searchForm.value.conc) params.append('conc', searchForm.value.conc.toString());
      if (searchForm.value.refresh) params.append('refresh', 'true');
      if (searchForm.value.res !== 'merge') params.append('res', searchForm.value.res);
      if (searchForm.value.src !== 'all') params.append('src', searchForm.value.src);
      if (searchForm.value.cloud_types) params.append('cloud_types', searchForm.value.cloud_types);
      if (searchForm.value.ext) params.append('ext', searchForm.value.ext);

      response = await axios.get(`/api/search?${params.toString()}`, { headers });
    }

    searchResponse.value = {
      success: true,
      status: response.status,
      data: response.data
    };
  } catch (error: any) {
    searchResponse.value = {
      success: false,
      status: error.response?.status || 0,
      data: error.response?.data || { message: error.message }
    };
  } finally {
    searchLoading.value = false;
  }
};

// 测试健康检查API
const testHealthAPI = async () => {
  healthLoading.value = true;
  healthResponse.value = null;

  try {
    const response = await axios.get('/api/health');
    healthResponse.value = {
      success: true,
      status: response.status,
      data: response.data
    };
  } catch (error: any) {
    healthResponse.value = {
      success: false,
      status: error.response?.status || 0,
      data: error.response?.data || { message: error.message }
    };
  } finally {
    healthLoading.value = false;
  }
};

// 数据来源变化处理
const onSourceChange = () => {
  // 当切换到仅插件时，清空频道列表
  if (searchForm.value.src === 'plugin') {
    searchForm.value.channels = '';
  }
  // 当切换到仅Telegram时，清空插件列表
  if (searchForm.value.src === 'tg') {
    searchForm.value.plugins = '';
  }
};

// 清空搜索表单
const clearSearchForm = () => {
  searchForm.value = {
    kw: '',
    channels: '',
    plugins: '',
    conc: null,
    refresh: false,
    res: 'merge',
    src: 'all',
    cloud_types: '',
    ext: ''
  };
  searchResponse.value = null;
};

// 生成认证请求预览
const generateAuthRequest = () => {
  if (authMethod.value === 'login') {
    const payload = {
      username: authForm.value.username || 'example',
      password: authForm.value.password || 'password'
    };
    return `POST /api/auth/login
Content-Type: application/json

${JSON.stringify(payload, null, 2)}`;
  } else if (authMethod.value === 'verify') {
    const token = debugToken.value || localStorage.getItem('auth_token') || 'your_token_here';
    return `POST /api/auth/verify
Authorization: Bearer ${token}`;
  } else {
    return `POST /api/auth/logout`;
  }
};

// 测试认证API
const testAuthAPI = async () => {
  authLoading.value = true;
  authResponse.value = null;

  try {
    let response;
    
    if (authMethod.value === 'login') {
      if (!authForm.value.username || !authForm.value.password) {
        alert('请输入用户名和密码');
        authLoading.value = false;
        return;
      }
      
      response = await axios.post('/api/auth/login', {
        username: authForm.value.username,
        password: authForm.value.password
      });
      
      // 登录成功，保存调试token并自动填充到搜索API
      if (response.data.token) {
        debugToken.value = response.data.token;
        // 如果用户没有手动输入token，则不需要设置 authToken
        // 因为 effectiveToken 会自动使用 debugToken
      }
    } else if (authMethod.value === 'verify') {
      const token = debugToken.value || localStorage.getItem('auth_token');
      response = await axios.post('/api/auth/verify', {}, {
        headers: {
          Authorization: `Bearer ${token}`
        }
      });
    } else {
      response = await axios.post('/api/auth/logout');
      debugToken.value = '';
      authToken.value = '';
    }

    authResponse.value = {
      success: true,
      status: response.status,
      data: response.data
    };
  } catch (error: any) {
    authResponse.value = {
      success: false,
      status: error.response?.status || 0,
      data: error.response?.data || { message: error.message }
    };
  } finally {
    authLoading.value = false;
  }
};

// 清空认证表单
const clearAuthForm = () => {
  authForm.value = {
    username: '',
    password: ''
  };
  authResponse.value = null;
};

// 加载健康状态并检查认证状态
const loadHealthStatus = async () => {
  try {
    const response = await axios.get('/api/health');
    if (response.data && typeof response.data.auth_enabled === 'boolean') {
      authEnabled.value = response.data.auth_enabled;
    }
  } catch (error) {
    console.error('获取健康状态失败:', error);
  }
};

// 组件加载时获取健康状态
loadHealthStatus();

// 复制到剪贴板
const copyToClipboard = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text);
    // 创建临时的成功提示
    const toast = document.createElement('div');
    toast.textContent = '✅ 已复制到剪贴板!';
    toast.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: #059669;
      color: white;
      padding: 12px 20px;
      border-radius: 8px;
      z-index: 10000;
      font-size: 14px;
      font-weight: 500;
      box-shadow: 0 4px 12px rgba(5, 150, 105, 0.3);
      animation: slideIn 0.3s ease-out;
    `;
    
    // 添加CSS动画
    if (!document.querySelector('#toast-styles')) {
      const style = document.createElement('style');
      style.id = 'toast-styles';
      style.textContent = `
        @keyframes slideIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        @keyframes slideOut {
          from { transform: translateX(0); opacity: 1; }
          to { transform: translateX(100%); opacity: 0; }
        }
      `;
      document.head.appendChild(style);
    }
    
    document.body.appendChild(toast);
    
    // 3秒后移除
    setTimeout(() => {
      toast.style.animation = 'slideOut 0.3s ease-out';
      setTimeout(() => {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 300);
    }, 3000);
  } catch (err) {
    console.error('复制失败:', err);
    alert('复制失败，请手动复制');
  }
};
</script>

<style scoped>
.api-docs {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

.docs-header {
  text-align: center;
  margin-bottom: 3rem;
}

.docs-title {
  font-size: 3rem;
  font-weight: 700;
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 1rem;
}

.docs-subtitle {
  font-size: 1.25rem;
  color: hsl(var(--muted-foreground));
  margin: 0;
}

.api-overview {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
  margin-bottom: 3rem;
}

.overview-card {
  display: flex;
  align-items: center;
  padding: 2rem;
  background: hsl(var(--card));
  border: 1px solid hsl(var(--border));
  border-radius: 12px;
  transition: all 0.3s ease;
}

.overview-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(37, 99, 235, 0.15);
  border-color: #93c5fd;
}

.card-icon {
  font-size: 3rem;
  margin-right: 1.5rem;
}

.card-content h3 {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0 0 0.5rem 0;
  color: hsl(var(--foreground));
}

.card-content p {
  color: hsl(var(--muted-foreground));
  margin: 0 0 0.75rem 0;
}

.endpoint {
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
  color: hsl(var(--accent-foreground));
  padding: 0.25rem 0.75rem;
  border-radius: 6px;
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 0.875rem;
}

.api-tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 2rem;
  border-bottom: 1px solid hsl(var(--border));
}

.tab-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1.5rem;
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-size: 1rem;
  font-weight: 500;
  color: hsl(var(--muted-foreground));
  transition: all 0.2s ease;
}

.tab-button:hover {
  color: hsl(var(--foreground));
}

.tab-button.tab-active {
  color: #2563eb;
  border-bottom-color: #2563eb;
  background: rgba(37, 99, 235, 0.05);
}

.tab-icon {
  font-size: 1.25rem;
}

.api-section {
  background: hsl(var(--card));
  border: 1px solid hsl(var(--border));
  border-radius: 12px;
  overflow: hidden;
}

.api-header {
  padding: 2rem;
  border-bottom: 1px solid hsl(var(--border));
}

.api-title {
  font-size: 2rem;
  font-weight: 600;
  margin: 0 0 1rem 0;
  color: hsl(var(--foreground));
}

.api-methods {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
}

.method-badge {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-weight: 600;
  font-size: 0.875rem;
  text-transform: uppercase;
}

.method-badge.post {
  background: #059669;
  color: white;
  border: 1px solid #065f46;
}

.method-badge.get {
  background: #2563eb;
  color: white;
  border: 1px solid #1e40af;
}

.endpoint-url {
  font-family: 'Monaco', 'Menlo', monospace;
  background: hsl(var(--background));
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid hsl(var(--border));
}

.api-content {
  padding: 2rem;
}

.section-title {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0 0 1.5rem 0;
  color: hsl(var(--foreground));
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.params-section {
  margin-bottom: 3rem;
}

.params-table {
  background: hsl(var(--background));
  border: 1px solid hsl(var(--border));
  border-radius: 8px;
  overflow: hidden;
}

.param-header {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 2fr;
  gap: 1rem;
  padding: 1rem;
  font-weight: 600;
  border-bottom: 1px solid hsl(var(--border));
}

.param-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 2fr;
  gap: 1rem;
  padding: 1rem;
  border-bottom: 1px solid hsl(var(--border));
  align-items: center;
}

.param-row:last-child {
  border-bottom: none;
}

.param-name {
  font-family: 'Monaco', 'Menlo', monospace;
  font-weight: 600;
  color: #1d4ed8;
}

.param-type {
  font-family: 'Monaco', 'Menlo', monospace;
  color: hsl(var(--muted-foreground));
  font-size: 0.875rem;
}

.param-required.required {
  color: #ef4444;
  font-weight: 600;
}

.param-desc {
  color: hsl(var(--muted-foreground));
}

.debug-section {
  margin-bottom: 3rem;
}

.debug-form {
  background: hsl(var(--background));
  padding: 2rem;
  border: 1px solid hsl(var(--border));
  border-radius: 8px;
  margin-bottom: 2rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: hsl(var(--foreground));
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}

.form-input, .form-select, .form-textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid hsl(var(--border));
  border-radius: 6px;
  background: hsl(var(--background));
  color: hsl(var(--foreground));
  font-size: 1rem;
  transition: border-color 0.2s ease;
}

.form-input:focus, .form-select:focus, .form-textarea:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.1);
}

.form-textarea {
  min-height: 100px;
  resize: vertical;
  font-family: 'Monaco', 'Menlo', monospace;
}

.form-checkbox {
  transform: scale(1.2);
}

.form-actions {
  display: flex;
  gap: 1rem;
  margin-top: 2rem;
}

.test-button, .clear-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.test-button {
  background: #2563eb;
  color: white;
  border: 1px solid #1d4ed8;
}

.test-button:hover:not(:disabled) {
  background: #2563eb;
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(29, 78, 216, 0.3);
}

.test-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.clear-button {
  background: hsl(var(--secondary));
  color: hsl(var(--secondary-foreground));
}

.clear-button:hover {
  background: hsl(var(--secondary) / 0.8);
}

.button-icon {
  font-size: 1.125rem;
}

.request-preview, .response-section {
  margin-bottom: 2rem;
}

.request-preview h4, .response-section h4 {
  margin: 0 0 1rem 0;
  font-weight: 600;
  color: hsl(var(--foreground));
}

.code-block {
  position: relative;
  background: hsl(var(--background));
  border: 1px solid hsl(var(--border));
  border-radius: 8px;
  overflow: hidden;
}

.code-block pre {
  margin: 0;
  padding: 1.5rem;
  overflow-x: auto;
}

.code-block code {
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 0.875rem;
  line-height: 1.5;
  color: hsl(var(--foreground));
}

.copy-btn {
  position: absolute;
  top: 1rem;
  right: 1rem;
  background: #2563eb;
  border: 1px solid hsl(var(--border));
  border-radius: 4px;
  padding: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
  transition: all 0.2s ease;
}

.copy-btn:hover {
  background: hsl(var(--accent) / 0.8);
}

.response-section {
  border-top: 1px solid hsl(var(--border));
  padding-top: 2rem;
}

.response-status {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  border-radius: 6px;
  margin-bottom: 1rem;
  font-weight: 600;
}

.response-status.success {
  background: #dcfdf7;
  color: #065f46;
  border: 1px solid #059669;
}

.response-status.error {
  background: #fef2f2;
  color: #991b1b;
  border: 1px solid #dc2626;
}

.status-icon {
  font-size: 1.25rem;
}

.status-code {
  background: hsl(var(--background));
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 0.875rem;
  margin-left: auto;
}

.response-body {
  max-height: 500px;
  overflow-y: auto;
}

/* 通用说明页面样式 */
.general-info {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.info-card {
  background: hsl(var(--background));
  padding: 2rem;
  border: 1px solid hsl(var(--border));
  border-radius: 8px;
}

.info-card h3 {
  margin: 0 0 1.5rem 0;
  font-size: 1.5rem;
  font-weight: 600;
  color: hsl(var(--foreground));
}

.cloud-types {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.cloud-tag {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-size: 0.875rem;
  transition: all 0.2s ease;
}

.cloud-tag:hover {
  background: #e2e8f0;
  border-color: #cbd5e1;
}

.cloud-icon {
  font-size: 1rem;
}

.cloud-tag code {
  background: hsl(var(--background));
  padding: 0.125rem 0.375rem;
  border-radius: 4px;
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 0.75rem;
}

.feature-list {
  margin: 0;
  padding-left: 1.5rem;
  color: #64748b;
  line-height: 1.8;
}

.feature-list li {
  margin-bottom: 0.75rem;
  line-height: 1.6;
}

.error-codes {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.error-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  transition: all 0.2s ease;
}

.error-item:hover {
  background: #f1f5f9;
  border-color: #cbd5e1;
}

.error-code {
  background: #dc2626;
  color: white;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  font-weight: 600;
  font-family: 'Monaco', 'Menlo', monospace;
  min-width: 50px;
  text-align: center;
  border: 1px solid #991b1b;
}

.tips {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.tip-item {
  display: flex;
  gap: 1rem;
  align-items: flex-start;
}

.tip-icon {
  font-size: 1.5rem;
  flex-shrink: 0;
  margin-top: 0.125rem;
}

.tip-item strong {
  color: #1d4ed8;
  font-weight: 600;
}

.desc-section {
  margin-bottom: 3rem;
}

.api-description {
  font-size: 1.125rem;
  line-height: 1.6;
  color: hsl(var(--muted-foreground));
  margin: 0;
}

.response-fields {
  margin-bottom: 3rem;
}

.field-notes {
  margin-top: 2rem;
  padding: 1.5rem;
  background: hsl(var(--background));
  border: 1px solid hsl(var(--border));
  border-radius: 8px;
}

.field-notes h4 {
  margin: 0 0 1rem 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: hsl(var(--foreground));
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.notes-list {
  margin: 0;
  padding-left: 1.5rem;
  color: hsl(var(--muted-foreground));
  line-height: 1.7;
}

.notes-list li {
  margin-bottom: 0.75rem;
  line-height: 1.6;
}

.notes-list strong {
  color: #1d4ed8;
  font-weight: 600;
}

/* 响应字段表格样式 */
.response-header {
  grid-template-columns: 1.5fr 1fr 2fr !important;
}

.response-row {
  grid-template-columns: 1.5fr 1fr 2fr !important;
}

/* 条件字段样式 */
.conditional-field {
  position: relative;
  transition: all 0.3s ease;
}

.conditional-field label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.field-status {
  font-size: 0.75rem;
  color: #2563eb;
  background: rgba(37, 99, 235, 0.1);
  padding: 0.125rem 0.5rem;
  border-radius: 12px;
  border: 1px solid #93c5fd;
  font-weight: 500;
}

.hint-icon {
  font-size: 0.875rem;
  opacity: 0.8;
}

.hint-text {
  font-size: 0.75rem;
  color: #64748b;
  font-style: italic;
}

.conditional-field .form-input {
  border-left: 3px solid #2563eb;
  transition: all 0.2s ease;
}

.conditional-field .form-input:focus {
  border-left-color: #1d4ed8;
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.1);
}

/* 进入和退出动画 */
.conditional-field {
  animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 认证Header样式 */
.auth-header-section {
  margin-bottom: 3rem;
  padding: 1.5rem;
  background: linear-gradient(135deg, rgba(37, 99, 235, 0.05) 0%, rgba(29, 78, 216, 0.02) 100%);
  border: 1px solid rgba(37, 99, 235, 0.2);
  border-radius: 8px;
}

.auth-header-form {
  background: hsl(var(--background));
  padding: 1.5rem;
  border: 1px solid hsl(var(--border));
  border-radius: 8px;
}

.auth-input-wrapper {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: 1px solid hsl(var(--border));
  border-radius: 6px;
  padding: 0.25rem 0.5rem;
  background: hsl(var(--background));
  transition: border-color 0.2s ease;
}

.auth-input-wrapper:focus-within {
  border-color: #2563eb;
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.1);
}

.auth-prefix {
  font-family: 'Monaco', 'Menlo', monospace;
  font-weight: 600;
  color: #2563eb;
  font-size: 0.875rem;
  white-space: nowrap;
}

.auth-input {
  border: none !important;
  box-shadow: none !important;
  padding: 0.5rem 0.5rem !important;
  flex: 1;
}

.auth-input:focus {
  outline: none;
  box-shadow: none !important;
}

.auth-hint {
  margin: 0.75rem 0 0 0;
  font-size: 0.875rem;
  color: hsl(var(--muted-foreground));
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .api-docs {
    padding: 1rem;
  }
  
  .docs-title {
    font-size: 2rem;
  }
  
  .param-header, .param-row {
    grid-template-columns: 1fr;
    gap: 0.5rem;
  }
  
  .param-header span, .param-row span {
    padding: 0.25rem 0;
  }
  
  .response-header, .response-row {
    grid-template-columns: 1fr !important;
  }
  
  .form-row {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .form-actions {
    flex-direction: column;
  }
  
  .cloud-types {
    gap: 0.5rem;
  }
  
  .cloud-tag {
    font-size: 0.8rem;
    padding: 0.375rem 0.75rem;
  }
  
  .hint-text {
    font-size: 0.7rem;
  }
  
  .field-status {
    font-size: 0.7rem;
    padding: 0.0625rem 0.375rem;
  }
  
  .api-header {
    padding: 1.5rem;
  }
  
  .api-content {
    padding: 1.5rem;
  }
}
</style>