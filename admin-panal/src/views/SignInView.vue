<script setup lang="ts">
import { nextTick, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import { adminApi } from '../api/admin'
import { ApiError } from '../api/http'
import AuthCard from '../components/AuthCard.vue'
import { saveSession } from '../session'

// Admins sign in with their email address and password. The server answers a wrong
// email and a wrong password the same way; after too many wrong passwords it locks
// sign-in for a while and says for how long.

const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const showPassword = ref(false)
const error = ref<string | null>(null)
const working = ref(false)
const passwordInput = ref<HTMLInputElement | null>(null)

async function signIn() {
  if (working.value) return
  if (!email.value.trim()) {
    error.value = 'Enter your email address.'
    return
  }
  if (!password.value) {
    error.value = 'Enter your password.'
    return
  }
  working.value = true
  error.value = null
  try {
    const signedIn = await adminApi.signIn(email.value.trim(), password.value)
    saveSession(signedIn.accessToken, signedIn.admin)
    const next = typeof route.query.next === 'string' && route.query.next.startsWith('/') ? route.query.next : '/'
    await router.replace(next)
  } catch (failure) {
    error.value = failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
    if (failure instanceof ApiError && failure.status === 400) {
      // Selected, so typing the password again replaces it.
      await nextTick()
      passwordInput.value?.select()
    }
  } finally {
    working.value = false
  }
}
</script>

<template>
  <AuthCard>
    <form class="auth-form" novalidate @submit.prevent="signIn">
      <h1>Sign in</h1>
      <p class="hint">Use your Pin admin email and password.</p>
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
          :aria-invalid="error !== null"
          autofocus
        />
      </label>
      <div class="field">
        <label for="password">Password</label>
        <span class="password-input">
          <input
            id="password"
            ref="passwordInput"
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            autocomplete="current-password"
            :aria-invalid="error !== null"
          />
          <button
            type="button"
            class="link reveal"
            :aria-label="showPassword ? 'Hide password' : 'Show password'"
            @click="showPassword = !showPassword"
          >
            {{ showPassword ? 'Hide' : 'Show' }}
          </button>
        </span>
      </div>
      <p v-if="error" class="error-text" role="alert">{{ error }}</p>
      <button type="submit" class="btn big" :disabled="working">{{ working ? 'Signing in…' : 'Sign in' }}</button>
      <p class="footnote"><RouterLink :to="{ name: 'forgot-password' }" class="link">Forgot your password?</RouterLink></p>
    </form>
  </AuthCard>
</template>
