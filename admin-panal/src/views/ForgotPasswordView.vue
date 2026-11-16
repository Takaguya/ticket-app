<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'

import { adminApi } from '../api/admin'
import { ApiError } from '../api/http'
import AuthCard from '../components/AuthCard.vue'

// "Forgot your password?". Only a development server sets a new password straight
// away, without checking who asks; on any other server the page says to ask Pin's
// tech team, who set a new one on the server.

const MIN_LENGTH = 12

const state = ref<'checking' | 'failed' | 'unavailable' | 'form' | 'done'>('checking')
const email = ref('')
const password = ref('')
const repeated = ref('')
const showPasswords = ref(false)
const error = ref<string | null>(null)
const working = ref(false)

async function check() {
  state.value = 'checking'
  error.value = null
  try {
    const { available } = await adminApi.passwordResetAvailable()
    state.value = available ? 'form' : 'unavailable'
  } catch (failure) {
    error.value = failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
    state.value = 'failed'
  }
}

async function reset() {
  if (working.value) return
  if (!email.value.trim()) {
    error.value = 'Enter your email address.'
    return
  }
  if ([...password.value].length < MIN_LENGTH) {
    error.value = `A password needs at least ${MIN_LENGTH} characters.`
    return
  }
  if (password.value !== repeated.value) {
    error.value = 'The two passwords are not the same.'
    return
  }
  working.value = true
  error.value = null
  try {
    await adminApi.resetPassword(email.value.trim(), password.value)
    state.value = 'done'
  } catch (failure) {
    error.value = failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
  } finally {
    working.value = false
  }
}

onMounted(check)
</script>

<template>
  <AuthCard>
    <div v-if="state === 'checking'" class="auth-form" aria-busy="true">
      <h1>Forgot your password?</h1>
      <p class="hint">One moment…</p>
    </div>

    <div v-else-if="state === 'failed'" class="auth-form">
      <h1>Forgot your password?</h1>
      <p class="error-text" role="alert">{{ error }}</p>
      <button type="button" class="btn big" @click="check">Try again</button>
      <p class="footnote"><RouterLink :to="{ name: 'sign-in' }" class="link">Back to sign in</RouterLink></p>
    </div>

    <div v-else-if="state === 'unavailable'" class="auth-form">
      <h1>Forgot your password?</h1>
      <p class="hint">Ask Pin's tech team to set a new password for you. You can sign in with it straight away.</p>
      <RouterLink :to="{ name: 'sign-in' }" class="btn big as-button">Back to sign in</RouterLink>
    </div>

    <div v-else-if="state === 'done'" class="auth-form">
      <h1>Password changed</h1>
      <p class="hint">Sign in with your new password. Any other browser signed in as you has been signed out.</p>
      <RouterLink :to="{ name: 'sign-in' }" class="btn big as-button">Sign in</RouterLink>
    </div>

    <form v-else class="auth-form" novalidate @submit.prevent="reset">
      <h1>Set a new password</h1>
      <p class="dev-notice" role="note">
        Development server: the password changes straight away, without checking it is you. Production servers
        do not offer this.
      </p>
      <label class="field">
        Email
        <input
          v-model="email"
          type="email"
          inputmode="email"
          autocomplete="username"
          autocapitalize="none"
          spellcheck="false"
          maxlength="254"
          placeholder="you@example.com"
          autofocus
        />
      </label>
      <div class="field">
        <label for="new-password">New password</label>
        <span class="password-input">
          <input
            id="new-password"
            v-model="password"
            :type="showPasswords ? 'text' : 'password'"
            autocomplete="new-password"
            aria-describedby="password-rule"
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
        <span id="password-rule" class="rule">At least {{ MIN_LENGTH }} characters.</span>
      </div>
      <label class="field">
        Repeat new password
        <input v-model="repeated" :type="showPasswords ? 'text' : 'password'" autocomplete="new-password" />
      </label>
      <p v-if="error" class="error-text" role="alert">{{ error }}</p>
      <button type="submit" class="btn big" :disabled="working">{{ working ? 'Saving…' : 'Set new password' }}</button>
      <p class="footnote"><RouterLink :to="{ name: 'sign-in' }" class="link">Back to sign in</RouterLink></p>
    </form>
  </AuthCard>
</template>

<style scoped>
.dev-notice {
  margin: -4px 0 2px;
  padding: 10px 12px;
  border-radius: 10px;
  background: #fdf4ce;
  color: #6b5000;
  font-size: 13px;
  line-height: 1.4;
}

.rule {
  font-size: 12.5px;
  font-weight: 400;
  color: var(--muted);
}

.as-button {
  display: flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
}
</style>
