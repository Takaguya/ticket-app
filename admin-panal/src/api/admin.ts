import { session } from '../session'
import { request } from './http'
import type {
  AddedAdmin,
  Admin,
  AdminEvent,
  AdminRole,
  AdminSession,
  AdminSummary,
  BookingPage,
  Merchant,
  MerchantStatusChange,
  Overview,
  Paid,
  Payouts,
  Period,
} from './types'

// The Pin API's admin endpoints. Signed-in calls send the session's token.

const signedIn = () => ({ token: session.token })

/** `?from=…&to=…` for a period; nothing for the server's default (this month up to today). */
const inPeriod = (period: Period | null) =>
  period ? `?${new URLSearchParams({ from: period.from, to: period.to })}` : ''

export const adminApi = {
  /**
   * Signs in with an admin's email and password. A wrong email or password is refused
   * with 400; after too many wrong passwords, sign-in is locked for a while (429).
   */
  signIn(email: string, password: string): Promise<AdminSession> {
    return request('/admin/auth/sign-in', { method: 'POST', body: { email, password } })
  },

  /** Whether "forgot password" can set a new password here: on development servers only. */
  passwordResetAvailable(): Promise<{ available: boolean }> {
    return request('/admin/auth/password-reset')
  },

  /** Development servers only: gives the admin a new password and signs them out everywhere. */
  resetPassword(email: string, newPassword: string): Promise<void> {
    return request('/admin/auth/password-reset', { method: 'POST', body: { email, newPassword } })
  },

  signOut(): Promise<void> {
    return request('/admin/auth/sign-out', { method: 'POST', ...signedIn() })
  },

  me(): Promise<Admin> {
    return request('/admin/me', signedIn())
  },

  /** Changes the signed-in admin's password. Their other browsers are signed out; this one stays. */
  changePassword(currentPassword: string, newPassword: string): Promise<void> {
    return request('/admin/me/password', { method: 'POST', body: { currentPassword, newPassword }, ...signedIn() })
  },

  /** Every admin, the earliest added first. */
  admins(): Promise<AdminSummary[]> {
    return request('/admin/admins', signedIn())
  },

  /** Super admins only: adds an admin. The answer holds their temporary password, shown this once only. */
  addAdmin(name: string, email: string, role: AdminRole): Promise<AddedAdmin> {
    return request('/admin/admins', { method: 'POST', body: { name, email, role }, ...signedIn() })
  },

  /** Super admins only: removes the admin, who is signed out at once. Never yourself. */
  removeAdmin(id: string): Promise<void> {
    return request(`/admin/admins/${encodeURIComponent(id)}/remove`, { method: 'POST', ...signedIn() })
  },

  /** Super admins only: gives another admin a new role, from their next request. Not your own. */
  changeRole(id: string, role: AdminRole): Promise<AdminSummary> {
    return request(`/admin/admins/${encodeURIComponent(id)}/role`, { method: 'POST', body: { role }, ...signedIn() })
  },

  /** The signed-in admin's profile. */
  profile(): Promise<AdminSummary> {
    return request('/admin/me/profile', signedIn())
  },

  /** The period figures are counted for (`period`, or this month), Pin's today and the commission rate. */
  overview(period: Period | null): Promise<Overview> {
    return request(`/admin/overview${inPeriod(period)}`, signedIn())
  },

  /** Every merchant, with online sales and commission in the period. */
  merchants(period: Period | null): Promise<Merchant[]> {
    return request(`/admin/merchants${inPeriod(period)}`, signedIn())
  },

  approveMerchant(id: string): Promise<MerchantStatusChange> {
    return request(`/admin/merchants/${encodeURIComponent(id)}/approve`, { method: 'POST', ...signedIn() })
  },

  suspendMerchant(id: string): Promise<MerchantStatusChange> {
    return request(`/admin/merchants/${encodeURIComponent(id)}/suspend`, { method: 'POST', ...signedIn() })
  },

  reinstateMerchant(id: string): Promise<MerchantStatusChange> {
    return request(`/admin/merchants/${encodeURIComponent(id)}/reinstate`, { method: 'POST', ...signedIn() })
  },

  events(): Promise<AdminEvent[]> {
    return request('/admin/events', signedIn())
  },

  approveEvent(id: string): Promise<{ id: string; name: string; approved: boolean }> {
    return request(`/admin/events/${encodeURIComponent(id)}/approve`, { method: 'POST', ...signedIn() })
  },

  /**
   * Sets or replaces an event's cover image with a picture (JPEG or PNG, up to 5 MB). The
   * server checks it, shrinks it and keeps its own copy. The answer is the picture's new
   * path, which changes whenever the picture does.
   */
  setEventImage(id: string, picture: File): Promise<{ imageUrl: string }> {
    return request(`/admin/events/${encodeURIComponent(id)}/image`, { method: 'PUT', file: picture, ...signedIn() })
  },

  /** Takes an event's cover image down. */
  removeEventImage(id: string): Promise<void> {
    return request(`/admin/events/${encodeURIComponent(id)}/image`, { method: 'DELETE', ...signedIn() })
  },

  /** Page `page` (from 1) of the bookings matching `query`, `size` per page (100 at most). */
  bookings(query: string, period: Period, page: number, size: number, signal?: AbortSignal): Promise<BookingPage> {
    const params = new URLSearchParams({
      q: query,
      from: period.from,
      to: period.to,
      page: String(page),
      size: String(size),
    })
    return request(`/admin/bookings?${params}`, { ...signedIn(), signal })
  },

  /** What Pin owes each merchant now, and the payouts made in the period. */
  payouts(period: Period | null): Promise<Payouts> {
    return request(`/admin/payouts${inPeriod(period)}`, signedIn())
  },

  /** Records that the merchant was sent `netCents`, everything it is owed. */
  pay(merchantId: string, netCents: number): Promise<Paid> {
    return request('/admin/payouts', { method: 'POST', body: { merchantId, netCents }, ...signedIn() })
  },
}
