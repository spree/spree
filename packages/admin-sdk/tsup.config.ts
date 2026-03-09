import { defineConfig } from 'tsup';
import path from 'node:path';

export default defineConfig({
  entry: {
    index: 'src/index.ts',
    'types/index': 'src/types/index.ts',
  },
  format: ['cjs', 'esm'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
  external: ['@spree/sdk-core'],
  esbuildOptions(options) {
    options.alias = {
      '@/types': path.resolve(import.meta.dirname, 'src/types/generated/index.ts'),
    };
  },
});
