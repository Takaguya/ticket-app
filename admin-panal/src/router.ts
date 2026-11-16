import { createRouter, createWebHistory } from 'vue-router'

import AppShell from './components/AppShell.vue'
import { isSignedIn, session } from './session'
import AdminsView from './views/AdminsView.vue'
import BookingsView from './views/BookingsView.vue'
import ChangePasswordView from './views/ChangePasswordView.vue'
import DashboardView from './views/DashboardView.vue'
import EventsView from './views/EventsView.vue'
import ForgotPasswordView from './views/ForgotPasswordView.vue'
import MerchantsView from './views/MerchantsView.vue'
import PayoutsView from './views/PayoutsView.vue'
import ProfileView from './views/ProfileView.vue'
import SignInView from './views/SignInView.vue'

declare module 'vue-router' {
  interface RouteMeta {
    /** Open without signing in. */
    public?: boolean
    title?: string
    subtitle?: string
    /** The header search box's placeholder. Pages without one have no search box. */
    searchHint?: string
    /** The page's figures follow the dates chosen at the top right, which only such pages show. */
    period?: boolean
  }
}

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/sign-in', name: 'sign-in', component: SignInView, meta: { public: true } },
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: ForgotPasswordView,
      meta: { public: true, title: 'Forgot password' },
    },
    {
      path: '/',
      component: AppShell,
      children: [
        {
          path: '',
          name: 'dashboard',
          component: DashboardView,
          meta: {
            title: 'Dashboard',
            subtitle: 'Sales, approvals and payouts at a glance',
            searchHint: 'Search',
            period: true,
          },
        },
        {
          path: 'merchants',
          name: 'merchants',
          component: MerchantsView,
          meta: {
            title: 'Merchants',
            subtitle: 'Businesses that sell on Pin',
            searchHint: 'Search business, owner or phone',
            period: true,
          },
        },
        {
          path: 'events',
          name: 'events',
          component: EventsView,
          meta: {
            title: 'Events',
            subtitle: 'Every event published by merchants',
            searchHint: 'Search event or merchant',
          },
        },
        {
          path: 'bookings',
          name: 'bookings',
          component: BookingsView,
          meta: {
            title: 'Bookings',
            subtitle: 'Tickets bought in the user app or at the door',
            searchHint: 'Search booking ID, buyer or event',
            period: true,
          },
        },
        {
          path: 'payouts',
          name: 'payouts',
          component: PayoutsView,
          meta: {
            title: 'Payouts',
            subtitle: 'What Pin owes each merchant for online sales',
            searchHint: 'Search merchant',
            period: true,
          },
        },
        {
          path: 'admins',
          name: 'admins',
          component: AdminsView,
          meta: { title: 'Admins', subtitle: 'Who can sign in to Pin Admin', searchHint: 'Search name or email' },
        },
        {
          path: 'profile',
          name: 'profile',
          component: ProfileView,
          meta: { title: 'Your profile', subtitle: 'Who you are in Pin Admin' },
        },
        {
          path: 'password',
          name: 'change-password',
          component: ChangePasswordView,
          meta: { title: 'Change password', subtitle: 'Your password for Pin Admin' },
        },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

router.beforeEach((to) => {
  if (!to.meta.public && !isSignedIn()) {
    return { name: 'sign-in', query: to.fullPath === '/' ? {} : { next: to.fullPath } }
  }
  if (to.name === 'sign-in' && isSignedIn()) return { name: 'dashboard' }
  // Signed in with a temporary password: choose your own before anything else.
  if (!to.meta.public && session.admin?.mustChangePassword && to.name !== 'change-password') {
    return { name: 'change-password' }
  }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.title ? `${to.meta.title} · Pin Admin` : 'Pin Admin'
})
