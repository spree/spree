import { useEffect, useState } from 'react'

/**
 * Distance from the bottom of the layout viewport to the bottom of the visual
 * one, in CSS pixels.
 *
 * A `position: fixed; bottom: 0` element anchors to the *layout* viewport. When
 * the page is pinch-zoomed — or a mobile browser's URL bar is expanded — the
 * visual viewport is a smaller window onto that layout, so the element sits
 * below what the merchant can actually see and only appears once they pan or
 * scroll down to it. Adding this offset to `bottom` keeps a fixed bar on screen
 * in both cases.
 *
 * Returns `0` when the two viewports agree, which is the ordinary desktop case
 * and costs nothing.
 *
 * @param active Pass the consumer's own visibility so the measurement happens
 *   when it appears — a value read at mount is taken before the element exists
 *   and never refreshed.
 */
export function useVisualViewportOffset(active = true): number {
  const [offset, setOffset] = useState(0)

  useEffect(() => {
    if (!active) return
    const vv = window.visualViewport
    if (!vv) return

    const update = () => {
      // `window.innerHeight`, not `documentElement.clientHeight`: `fixed`
      // positioning resolves against the former, and the two disagree in
      // exactly the situation this hook exists for — a zoomed or URL-bar-inset
      // page reports the *visual* height as `clientHeight`, which would make
      // the offset compute to zero and move nothing.
      const below = window.innerHeight - (vv.offsetTop + vv.height)
      setOffset(Math.max(0, Math.round(below)))
    }

    update()
    // The two viewports can still disagree on the first frame — a zoom level
    // restored with the page, or a URL bar that has not settled, both report
    // stale numbers until layout completes. Re-read once after paint so the
    // bar is placed correctly without waiting for the user to resize.
    const raf = requestAnimationFrame(update)

    vv.addEventListener('resize', update)
    vv.addEventListener('scroll', update)
    window.addEventListener('resize', update)
    return () => {
      cancelAnimationFrame(raf)
      vv.removeEventListener('resize', update)
      vv.removeEventListener('scroll', update)
      window.removeEventListener('resize', update)
    }
    // `active` is in the deps so the offset is measured when the consumer
    // actually appears. Reading it once at mount is too early: the element is
    // usually not rendered yet, and nothing re-measures when it later shows.
  }, [active])

  return offset
}
