<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, watch } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'

import { adminApi } from '../api/admin'
import { awaitingEvents, backOffice, pendingMerchants, refresh, resetBackOffice } from '../backOffice'
import { initials, shortName } from '../format'
import { choosePeriod } from '../period'
import { pageSearch } from '../search'
import { clearSession, saveSession, session } from '../session'
import PeriodPicker from './PeriodPicker.vue'

// The signed-in layout: navigation on the left, the page's title, search and period
// on top. The lists are reloaded every 30 seconds while the tab is visible, so new
// merchants, events and bookings show up without a reload.

const REFRESH_EVERY_MS = 30_000

const NAV = [
  { name: 'dashboard', label: 'Dashboard', icon: 'M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z' },
  { name: 'merchants', label: 'Merchants', icon: 'M4 9l1-5h14l1 5M4 9v11h16V9M4 9h16M9 20v-6h6v6' },
  { name: 'events', label: 'Events', icon: 'M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1zM4 10h16M8 3v4M16 3v4' },
  { name: 'bookings', label: 'Bookings', icon: 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6' },
  {
    name: 'payouts',
    label: 'Payouts',
    icon: 'M3 7a2 2 0 0 1 2-2h13v4M3 7v10a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2zM16.5 14h.01',
  },
  {
    name: 'admins',
    label: 'Admins',
    icon: 'M16 20v-1a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v1M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 20v-1a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  },
] as const

const route = useRoute()
const router = useRouter()

const badges = computed<Record<string, number>>(() => ({
  merchants: pendingMerchants.value.length,
  events: awaitingEvents.value.length,
}))

const adminName = computed(() => session.admin?.name ?? '')

/** Signed in with a temporary password: only Change password is open until they choose their own. */
const mustChangePassword = computed(() => session.admin?.mustChangePassword === true)

watch(
  () => route.name,
  () => {
    pageSearch.value = ''
  },
)

let timer: ReturnType<typeof setInterval> | undefined

function refreshIfVisible() {
  if (document.visibilityState === 'visible' && !mustChangePassword.value) void refresh()
}

/**
 * The saved admin may be older than a change made since, such as a new role: take the
 * server's. A refused session (401) returns to sign-in on its own.
 */
async function reloadMe() {
  try {
    const me = await adminApi.me()
    if (session.token) saveSession(session.token, me)
  } catch {
    // Keep the saved admin until the next try.
  }
}

onMounted(() => {
  void reloadMe()
  if (!mustChangePassword.value) void refresh()
  timer = setInterval(refreshIfVisible, REFRESH_EVERY_MS)
  document.addEventListener('visibilitychange', refreshIfVisible)
})

onBeforeUnmount(() => {
  clearInterval(timer)
  document.removeEventListener('visibilitychange', refreshIfVisible)
})

async function signOut() {
  try {
    await adminApi.signOut()
  } catch {
    // Signed out on this browser either way.
  }
  clearSession()
  choosePeriod(null)
  resetBackOffice()
  await router.replace({ name: 'sign-in' })
}
</script>

<template>
  <div class="layout">
    <nav class="sidebar" aria-label="Admin sections">
      <div class="brand">
        <img src="/pin-logo.png" alt="Pin" />
        <div>
          <div class="brand-name">Pin Admin</div>
          <div class="brand-sub">Back office</div>
        </div>
      </div>

      <div v-if="!mustChangePassword" class="nav-list">
        <RouterLink
          v-for="item in NAV"
          :key="item.name"
          :to="{ name: item.name }"
          class="nav"
          :aria-current="route.name === item.name ? 'page' : undefined"
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path :d="item.icon" />
          </svg>
          <span class="nav-label">{{ item.label }}</span>
          <span
            v-if="badges[item.name]"
            class="pill num badge"
            :aria-label="`${badges[item.name]} waiting for approval`"
          >
            {{ badges[item.name] }}
          </span>
        </RouterLink>
      </div>

      <div class="me">
        <RouterLink :to="{ name: 'profile' }" class="avatar" tabindex="-1" aria-hidden="true">
          {{ initials(adminName) }}
        </RouterLink>
        <div class="me-text">
          <RouterLink
            :to="{ name: 'profile' }"
            class="me-name"
            title="Your profile"
            :aria-current="route.name === 'profile' ? 'page' : undefined"
          >
            {{ shortName(adminName) }}
          </RouterLink>
          <div class="me-actions">
            <RouterLink
              :to="{ name: 'change-password' }"
              class="link"
              :aria-current="route.name === 'change-password' ? 'page' : undefined"
            >
              Change password
            </RouterLink>
            <button type="button" class="link" @click="signOut">Sign out</button>
          </div>
        </div>
      </div>
    </nav>

    <div class="main">
      <header class="header">
        <div class="titles">
          <h1>{{ route.meta.title }}</h1>
          <div class="subtitle">{{ route.meta.subtitle }}</div>
        </div>
        <label v-if="route.meta.searchHint" class="search">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#5c5c5c" stroke-width="2" stroke-linecap="round" aria-hidden="true">
            <path d="M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4" />
          </svg>
          <span class="visually-hidden">Search this page</span>
          <input v-model="pageSearch" type="search" :placeholder="route.meta.searchHint" />
        </label>
        <PeriodPicker v-if="route.meta.period" />
      </header>

      <main class="content">
        <div v-if="backOffice.error" class="notice" role="alert">
          <span>{{ backOffice.error }}</span>
          <button type="button" class="btn ghost" @click="refresh">Try again</button>
        </div>
        <RouterView />
      </main>
    </div>
  </div>
</template>

<style scoped>
.layout {
  min-height: 100vh;
  display: flex;
  flex-wrap: wrap;
  align-items: stretch;
}

.sidebar {
  flex: 1 1 232px;
  max-width: 100%;
  background: #fff;
  border-right: 1px solid var(--line);
  padding: 20px 14px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

/*
 * Beside the page (wide screens), the sidebar stays in view while the page scrolls,
 * so the profile at its foot is always at the bottom of the window. On narrow screens
 * it sits above the page and scrolls with it.
 */
@media (min-width: 800px) {
  .sidebar {
    position: sticky;
    top: 0;
    align-self: flex-start;
    height: 100vh;
    overflow-y: auto;
  }
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 6px;
}

.brand img {
  height: 34px;
  width: auto;
  display: block;
}

.brand-name {
  font-size: 16px;
  font-weight: 800;
  line-height: 1.1;
}

.brand-sub {
  font-size: 12px;
  color: var(--muted);
}

.nav-list {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-label {
  flex: 1 1 0%;
}

.badge {
  background: var(--yellow);
  color: var(--ink);
}

.me {
  margin-top: auto;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 6px 0;
  border-top: 1px solid var(--line-soft);
}

.avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--blue);
  color: #fff;
  font-size: 13px;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
}

.me-text {
  min-width: 0;
}

.avatar {
  text-decoration: none;
}

.me-name {
  display: block;
  font-size: 13.5px;
  font-weight: 700;
  color: var(--ink);
  text-decoration: none;
}

.me-name:hover,
.me-name[aria-current='page'] {
  color: var(--blue);
  text-decoration: underline;
}

.me-actions {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
}

.me-actions .link {
  font-size: 13px;
  text-decoration: none;
}

.main {
  flex: 999 1 560px;
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.header {
  background: #fff;
  border-bottom: 1px solid var(--line);
  padding: 14px 24px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
}

.titles {
  flex: 1 1 220px;
  min-width: 0;
}

h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 800;
  line-height: 1.2;
}

.subtitle {
  font-size: 13px;
  color: var(--muted);
  margin-top: 2px;
}

.search {
  flex: 1 1 240px;
  max-width: 360px;
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--page);
  border-radius: 12px;
  padding: 0 12px;
  min-height: 44px;
}

.search input {
  flex: 1 1 0%;
  min-width: 0;
  border: 0;
  outline: 0;
  background: transparent;
  font-size: 14px;
  color: var(--ink);
}

.content {
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  min-width: 0;
}
</style>
