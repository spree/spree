import { describe, it, expect } from 'vitest';
import { transformListParams } from '../src/params';

describe('transformListParams', () => {
  it('passes through pagination params unchanged', () => {
    const result = transformListParams({ page: 2, per_page: 10 });
    expect(result).toEqual({ page: 2, per_page: 10 });
  });

  it('passes through includes param unchanged', () => {
    const result = transformListParams({ includes: 'variants,images' });
    expect(result).toEqual({ includes: 'variants,images' });
  });

  it('passes through include param unchanged', () => {
    const result = transformListParams({ include: 'variants' });
    expect(result).toEqual({ include: 'variants' });
  });

  it('transforms sort to q[s]', () => {
    const result = transformListParams({ sort: 'price asc' });
    expect(result).toEqual({ 'q[s]': 'price asc' });
  });

  it('wraps filter keys in q[...]', () => {
    const result = transformListParams({
      name_cont: 'shirt',
      price_gte: 20,
      price_lte: 100,
    });
    expect(result).toEqual({
      'q[name_cont]': 'shirt',
      'q[price_gte]': 20,
      'q[price_lte]': 100,
    });
  });

  it('transforms multi_search', () => {
    const result = transformListParams({ multi_search: 'shirt' });
    expect(result).toEqual({ 'q[multi_search]': 'shirt' });
  });

  it('passes through already-wrapped q[...] keys (backward compat)', () => {
    const result = transformListParams({ 'q[name_cont]': 'shirt' });
    expect(result).toEqual({ 'q[name_cont]': 'shirt' });
  });

  it('skips undefined values', () => {
    const result = transformListParams({ name_cont: undefined, page: 1 });
    expect(result).toEqual({ page: 1 });
  });

  it('handles a full combined query', () => {
    const result = transformListParams({
      page: 1,
      per_page: 12,
      includes: 'images,default_variant',
      sort: 'created_at desc',
      name_cont: 'shirt',
      price_gte: 20,
      taxons_id_eq: 'txn_abc123',
    });
    expect(result).toEqual({
      page: 1,
      per_page: 12,
      includes: 'images,default_variant',
      'q[s]': 'created_at desc',
      'q[name_cont]': 'shirt',
      'q[price_gte]': 20,
      'q[taxons_id_eq]': 'txn_abc123',
    });
  });
});
