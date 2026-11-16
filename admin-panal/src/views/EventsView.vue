<script setup lang="ts">
import { computed, ref } from 'vue'

import { apiUrl } from '../api/http'
import type { AdminEvent } from '../api/types'
import { approveEvent, backOffice, isBusy, removeEventImage, setEventImage, today } from '../backOffice'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import StatusPill from '../components/StatusPill.vue'
import { EVENT_KINDS, eventDate } from '../format'
import { matchesSearch } from '../search'
import { showToast } from '../toast'

const COLUMNS = '2.4fr 1.5fr 1fr 1.5fr 1.1fr 1.6fr'

/** The server accepts a picture up to this size; saying so here saves a slow upload that would be refused. */
const MAX_PICTURE_BYTES = 5 * 1024 * 1024

const rows = computed(() => backOffice.events.filter((e) => matchesSearch(e.name, e.merchantName, e.venue)))

function soldShare(event: AdminEvent): string {
  return `${event.capacity ? Math.min(100, (event.sold / event.capacity) * 100) : 0}%`
}

/** Events go on sale only for approved merchants, so a pending merchant is approved first. */
function blockedBy(event: AdminEvent): string | null {
  const merchant = backOffice.merchants.find((m) => m.id === event.merchantId)
  return merchant && merchant.status !== 'active' ? `Approve ${merchant.name} first` : null
}

// The cover image: one hidden file chooser shared by every row.
const chooser = ref<HTMLInputElement | null>(null)
const choosingFor = ref<AdminEvent | null>(null)
const toRemove = ref<AdminEvent | null>(null)

function choosePicture(event: AdminEvent) {
  choosingFor.value = event
  chooser.value?.click()
}

async function onPictureChosen(change: Event) {
  const input = change.target as HTMLInputElement
  const picture = input.files?.[0]
  const event = choosingFor.value
  // Cleared so that choosing the same file again later still counts as a change.
  input.value = ''
  choosingFor.value = null
  if (!picture || !event) return
  if (picture.size > MAX_PICTURE_BYTES) {
    showToast('That picture is too big. Keep it under 5 MB.', 'error')
    return
  }
  await setEventImage(event, picture)
}

async function confirmRemove() {
  const event = toRemove.value
  toRemove.value = null
  if (event) await removeEventImage(event)
}
</script>

<template>
  <section class="card table">
    <input
      ref="chooser"
      type="file"
      accept="image/jpeg,image/png"
      class="chooser"
      aria-label="Choose a picture for the event"
      @change="onPictureChosen"
    />
    <div class="min">
      <div class="row th" :style="{ gridTemplateColumns: COLUMNS }">
        <div>Event</div>
        <div>Merchant</div>
        <div>Date</div>
        <div>Sold</div>
        <div>Status</div>
        <div>Action</div>
      </div>
      <div v-for="event in rows" :key="event.id" class="row" :style="{ gridTemplateColumns: COLUMNS }">
        <div class="event">
          <img v-if="event.imageUrl" class="thumb" :src="apiUrl(event.imageUrl)" :alt="`Picture of ${event.name}`" loading="lazy" />
          <div v-else class="thumb none" role="img" aria-label="No picture" />
          <div class="text">
            <div class="strong">
              {{ event.name }}
              <span v-if="event.kind && EVENT_KINDS[event.kind]" class="kind">{{ EVENT_KINDS[event.kind] }}</span>
            </div>
            <div class="sub">{{ event.venue }}</div>
          </div>
        </div>
        <div>{{ event.merchantName }}</div>
        <!-- A place is open every day: its date is only the day it was published. -->
        <div class="num">{{ event.kind === 'admission' ? 'Every day' : eventDate(event.startsAt, today) }}</div>
        <div v-if="event.kind === 'admission'">
          <div class="num sold">{{ event.sold }} sold</div>
          <div class="sub">its limits are per day</div>
        </div>
        <div v-else>
          <div class="num sold">{{ event.sold }} of {{ event.capacity }}</div>
          <div class="bar" aria-hidden="true"><div :style="{ width: soldShare(event) }" /></div>
        </div>
        <div><StatusPill :status="event.status" /></div>
        <div class="actions">
          <template v-if="event.status === 'awaitingApproval'">
            <button
              type="button"
              class="btn"
              :disabled="isBusy(event.id) || blockedBy(event) !== null"
              @click="approveEvent(event)"
            >
              Approve
            </button>
            <div v-if="blockedBy(event)" class="sub">{{ blockedBy(event) }}</div>
          </template>
          <button type="button" class="btn ghost" :disabled="isBusy(event.id)" @click="choosePicture(event)">
            {{ event.imageUrl ? 'Change picture' : 'Add picture' }}
          </button>
          <button
            v-if="event.imageUrl"
            type="button"
            class="btn danger"
            :disabled="isBusy(event.id)"
            @click="toRemove = event"
          >
            Remove picture
          </button>
        </div>
      </div>
      <div v-if="backOffice.loaded && rows.length === 0" class="empty">No events match.</div>
    </div>
  </section>

  <ConfirmDialog
    v-if="toRemove"
    :title="`Remove the picture of ${toRemove.name}?`"
    confirm-label="Remove picture"
    danger
    @confirm="confirmRemove"
    @cancel="toRemove = null"
  >
    Buyers will see the event without a picture in the Pin app. The merchant can add one again.
  </ConfirmDialog>
</template>

<style scoped>
.min {
  min-width: 980px;
}

.sold {
  font-size: 13px;
}

.kind {
  margin-left: 6px;
  padding: 1px 7px;
  border-radius: 999px;
  background: #efefef;
  color: #4d4d4d;
  font-size: 11px;
  font-weight: 600;
  vertical-align: 1px;
}

.chooser {
  display: none;
}

.event {
  display: flex;
  align-items: center;
  gap: 12px;
}

.text {
  min-width: 0;
}

.thumb {
  flex: none;
  width: 56px;
  height: 40px;
  border-radius: 8px;
  object-fit: cover;
  background: #efefef;
}

.thumb.none {
  border: 1.5px dashed #d0d0d0;
  background: #f6f6f6;
}

.actions {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6px;
}
</style>
