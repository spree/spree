import * as React from 'react'

/**
 * Tracks the user's `prefers-reduced-motion` setting, live.
 *
 * For motion that CSS alone can't soften. Suppressing a transition in CSS
 * turns a slide into a jump, which is the opposite of what the setting asks
 * for; reading the preference here lets a component drop the movement
 * altogether and simply hold its position.
 *
 * Starts `false` so a future SSR render and the first client paint agree; the
 * effect resyncs on mount.
 */
export function usePrefersReducedMotion() {
  const [prefersReducedMotion, setPrefersReducedMotion] = React.useState(false)

  React.useEffect(() => {
    const mql = window.matchMedia('(prefers-reduced-motion: reduce)')
    const onChange = () => setPrefersReducedMotion(mql.matches)
    onChange()
    mql.addEventListener('change', onChange)
    return () => mql.removeEventListener('change', onChange)
  }, [])

  return prefersReducedMotion
}
