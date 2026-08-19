import { beforeEach, describe, expect, it } from 'vitest'
import {
  __resetCreateActionRegistry,
  type CreateActionEntry,
  createActionRegistry,
  matchCreateActions,
} from '../src/lib/create-action-registry'

// A stand-in translator: keys map to their last segment, title-cased, except
// the verb list and the two-word nouns declared here.
const DICT: Record<string, string> = {
  'admin.components.command_palette.create.verbs': 'add,new,create',
  'nouns.product': 'Product',
  'nouns.product_plural': 'Products',
  'nouns.customer': 'Customer',
  'nouns.customer_plural': 'Customers',
  'nouns.customer_group': 'Customer group',
  'nouns.promotion': 'Promotion',
  'nouns.discount': 'Discount',
  'nouns.discount_plural': 'Discounts',
}
const t = (key: string) => DICT[key] ?? key

function entry(key: string, labelKey: string, aliasKeys?: string[]): CreateActionEntry {
  return { key, labelKey, aliasKeys, getRoute: () => ({ to: `/${key}` }) }
}

const ENTRIES = [
  entry('product', 'nouns.product', ['nouns.product_plural']),
  entry('customer', 'nouns.customer', ['nouns.customer_plural']),
  entry('customer_group', 'nouns.customer_group'),
  entry('promotion', 'nouns.promotion', ['nouns.discount', 'nouns.discount_plural']),
]

const match = (query: string) =>
  matchCreateActions({ query, entries: ENTRIES, t }).map((m) => m.entry.key)

describe('matchCreateActions', () => {
  it('maps "<verb> <noun>" to the matching action', () => {
    expect(match('add product')).toEqual(['product'])
    expect(match('new customer group')).toEqual(['customer_group'])
    expect(match('create promotion')).toEqual(['promotion'])
  })

  it('accepts every registered verb', () => {
    for (const verb of ['add', 'new', 'create']) {
      expect(match(`${verb} product`)).toEqual(['product'])
    }
  })

  it('ignores queries that name no verb, so plain search is unaffected', () => {
    expect(match('product')).toEqual([])
    expect(match('blue running shoe')).toEqual([])
    expect(match('')).toEqual([])
  })

  it('matches the plural the merchant may type', () => {
    expect(match('add products')).toEqual(['product'])
  })

  it('matches an alias but reports the resource under its real name', () => {
    const matches = matchCreateActions({ query: 'new discount', entries: ENTRIES, t })
    expect(matches.map((m) => m.entry.key)).toEqual(['promotion'])
    expect(matches[0].noun).toBe('Promotion')
  })

  it('matches a plural alias', () => {
    expect(match('add discounts')).toEqual(['promotion'])
  })

  it('accepts a trailing verb, for languages that put it last', () => {
    expect(match('product add')).toEqual(['product'])
  })

  it('lists everything creatable for a bare verb', () => {
    expect(match('new')).toEqual(['product', 'customer', 'customer_group', 'promotion'])
  })

  it('ranks an exact noun above a merely-prefixed one', () => {
    // "customer" is exact for Customer and a prefix of "Customer group".
    expect(match('add customer')).toEqual(['customer', 'customer_group'])
  })

  it('is case- and accent-insensitive', () => {
    expect(match('ADD Prödüct')).toEqual(['product'])
  })

  it('tolerates extra whitespace', () => {
    expect(match('  add   product  ')).toEqual(['product'])
  })

  it('does not read a verb out of the middle of an ordinary word', () => {
    // "address" starts with the verb "add" — matching it would hijack search.
    expect(match('address')).toEqual([])
    expect(match('newsletter')).toEqual([])
  })
})

// Chinese and Japanese are written without spaces between words, so the whole
// query arrives as a single token and word-equality never finds the verb.
describe('matchCreateActions — unspaced scripts', () => {
  const CJK: Record<string, string> = {
    'admin.components.command_palette.create.verbs': '新建,添加,创建,新增',
    'nouns.product': '商品',
    'nouns.order': '订单',
  }
  const tCjk = (key: string) => CJK[key] ?? key
  const cjkEntries = [entry('product', 'nouns.product'), entry('order', 'nouns.order')]
  const matchCjk = (query: string) =>
    matchCreateActions({ query, entries: cjkEntries, t: tCjk }).map((m) => m.entry.key)

  it('matches a verb prefixed onto the noun with no space', () => {
    expect(matchCjk('新建商品')).toEqual(['product'])
    expect(matchCjk('添加订单')).toEqual(['order'])
  })

  it('still matches when a space is typed', () => {
    expect(matchCjk('新建 商品')).toEqual(['product'])
  })

  it('lists everything creatable for a bare verb', () => {
    expect(matchCjk('新建')).toEqual(['product', 'order'])
  })

  it('ignores a query naming no verb', () => {
    expect(matchCjk('商品')).toEqual([])
  })
})

describe('createActionRegistry', () => {
  beforeEach(() => {
    __resetCreateActionRegistry()
  })

  it('rejects a duplicate key rather than silently shadowing', () => {
    createActionRegistry.add(entry('product', 'nouns.product'))
    expect(() => createActionRegistry.add(entry('product', 'nouns.product'))).toThrow(
      /already registered/,
    )
  })

  it('throws when updating an action that was never registered', () => {
    expect(() => createActionRegistry.update('ghost', { position: 1 })).toThrow(/not found/)
  })

  it('removes a registered action and ignores a missing one', () => {
    createActionRegistry.add(entry('product', 'nouns.product'))
    createActionRegistry.remove('product')
    expect(() => createActionRegistry.remove('product')).not.toThrow()
  })
})
