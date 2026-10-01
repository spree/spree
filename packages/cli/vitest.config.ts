import { defineConfig } from 'vitest/config'
import { pluginPeerRanges } from './scripts/plugin-peer-ranges.mjs'

export default defineConfig({
  define: { __SPREE_PLUGIN_PEER_RANGES__: JSON.stringify(pluginPeerRanges()) },
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
})
