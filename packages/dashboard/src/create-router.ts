import {
  type AnyRoute,
  createRouter,
  type RouterConstructorOptions,
  type RouterHistory,
} from '@tanstack/react-router'

/**
 * Build the dashboard's router from a generated route tree.
 *
 * Hosts generate their own `routeTree.gen.ts` (via `@spree/dashboard/vite`,
 * which composes the shell's routes with every installed plugin's file
 * routes) and register the resulting router for typed links:
 *
 *     import { routeTree } from './routeTree.gen'
 *
 *     const router = createDashboardRouter(routeTree)
 *
 *     declare module '@tanstack/react-router' {
 *       interface Register {
 *         router: typeof router
 *       }
 *     }
 *
 * The `Register` augmentation lives in HOST code on purpose: interface
 * augmentations merge program-wide, so the shell declaring its own would
 * conflict with the host's composed tree.
 */
export function createDashboardRouter<TRouteTree extends AnyRoute>(routeTree: TRouteTree) {
  // Cast because the shell's root route requires no router context, which
  // TypeScript cannot prove through the generic tree parameter. The return
  // type stays parameterized by TRouteTree — that's what makes links typed.
  const options = { routeTree } as RouterConstructorOptions<
    TRouteTree,
    'never',
    false,
    RouterHistory,
    Record<string, unknown>
  >
  return createRouter(options)
}
