import type { AnyRoute, RouterConstructorOptions, RouterHistory } from '@tanstack/react-router'
import { createRouter } from '@tanstack/react-router'

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

  return createRouter(options)
}
