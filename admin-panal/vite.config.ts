import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

// The panel calls the API under /api. In development Vite passes those calls to the
// Pin backend on port 8080 (same origin, so no CORS is needed). Build for another
// address with VITE_API_BASE_URL.
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.ts'],
  },
})
