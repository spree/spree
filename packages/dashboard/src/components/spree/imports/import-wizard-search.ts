import { useNavigate } from '@tanstack/react-router'
import { z } from 'zod'

/**
 * `?import=<prefixed id>` names the import whose wizard is open over a page —
 * deep-linkable and refresh-safe. Add the schema to a route's `validateSearch`
 * and drive the dialog from the hook.
 */
// Loose, so a route that uses the schema on its own keeps whatever other
// search params it carries; `z.object()` would strip them before `open` and
// `close` ever see `prev`.
export const importWizardSearchSchema = z.looseObject({
  import: z.string().optional(),
})

/**
 * The wizard's open/closed state as the URL holds it: `importId` is the
 * import to show (or null), `open` writes an id into the search params and
 * `close` removes it, both preserving the page's other params.
 *
 * @param search the route's validated search params
 */
export function useImportWizardSearch(search: { import?: string }) {
  const navigate = useNavigate()

  return {
    importId: search.import ?? null,
    open: (id: string) =>
      navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, import: id }) as never }),
    close: () =>
      navigate({
        search: (prev: Record<string, unknown>) => {
          const { import: _i, ...rest } = prev
          return rest as never
        },
      }),
  }
}
