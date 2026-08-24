import { useNavigate } from '@tanstack/react-router'

/**
 * Opens the method sheet for an existing method, or for a new one.
 *
 * Every move replaces the history entry rather than pushing one. The sheet
 * lives in the URL so a deep link reopens it, but opening and closing one is
 * not a place a merchant navigated to — pushing would leave the page's back
 * arrow walking through sheets they already dismissed instead of returning to
 * the profile list.
 */
export function useMethodSheetNavigation() {
  const navigate = useNavigate()

  const openMethod = (methodId: string) =>
    navigate({
      replace: true,
      search: (prev: Record<string, unknown>) => {
        const { zone: _z, group: _g, provider: _p, ...rest } = prev
        return { ...rest, method: methodId } as never
      },
    })

  const openNewMethod = (options: { zone?: string; group?: string; provider?: string } = {}) =>
    navigate({
      replace: true,
      search: (prev: Record<string, unknown>) =>
        ({
          ...prev,
          method: 'new',
          ...(options.zone ? { zone: options.zone } : { zone: undefined }),
          ...(options.group ? { group: options.group } : { group: undefined }),
          ...(options.provider ? { provider: options.provider } : { provider: undefined }),
        }) as never,
    })

  const closeMethodSheet = () =>
    navigate({
      replace: true,
      search: (prev: Record<string, unknown>) => {
        const { method: _m, zone: _z, group: _g, provider: _p, ...rest } = prev
        return rest as never
      },
    })

  return { openMethod, openNewMethod, closeMethodSheet }
}
