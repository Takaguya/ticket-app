<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'

import type { Period } from '../api/types'
import { currentPeriod, refresh, today } from '../backOffice'
import { period as periodLabel } from '../format'
import { choosePeriod, chosenPeriod, presets, samePeriod, type Preset } from '../period'

// The dates at the top right: which days sales, commission, payouts made and bookings
// are counted for. Quick choices, or any From and To. Choosing reloads the lists.

const open = ref(false)
const from = ref('')
const to = ref('')
const error = ref<string | null>(null)
const root = ref<HTMLElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)

const label = computed(() => (currentPeriod.value ? periodLabel(currentPeriod.value.from, currentPeriod.value.to) : ''))
const choices = computed(() => (today.value ? presets(today.value) : []))

async function toggle() {
  if (open.value) {
    close()
    return
  }
  from.value = currentPeriod.value?.from ?? ''
  to.value = currentPeriod.value?.to ?? ''
  error.value = null
  open.value = true
  document.addEventListener('mousedown', onOutside)
  document.addEventListener('keydown', onKey)
  await nextTick()
  root.value?.querySelector<HTMLElement>('.choice[aria-pressed="true"]')?.focus()
}

function close() {
  open.value = false
  document.removeEventListener('mousedown', onOutside)
  document.removeEventListener('keydown', onKey)
}

function onOutside(event: MouseEvent) {
  if (!root.value?.contains(event.target as Node)) close()
}

function onKey(event: KeyboardEvent) {
  if (event.key !== 'Escape') return
  close()
  trigger.value?.focus()
}

function pick(choice: Preset) {
  apply(choice.period)
}

function applyCustom() {
  if (!from.value || !to.value) {
    error.value = 'Choose both dates.'
    return
  }
  if (from.value > to.value) {
    error.value = 'The start date must be on or before the end date.'
    return
  }
  apply({ from: from.value, to: to.value })
}

function apply(period: Period | null) {
  close()
  trigger.value?.focus()
  if (samePeriod(period, chosenPeriod.value)) return
  choosePeriod(period)
  void refresh()
}

onBeforeUnmount(close)
</script>

<template>
  <div ref="root" class="picker">
    <button
      ref="trigger"
      type="button"
      class="trigger"
      :aria-expanded="open"
      aria-haspopup="dialog"
      :aria-label="label ? `Dates: ${label}. Change` : 'Dates'"
      :disabled="!label"
      @click="toggle"
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
        stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1zM4 10h16M8 3v4M16 3v4" />
      </svg>
      <span class="num">{{ label || '…' }}</span>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"
        stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M6 9l6 6 6-6" />
      </svg>
    </button>

    <div v-if="open" class="popover card" role="dialog" aria-label="Choose the dates">
      <div class="choices" role="group" aria-label="Quick choices">
        <button
          v-for="choice in choices"
          :key="choice.label"
          type="button"
          class="choice"
          :aria-pressed="samePeriod(choice.period, chosenPeriod)"
          @click="pick(choice)"
        >
          {{ choice.label }}
        </button>
      </div>
      <form class="custom" novalidate @submit.prevent="applyCustom">
        <div class="dates">
          <label class="field">
            From
            <input v-model="from" type="date" :max="today" />
          </label>
          <label class="field">
            To
            <input v-model="to" type="date" :min="from || undefined" :max="today" />
          </label>
        </div>
        <p v-if="error" class="error-text" role="alert">{{ error }}</p>
        <button type="submit" class="btn">Show these dates</button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.picker {
  position: relative;
}

.trigger {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 44px;
  padding: 0 12px 0 14px;
  border: 0;
  border-radius: 12px;
  background: var(--page);
  color: var(--ink-2);
  font-size: 13px;
  font-weight: 700;
}

.trigger:hover:not(:disabled),
.trigger[aria-expanded='true'] {
  background: var(--line);
}

.popover {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  z-index: 10;
  width: 320px;
  padding: 14px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  box-shadow: 0 12px 32px rgba(17, 17, 17, 0.16);
}

.choices {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px;
}

.choice {
  min-height: 36px;
  border: 0;
  border-radius: 10px;
  background: var(--page);
  color: var(--ink-2);
  font-size: 13px;
  font-weight: 700;
}

.choice:hover {
  background: var(--line);
}

.choice[aria-pressed='true'] {
  background: #1a1a1a;
  color: #fff;
}

.custom {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-top: 12px;
  border-top: 1px solid var(--line-soft);
}

.dates {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}

.dates input {
  min-height: 40px;
  padding: 0 8px;
  font-size: 14px;
}
</style>
