<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue'

import { adminApi } from '../api/admin'
import { ApiError } from '../api/http'
import type { AddedAdmin, AdminRole, AdminSummary } from '../api/types'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import StatusPill from '../components/StatusPill.vue'
import { ADMIN_ROLES, date, type Status } from '../format'
import { matchesSearch } from '../search'
import { session } from '../session'
import { showToast } from '../toast'

// Pin's admins. Every admin sees the list; only super admins add and remove admins
// (the server refuses anyone else). A new admin gets a temporary password, shown here
// once, to pass on privately; at their first sign-in they must choose their own.

const PASSWORD_STATUS: Record<AdminSummary['password'], Status> = {
  own: 'active',
  temporary: 'firstSignIn',
  none: 'noPassword',
}

const ROLE_CHOICES: { value: AdminRole; hint: string }[] = [
  { value: 'admin', hint: 'Everything except adding and removing admins' },
  { value: 'superAdmin', hint: 'Everything, including adding and removing admins' },
]

const canManage = computed(() => session.admin?.role === 'superAdmin')
const columns = computed(() =>
  canManage.value ? '1.4fr 1.8fr 1.3fr 1.3fr 1.4fr 0.8fr' : '1.5fr 2fr 1.1fr 1.4fr 1.5fr',
)

const admins = ref<AdminSummary[] | null>(null)
const loadError = ref<string | null>(null)

const formOpen = ref(false)
const name = ref('')
const email = ref('')
const role = ref<AdminRole>('admin')
const formError = ref<string | null>(null)
const working = ref(false)
const added = ref<AddedAdmin | null>(null)
const nameInput = ref<HTMLInputElement | null>(null)

const toRemove = ref<AdminSummary | null>(null)
const removing = ref<string | null>(null)
const toPromote = ref<AdminSummary | null>(null)
const changingRole = ref<string | null>(null)

const rows = computed(() =>
  (admins.value ?? []).filter((admin) => matchesSearch(admin.name, admin.email, admin.addedBy, ADMIN_ROLES[admin.role])),
)

async function load() {
  try {
    admins.value = await adminApi.admins()
    loadError.value = null
  } catch (failure) {
    loadError.value = message(failure)
  }
}

async function openForm() {
  formOpen.value = true
  added.value = null
  name.value = ''
  email.value = ''
  role.value = 'admin'
  formError.value = null
  await nextTick()
  nameInput.value?.focus()
}

function closeForm() {
  formOpen.value = false
  added.value = null
}

async function add() {
  if (working.value) return
  if (!name.value.trim()) {
    formError.value = 'Enter their name.'
    return
  }
  if (!email.value.trim()) {
    formError.value = 'Enter their email address.'
    return
  }
  working.value = true
  formError.value = null
  try {
    added.value = await adminApi.addAdmin(name.value.trim(), email.value.trim(), role.value)
    void load()
  } catch (failure) {
    formError.value = message(failure)
  } finally {
    working.value = false
  }
}

async function copyPassword() {
  if (!added.value) return
  try {
    await navigator.clipboard.writeText(added.value.temporaryPassword)
    showToast('Password copied.')
  } catch {
    showToast("Couldn't copy it. Select the password and copy it yourself.", 'error')
  }
}

async function confirmRemove() {
  const admin = toRemove.value
  toRemove.value = null
  if (!admin || removing.value) return
  removing.value = admin.id
  try {
    await adminApi.removeAdmin(admin.id)
    showToast(`${admin.name} was removed.`)
  } catch (failure) {
    showToast(message(failure), 'error')
  } finally {
    removing.value = null
    void load()
  }
}

/** Making someone an admin is done at once; making them a super admin asks first. */
function onRoleChange(admin: AdminSummary, event: Event) {
  const select = event.target as HTMLSelectElement
  const role = select.value as AdminRole
  // Shows the role they have until the server has changed it.
  select.value = admin.role
  if (role === admin.role) return
  if (role === 'superAdmin') toPromote.value = admin
  else void changeRole(admin, role)
}

async function confirmPromote() {
  const admin = toPromote.value
  toPromote.value = null
  if (admin) await changeRole(admin, 'superAdmin')
}

async function changeRole(admin: AdminSummary, newRole: AdminRole) {
  if (changingRole.value) return
  changingRole.value = admin.id
  try {
    await adminApi.changeRole(admin.id, newRole)
    showToast(`${admin.name} is now ${newRole === 'superAdmin' ? 'a super admin' : 'an admin'}.`)
  } catch (failure) {
    showToast(message(failure), 'error')
  } finally {
    changingRole.value = null
    await load()
  }
}

function message(failure: unknown): string {
  return failure instanceof ApiError ? failure.message : 'Something went wrong. Please try again.'
}

onMounted(load)
</script>

<template>
  <div class="intro">
    <p class="sub">
      <template v-if="canManage">
        As a super admin you add and remove admins and change their roles. A new admin gets a temporary password and
        chooses their own at their first sign-in.
      </template>
      <template v-else>Only super admins can manage admins.</template>
    </p>
    <button v-if="canManage && !formOpen" type="button" class="btn" @click="openForm">Add admin</button>
  </div>

  <section v-if="canManage && formOpen" class="card add" aria-labelledby="add-title">
    <form v-if="!added" class="add-form" novalidate @submit.prevent="add">
      <h2 id="add-title">Add an admin</h2>
      <div class="fields">
        <label class="field">
          Name
          <input ref="nameInput" v-model="name" maxlength="80" autocomplete="off" />
        </label>
        <label class="field">
          Email
          <input
            v-model="email"
            type="email"
            inputmode="email"
            maxlength="254"
            autocomplete="off"
            autocapitalize="none"
            spellcheck="false"
            placeholder="name@example.com"
          />
        </label>
      </div>
      <fieldset class="roles">
        <legend>Role</legend>
        <label v-for="choice in ROLE_CHOICES" :key="choice.value" class="role">
          <input v-model="role" type="radio" name="role" :value="choice.value" />
          <span>
            <span class="strong">{{ ADMIN_ROLES[choice.value] }}</span>
            <span class="sub">{{ choice.hint }}</span>
          </span>
        </label>
      </fieldset>
      <p v-if="formError" class="error-text" role="alert">{{ formError }}</p>
      <div class="actions">
        <button type="button" class="btn ghost" @click="closeForm">Cancel</button>
        <button type="submit" class="btn" :disabled="working">{{ working ? 'Adding…' : 'Add admin' }}</button>
      </div>
    </form>

    <div v-else class="add-form" role="status">
      <h2 id="add-title">{{ added.name }} is now a Pin {{ ADMIN_ROLES[added.role].toLowerCase() }}</h2>
      <p class="sub">
        Give them this temporary password privately, in person or by phone. It is shown only now. When they sign in
        with <strong>{{ added.email }}</strong>, they choose their own password.
      </p>
      <div class="secret">
        <code>{{ added.temporaryPassword }}</code>
        <button type="button" class="btn ghost" @click="copyPassword">Copy</button>
      </div>
      <div class="actions">
        <button type="button" class="btn" @click="closeForm">Done</button>
      </div>
    </div>
  </section>

  <div v-if="loadError" class="notice" role="alert">
    <span>{{ loadError }}</span>
    <button type="button" class="btn ghost" @click="load">Try again</button>
  </div>

  <section class="card table">
    <div class="min">
      <div class="row th" :style="{ gridTemplateColumns: columns }">
        <div>Name</div>
        <div>Email</div>
        <div>Role</div>
        <div>Added</div>
        <div>Status</div>
        <div v-if="canManage">Action</div>
      </div>
      <div v-for="admin in rows" :key="admin.id" class="row" :style="{ gridTemplateColumns: columns }">
        <div class="strong">
          {{ admin.name }}
          <span v-if="admin.you" class="you">You</span>
        </div>
        <div>{{ admin.email }}</div>
        <div>
          <select
            v-if="canManage && !admin.you"
            class="role-select"
            :value="admin.role"
            :aria-label="`Role of ${admin.name}`"
            :disabled="changingRole === admin.id"
            @change="onRoleChange(admin, $event)"
          >
            <option value="admin">{{ ADMIN_ROLES.admin }}</option>
            <option value="superAdmin">{{ ADMIN_ROLES.superAdmin }}</option>
          </select>
          <template v-else>{{ ADMIN_ROLES[admin.role] }}</template>
        </div>
        <div>
          <div>{{ date(admin.addedAt) }}</div>
          <div class="sub">{{ admin.addedBy ? `by ${admin.addedBy}` : 'on the server' }}</div>
        </div>
        <div><StatusPill :status="PASSWORD_STATUS[admin.password]" /></div>
        <div v-if="canManage">
          <button
            v-if="!admin.you"
            type="button"
            class="btn danger"
            :disabled="removing === admin.id"
            @click="toRemove = admin"
          >
            Remove
          </button>
        </div>
      </div>
      <div v-if="admins && rows.length === 0" class="empty">No admins match.</div>
      <div v-if="!admins && !loadError" class="empty">Loading admins…</div>
    </div>
  </section>

  <ConfirmDialog
    v-if="toRemove"
    :title="`Remove ${toRemove.name}?`"
    confirm-label="Remove"
    danger
    @confirm="confirmRemove"
    @cancel="toRemove = null"
  >
    They are signed out at once and can no longer sign in to Pin Admin. Payouts they recorded keep their name.
  </ConfirmDialog>

  <ConfirmDialog
    v-if="toPromote"
    :title="`Make ${toPromote.name} a super admin?`"
    confirm-label="Make super admin"
    @confirm="confirmPromote"
    @cancel="toPromote = null"
  >
    They will be able to add and remove admins and change their roles, yours included.
  </ConfirmDialog>
</template>

<style scoped>
.intro {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.intro .sub {
  margin: 0;
}

.add {
  padding: 20px 24px;
  max-width: 640px;
}

.add-form {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

h2 {
  margin: 0;
  font-size: 17px;
  font-weight: 800;
}

.add-form p {
  margin: 0;
}

.fields {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
}

.roles {
  margin: 0;
  padding: 0;
  border: 0;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 8px 12px;
}

.roles legend {
  padding: 0;
  margin-bottom: 6px;
  font-size: 13px;
  font-weight: 700;
  color: var(--ink-2);
}

.role {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 12px;
  border: 1.5px solid var(--line);
  border-radius: 12px;
  cursor: pointer;
}

.role:has(input:checked) {
  border-color: var(--blue);
  background: var(--blue-soft);
}

.role input {
  margin-top: 3px;
}

.role .sub {
  display: block;
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.secret {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  padding: 12px 14px;
  border-radius: 12px;
  background: var(--page);
}

.secret code {
  flex: 1 1 auto;
  font-size: 20px;
  font-weight: 700;
  letter-spacing: 1px;
  user-select: all;
}

.role-select {
  min-height: 34px;
  padding: 0 8px;
  border: 1.5px solid var(--line);
  border-radius: 10px;
  background: #fff;
  color: var(--ink);
  font: inherit;
  font-size: 13.5px;
}

.role-select:focus {
  border-color: var(--blue);
  outline: none;
}

.you {
  margin-left: 6px;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--blue-soft);
  color: var(--blue);
  font-size: 11.5px;
  font-weight: 700;
}

.min {
  min-width: 760px;
}
</style>
