import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    // Node, not jsdom: what is worth unit-testing here is the logic between
    // your UI and the API — query keys, payload mapping, permission
    // predicates. Rendering a component to assert its markup tests React.
    // Reach for a browser through Playwright instead (`pnpm test:e2e`).
    environment: 'node',
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    exclude: ['node_modules/**', 'e2e/**', 'dist/**'],
  },
})
