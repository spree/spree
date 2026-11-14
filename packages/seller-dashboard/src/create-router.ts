import { reportCaughtError } from '@spree/dashboard-core'
import { ErrorState } from '@spree/dashboard-ui'
import type { AnyRoute, RouterConstructorOptions, RouterHistory } from '@tanstack/react-router'
import { createRouter } from '@tanstack/react-router'
import { createElement } from 'react'

export interface SellerRouterOptions {
  /** Mirrors Vite's `base` so sub-path mounts route correctly. */
  basepath?: string
}

/**
 * Builds the panel's router from a route tree.
 *
 * Hosts own their entry point and pass the tree in, exactly as they do for
 * the operator's dashboard — so a marketplace can add its own seller-facing
 * pages without forking this package.
 */
export function createSellerRouter<TRouteTree extends AnyRoute>(
  routeTree: TRouteTree,
  { basepath }: SellerRouterOptions = {},
) {
  // Cast because the shell's root route requires no router context, which
  // TypeScript cannot prove through the generic tree parameter. The return
  // type stays parameterized by TRouteTree — that's what keeps links typed.
  const options = { routeTree, basepath } as RouterConstructorOptions<
    TRouteTree,
    'never',
    false,
    RouterHistory,
    Record<string, unknown>
  >

  return createRouter({
    ...options,
    // A thrown render or loader error shows the message and a retry inside
    // the panel instead of the router's bare fallback, and reaches
    // error-tracking plugins: the error screen stops it before
    // window.onerror would see it.
    defaultErrorComponent: ({ error, reset }) =>
      createElement(ErrorState, { error, onRetry: reset }),
    defaultOnCatch: reportCaughtError,
  })
}
