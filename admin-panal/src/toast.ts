import { reactive, readonly } from 'vue'

// One short message at the bottom of the screen, e.g. "Laugh PP is suspended".

interface ToastState {
  message: string | null
  tone: 'info' | 'error'
}

const state = reactive<ToastState>({ message: null, tone: 'info' })
let timer: ReturnType<typeof setTimeout> | undefined

export const toast = readonly(state)

/** Errors stay longer, so there is time to read them. */
export function showToast(message: string, tone: ToastState['tone'] = 'info'): void {
  state.message = message
  state.tone = tone
  clearTimeout(timer)
  timer = setTimeout(hideToast, tone === 'error' ? 6000 : 2600)
}

export function hideToast(): void {
  clearTimeout(timer)
  state.message = null
}
