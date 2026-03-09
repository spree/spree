import { defineConfig } from 'tsup';

export default defineConfig({
  entry: {
    index: 'src/index.ts',
    'types/index': 'src/types/index.ts',
    'zod/index': 'src/zod/index.ts',
  },
  format: ['cjs', 'esm'],
  dts: { resolve: ['@spree/sdk-core'] },
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  minify: false,
  noExternal: ['@spree/sdk-core'],
  esbuildOptions(options) {
    options.alias = {
      '@/types': './src/types/generated/index.ts',
    };
  },
});
