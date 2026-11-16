<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'

import { adminApi } from '../api/admin'
import { ApiError } from '../api/http'
import type { AdminSummary } from '../api/types'
import { ADMIN_ROLES, date, initials } from '../format'

// The signed-in admin's own profile: who they are, their role and what it allows, and
// who added them. Changing the password is one click away.

const profile = ref<AdminSummary | null>(null)
const error = ref<string | null>(null)

async function load() {
  try {
    profile.value = await adminApi.profile()
    error.value = null
  } catch (failure) {
    error.value = failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
  }
}

onMounted(load)
</script>

<template>
  <div v-if="error" class="notice" role="alert">
    <span>{{ error }}</span>
    <button type="button" class="btn ghost" @click="load">Try again</button>
  </div>

  <section v-if="profile" class="card panel">
    <div class="head">
      <div class="avatar" aria-hidden="true">{{ initials(profile.name) }}</div>
      <div>
        <h2>{{ profile.name }}</h2>
        <div class="sub">{{ ADMIN_ROLES[profile.role] }} · {{ profile.email }}</div>
      </div>
    </div>

    <dl class="details">
      <div>
        <dt>Role</dt>
        <dd>
          {{ ADMIN_ROLES[profile.role] }}
          <span class="sub">
            {{
              profile.role === 'superAdmin'
                ? 'Everything in Pin Admin, including adding and removing admins.'
                : 'Everything in Pin Admin except adding and removing admins.'
            }}
          </span>
        </dd>
      </div>
      <div>
        <dt>Email</dt>
        <dd>{{ profile.email }} <span class="sub">You sign in with it.</span></dd>
      </div>
      <div>
        <dt>Added</dt>
        <dd>
          {{ date(profile.addedAt) }}
          <span class="sub">{{ profile.addedBy ? `by ${profile.addedBy}` : 'on the server' }}</span>
        </dd>
      </div>
    </dl>

    <div class="actions">
      <RouterLink :to="{ name: 'change-password' }" class="btn ghost as-button">Change password</RouterLink>
    </div>
  </section>

  <section v-else-if="!error" class="card panel">
    <p class="sub">Loading your profile…</p>
  </section>
</template>

<style scoped>
.panel {
  max-width: 560px;
  padding: 24px;
}

.head {
  display: flex;
  align-items: center;
  gap: 14px;
}

.avatar {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--blue);
  color: #fff;
  font-size: 19px;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
}

h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 800;
}

.details {
  margin: 22px 0 0;
  border-top: 1px solid var(--line-soft);
}

.details > div {
  display: grid;
  grid-template-columns: 110px 1fr;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid var(--line-soft);
}

dt {
  font-size: 13px;
  font-weight: 700;
  color: var(--ink-2);
}

dd {
  margin: 0;
  font-size: 14px;
}

dd .sub {
  display: block;
  margin-top: 2px;
}

.actions {
  margin-top: 18px;
}

.as-button {
  display: inline-flex;
  align-items: center;
  text-decoration: none;
}
</style>
