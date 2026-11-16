<script setup lang="ts">
import { hideToast, toast } from '../toast'
</script>

<template>
  <div class="toast-area" aria-live="polite">
    <div v-if="toast.message" class="toast" :class="toast.tone" role="status" @click="hideToast">
      {{ toast.message }}
    </div>
  </div>
</template>

<style scoped>
.toast-area {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 24px;
  display: flex;
  justify-content: center;
  pointer-events: none;
  z-index: 30;
}

.toast {
  pointer-events: auto;
  max-width: min(560px, calc(100% - 32px));
  padding: 12px 18px;
  border-radius: 12px;
  background: #1a1a1a;
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.18);
}

.toast.error {
  background: var(--red);
}
</style>
