import { reactive, readonly } from 'vue'

import type { Admin } from './api/types'

// Who is signed in. Kept in sessionStorage: it survives a page reload but not closing
// the tab, which suits a back office on shared computers. The server ends sessions
// after 12 hours anyway.

const STORAGE_KEY = 'pin-admin-session'

interface SessionState {
  token: string | null
  admin: Admin | null
}

const state = reactive<SessionState>(load())

export const session = readonly(state)

export function isSignedIn(): boolean {
  return state.token !== null
}

export function saveSession(token: string, admin: Admin): void {
  state.token = token
  state.admin = admin
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ token, admin }))
}

export function clearSession(): void {
  state.token = null
  state.admin = null
  sessionStorage.removeItem(STORAGE_KEY)
}

function load(): SessionState {
  try {
    const saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY) ?? 'null') as SessionState | null
    if (saved && typeof saved.token === 'string' && saved.admin) return saved
  } catch {
    // A damaged entry: start signed out.
  }
  return { token: null, admin: null }
}
