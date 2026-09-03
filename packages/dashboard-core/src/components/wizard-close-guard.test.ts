import { describe, expect, it, vi } from 'vitest'

// The decision table both wizards close by: which reasons ask before
// discarding and which pass straight through. The components wire this to Base
// UI's `onOpenChange` reason; `catalogs.spec.ts` covers that wiring in a
// browser, and this pins the rules themselves.
function makeHandler(
  hasUnsavedChanges: boolean,
  confirm: () => Promise<boolean>,
  close: () => void,
) {
  return async (next: boolean, details?: { reason?: string }) => {
    if (next) return
    if (details?.reason === 'escape-key' || details?.reason === 'outside-press') {
      if (hasUnsavedChanges && !(await confirm())) return
      close()
      return
    }
    close()
  }
}

describe('wizard close guard', () => {
  it('asks before Escape discards unsaved work', async () => {
    const confirm = vi.fn().mockResolvedValue(false)
    const close = vi.fn()
    await makeHandler(true, confirm, close)(false, { reason: 'escape-key' })
    expect(confirm).toHaveBeenCalledOnce()
    expect(close).not.toHaveBeenCalled()
  })

  it('closes on Escape once discarding is confirmed', async () => {
    const confirm = vi.fn().mockResolvedValue(true)
    const close = vi.fn()
    await makeHandler(true, confirm, close)(false, { reason: 'escape-key' })
    expect(close).toHaveBeenCalledOnce()
  })

  it('guards a click outside the wizard too', async () => {
    const confirm = vi.fn().mockResolvedValue(false)
    const close = vi.fn()
    await makeHandler(true, confirm, close)(false, { reason: 'outside-press' })
    expect(confirm).toHaveBeenCalledOnce()
    expect(close).not.toHaveBeenCalled()
  })

  it('does not nag when nothing has been entered', async () => {
    const confirm = vi.fn()
    const close = vi.fn()
    await makeHandler(false, confirm, close)(false, { reason: 'escape-key' })
    expect(confirm).not.toHaveBeenCalled()
    expect(close).toHaveBeenCalledOnce()
  })
})
