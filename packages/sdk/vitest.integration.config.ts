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
    include: ['tests/integration/**/*.test.ts'],
    globalSetup: ['./tests/integration/global-setup.ts'],
    testTimeout: 15_000,
    // Run sequentially — tests share server + SQLite database
    fileParallelism: false,
  },
})
