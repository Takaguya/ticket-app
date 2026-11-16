import { ref } from 'vue'

import type { Period } from './api/types'

// The days the panel's figures are counted for, chosen with the dates at the top right.
// Null is the server's default, this month up to today, which moves on with the
// calendar. Kept in sessionStorage like the session, so a reload keeps it.

const STORAGE_KEY = 'pin-admin-period'

export const chosenPeriod = ref<Period | null>(load())

export function choosePeriod(period: Period | null): void {
  chosenPeriod.value = period
  if (period) sessionStorage.setItem(STORAGE_KEY, JSON.stringify(period))
  else sessionStorage.removeItem(STORAGE_KEY)
}

export interface Preset {
  label: string
  /** Null for "This month": the server's default. */
  period: Period | null
}

/** The quick choices, from Pin's today, e.g. "2026-11-14". */
export function presets(today: string): Preset[] {
  const [year = 2000, month = 1, day = 1] = today.split('-').map(Number)
  return [
    { label: 'Today', period: { from: today, to: today } },
    { label: 'Last 7 days', period: { from: isoDate(year, month, day - 6), to: today } },
    { label: 'Last 30 days', period: { from: isoDate(year, month, day - 29), to: today } },
    { label: 'This month', period: null },
    { label: 'Last month', period: { from: isoDate(year, month - 1, 1), to: isoDate(year, month, 0) } },
    { label: 'This year', period: { from: isoDate(year, 1, 1), to: today } },
  ]
}

export function samePeriod(a: Period | null, b: Period | null): boolean {
  return a === b || (a !== null && b !== null && a.from === b.from && a.to === b.to)
}

/** "2026-11-08" for (2026, 11, 8). Days and months past either end roll over: day 0 is the month before's last. */
function isoDate(year: number, month: number, day: number): string {
  return new Date(Date.UTC(year, month - 1, day)).toISOString().slice(0, 10)
}

function load(): Period | null {
  try {
    const saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY) ?? 'null') as Period | null
    if (saved && typeof saved.from === 'string' && typeof saved.to === 'string') return saved
  } catch {
    // A damaged entry: the default.
  }
  return null
}
