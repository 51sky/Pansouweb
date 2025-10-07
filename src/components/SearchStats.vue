<script setup lang="ts">
import { computed } from 'vue';
import type { MergedResults } from '@/types';
import { Icons } from '@/components/ui';

const props = defineProps<{
  total: number;
  mergedResults: MergedResults;
  loading: boolean;
  searchTime?: number;
  isUpdating: boolean;
  updateCount: number;
}>();

// 计算网盘类型数量
const diskTypeCount = computed(() => {
  return Object.keys(props.mergedResults || {}).length;
});
</script>

<template>
  <div class="card">
    <div class="flex items-center justify-between p-4">
      <div class="flex items-center gap-6">
        <!-- 搜索结果总数 -->
        <div class="flex items-center gap-2">
          <component :is="Icons.Grid()" class="w-4 h-4 text-muted-foreground" />
          <span class="text-sm text-muted-foreground">搜索结果</span>
          <span class="font-semibold text-foreground">{{ total.toLocaleString() }}</span>
        </div>
        
        <!-- 网盘类型数量 -->
        <div class="flex items-center gap-2">
          <component :is="Icons.Folder()" class="w-4 h-4 text-muted-foreground" />
          <span class="text-sm text-muted-foreground">网盘类型</span>
          <span class="font-semibold text-foreground">{{ diskTypeCount }}</span>
        </div>
        
        <!-- 搜索耗时 -->
        <div v-if="searchTime" class="flex items-center gap-2">
          <component :is="Icons.Clock()" class="w-4 h-4 text-muted-foreground" />
          <span class="text-sm text-muted-foreground">用时</span>
          <span class="font-semibold text-foreground">{{ searchTime }}ms</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.stats-container {
  margin-bottom: 1.5rem;
  background-color: #fff;
  border-radius: 0.75rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  overflow: hidden;
}

.stats-content {
  display: flex;
  align-items: center;
  padding: 1rem;
}

.stats-item {
  display: flex;
  flex-direction: column;
  padding: 0.5rem 1rem;
}

.stats-divider {
  width: 1px;
  height: 2rem;
  background-color: #e5e7eb;
  margin: 0 0.5rem;
}

.stats-label {
  font-size: 0.75rem;
  color: #6b7280;
  margin-bottom: 0.25rem;
}

.stats-value {
  font-size: 1rem;
  font-weight: 600;
  color: #111827;
}

@media (max-width: 768px) {
  .stats-content {
    padding: 0.75rem;
    flex-wrap: wrap;
    justify-content: space-around;
  }
  
  .stats-divider {
    display: none;
  }
  
  .stats-item {
    padding: 0.5rem;
    align-items: center;
  }
}
</style> 