import type { ReactNode } from 'react'

/**
 * Settings content padding. The secondary sidebar lives one level up, in the
 * shared app shell, so it can extend the full height of the content sheet.
 * This container owns only the right-side content padding.
 *
 * Every settings page inherits it — a page must NOT add its own
 * `p-4`/`container`/`mx-auto`, or it double-pads and drifts from the rest of
 * the area. Start a settings page at `<div className="flex flex-col gap-6">`.
 */
export function SettingsContainer({ children }: { children: ReactNode }) {
  return <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">{children}</div>
}
