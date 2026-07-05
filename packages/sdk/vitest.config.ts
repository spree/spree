import path from 'node:path'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  resolve: {
    alias: {
      '@/types': path.resolve(__dirname, './src/types/generated/index.ts'),
    },
  },
  test: {
    globals: true,
    environment: 'node',
    exclude: ['tests/integration/**', 'node_modules/**'],
    setupFiles: ['./tests/setup.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/**/*.ts'],
      exclude: ['src/types/**'],
    },
  },
})
