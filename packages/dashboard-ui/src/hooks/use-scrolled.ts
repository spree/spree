import * as React from 'react'

/**
 * Returns true once the page has been scrolled past `threshold` pixels from
 * the top, false at rest. Used to fade in subtle elevation on sticky headers
 * so they don't look heavy when nothing is scrolled behind them.
 *
 * Listens on the document in the capture phase rather than on `window`, and
 * reads the offset from whichever element actually scrolled. The shell's
 * content is an inset sheet that scrolls internally, so `window.scrollY` stays
 * 0 there for the whole life of the page — a window listener would report "not
 * scrolled" no matter how far down a long form the user went. Scroll events do
 * not bubble, which is why this has to capture.
 *
 * Default threshold is 4px to avoid flickering at the boundary on devices that
 * report fractional scroll positions.
 *
 * @param threshold Scroll offset, in pixels, at which the state flips to true.
 * @param releaseThreshold Offset the user must scroll back above before it
 *   flips to false again. Defaults to `threshold` (no hysteresis). Set it
 *   lower than `threshold` when the flag drives motion: a single boundary
 *   makes a slow scroll across it toggle repeatedly, and anything animating
 *   off this flag then flickers.
 */
export function useScrolled(threshold = 4, releaseThreshold = threshold) {
  // Always start `false` so a future SSR render and the first client paint
  // agree (no hydration mismatch). The effect below resyncs against the
  // actual scroll position on mount, so any restored scroll position is
  // reflected as soon as the effect runs.
  const [scrolled, setScrolled] = React.useState(false)

  React.useEffect(() => {
    const onScroll = (event?: Event) => {
      // The scrolled element for a container, `window.scrollY` for the page.
      const target = event?.target
      const offset = target instanceof HTMLElement ? target.scrollTop : window.scrollY

      // Reading the previous value here (rather than from a dependency) keeps
      // the listener stable while still letting the two thresholds apply
      // directionally: past `threshold` to engage, back above
      // `releaseThreshold` to disengage.
      setScrolled((wasScrolled) => (wasScrolled ? offset > releaseThreshold : offset > threshold))
    }
    onScroll()
    document.addEventListener('scroll', onScroll, { capture: true, passive: true })
    return () => document.removeEventListener('scroll', onScroll, { capture: true })
  }, [threshold, releaseThreshold])

  return scrolled
}
