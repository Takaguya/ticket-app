<script setup lang="ts">
import { computed, ref } from 'vue'

import type { Merchant, MerchantStatus } from '../api/types'
import { approveMerchant, backOffice, isBusy, reinstateMerchant, suspendMerchant } from '../backOffice'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import StatusPill from '../components/StatusPill.vue'
import { BUSINESS_TYPES, money, phone } from '../format'
import { matchesSearch } from '../search'

type Filter = 'all' | MerchantStatus

const FILTERS: { value: Filter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'active', label: 'Active' },
  { value: 'pending', label: 'Pending' },
  { value: 'suspended', label: 'Suspended' },
]
const COLUMNS = '2fr 1fr 1.4fr 0.7fr 1fr 1.1fr 1.3fr'

const filter = ref<Filter>('all')
const toSuspend = ref<Merchant | null>(null)

function count(value: Filter): number {
  return backOffice.merchants.filter((m) => value === 'all' || m.status === value).length
}

const rows = computed(() =>
  backOffice.merchants.filter(
    (m) =>
      (filter.value === 'all' || m.status === filter.value) &&
      matchesSearch(m.name, m.owner?.name, m.owner?.phone, m.owner && phone(m.owner.phone), BUSINESS_TYPES[m.type]),
  ),
)

async function confirmSuspend() {
  const merchant = toSuspend.value
  toSuspend.value = null
  if (merchant) await suspendMerchant(merchant)
}
</script>

<template>
  <div class="chips" role="group" aria-label="Show merchants">
    <button
      v-for="option in FILTERS"
      :key="option.value"
      type="button"
      class="chip"
      :aria-pressed="filter === option.value"
      @click="filter = option.value"
    >
      {{ option.label }} · {{ count(option.value) }}
    </button>
  </div>

  <section class="card table">
    <div class="min">
      <div class="row th" :style="{ gridTemplateColumns: COLUMNS }">
        <div>Business</div>
        <div>Type</div>
        <div>Owner</div>
        <div>Events</div>
        <div>Online sales</div>
        <div>Status</div>
        <div>Action</div>
      </div>
      <div v-for="merchant in rows" :key="merchant.id" class="row" :style="{ gridTemplateColumns: COLUMNS }">
        <div class="strong">{{ merchant.name }}</div>
        <div>{{ BUSINESS_TYPES[merchant.type] }}</div>
        <div>
          <template v-if="merchant.owner">
            <div>{{ merchant.owner.name }}</div>
            <div class="sub num">{{ phone(merchant.owner.phone) }}</div>
          </template>
          <span v-else class="sub">Unknown</span>
        </div>
        <div class="num">{{ merchant.events }}</div>
        <div class="num">{{ money(merchant.onlineSalesCents) }}</div>
        <div><StatusPill :status="merchant.status" /></div>
        <div>
          <button
            v-if="merchant.status === 'pending'"
            type="button"
            class="btn"
            :disabled="isBusy(merchant.id)"
            @click="approveMerchant(merchant)"
          >
            Approve
          </button>
          <button
            v-else-if="merchant.status === 'active'"
            type="button"
            class="btn danger"
            :disabled="isBusy(merchant.id)"
            @click="toSuspend = merchant"
          >
            Suspend
          </button>
          <button
            v-else
            type="button"
            class="btn ghost"
            :disabled="isBusy(merchant.id)"
            @click="reinstateMerchant(merchant)"
          >
            Reinstate
          </button>
        </div>
      </div>
      <div v-if="backOffice.loaded && rows.length === 0" class="empty">No merchants match.</div>
    </div>
  </section>

  <ConfirmDialog
    v-if="toSuspend"
    :title="`Suspend ${toSuspend.name}?`"
    confirm-label="Suspend"
    danger
    @confirm="confirmSuspend"
    @cancel="toSuspend = null"
  >
    It can't sell tickets or publish events until you reinstate it. Tickets it has already sold can still be
    scanned at the entrance.
  </ConfirmDialog>
</template>

<style scoped>
.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.min {
  min-width: 860px;
}
</style>
