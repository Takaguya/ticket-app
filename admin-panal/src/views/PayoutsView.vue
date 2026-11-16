<script setup lang="ts">
import { computed, ref } from 'vue'

import type { Owed } from '../api/types'
import { backOffice, isBusy, markPaid } from '../backOffice'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import StatusPill from '../components/StatusPill.vue'
import { dateTime, money, percent, refunds } from '../format'
import { matchesSearch } from '../search'

// What Pin owes each merchant: online sales not paid out yet, minus Pin's commission and
// the refunds of paid-out bookings the merchant cancelled since.
// Door sales are paid to the merchant directly and never appear here. Marking a
// payout as paid records the exact bookings it covers, so they are never paid twice.

const COLUMNS = '2fr 1.1fr 1.2fr 1fr 1.1fr 0.9fr 1.4fr'

const toPay = ref<Owed | null>(null)

const rate = computed(() => percent(backOffice.overview?.commissionRate ?? 5))
const owed = computed(() => backOffice.payouts.owed.filter((o) => matchesSearch(o.merchantName)))
const paid = computed(() => backOffice.payouts.paid.filter((p) => matchesSearch(p.merchantName)))

async function confirmPaid() {
  const payout = toPay.value
  toPay.value = null
  if (payout) await markPaid(payout)
}
</script>

<template>
  <section class="card table">
    <div class="min">
      <div class="row th" :style="{ gridTemplateColumns: COLUMNS }">
        <div>Merchant</div>
        <div>Online sales</div>
        <div>Pin commission ({{ rate }})</div>
        <div>Refunds</div>
        <div>Payout</div>
        <div>Status</div>
        <div>Action</div>
      </div>

      <div v-for="row in owed" :key="'owed' + row.merchantId" class="row" :style="{ gridTemplateColumns: COLUMNS }">
        <div>
          <div class="strong">{{ row.merchantName }}</div>
          <div class="sub">{{ row.bookingCount }} {{ row.bookingCount === 1 ? 'booking' : 'bookings' }}</div>
        </div>
        <div class="num">{{ money(row.grossCents) }}</div>
        <div class="num">−{{ money(row.commissionCents) }}</div>
        <div class="num">{{ refunds(row.refundsCents) }}</div>
        <div class="num net">{{ money(row.netCents) }}</div>
        <div><StatusPill status="due" /></div>
        <div>
          <button type="button" class="btn" :disabled="isBusy(row.merchantId)" @click="toPay = row">
            Mark as paid
          </button>
        </div>
      </div>

      <div v-for="row in paid" :key="'paid' + row.id" class="row" :style="{ gridTemplateColumns: COLUMNS }">
        <div>
          <div class="strong">{{ row.merchantName }}</div>
          <div class="sub">{{ row.bookingCount }} {{ row.bookingCount === 1 ? 'booking' : 'bookings' }}</div>
        </div>
        <div class="num">{{ money(row.grossCents) }}</div>
        <div class="num">−{{ money(row.commissionCents) }}</div>
        <div class="num">{{ refunds(row.refundsCents) }}</div>
        <div class="num net">{{ money(row.netCents) }}</div>
        <div><StatusPill status="paid" /></div>
        <div class="sub">{{ dateTime(row.paidAt) }} by {{ row.paidBy }}</div>
      </div>

      <div v-if="backOffice.loaded && owed.length === 0 && paid.length === 0" class="empty">
        {{
          backOffice.payouts.owed.length + backOffice.payouts.paid.length === 0
            ? 'Nothing is owed, and nothing was paid in these dates.'
            : 'No payouts match your search.'
        }}
      </div>
    </div>
  </section>

  <ConfirmDialog
    v-if="toPay"
    :title="`Mark ${money(toPay.netCents)} to ${toPay.merchantName} as paid?`"
    confirm-label="Mark as paid"
    @confirm="confirmPaid"
    @cancel="toPay = null"
  >
    Do this once the money has been sent. It covers {{ toPay.bookingCount }} online
    {{ toPay.bookingCount === 1 ? 'booking' : 'bookings' }}: {{ money(toPay.grossCents) }} in sales minus
    {{ money(toPay.commissionCents) }} commission<template v-if="toPay.refundsCents">
      minus {{ money(toPay.refundsCents) }} refunds</template
    >. If anything was booked or cancelled since this page loaded, Pin
    asks you to check the new amount first.
  </ConfirmDialog>
</template>

<style scoped>
.min {
  min-width: 920px;
}

.net {
  font-weight: 800;
}
</style>
