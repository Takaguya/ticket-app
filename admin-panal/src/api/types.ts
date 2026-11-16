// The JSON of the Pin API's admin endpoints (backend: admin/web/AdminDtos.java).
// Money is whole US cents. Dates and times are local to Pin's time zone, without an
// offset: "2026-11-14" and "2026-11-14T05:30:00".

/** Super admins also add and remove admins; admins do everything else. */
export type AdminRole = 'superAdmin' | 'admin'

export interface Admin {
  id: string
  name: string
  /** Lower case, e.g. moniroth@pin.example */
  email: string
  role: AdminRole
  /** Signed in with a temporary password: must choose their own before anything else. */
  mustChangePassword: boolean
}

/** One admin on the Admins page, or the signed-in admin's profile. */
export interface AdminSummary {
  id: string
  name: string
  email: string
  role: AdminRole
  addedAt: string
  /** The admin who added them; null when added from the server settings. */
  addedBy: string | null
  /** `temporary`: still has the password they were given; `none`: cannot sign in. */
  password: 'own' | 'temporary' | 'none'
  /** The signed-in admin. */
  you: boolean
}

/** A newly added admin, with the temporary password: the only time it is shown. */
export interface AddedAdmin {
  id: string
  name: string
  email: string
  role: AdminRole
  temporaryPassword: string
}

export interface AdminSession {
  accessToken: string
  admin: Admin
}

/** Days, both included, e.g. { from: "2026-11-01", to: "2026-11-14" }. */
export interface Period {
  from: string
  to: string
}

export interface Overview {
  /** The days figures are counted for: the period asked for, or this month up to today. */
  period: Period
  /** Today in Pin's time zone, e.g. "2026-11-14". */
  today: string
  /** Percent Pin keeps of online sales, for new events. */
  commissionRate: number
}

export type MerchantStatus = 'pending' | 'active' | 'suspended'
export type BusinessType = 'events' | 'bus' | 'cinema' | 'admission'

export interface Merchant {
  id: string
  name: string
  type: BusinessType
  status: MerchantStatus
  /** Null only if the owner's record is missing. */
  owner: { name: string; phone: string } | null
  events: number
  /** Online sales this period, not cancelled. */
  onlineSalesCents: number
  commissionCents: number
  registeredAt: string
}

export interface MerchantStatusChange {
  id: string
  name: string
  status: MerchantStatus
}

/** `paused`: approved, but its merchant is suspended. */
export type EventStatus = 'awaitingApproval' | 'live' | 'onSale' | 'paused' | 'ended'

/** `admission`: a place open every day. Its `startsAt` is only the day it was published, `capacity` is 0 and `sold` counts every day. */
export type EventKind = 'marathon' | 'concert' | 'show' | 'bus' | 'cinema' | 'admission'

export interface AdminEvent {
  id: string
  name: string
  venue: string
  startsAt: string
  merchantId: string
  merchantName: string
  status: EventStatus
  sold: number
  capacity: number
  /** Chosen by the merchant. Missing from an older server. */
  kind?: EventKind
  /** Where the cover image is on the server (a path), or null when it has none. Missing from an older server. */
  imageUrl?: string | null
}

export type PaymentMethod = 'abaKhqr' | 'card' | 'cash'
export type BookingStatus = 'open' | 'checkedIn' | 'cancelled'

export interface AdminBooking {
  id: string
  buyerName: string
  eventName: string
  merchantName: string
  tickets: number
  totalCents: number
  payment: PaymentMethod
  channel: 'online' | 'door'
  status: BookingStatus
  createdAt: string
}

/** One page of a bookings search, newest first. */
export interface BookingPage {
  /** How many bookings match in all. */
  total: number
  /** This page, from 1. */
  page: number
  /** Bookings per page. */
  size: number
  /** How many pages the matches fill; at least 1. */
  pages: number
  bookings: AdminBooking[]
}

/** What Pin owes a merchant now: online bookings no payout covers yet. */
export interface Owed {
  merchantId: string
  merchantName: string
  grossCents: number
  commissionCents: number
  /** The merchant's share of paid-out bookings it cancelled since, taken off this payout. 0 when missing. */
  refundsCents?: number
  netCents: number
  bookingCount: number
}

export interface Paid {
  id: string
  merchantId: string
  merchantName: string
  grossCents: number
  commissionCents: number
  refundsCents?: number
  netCents: number
  bookingCount: number
  paidAt: string
  paidBy: string
}

export interface Payouts {
  owed: Owed[]
  /** Payouts made this period, newest first. */
  paid: Paid[]
}
