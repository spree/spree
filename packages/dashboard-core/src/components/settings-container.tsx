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
    // The same `container` as every other page, so settings content lines up
    // with them.
    <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:gap-6 lg:p-6">
      {children}
    </div>
  )
}
