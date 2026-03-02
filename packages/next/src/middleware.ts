import { NextResponse, type NextRequest } from 'next/server';

export interface SpreeMiddlewareConfig {
  /** Default country ISO code (default: 'us') */
  defaultCountry?: string;
  /** Default locale code (default: 'en') */
  defaultLocale?: string;
  /** Routes to skip — prefixes matched with startsWith (default: ['/_next', '/api', '/favicon.ico']) */
  staticRoutes?: string[];
}

/**
 * Creates a Next.js middleware that handles:
 * - Redirecting bare paths to /{country}/{locale}/...
 * - Detecting country from cookies → geo headers → default
 * - Detecting locale from cookies → accept-language → default
 *
 * Usage in your middleware.ts:
 * ```typescript
 * import { createSpreeMiddleware } from '@spree/next/middleware';
 * export default createSpreeMiddleware({ defaultCountry: 'us', defaultLocale: 'en' });
 * export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\..*$).*)'] };
 * ```
 */
export function createSpreeMiddleware(config: SpreeMiddlewareConfig = {}) {
  const defaultCountry = config.defaultCountry ?? 'us';
  const defaultLocale = config.defaultLocale ?? 'en';
  const staticRoutes = config.staticRoutes ?? ['/_next', '/api', '/favicon.ico'];

  return function middleware(request: NextRequest) {
    const { pathname } = request.nextUrl;

    // Skip static routes
    if (staticRoutes.some((route) => pathname.startsWith(route))) {
      return NextResponse.next();
    }

    // Skip if pathname contains a file extension (static assets)
    if (/\.\w+$/.test(pathname)) {
      return NextResponse.next();
    }

    // Already has /{country}/{locale} prefix
    if (/^\/[a-z]{2}\/[a-z]{2}(\/|$)/i.test(pathname)) {
      return NextResponse.next();
    }

    // Detect country: cookie → geo headers → default
    const country =
      request.cookies.get('spree_country')?.value ??
      request.headers.get('x-vercel-ip-country')?.toLowerCase() ??
      request.headers.get('cf-ipcountry')?.toLowerCase() ??
      defaultCountry;

    // Detect locale: cookie → accept-language → default
    const locale =
      request.cookies.get('spree_locale')?.value ??
      request.headers.get('accept-language')?.split(',')[0]?.split('-')[0]?.toLowerCase() ??
      defaultLocale;

    const url = request.nextUrl.clone();
    url.pathname = `/${country}/${locale}${pathname === '/' ? '' : pathname}`;
    return NextResponse.redirect(url);
  };
}
