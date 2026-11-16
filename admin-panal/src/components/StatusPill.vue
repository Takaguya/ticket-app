<script setup lang="ts">
import { computed } from 'vue'

import { STATUSES, type Status } from '../format'

const props = defineProps<{ status: Status }>()

const look = computed(() => STATUSES[props.status])
</script>

<template>
  <span class="pill" :style="{ background: look.background, color: look.color }">{{ look.label }}</span>
</template>
