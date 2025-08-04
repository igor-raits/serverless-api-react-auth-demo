import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    open: true
  },
  build: {
    outDir: 'build',
    sourcemap: true,
    rollupOptions: {
      output: {
        // Split chunks for better caching - Vite will use default naming
        manualChunks: {
          // Vendor libraries get their own chunk
          vendor: ['react', 'react-dom'],
          // AWS/Auth libraries get their own chunk
          aws: ['aws-amplify', '@aws-amplify/auth', '@aws-amplify/core'],
          // Utils get their own chunk
          utils: ['jwt-decode']
        }
      }
    }
  },
  define: {
    global: 'globalThis',
  }
})
