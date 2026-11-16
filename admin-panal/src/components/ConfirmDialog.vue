<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

// Asks before an action that is hard to take back, like suspending a merchant or
// recording a payout. Escape or the backdrop cancels.

defineProps<{
  title: string
  confirmLabel: string
  danger?: boolean
}>()

const emit = defineEmits<{ confirm: []; cancel: [] }>()

const cancelButton = ref<HTMLButtonElement | null>(null)

function onKey(event: KeyboardEvent) {
  if (event.key === 'Escape') emit('cancel')
}

onMounted(async () => {
  document.addEventListener('keydown', onKey)
  await nextTick()
  cancelButton.value?.focus()
})

onBeforeUnmount(() => document.removeEventListener('keydown', onKey))
</script>

<template>
  <div class="backdrop" @click.self="emit('cancel')">
    <div class="dialog card" role="alertdialog" aria-modal="true" aria-labelledby="confirm-title">
      <h2 id="confirm-title">{{ title }}</h2>
      <div class="body"><slot /></div>
      <div class="actions">
        <button ref="cancelButton" type="button" class="btn ghost" @click="emit('cancel')">Cancel</button>
        <button type="button" class="btn" :class="{ 'solid-danger': danger }" @click="emit('confirm')">
          {{ confirmLabel }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.backdrop {
  position: fixed;
  inset: 0;
  background: rgba(17, 17, 17, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  z-index: 20;
}

.dialog {
  width: min(440px, 100%);
  padding: 22px 24px 20px;
}

h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
}

.body {
  margin-top: 8px;
  font-size: 14px;
  line-height: 1.5;
  color: var(--ink-2);
}

.actions {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
