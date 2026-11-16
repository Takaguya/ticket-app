// How amounts, dates and phone numbers are written in the panel.

import type {
  AdminRole,
  BookingStatus,
  BusinessType,
  EventKind,
  EventStatus,
  MerchantStatus,
  PaymentMethod,
} from './api/types'

const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** 302100 → "$3,021.00" */
export function money(cents: number): string {
  return usd.format(cents / 100)
}

/** Refunds taken off a payout: 1500 → "−$15.00"; none (or an older server that sends none) → "—". */
export function refunds(cents: number | undefined): string {
  return cents ? `−${money(cents)}` : '—'
}

/** "2026-11-19T06:00:00" or "2026-11-19" → "19 Nov 2026". The date as written, no time zone. */
export function date(localDateTime: string): string {
  const { year, month, day } = parts(localDateTime)
  return `${day} ${MONTHS[month - 1]} ${year}`
}

/** "Today" when the date is `today` (Pin's today, from the server), else "19 Nov 2026". */
export function eventDate(startsAt: string, today: string | undefined): string {
  return today !== undefined && startsAt.slice(0, 10) === today ? 'Today' : date(startsAt)
}

/** "2026-11-12T10:05:00" → "12 Nov, 10:05" */
export function dateTime(localDateTime: string): string {
  const { month, day } = parts(localDateTime)
  return `${day} ${MONTHS[month - 1]}, ${localDateTime.slice(11, 16)}`
}

/** "2026-11-01" to "2026-11-14" → "1–14 Nov 2026" */
export function period(from: string, to: string): string {
  const a = parts(from)
  const b = parts(to)
  if (from === to) return date(from)
  if (a.year === b.year && a.month === b.month) return `${a.day}–${b.day} ${MONTHS[b.month - 1]} ${b.year}`
  if (a.year === b.year) return `${a.day} ${MONTHS[a.month - 1]} – ${date(to)}`
  return `${date(from)} – ${date(to)}`
}

/** "+85512345678" → "012 345 678", as people write Cambodian numbers. */
export function phone(e164: string): string {
  if (!e164.startsWith('+855')) return e164
  const local = '0' + e164.slice(4)
  return `${local.slice(0, 3)} ${local.slice(3, 6)} ${local.slice(6)}`
}

/** "Moniroth Prak" → "Moniroth P." */
export function shortName(name: string): string {
  const [first, ...rest] = name.trim().split(/\s+/)
  const last = rest.at(-1)
  return last ? `${first} ${last[0]}.` : (first ?? '')
}

/** "Moniroth Prak" → "MP" */
export function initials(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean)
  const letters = words.length > 1 ? [words[0], words.at(-1)] : words
  return letters.map((word) => word?.[0]?.toUpperCase() ?? '').join('')
}

export function percent(rate: number): string {
  return `${Number.isInteger(rate) ? rate : rate.toFixed(1)}%`
}

export const BUSINESS_TYPES: Record<BusinessType, string> = {
  events: 'Events',
  bus: 'Bus',
  cinema: 'Cinema',
  admission: 'Admission',
}

export const EVENT_KINDS: Record<EventKind, string> = {
  marathon: 'Marathon',
  concert: 'Concert',
  show: 'Show',
  bus: 'Bus trip',
  cinema: 'Screening',
  admission: 'Place',
}

export const ADMIN_ROLES: Record<AdminRole, string> = {
  superAdmin: 'Super admin',
  admin: 'Admin',
}

export const PAYMENT_METHODS: Record<PaymentMethod, string> = {
  abaKhqr: 'ABA / KHQR',
  card: 'Card',
  cash: 'Cash',
}

export type Status = MerchantStatus | EventStatus | BookingStatus | 'due' | 'paid' | 'firstSignIn' | 'noPassword'

/** The words and colours of each status pill, from the design. */
export const STATUSES: Record<Status, { label: string; background: string; color: string }> = {
  active: { label: 'Active', background: '#e7f5ea', color: '#1d6b2d' },
  pending: { label: 'Pending', background: '#fdf4ce', color: '#6b5000' },
  suspended: { label: 'Suspended', background: '#fdeaea', color: '#b02a2e' },
  live: { label: 'Live', background: '#e7f5ea', color: '#1d6b2d' },
  onSale: { label: 'On sale', background: '#e8f1fb', color: '#0151A6' },
  awaitingApproval: { label: 'Awaiting approval', background: '#fdf4ce', color: '#6b5000' },
  paused: { label: 'Merchant suspended', background: '#fdeaea', color: '#b02a2e' },
  ended: { label: 'Ended', background: '#efefef', color: '#4d4d4d' },
  checkedIn: { label: 'Checked in', background: '#e7f5ea', color: '#1d6b2d' },
  open: { label: 'Not checked in', background: '#e8f1fb', color: '#0151A6' },
  cancelled: { label: 'Cancelled', background: '#fdeaea', color: '#b02a2e' },
  due: { label: 'Due', background: '#fdf4ce', color: '#6b5000' },
  paid: { label: 'Paid', background: '#e7f5ea', color: '#1d6b2d' },
  firstSignIn: { label: 'Waiting for first sign-in', background: '#fdf4ce', color: '#6b5000' },
  noPassword: { label: "Can't sign in", background: '#efefef', color: '#4d4d4d' },
}

function parts(text: string): { year: number; month: number; day: number } {
  const [year = 0, month = 1, day = 1] = text.slice(0, 10).split('-').map(Number)
  return { year, month, day }
}
