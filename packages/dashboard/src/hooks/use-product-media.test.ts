import { beforeEach, describe, expect, it, vi } from 'vitest'

const list = vi.fn()

vi.mock('@spree/dashboard-core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@spree/dashboard-core')>()),
  adminClient: { products: { media: { list: (...args: unknown[]) => list(...args) } } },
}))

const { listAllProductMedia } = await import('./use-product-media')

function page(ids: string[], pageNumber: number, pages: number) {
  return { data: ids.map((id) => ({ id })), meta: { page: pageNumber, pages } }
}

describe('listAllProductMedia', () => {
  beforeEach(() => list.mockReset())

  it('reads every page so the whole list reaches the form', async () => {
    list
      .mockResolvedValueOnce(page(['media_1', 'media_2'], 1, 2))
      .mockResolvedValueOnce(page(['media_3'], 2, 2))

    const result = await listAllProductMedia('prod_1')

    expect(result.data.map((media) => media.id)).toEqual(['media_1', 'media_2', 'media_3'])
    expect(list).toHaveBeenLastCalledWith('prod_1', { limit: 100, page: 2 })
  })

  it('stops after one request when there is a single page', async () => {
    list.mockResolvedValueOnce(page(['media_1'], 1, 1))

    await listAllProductMedia('prod_1')

    expect(list).toHaveBeenCalledTimes(1)
  })
})
