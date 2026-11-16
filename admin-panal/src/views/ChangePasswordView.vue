<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { useRouter } from 'vue-router'

import { adminApi } from '../api/admin'
import { ApiError } from '../api/http'
import { refresh } from '../backOffice'
import { saveSession, session } from '../session'
import { showToast } from '../toast'

// The signed-in admin changes their password. The current one must be right; wrong
// guesses count towards the same lock as at sign-in. This browser stays signed in,
// every other browser signed in as the admin is signed out.
//
// A new admin lands here after signing in with the temporary password they were given,
// and can use the rest of the panel once they have chosen their own.

const MIN_LENGTH = 12

const router = useRouter()

const firstTime = computed(() => session.admin?.mustChangePassword === true)

const current = ref('')
const password = ref('')
const repeated = ref('')
const showPasswords = ref(false)
const error = ref<string | null>(null)
const working = ref(false)
const currentInput = ref<HTMLInputElement | null>(null)

async function save() {
  if (working.value) return
  if (!current.value) {
    error.value = 'Enter your current password.'
    return
  }
  if ([...password.value].length < MIN_LENGTH) {
    error.value = `A password needs at least ${MIN_LENGTH} characters.`
    return
  }
  if (password.value !== repeated.value) {
    error.value = 'The two new passwords are not the same.'
    return
  }
  working.value = true
  error.value = null
  try {
    await adminApi.changePassword(current.value, password.value)
    current.value = ''
    password.value = ''
    repeated.value = ''
    showPasswords.value = false
    if (firstTime.value && session.token && session.admin) {
      saveSession(session.token, { ...session.admin, mustChangePassword: false })
      void refresh()
      showToast('Password set. Welcome to Pin Admin.')
      await router.replace({ name: 'dashboard' })
    } else {
      showToast('Password changed. Your other browsers were signed out.')
    }
  } catch (failure) {
    error.value = failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
    if (failure instanceof ApiError && failure.message === 'Your current password is wrong.') {
      // Selected, so typing it again replaces it.
      await nextTick()
      currentInput.value?.select()
    }
  } finally {
    working.value = false
  }
}
</script>

<template>
  <section class="card panel">
    <form class="form" novalidate @submit.prevent="save">
      <p v-if="firstTime" class="welcome">
        Welcome to Pin Admin. Choose your own password to start. Your current password is the temporary one you were
        given.
      </p>
      <p v-else class="hint">You stay signed in here. Any other browser signed in as you is signed out.</p>
      <div class="field">
        <label for="current-password">Current password</label>
        <span class="password-input">
          <input
            id="current-password"
            ref="currentInput"
            v-model="current"
            :type="showPasswords ? 'text' : 'password'"
            autocomplete="current-password"
            autofocus
          />
          <button
            type="button"
            class="link reveal"
            :aria-label="showPasswords ? 'Hide passwords' : 'Show passwords'"
            @click="showPasswords = !showPasswords"
          >
            {{ showPasswords ? 'Hide' : 'Show' }}
          </button>
        </span>
      </div>
      <label class="field">
        New password
        <input
          v-model="password"
          :type="showPasswords ? 'text' : 'password'"
          autocomplete="new-password"
          aria-describedby="new-password-rule"
        />
        <span id="new-password-rule" class="rule">At least {{ MIN_LENGTH }} characters.</span>
      </label>
      <label class="field">
        Repeat new password
        <input v-model="repeated" :type="showPasswords ? 'text' : 'password'" autocomplete="new-password" />
      </label>
      <p v-if="error" class="error-text" role="alert">{{ error }}</p>
      <div>
        <button type="submit" class="btn save" :disabled="working">
          {{ working ? 'Saving…' : 'Change password' }}
        </button>
      </div>
    </form>
  </section>
</template>

<style scoped>
.panel {
  max-width: 460px;
  padding: 24px;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.hint {
  margin: 0 0 4px;
  font-size: 14px;
  color: var(--muted);
}

.welcome {
  margin: 0 0 4px;
  padding: 10px 12px;
  border-radius: 10px;
  background: var(--blue-soft);
  color: var(--ink);
  font-size: 14px;
  line-height: 1.4;
}

.rule {
  font-size: 12.5px;
  font-weight: 400;
  color: var(--muted);
}

.save {
  min-height: 44px;
  padding: 0 20px;
  font-size: 14px;
}
</style>
