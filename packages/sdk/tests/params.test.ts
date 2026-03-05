import { describe, it, expect } from 'vitest';
import { transformListParams } from '../src/params';

describe('transformListParams', () => {
  it('passes through pagination params unchanged', () => {
    const result = transformListParams({ page: 2, limit: 10 });
    expect(result).toEqual({ page: 2, limit: 10 });
  });

  it('joins expand array into comma-separated string', () => {
    const result = transformListParams({ expand: ['variants', 'images'] });
    expect(result).toEqual({ expand: 'variants,images' });
  });

  it('joins single-element expand array', () => {
    const result = transformListParams({ expand: ['variants'] });
    expect(result).toEqual({ expand: 'variants' });
  });

  it('handles empty expand array', () => {
    const result = transformListParams({ expand: [] });
    expect(result).toEqual({ expand: '' });
  });

  it('passes through descending sort param unchanged', () => {
    const result = transformListParams({ sort: '-price' });
    expect(result).toEqual({ sort: '-price' });
  });

  it('passes through ascending sort param unchanged', () => {
    const result = transformListParams({ sort: 'name' });
    expect(result).toEqual({ sort: 'name' });
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

  it('wraps array values with [] suffix automatically', () => {
    const result = transformListParams({
      with_option_value_ids: ['optval_abc', 'optval_def'],
    });
    expect(result).toEqual({
      'q[with_option_value_ids][]': ['optval_abc', 'optval_def'],
    });
  });

  it('handles array values even when key already has [] suffix', () => {
    const result = transformListParams({
      'with_option_value_ids[]': ['optval_abc'],
    });
    expect(result).toEqual({
      'q[with_option_value_ids][]': ['optval_abc'],
    });
  });

  it('handles a full combined query', () => {
    const result = transformListParams({
      page: 1,
      limit: 12,
      expand: ['images', 'default_variant'],
      sort: '-created_at',
      name_cont: 'shirt',
      price_gte: 20,
      taxons_id_eq: 'txn_abc123',
    });
    expect(result).toEqual({
      page: 1,
      limit: 12,
      expand: 'images,default_variant',
      sort: '-created_at',
      'q[name_cont]': 'shirt',
      'q[price_gte]': 20,
      'q[taxons_id_eq]': 'txn_abc123',
    });
  });
});
