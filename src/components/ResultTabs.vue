<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
import type { MergedResults, MergedResultItem, DiskCheckStatus } from '@/types';
import { getDiskTypeName } from '@/utils/diskTypes';
import { diskChecker } from '@/utils/diskChecker';

const props = defineProps<{
  mergedResults: MergedResults;
  loading: boolean;
  hasSearched: boolean;
  isActivelySearching: boolean;
}>();

// 当前激活的标签
const activeTab = ref('');
// 当前标签页的数据
const currentTabData = ref<MergedResultItem[]>([]);
// 虚拟列表显示的数据
const visibleItems = ref<MergedResultItem[]>([]);
// 每次加载的数量
const PAGE_SIZE = 20;
// 当前加载的页码
const currentPage = ref(1);
// 正在检测的链接
const checkingLinks = ref(new Set<string>());
// 检测结果缓存
const checkResults = ref(new Map<string, DiskCheckStatus>());

// 计算所有可用的网盘类型
const diskTypes = computed(() => {
  return Object.keys(props.mergedResults || {}).sort();
});

// 判断是否有搜索结果
const hasResults = computed(() => {
  return diskTypes.value.length > 0;
});

// 判断是否显示空状态（无结果且已完成搜索）
const showEmptyState = computed(() => {
  return !hasResults.value && props.hasSearched && !props.isActivelySearching;
});

// 判断是否显示搜索中状态（无结果但正在搜索）
const showSearchingState = computed(() => {
  return !hasResults.value && props.hasSearched && props.isActivelySearching;
});

// 判断是否显示初始状态（未搜索）
const showInitialState = computed(() => {
  return !hasResults.value && !props.hasSearched;
});

// 监听结果变化，智能选择标签
watch(
  () => props.mergedResults,
  (newVal) => {
    if (newVal && Object.keys(newVal).length > 0) {
      nextTick(() => {
        // 如果当前没有选中标签，或者当前选中的标签在新数据中不存在，则选择第一个标签
        const availableTypes = Object.keys(newVal);
        if (!activeTab.value || !availableTypes.includes(activeTab.value)) {
          activeTab.value = availableTypes[0] || '';
        }
        updateCurrentTabData();
      });
    } else {
      // 当没有结果时，清空当前数据
      activeTab.value = '';
      currentTabData.value = [];
      visibleItems.value = [];
    }
  },
  { immediate: true, deep: true }
);

// 监听标签页切换
watch(
  () => activeTab.value,
  () => {
    currentPage.value = 1;
    updateCurrentTabData();
  }
);

// 监听可见项变化，自动检测新链接
watch(
  () => visibleItems.value,
  (newItems) => {
    if (newItems.length > 0) {
      // 延迟执行检测，避免影响页面渲染
      setTimeout(() => {
        batchCheckLinks();
      }, 1000);
    }
  },
  { deep: true }
);

// 更新当前标签页数据
const updateCurrentTabData = () => {
  if (!activeTab.value || !props.mergedResults[activeTab.value]) {
    currentTabData.value = [];
    visibleItems.value = [];
    return;
  }
  
  currentTabData.value = props.mergedResults[activeTab.value] || [];
  loadMoreItems();
};

// 加载更多数据
const loadMoreItems = () => {
  const start = 0;
  const end = currentPage.value * PAGE_SIZE;
  visibleItems.value = currentTabData.value.slice(start, end);
};

// 处理滚动加载更多
const handleScroll = (e: Event) => {
  const target = e.target as HTMLElement;
  const scrollBottom = target.scrollHeight - target.scrollTop - target.clientHeight;
  
  // 当滚动到底部100px时，加载更多数据
  if (scrollBottom < 100 && visibleItems.value.length < currentTabData.value.length) {
    currentPage.value++;
    loadMoreItems();
  }
};

// 打开链接
const openLink = (url: string) => {
  window.open(url, '_blank');
};

// 仅复制密码
const copyPassword = (password: string, event: Event) => {
  // 阻止事件冒泡，避免触发父元素的点击事件
  event.stopPropagation();
  
  const target = event.target as HTMLElement;
  const passwordElement = target.closest('.result-password') as HTMLElement;
  
  navigator.clipboard.writeText(password)
    .then(() => {
      // 在密码位置显示复制成功提示
      if (passwordElement) {
        const originalHTML = passwordElement.innerHTML;
        passwordElement.innerHTML = `<span class="copy-success">复制成功</span>`;
        passwordElement.classList.add('copied');
        
        // 2秒后恢复原始内容
        setTimeout(() => {
          passwordElement.innerHTML = originalHTML;
          passwordElement.classList.remove('copied');
        }, 2000);
      }
    })
    .catch(() => {
      // 复制失败时显示提示
      if (passwordElement) {
        const originalHTML = passwordElement.innerHTML;
        passwordElement.innerHTML = `<span class="copy-error">复制失败</span>`;
        passwordElement.classList.add('copy-failed');
        
        // 2秒后恢复原始内容
        setTimeout(() => {
          passwordElement.innerHTML = originalHTML;
          passwordElement.classList.remove('copy-failed');
        }, 2000);
      }
    });
};

// 格式化日期时间
const formatDateTime = (dateTimeStr?: string) => {
  if (!dateTimeStr) return '';
  
  try {
    const date = new Date(dateTimeStr);
    return date.toLocaleString('zh-CN', { 
      year: 'numeric', 
      month: '2-digit', 
      day: '2-digit'
    });
  } catch (e) {
    return dateTimeStr;
  }
};

// 获取网盘类型中文名称
const getDiskName = (type: string) => {
  return getDiskTypeName(type);
};

// 检测单个链接有效性
const checkLinkValidity = async (item: MergedResultItem) => {
  if (!item.url) return;
  
  // 标记为正在检测
  checkingLinks.value.add(item.url);
  if (!item.checkStatus) {
    item.checkStatus = {};
  }
  item.checkStatus.isChecking = true;
  
  try {
    const result = await diskChecker.checkDiskLink(item.url);
    
    // 更新检测结果
    item.checkStatus = {
      isValid: result.isValid,
      message: result.message,
      isChecking: false,
      lastChecked: new Date().toISOString()
    };
    
    // 缓存结果
    checkResults.value.set(item.url, item.checkStatus);
  } catch (error) {
    console.error('链接检测失败:', error);
    item.checkStatus = {
      isValid: true, // 默认认为有效
      message: '检测失败',
      isChecking: false,
      lastChecked: new Date().toISOString()
    };
  } finally {
    checkingLinks.value.delete(item.url);
  }
};

// 批量检测当前页面的所有链接
const batchCheckLinks = async () => {
  const linksToCheck = visibleItems.value
    .filter(item => item.url && (!item.checkStatus || !item.checkStatus.lastChecked))
    .map(item => item.url);
  
  if (linksToCheck.length === 0) return;
  
  // 批量检测
  for (const item of visibleItems.value) {
    if (item.url && (!item.checkStatus || !item.checkStatus.lastChecked)) {
      await checkLinkValidity(item);
      // 添加延迟避免请求过于频繁
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }
};

// 获取链接状态显示文本
const getLinkStatusText = (item: MergedResultItem) => {
  if (!item.checkStatus) return '';
  
  if (item.checkStatus.isChecking) {
    return '检测中...';
  }
  
  if (item.checkStatus.isValid === false) {
    return '资源失效';
  }
  
  if (item.checkStatus.message) {
    return item.checkStatus.message;
  }
  
  return '链接有效';
};

// 获取链接状态样式类
const getLinkStatusClass = (item: MergedResultItem) => {
  if (!item.checkStatus) return '';
  
  if (item.checkStatus.isChecking) {
    return 'status-checking';
  }
  
  if (item.checkStatus.isValid === false) {
    return 'status-invalid';
  }
  
  if (item.checkStatus.isValid === true) {
    return 'status-valid';
  }
  
  return 'status-unknown';
};

// 手动触发链接检测
const triggerLinkCheck = (item: MergedResultItem, event: Event) => {
  event.stopPropagation();
  checkLinkValidity(item);
};

</script>

<template>
  <div class="results-wrapper">
    <!-- 初始状态 -->
    <div v-if="showInitialState" class="empty-state">
      <div class="empty-icon">
        <svg class="icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
        </svg>
      </div>
      <p class="empty-title">输入关键词开始搜索</p>
    </div>
    
    <!-- 搜索中状态 -->
    <div v-else-if="showSearchingState" class="searching-state">
      <div class="searching-icon">
        <div class="searching-spinner"></div>
      </div>
      <p class="searching-title">正在搜索资源中...</p>
      <p class="searching-subtitle">资源搜索可能需要一些时间，请耐心等待</p>
    </div>
    
    <!-- 搜索无结果状态 -->
    <div v-else-if="showEmptyState" class="empty-state">
      <div class="empty-icon">
        <svg class="icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
      </div>
      <p class="empty-title">未找到相关资源</p>
      <p class="empty-subtitle">请尝试其他关键词</p>
    </div>
    
    <!-- 搜索结果 -->
    <div v-else-if="hasResults" class="results-container">
      <!-- 标签页 -->
      <div class="tabs">
        <button 
          v-for="type in diskTypes" 
          :key="type"
          class="tab-button"
          :class="{ active: activeTab === type }"
          @click="activeTab = type"
        >
          {{ getDiskName(type) }} ({{ mergedResults[type]?.length || 0 }})
        </button>
      </div>
      
      <!-- 内容区域 -->
      <div class="tab-content">
        <div v-if="!currentTabData.length" class="empty-tab">
          <p>暂无数据</p>
        </div>
        
        <div v-else class="result-list" @scroll="handleScroll">
          <div 
            v-for="(item, index) in visibleItems" 
            :key="index" 
            class="result-item"
          >
            <!-- 标题行（移动端单独占一行） -->
            <div class="result-header">
              <div class="result-title" :title="item.note">{{ item.note }}</div>
              <!-- 桌面端：数据来源+时间与标题同行 -->
              <div class="result-meta desktop-only" v-if="item.source || item.datetime">
                <span v-if="item.source" class="result-source">{{ item.source }}</span>
                <span v-if="item.source && item.datetime" class="meta-separator">·</span>
                <span v-if="item.datetime" class="result-date">{{ formatDateTime(item.datetime) }}</span>
              </div>
            </div>
            
            <!-- 移动端：数据来源+时间单独一行 -->
            <div class="result-meta mobile-only" v-if="item.source || item.datetime">
              <span v-if="item.source" class="result-source">{{ item.source }}</span>
              <span v-if="item.source && item.datetime" class="meta-separator">·</span>
              <span v-if="item.datetime" class="result-date">{{ formatDateTime(item.datetime) }}</span>
            </div>
            
            <!-- 第二行：链接和提取码 -->
            <div class="result-row">
              <div class="result-link" @click="openLink(item.url)">{{ item.url }}</div>
              <div v-if="item.password" class="result-password" @click="copyPassword(item.password, $event)">
                提取码: <span class="password-value">{{ item.password }}</span>
              </div>
            </div>
            
            <!-- 第三行：链接检测状态 -->
            <div class="result-row">
              <div class="link-status" :class="getLinkStatusClass(item)">
                <span>{{ getLinkStatusText(item) }}</span>
                <button 
                  v-if="!item.checkStatus?.isChecking" 
                  class="check-button"
                  @click="triggerLinkCheck(item, $event)"
                  title="重新检测链接有效性"
                >
                  检测
                </button>
              </div>
            </div>
          </div>
          
          <div v-if="visibleItems.length < currentTabData.length" class="loading-more">
            <div class="loading-spinner"></div>
            <span>加载更多...</span>
          </div>
        </div>
      </div>
      
      <!-- 持续搜索提示 -->
      <div v-if="isActivelySearching" class="ongoing-search-hint">
        <div class="hint-spinner"></div>
        <span>正在持续搜索更多资源...</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.results-wrapper {
  width: 100%;
}

.empty-state, .searching-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem 1rem;
  text-align: center;
  background-color: #fff;
  border-radius: 0.75rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.empty-icon {
  width: 4rem;
  height: 4rem;
  background-color: #f3f4f6;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
}

.empty-icon .icon {
  width: 2rem;
  height: 2rem;
  color: #9ca3af;
}

.searching-icon {
  width: 4rem;
  height: 4rem;
  background-color: #f0f9ff;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
}

.searching-spinner {
  width: 2rem;
  height: 2rem;
  border: 3px solid #e5e7eb;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

.empty-title, .searching-title {
  font-size: 1.125rem;
  font-weight: 500;
  color: #4b5563;
  margin-bottom: 0.5rem;
}

.empty-subtitle, .searching-subtitle {
  font-size: 0.875rem;
  color: #6b7280;
}

.results-container {
  background-color: #fff;
  border-radius: 0.75rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  overflow: hidden;
}

.tabs {
  display: flex;
  overflow-x: auto;
  border-bottom: 1px solid #e5e7eb;
  background-color: #f9fafb;
  padding: 0 1rem;
}

.tab-button {
  padding: 0.75rem 1rem;
  white-space: nowrap;
  font-size: 0.875rem;
  color: #4b5563;
  background: transparent;
  border: none;
  cursor: pointer;
  position: relative;
  transition: all 0.2s ease;
}

.tab-button:hover {
  color: #3b82f6;
}

.tab-button.active {
  color: #3b82f6;
  font-weight: 500;
}

.tab-button.active::after {
  content: '';
  position: absolute;
  bottom: -1px;
  left: 0;
  width: 100%;
  height: 2px;
  background-color: #3b82f6;
}

.tab-content {
  min-height: 300px;
}

.empty-tab {
  padding: 3rem 1rem;
  text-align: center;
  color: #6b7280;
}

.result-list {
  max-height: 600px;
  overflow-y: auto;
  padding: 1rem;
}

.result-item {
  padding: 0.75rem;
  border-bottom: 1px solid #f3f4f6;
  transition: background-color 0.2s ease;
}

.result-item:hover {
  background-color: #f9fafb;
}

.result-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.result-row:last-child {
  margin-bottom: 0;
}

/* 链接检测状态样式 */
.link-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  margin-top: 0.25rem;
}

.status-checking {
  color: #f59e0b;
  background-color: #fffbeb;
  border: 1px solid #fcd34d;
}

.status-valid {
  color: #10b981;
  background-color: #ecfdf5;
  border: 1px solid #a7f3d0;
}

.status-invalid {
  color: #ef4444;
  background-color: #fef2f2;
  border: 1px solid #fca5a5;
}

.status-unknown {
  color: #6b7280;
  background-color: #f9fafb;
  border: 1px solid #d1d5db;
}

.check-button {
  padding: 0.125rem 0.375rem;
  font-size: 0.625rem;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 0.125rem;
  cursor: pointer;
  transition: background-color 0.2s;
}

.check-button:hover {
  background-color: #2563eb;
}

.result-title {
  font-size: 0.95rem;
  font-weight: 500;
  color: #111827;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
}

/* 标题行布局 */
.result-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  width: 100%;
}

/* 桌面端：数据来源与标题同行 */
.result-meta.desktop-only {
  display: flex;
  align-items: center;
  margin-left: 0.75rem;
  white-space: nowrap;
  flex-shrink: 0;
}

/* 移动端：数据来源单独一行 */
.result-meta.mobile-only {
  display: none;
  align-items: center;
  margin-top: 0.375rem;
  margin-bottom: 0.25rem;
}

/* 响应式显示控制 */
@media (max-width: 768px) {
  .desktop-only {
    display: none !important;
  }
  
  .mobile-only {
    display: flex !important;
  }
  
  .result-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .result-title {
    width: 100%;
    margin-bottom: 0;
  }
  
  /* 移动端数据来源标签优化 */
  .result-source {
    font-size: 0.6875rem;
    padding: 0.0625rem 0.25rem;
  }
}

.result-source {
  font-size: 0.75rem;
  color: #3b82f6;
  font-weight: 500;
  background-color: #eff6ff;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  border: 1px solid #bfdbfe;
}

.meta-separator {
  font-size: 0.75rem;
  color: #9ca3af;
  margin: 0 0.375rem;
}

.result-date {
  font-size: 0.75rem;
  color: #6b7280;
}

.result-link {
  font-size: 0.875rem;
  color: #3b82f6;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;
  flex: 1;
}

.result-link:hover {
  text-decoration: underline;
}

.result-password {
  font-size: 0.75rem;
  color: #6b7280;
  margin-left: 0.75rem;
  white-space: nowrap;
  cursor: pointer;
  transition: all 0.2s ease;
}

.result-password:hover {
  color: #4b5563;
}

.result-password.copied {
  color: #10b981;
  background-color: #ecfdf5;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
}

.result-password.copy-failed {
  color: #ef4444;
  background-color: #fef2f2;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
}

.copy-success {
  color: #10b981;
  font-weight: 500;
}

.copy-error {
  color: #ef4444;
  font-weight: 500;
}

.password-value {
  color: #10b981;
  font-weight: 500;
}

.loading-more {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 1rem;
  color: #6b7280;
  font-size: 0.875rem;
}

.loading-spinner, .hint-spinner {
  width: 1rem;
  height: 1rem;
  border: 2px solid #e5e7eb;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

.ongoing-search-hint {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background-color: #f0f9ff;
  color: #3b82f6;
  font-size: 0.875rem;
  border-top: 1px solid #e5e7eb;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 768px) {
  .result-list {
    max-height: 500px;
    padding: 0.5rem;
  }
  
  .result-item {
    padding: 0.75rem 0.5rem;
  }
  
  .tab-button {
    padding: 0.5rem 0.75rem;
    font-size: 0.75rem;
  }
}
</style> 