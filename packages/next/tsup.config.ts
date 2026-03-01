import { defineConfig } from 'tsup';

export default defineConfig([
  // Plain modules (no directive) — config, types, data reads
  {
    entry: {
      index: 'src/index.ts',
      config: 'src/config.ts',
      types: 'src/types.ts',
      locale: 'src/locale.ts',
      'data/products': 'src/data/products.ts',
      'data/taxons': 'src/data/taxons.ts',
      'data/taxonomies': 'src/data/taxonomies.ts',
      'data/store': 'src/data/store.ts',
      'data/countries': 'src/data/countries.ts',
      'data/currencies': 'src/data/currencies.ts',
      'data/locales': 'src/data/locales.ts',
    },
    format: ['esm'],
    dts: true,
    splitting: false,
    sourcemap: true,
    treeshake: true,
    external: ['next', 'next/cache', 'next/headers', '@spree/sdk', 'react'],
  },
  // Server action files — need "use server" banner preserved
  {
    entry: {
      'actions/cart': 'src/actions/cart.ts',
      'actions/checkout': 'src/actions/checkout.ts',
      'actions/auth': 'src/actions/auth.ts',
      'actions/addresses': 'src/actions/addresses.ts',
      'actions/orders': 'src/actions/orders.ts',
      'actions/credit-cards': 'src/actions/credit-cards.ts',
      'actions/gift-cards': 'src/actions/gift-cards.ts',
      'actions/payment-sessions': 'src/actions/payment-sessions.ts',
      'actions/payment-setup-sessions': 'src/actions/payment-setup-sessions.ts',
      'actions/locale': 'src/actions/locale.ts',
    },
    format: ['esm'],
    dts: true,
    splitting: false,
    sourcemap: true,
    external: ['next', 'next/cache', 'next/headers', '@spree/sdk', 'react'],
  },
  // Middleware — separate entry (Edge runtime, no next/headers)
  {
    entry: {
      middleware: 'src/middleware.ts',
    },
    format: ['esm'],
    dts: true,
    splitting: false,
    sourcemap: true,
    external: ['next', 'next/server', '@spree/sdk'],
  },
]);
