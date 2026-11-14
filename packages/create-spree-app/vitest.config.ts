import { defineConfig } from 'vitest/config'
import { spreePackagesRange } from './scripts/spree-packages-range.mjs'

export default defineConfig({
  define: {
    __SPREE_PACKAGES_RANGE__: JSON.stringify(spreePackagesRange()),
  },
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
})
