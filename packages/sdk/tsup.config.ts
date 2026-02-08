import { defineConfig } from 'tsup';

export default defineConfig({
  entry: {
    index: 'src/index.ts',
    'types/index': 'src/types/index.ts',
    'zod/index': 'src/zod/index.ts',
  },
  format: ['cjs', 'esm'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
  external: [],
  esbuildOptions(options) {
    options.alias = {
      '@/types': './src/types/generated/index.ts',
      '@': './src',
    };
  },
});
