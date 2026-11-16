<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'

import type { AdminEvent, Merchant } from '../api/types'
import {
  approveEvent,
  approveMerchant,
  awaitingEvents,
  backOffice,
  isBusy,
  pendingMerchants,
  today,
} from '../backOffice'
import { BUSINESS_TYPES, eventDate, money, percent } from '../format'
import { matchesSearch } from '../search'

const router = useRouter()

const kpis = computed(() => {
  const merchants = backOffice.merchants
  const rate = backOffice.overview?.commissionRate ?? 5
  const sales = merchants.reduce((sum, m) => sum + m.onlineSalesCents, 0)
  const commission = merchants.reduce((sum, m) => sum + m.commissionCents, 0)
  const active = merchants.filter((m) => m.status === 'active').length
  const onSale = backOffice.events.filter((e) => e.status === 'onSale' || e.status === 'live').length
  return [
    { label: 'Online ticket sales', value: money(sales), note: 'All merchants, this period' },
    { label: 'Pin commission', value: money(commission), note: `${percent(rate)} of online sales` },
    { label: 'Active merchants', value: String(active), note: `of ${merchants.length} registered` },
    { label: 'Events on sale', value: String(onSale), note: `${awaitingEvents.value.length} awaiting approval` },
  ]
})

type Approval =
  | { kind: 'merchant'; id: string; name: string; detail: string; merchant: Merchant }
  | { kind: 'event'; id: string; name: string; detail: string; event: AdminEvent }

const approvals = computed<Approval[]>(() => [
  ...pendingMerchants.value.map((merchant) => ({
    kind: 'merchant' as const,
    id: merchant.id,
    name: merchant.name,
    detail: `${BUSINESS_TYPES[merchant.type]} · ${merchant.owner?.name ?? 'Owner unknown'}`,
    merchant,
  })),
  ...awaitingEvents.value.map((event) => ({
    kind: 'event' as const,
    id: event.id,
    name: event.name,
    detail: `${event.merchantName} · ${eventDate(event.startsAt, today.value)}`,
    event,
  })),
])

const shownApprovals = computed(() => approvals.value.filter((a) => matchesSearch(a.name, a.detail)))
const shownOwed = computed(() => backOffice.payouts.owed.filter((o) => matchesSearch(o.merchantName)))

/** An event of a merchant that is not approved yet cannot be approved before it. */
function blockedBy(approval: Approval): string | null {
  if (approval.kind !== 'event') return null
  const merchant = backOffice.merchants.find((m) => m.id === approval.event.merchantId)
  return merchant && merchant.status !== 'active' ? `Approve ${merchant.name} first` : null
}

function approve(approval: Approval) {
  void (approval.kind === 'merchant' ? approveMerchant(approval.merchant) : approveEvent(approval.event))
}
</script>

<template>
  <div class="kpis">
    <div v-for="kpi in kpis" :key="kpi.label" class="card kpi">
      <div class="kpi-label">{{ kpi.label }}</div>
      <div class="kpi-value num">{{ backOffice.loaded ? kpi.value : '–' }}</div>
      <div class="sub">{{ kpi.note }}</div>
    </div>
  </div>

  <div class="columns">
    <section class="card list" aria-labelledby="approvals-title">
      <div class="list-head">
        <h2 id="approvals-title">Needs approval</h2>
        <span class="pill num waiting">{{ approvals.length }} waiting</span>
      </div>
      <div v-for="approval in shownApprovals" :key="approval.kind + approval.id" class="row two">
        <div class="cell">
          <div class="strong">{{ approval.name }}</div>
          <div class="sub">
            {{ approval.kind === 'merchant' ? 'New merchant' : 'New event' }} · {{ approval.detail }}
          </div>
          <div v-if="blockedBy(approval)" class="sub">{{ blockedBy(approval) }}</div>
        </div>
        <button
          type="button"
          class="btn"
          :disabled="isBusy(approval.id) || blockedBy(approval) !== null"
          @click="approve(approval)"
        >
          Approve
        </button>
      </div>
      <div v-if="backOffice.loaded && shownApprovals.length === 0" class="empty">
        {{ approvals.length === 0 ? 'Nothing is waiting for approval.' : 'Nothing matches your search.' }}
      </div>
    </section>

    <section class="card list" aria-labelledby="payouts-title">
      <div class="list-head">
        <h2 id="payouts-title">Payouts due</h2>
        <button type="button" class="btn ghost" @click="router.push({ name: 'payouts' })">See all</button>
      </div>
      <div v-for="owed in shownOwed" :key="owed.merchantId" class="row two">
        <div class="cell">
          <div class="strong">{{ owed.merchantName }}</div>
          <div class="sub">
            Online sales <span class="num">{{ money(owed.grossCents) }}</span> · commission
            <span class="num">{{ money(owed.commissionCents) }}</span>
            <template v-if="owed.refundsCents">
              · refunds <span class="num">{{ money(owed.refundsCents) }}</span>
            </template>
          </div>
        </div>
        <div class="num net">{{ money(owed.netCents) }}</div>
      </div>
      <div v-if="backOffice.loaded && shownOwed.length === 0" class="empty">
        {{ backOffice.payouts.owed.length === 0 ? 'Every merchant is paid up.' : 'Nothing matches your search.' }}
      </div>
    </section>
  </div>
</template>

<style scoped>
.kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(200px, 100%), 1fr));
  gap: 16px;
}

.kpi {
  padding: 18px 20px;
}

.kpi-label {
  font-size: 13px;
  font-weight: 700;
  color: var(--muted);
}

.kpi-value {
  font-size: 28px;
  font-weight: 800;
  margin-top: 6px;
  line-height: 1.1;
}

.columns {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(340px, 100%), 1fr));
  gap: 16px;
  align-items: start;
}

.list {
  overflow: hidden;
}

.list-head {
  padding: 16px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

h2 {
  margin: 0;
  font-size: 16px;
  font-weight: 800;
}

.waiting {
  background: #fdf4ce;
  color: #6b5000;
}

.two {
  grid-template-columns: minmax(0, 1fr) auto;
}

.cell {
  min-width: 0;
}

.net {
  font-weight: 800;
}
</style>
