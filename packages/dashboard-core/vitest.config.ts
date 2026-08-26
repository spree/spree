import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    // `src/**` too: the product form's tests live beside the code they cover,
    // and a pattern that only saw `tests/` silently stopped running them when
    // that code moved into this package.
    include: ['tests/**/*.test.ts', 'src/**/*.test.ts'],
  },
})
