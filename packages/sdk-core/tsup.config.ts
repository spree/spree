import { defineConfig } from 'tsup'

export default defineConfig({
  entry: {
    index: 'src/index.ts',
  },
  format: ['cjs', 'esm'],
  // Inlined, so the SDKs that bundle this package stay self-contained.
  dts: { resolve: ['@spree/core'] },
  noExternal: ['@spree/core'],
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
  // Left to the SDKs that upload, which bundle it themselves; the Store SDK
  // never uploads and so never ships it.
  external: ['spark-md5'],
})
