import { describe, expect, it, vi } from 'vitest'
import { type PanelApiClient, setApiClient } from '../api-client'
import { fetchOptionTypesByIds } from './use-product-form-data'

function registerOptionTypes(list?: NonNullable<PanelApiClient['optionTypes']>['list']) {
  setApiClient({ optionTypes: list ? { list } : undefined } as PanelApiClient)
}

describe('fetchOptionTypesByIds', () => {
  // The form's own list is one page, so a type naming an option type past it
  // must be fetched by id rather than picked out of that page.
  it('asks for exactly the named ids', async () => {
    const data = [{ id: 'opt_2', name: 'size', label: 'Size' }]
    const list = vi.fn().mockResolvedValue({ data })
    registerOptionTypes(list)

    await expect(fetchOptionTypesByIds(['opt_1', 'opt_2'])).resolves.toEqual({ data })
    expect(list).toHaveBeenCalledWith({ id_in: ['opt_1', 'opt_2'], limit: 2 })
  })

  it('answers empty without a request when nothing is named', async () => {
    const list = vi.fn()
    registerOptionTypes(list)

    await expect(fetchOptionTypesByIds([])).resolves.toEqual({ data: [] })
    expect(list).not.toHaveBeenCalled()
  })

  it('answers empty in a panel that registers no option types', async () => {
    registerOptionTypes()

    await expect(fetchOptionTypesByIds(['opt_1'])).resolves.toEqual({ data: [] })
  })
})
