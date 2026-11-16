/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Where the Pin API is. Defaults to /api, which the dev server passes to the backend. */
  readonly VITE_API_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<object, object, unknown>
  export default component
}
