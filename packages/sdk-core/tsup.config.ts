import { defineConfig } from 'tsup'

export default defineConfig({
  entry: {
    index: 'src/index.ts',
  },
  format: ['cjs', 'esm'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
  // Left to the SDKs that upload, which bundle it themselves; the Store SDK
  // never uploads and so never ships it.
  external: ['spark-md5'],
})
