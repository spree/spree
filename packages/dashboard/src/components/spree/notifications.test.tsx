import type { UpdateStatus } from '@spree/admin-sdk'
import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import '../../i18n-setup'
import { useUpdateStatus } from '../../hooks/use-update-status'
import { Notifications } from './notifications'

vi.mock('../../hooks/use-update-status', () => ({ useUpdateStatus: vi.fn() }))
vi.mock('../../hooks/use-release-notes', () => ({
  useReleaseNotes: () => ({ isPending: true }),
}))

const newerRelease: UpdateStatus = {
  current_version: '6.0.0',
  enabled: true,
  checked_at: '2026-10-03T04:00:00.000Z',
  update_available: true,
  latest_version: '6.0.1',
  latest_release_url: 'https://github.com/spree/spree/releases/tag/v6.0.1',
  latest_release_published_at: '2026-10-02T10:51:38.000Z',
}

function render(status: UpdateStatus | undefined) {
  vi.mocked(useUpdateStatus).mockReturnValue({ data: status } as ReturnType<typeof useUpdateStatus>)
  return renderToStaticMarkup(<Notifications />)
}

describe('the notifications bell', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('marks a release the admin has not seen yet', () => {
    const html = render(newerRelease)

    expect(html).toContain('aria-label="Notifications, 1 unread"')
    expect(html).toContain('bg-blue-500')
  })

  it('shows no dot when the install is up to date', () => {
    const html = render({ ...newerRelease, update_available: false, latest_version: null })

    expect(html).toContain('aria-label="Notifications"')
    expect(html).not.toContain('bg-blue-500')
  })

  it('drops the dot once that release was seen, and brings it back for the next one', () => {
    vi.stubGlobal('window', { localStorage: { getItem: () => '6.0.1' } })

    expect(render(newerRelease)).not.toContain('bg-blue-500')
    expect(render({ ...newerRelease, latest_version: '6.0.2' })).toContain('bg-blue-500')
  })
})
