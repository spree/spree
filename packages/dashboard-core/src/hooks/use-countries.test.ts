import { afterEach, describe, expect, it, vi } from 'vitest'
import { type PanelApiClient, setApiClient } from '../api-client'
import { loadCountries, resetCountriesCache } from './use-countries'

function registerClient(listCountries?: PanelApiClient['listCountries']) {
  setApiClient({ listCountries } as PanelApiClient)
}

afterEach(() => {
  resetCountriesCache()
})

describe('loadCountries', () => {
  it('calls the API once and reuses the stored list', async () => {
    const data = [{ iso: 'US', iso3: 'USA', name: 'United States' }]
    const listCountries = vi.fn().mockResolvedValue({ data })
    registerClient(listCountries)

    const first = await loadCountries()
    const second = await loadCountries()

    expect(listCountries).toHaveBeenCalledTimes(1)
    expect(first).toBe(second)
    expect(first.data).toEqual(data)
  })

  it('shares one in-flight request across overlapping callers', async () => {
    let resolveList!: (value: { data: [] }) => void
    const listCountries = vi.fn(
      () =>
        new Promise<{ data: [] }>((resolve) => {
          resolveList = resolve
        }),
    )
    registerClient(listCountries)

    const first = loadCountries()
    const second = loadCountries()
    resolveList({ data: [] })

    expect(await first).toBe(await second)
    expect(listCountries).toHaveBeenCalledTimes(1)
  })

  it('retries after a failed load', async () => {
    const listCountries = vi
      .fn()
      .mockRejectedValueOnce(new Error('network'))
      .mockResolvedValueOnce({ data: [] })
    registerClient(listCountries)

    await expect(loadCountries()).rejects.toThrow('network')
    await expect(loadCountries()).resolves.toEqual({ data: [] })
    expect(listCountries).toHaveBeenCalledTimes(2)
  })
})
