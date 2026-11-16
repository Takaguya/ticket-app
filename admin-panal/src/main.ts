import { createApp } from 'vue'

import App from './App.vue'
import { onSessionRejected } from './api/http'
import { resetBackOffice } from './backOffice'
import { router } from './router'
import { clearSession } from './session'
import { showToast } from './toast'
import './styles.css'

// A token the server refuses (expired after 12 hours, or signed out elsewhere) ends
// the session here too.
onSessionRejected(() => {
  clearSession()
  resetBackOffice()
  showToast('Your session has ended. Please sign in again.', 'error')
  void router.replace({ name: 'sign-in', query: { next: router.currentRoute.value.fullPath } })
})

createApp(App).use(router).mount('#app')
