import { computed, reactive, readonly } from 'vue'

import { adminApi } from './api/admin'
import { ApiError } from './api/http'
import type { AdminEvent, Merchant, Overview, Owed, Payouts, Period } from './api/types'
import { money } from './format'
import { chosenPeriod, samePeriod } from './period'
import { showToast } from './toast'

// What the dashboard, merchants, events and payouts pages show, loaded together and
// kept fresh while the panel is open. Actions call the API, then reload, so the pages
// always show what the server decided, also when another admin acted first.

interface BackOfficeState {
  overview: Overview | null
  merchants: Merchant[]
  events: AdminEvent[]
  payouts: Payouts
  /** True once the first load has finished. */
  loaded: boolean
  /** Why the last load failed, or null. */
  error: string | null
  /** IDs of merchants, events or payouts with an action in flight. */
  busy: string[]
}

const state = reactive<BackOfficeState>(emptyState())

export const backOffice = readonly(state)

export const pendingMerchants = computed(() => state.merchants.filter((m) => m.status === 'pending'))
export const awaitingEvents = computed(() => state.events.filter((e) => e.status === 'awaitingApproval'))
/** Pin's today, from the server, e.g. "2026-11-14". */
export const today = computed(() => state.overview?.today)
/**
 * The days the figures are counted for: the period chosen, or the default, this month
 * up to today, once Pin's today is known.
 */
export const currentPeriod = computed<Period | null>(() => {
  if (chosenPeriod.value) return chosenPeriod.value
  const day = today.value
  return day ? { from: `${day.slice(0, 7)}-01`, to: day } : null
})

let loading: Promise<void> | null = null
let loadingFor: Period | null = null
/** Counts loads started, so a finished load knows whether a newer one is running. */
let loadsStarted = 0

/**
 * Loads everything for the chosen period. Calls made while a load for the same period
 * is running wait for that one; an answer for a period no longer chosen is dropped.
 */
export function refresh(): Promise<void> {
  const period = chosenPeriod.value
  if (loading && samePeriod(loadingFor, period)) return loading
  const thisLoad = ++loadsStarted
  loading = (async () => {
    try {
      const [overview, merchants, events, payouts] = await Promise.all([
        adminApi.overview(period),
        adminApi.merchants(period),
        adminApi.events(),
        adminApi.payouts(period),
      ])
      if (!samePeriod(period, chosenPeriod.value)) return
      Object.assign(state, { overview, merchants, events, payouts, loaded: true, error: null })
    } catch (error) {
      if (samePeriod(period, chosenPeriod.value)) state.error = messageOf(error)
    } finally {
      if (thisLoad === loadsStarted) loading = null
    }
  })()
  loadingFor = period
  return loading
}

/** Forgets everything, e.g. on sign-out. */
export function resetBackOffice(): void {
  Object.assign(state, emptyState())
}

export function isBusy(id: string): boolean {
  return state.busy.includes(id)
}

export function approveMerchant(merchant: Merchant): Promise<void> {
  return act(merchant.id, () => adminApi.approveMerchant(merchant.id), `${merchant.name} is approved`)
}

export function suspendMerchant(merchant: Merchant): Promise<void> {
  return act(merchant.id, () => adminApi.suspendMerchant(merchant.id), `${merchant.name} is suspended`)
}

export function reinstateMerchant(merchant: Merchant): Promise<void> {
  return act(merchant.id, () => adminApi.reinstateMerchant(merchant.id), `${merchant.name} is active again`)
}

export function approveEvent(event: AdminEvent): Promise<void> {
  return act(event.id, () => adminApi.approveEvent(event.id), `${event.name} is approved and on sale`)
}

/** Sets or replaces the event's cover image. A refused picture shows the server's reason. */
export function setEventImage(event: AdminEvent, picture: File): Promise<void> {
  return act(event.id, () => adminApi.setEventImage(event.id, picture), `The picture of ${event.name} is updated`)
}

/** Takes the event's cover image down. */
export function removeEventImage(event: AdminEvent): Promise<void> {
  return act(event.id, () => adminApi.removeEventImage(event.id), `The picture of ${event.name} is removed`)
}

export function markPaid(owed: Owed): Promise<void> {
  return act(
    owed.merchantId,
    () => adminApi.pay(owed.merchantId, owed.netCents),
    `Payout of ${money(owed.netCents)} to ${owed.merchantName} marked as paid`,
  )
}

/**
 * Runs an action once at a time per item. Refusals (e.g. another admin approved it
 * first) are shown as the server wrote them. Either way the lists are reloaded.
 */
async function act(id: string, action: () => Promise<unknown>, done: string): Promise<void> {
  if (isBusy(id)) return
  state.busy.push(id)
  try {
    await action()
    showToast(done)
  } catch (error) {
    showToast(messageOf(error), 'error')
  } finally {
    await refresh()
    state.busy = state.busy.filter((busy) => busy !== id)
  }
}

function messageOf(error: unknown): string {
  if (error instanceof ApiError) return error.message
  console.error(error)
  return 'Something went wrong. Please try again.'
}

function emptyState(): BackOfficeState {
  return {
    overview: null,
    merchants: [],
    events: [],
    payouts: { owed: [], paid: [] },
    loaded: false,
    error: null,
    busy: [],
  }
}
