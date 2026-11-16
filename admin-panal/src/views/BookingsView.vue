<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { adminApi } from '../api/admin'
import { ApiError } from '../api/http'
import type { BookingPage } from '../api/types'
import { backOffice, currentPeriod, refresh } from '../backOffice'
import Pager from '../components/Pager.vue'
import StatusPill from '../components/StatusPill.vue'
import { PAYMENT_METHODS, money } from '../format'
import { samePeriod } from '../period'
import { pageSearch } from '../search'

// Every merchant's bookings made in the dates chosen at the top right, newest first.
// There can be very many, so the server searches them and sends one page at a time.

const COLUMNS = '1.1fr 1.3fr 2.2fr 0.7fr 0.8fr 1.1fr 1.2fr'
const PAGE_SIZE = 25
const TYPING_PAUSE_MS = 300

const page = ref<BookingPage | null>(null)
const pageNumber = ref(1)
const loading = ref(false)
const error = ref<string | null>(null)

/** "26–50": which of the matches this page shows. */
const shown = computed(() => {
  if (!page.value || page.value.bookings.length === 0) return ''
  const first = (page.value.page - 1) * page.value.size + 1
  return `${first.toLocaleString('en-US')}–${(first + page.value.bookings.length - 1).toLocaleString('en-US')}`
})

let controller: AbortController | null = null
let typingTimer: ReturnType<typeof setTimeout> | undefined

/** Loads the page of the current search. A newer request cancels the one still loading. */
async function load() {
  controller?.abort()
  const current = new AbortController()
  controller = current
  loading.value = true
  try {
    // The default dates need Pin's today, which comes with the lists' first load.
    if (!currentPeriod.value) await refresh()
    if (current.signal.aborted) return
    const period = currentPeriod.value
    if (!period) {
      error.value = backOffice.error ?? 'Something went wrong. Please try again.'
      return
    }
    const result = await adminApi.bookings(pageSearch.value.trim(), period, pageNumber.value, PAGE_SIZE,
      current.signal)
    if (result.bookings.length === 0 && result.page > result.pages) {
      // Fewer bookings match than when this page was asked for: show the last page.
      pageNumber.value = result.pages
      void load()
      return
    }
    page.value = result
    error.value = null
  } catch (failure) {
    if (current.signal.aborted) return
    error.value = failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
  } finally {
    if (controller === current) loading.value = false
  }
}

async function goTo(number: number) {
  pageNumber.value = number
  await load()
  window.scrollTo({ top: 0 })
}

watch(pageSearch, () => {
  clearTimeout(typingTimer)
  typingTimer = setTimeout(() => {
    pageNumber.value = 1
    void load()
  }, TYPING_PAUSE_MS)
})

// Other dates chosen at the top right: their first page. (The first dates known are
// the ones the first load waits for.)
watch(currentPeriod, (now, before) => {
  if (before === null || samePeriod(now, before)) return
  pageNumber.value = 1
  void load()
})

onMounted(load)

onBeforeUnmount(() => {
  clearTimeout(typingTimer)
  controller?.abort()
})
</script>

<template>
  <div v-if="error" class="notice" role="alert">
    <span>{{ error }}</span>
    <button type="button" class="btn ghost" @click="load">Try again</button>
  </div>

  <section class="card table" :aria-busy="loading">
    <div class="min">
      <div class="row th" :style="{ gridTemplateColumns: COLUMNS }">
        <div>Booking ID</div>
        <div>Buyer</div>
        <div>Event</div>
        <div>Tickets</div>
        <div>Total</div>
        <div>Payment</div>
        <div>Status</div>
      </div>
      <div v-for="booking in page?.bookings ?? []" :key="booking.id" class="row" :style="{ gridTemplateColumns: COLUMNS }">
        <div class="num strong">{{ booking.id }}</div>
        <div>{{ booking.buyerName }}</div>
        <div>
          <div>{{ booking.eventName }}</div>
          <div class="sub">{{ booking.merchantName }}</div>
        </div>
        <div class="num">{{ booking.tickets }}</div>
        <div class="num">{{ money(booking.totalCents) }}</div>
        <div>
          <div>{{ PAYMENT_METHODS[booking.payment] }}</div>
          <div class="sub">{{ booking.channel === 'door' ? 'At the door' : 'Pin app' }}</div>
        </div>
        <div><StatusPill :status="booking.status" /></div>
      </div>
      <div v-if="page && page.bookings.length === 0" class="empty">
        {{
          pageSearch.trim()
            ? 'No bookings in these dates match your search.'
            : 'No bookings in these dates. Change them at the top right.'
        }}
      </div>
      <div v-if="!page && loading" class="empty">Loading bookings…</div>
    </div>
  </section>

  <div v-if="page && page.total > 0" class="footer">
    <span class="sub num">Showing {{ shown }} of {{ page.total.toLocaleString('en-US') }}</span>
    <Pager v-if="page.pages > 1" :page="page.page" :pages="page.pages" :disabled="loading" @go="goTo" />
  </div>
</template>

<style scoped>
.min {
  min-width: 860px;
}

/* The page being replaced, while the next one loads. */
.table[aria-busy='true'] .row:not(.th) {
  opacity: 0.55;
}

.footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}
</style>
