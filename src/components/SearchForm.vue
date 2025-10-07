<script setup lang="ts">
import { ref } from 'vue';
import type { SearchParams } from '@/api';
import { Button, Input, Icons } from '@/components/ui';

const keyword = ref('');
const loading = ref(false);

const emit = defineEmits<{
  (e: 'search', params: SearchParams): void;
  (e: 'searchComplete'): void;
}>();

const handleSearch = () => {
  if (!keyword.value.trim()) {
    return;
  }
  
  loading.value = true;
  
  const params: SearchParams = {
    kw: keyword.value,
    res: 'merge',
    src: 'all'
  };
  
  emit('search', params);
  
  // 2秒后重置loading状态
  setTimeout(() => {
    loading.value = false;
    // 不再触发searchComplete事件
  }, 2000);
};
</script>

<template>
  <div class="w-full max-w-content mx-auto">
    <div class="relative w-full">
      <div class="relative flex flex-row items-center w-full">
        <div class="relative w-full">
          <input
            v-model="keyword"
            type="text"
            placeholder="搜索资源、电影、音乐、软件..."
            :disabled="loading"
            @keydown.enter="handleSearch"
            class="flex h-10 outline-none focus:outline-none rounded-md border bg-background px-3 py-2 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50 w-full text-center pr-12 transition-all duration-300 border-primary/20 hover:border-primary/40 shadow-sm hover:shadow-md focus-visible:shadow-lg focus-visible:ring-primary/30 focus-visible:ring-offset-0 focus-visible:border-primary/60"
          />
          <button
            type="button"
            @click="handleSearch"
            :disabled="loading || !keyword.trim()"
            class="inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium focus-visible:outline-none disabled:pointer-events-none disabled:opacity-50 w-10 absolute right-0 top-0 h-full rounded-l-none transition-all duration-300 border-0 hover:border hover:border-l-0 hover:border-primary/40 hover:bg-primary hover:text-primary-foreground hover:scale-[1.03]"
          >
            <component 
              :is="loading ? Icons.Loading() : Icons.Send()" 
              :class="[
                'w-4 h-4',
                loading && 'animate-spin'
              ]"
            />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.search-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  margin-bottom: 2rem;
}

.search-input-wrapper {
  position: relative;
  width: 100%;
  flex: 1;
}

.search-input {
  width: 100%;
  padding: 0.75rem 1rem;
  border-radius: 0.75rem;
  border: 1px solid #e5e7eb;
  background-color: #fff;
  color: #111827;
  font-size: 1rem;
  outline: none;
  transition: all 0.2s ease;
}

.search-input::placeholder {
  color: #9ca3af;
}

.search-input:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
}

.search-button {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.75rem 1.5rem;
  border-radius: 0.75rem;
  background-color: #3b82f6;
  color: #fff;
  font-weight: 500;
  font-size: 1rem;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
}

.search-button:hover:not(:disabled) {
  background-color: #2563eb;
}

.search-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.loading-spinner {
  display: inline-block;
  width: 1rem;
  height: 1rem;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  border-top-color: #fff;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (min-width: 768px) {
  .search-form {
    flex-direction: row;
    align-items: center;
  }
  
  .search-button {
    width: auto;
    white-space: nowrap;
  }
}
</style> 