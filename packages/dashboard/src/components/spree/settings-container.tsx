import type { ReactNode } from 'react'

/**
 * Settings content padding. The settings nav lives one level up, in the shared
 * app shell's chrome, so this container owns only the content's padding.
 *
 * Every settings page inherits it — a page must NOT add its own
 * `p-4`/`container`/`mx-auto`, or it double-pads and drifts from the rest of
 * the area. Start a settings page at `<div className="flex flex-col gap-6">`.
 */
export function SettingsContainer({ children }: { children: ReactNode }) {
  return (
    // Capped and centred, like the shell's `container` around every other
    // page. Not `container` itself: its widths follow the window, while this
    // area is the window less two rails, so it would never cap anything.
    <div className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-4 p-4 lg:gap-6 lg:p-6">
      {children}
    </div>
  )
}
