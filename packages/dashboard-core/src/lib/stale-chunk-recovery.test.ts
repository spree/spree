import { afterEach, describe, expect, it, vi } from 'vitest'
import { addErrorReporter, reportCaughtError } from './error-reporting'
import {
  installStaleChunkRecovery,
  isStaleChunkError,
  reloadForStaleChunk,
  resetStaleChunkRecoveryForTests,
  STALE_CHUNK_RELOAD_WINDOW_MS,
  STALE_CHUNK_RELOADED_AT_KEY,
} from './stale-chunk-recovery'

function memoryStorage(initial: Record<string, string> = {}): Storage {
  const items = new Map(Object.entries(initial))
  return {
    get length() {
      return items.size
    },
    clear: () => items.clear(),
    getItem: (key) => items.get(key) ?? null,
    key: (index) => [...items.keys()][index] ?? null,
    removeItem: (key) => void items.delete(key),
    setItem: (key, value) => void items.set(key, String(value)),
  }
}

const chromium = new TypeError(
  'Failed to fetch dynamically imported module: https://example.com/dashboard/assets/json-preview-drawer-BZt9RwGr.js',
)

afterEach(() => {
  resetStaleChunkRecoveryForTests()
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('isStaleChunkError', () => {
  it.each([
    ['Chromium', chromium],
    ['Firefox', new TypeError('error loading dynamically imported module: https://x/a.js')],
    ['Safari', new TypeError('Importing a module script failed.')],
    [
      'a chunk answered with index.html',
      new TypeError(
        'Failed to load module script: Expected a JavaScript module script but the server responded with a MIME type of "text/html". Strict MIME type checking is enforced for module scripts per HTML spec. \'text/html\' is not a valid JavaScript MIME type.',
      ),
    ],
    ['a missing stylesheet', new Error('Unable to preload CSS for /assets/a.css')],
    ['a wrapped import error', new Error('Route failed to load', { cause: chromium })],
  ])('recognises %s', (_engine, error) => {
    expect(isStaleChunkError(error)).toBe(true)
  })

  it('ignores other errors', () => {
    expect(isStaleChunkError(new TypeError('Failed to fetch'))).toBe(false)
    expect(isStaleChunkError(new Error('boom'))).toBe(false)
    expect(isStaleChunkError(undefined)).toBe(false)
  })
})

describe('reloadForStaleChunk', () => {
  it('reloads and records when', () => {
    const storage = memoryStorage()
    const reload = vi.fn()

    expect(reloadForStaleChunk({ storage, reload, now: 1_000_000 })).toBe(true)
    expect(reload).toHaveBeenCalledOnce()
    expect(storage.getItem(STALE_CHUNK_RELOADED_AT_KEY)).toBe('1000000')
  })

  it('does not reload again within a minute of the last reload, so a broken build cannot loop', () => {
    const storage = memoryStorage({ [STALE_CHUNK_RELOADED_AT_KEY]: '1000000' })
    const reload = vi.fn()

    expect(
      reloadForStaleChunk({ storage, reload, now: 1_000_000 + STALE_CHUNK_RELOAD_WINDOW_MS - 1 }),
    ).toBe(false)
    expect(reload).not.toHaveBeenCalled()
  })

  it('reloads for a later deploy in the same tab', () => {
    const storage = memoryStorage({ [STALE_CHUNK_RELOADED_AT_KEY]: '1000000' })
    const reload = vi.fn()

    expect(
      reloadForStaleChunk({ storage, reload, now: 1_000_000 + STALE_CHUNK_RELOAD_WINDOW_MS }),
    ).toBe(true)
    expect(reload).toHaveBeenCalledOnce()
  })

  it('does nothing without session storage, where a loop could not be detected', () => {
    const reload = vi.fn()
    const blocked = memoryStorage()
    blocked.setItem = () => {
      throw new DOMException('blocked', 'SecurityError')
    }

    expect(reloadForStaleChunk({ storage: undefined, reload })).toBe(false)
    expect(reloadForStaleChunk({ storage: blocked, reload })).toBe(false)
    expect(reload).not.toHaveBeenCalled()
  })
})

describe('installStaleChunkRecovery', () => {
  function stubBrowser(storage: Storage) {
    const reload = vi.fn()
    vi.stubGlobal('sessionStorage', storage)
    vi.stubGlobal('window', { location: { reload } })
    return reload
  }

  function preloadError() {
    return new Event('vite:preloadError', { cancelable: true })
  }

  it('reloads on a failed dynamic import and stops it from rejecting', () => {
    const reload = stubBrowser(memoryStorage())
    const target = new EventTarget()
    installStaleChunkRecovery(target)

    const event = preloadError()
    target.dispatchEvent(event)

    expect(reload).toHaveBeenCalledOnce()
    expect(event.defaultPrevented).toBe(true)
  })

  it('lets the import reject right after a reload, so the error screen shows', () => {
    const reload = stubBrowser(memoryStorage({ [STALE_CHUNK_RELOADED_AT_KEY]: String(Date.now()) }))
    const target = new EventTarget()
    installStaleChunkRecovery(target)

    const event = preloadError()
    target.dispatchEvent(event)

    expect(reload).not.toHaveBeenCalled()
    expect(event.defaultPrevented).toBe(false)
  })

  it('listens once however often it is called', () => {
    const target = new EventTarget()
    const add = vi.spyOn(target, 'addEventListener')

    installStaleChunkRecovery(target)
    installStaleChunkRecovery(target)

    expect(add).toHaveBeenCalledOnce()
  })
})

describe('reportCaughtError with a stale chunk', () => {
  const removers: Array<() => void> = []
  afterEach(() => {
    for (const remove of removers.splice(0)) remove()
  })

  it('reloads instead of reporting, and reports nothing else caught while reloading', () => {
    const reload = vi.fn()
    vi.stubGlobal('sessionStorage', memoryStorage())
    vi.stubGlobal('window', { location: { reload } })
    const reporter = vi.fn()
    removers.push(addErrorReporter('reporter', reporter))

    reportCaughtError(chromium)
    // React.lazy, handed the undefined a prevented import resolves to.
    reportCaughtError(new Error('lazy: Expected the result of a dynamic import() call.'))

    expect(reload).toHaveBeenCalledOnce()
    expect(reporter).not.toHaveBeenCalled()
  })

  it('reports a chunk still missing right after a reload', () => {
    const reload = vi.fn()
    vi.stubGlobal(
      'sessionStorage',
      memoryStorage({ [STALE_CHUNK_RELOADED_AT_KEY]: String(Date.now()) }),
    )
    vi.stubGlobal('window', { location: { reload } })
    const reporter = vi.fn()
    removers.push(addErrorReporter('reporter', reporter))

    reportCaughtError(chromium)

    expect(reload).not.toHaveBeenCalled()
    expect(reporter).toHaveBeenCalledWith(chromium, undefined)
  })
})
