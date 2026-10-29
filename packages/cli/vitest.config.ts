import { defineConfig } from 'vitest/config'
import { pluginPeerRanges } from './scripts/plugin-peer-ranges.mjs'
import { releaseLine } from './scripts/release-line.mjs'

export default defineConfig({
  define: {
    __SPREE_PLUGIN_PEER_RANGES__: JSON.stringify(pluginPeerRanges()),
    __SPREE_RELEASE_LINE__: JSON.stringify(releaseLine()),
  },
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
})
