<script setup lang="ts">
import { computed } from 'vue'

import { pageNumbers } from '../pagination'

// Previous, the page numbers (with gaps when there are many), Next. Asks for a page
// with `go`; the parent loads it and passes the new `page` back.

const props = defineProps<{
  /** The page shown, from 1. */
  page: number
  pages: number
  /** While a page loads. */
  disabled?: boolean
}>()

const emit = defineEmits<{ go: [page: number] }>()

const items = computed(() => pageNumbers(props.page, props.pages))

function go(page: number) {
  if (page !== props.page && page >= 1 && page <= props.pages) emit('go', page)
}
</script>

<template>
  <nav class="pager" aria-label="Pages">
    <button type="button" class="step" :disabled="disabled || page <= 1" @click="go(page - 1)">‹ Previous</button>
    <template v-for="(item, index) in items" :key="index">
      <span v-if="item === 'gap'" class="gap" aria-hidden="true">…</span>
      <button
        v-else
        type="button"
        class="number num"
        :aria-current="item === page ? 'page' : undefined"
        :aria-label="`Page ${item}`"
        :disabled="disabled"
        @click="go(item)"
      >
        {{ item }}
      </button>
    </template>
    <button type="button" class="step" :disabled="disabled || page >= pages" @click="go(page + 1)">Next ›</button>
  </nav>
</template>

<style scoped>
.pager {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-wrap: wrap;
}

.step,
.number {
  min-height: 36px;
  border: 0;
  border-radius: 10px;
  background: none;
  color: var(--ink-2);
  font-size: 13px;
  font-weight: 700;
}

.step {
  padding: 0 10px;
}

.number {
  min-width: 36px;
  padding: 0 8px;
}

.step:hover:not(:disabled),
.number:hover:not(:disabled):not([aria-current='page']) {
  background: var(--line);
}

.number[aria-current='page'] {
  background: #1a1a1a;
  color: #fff;
}

.step:disabled {
  color: var(--muted);
}

.gap {
  min-width: 24px;
  text-align: center;
  color: var(--muted);
}
</style>
