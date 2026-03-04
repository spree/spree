import type { PaginatedResponse } from './types';

/**
 * A lazy paginated list that supports both `await` (single page) and `for await` (all pages).
 *
 * @example
 * // Get first page (existing behavior):
 * const response = await client.store.products.list({ limit: 10 });
 * console.log(response.data);
 *
 * // Auto-paginate through all items:
 * for await (const product of client.store.products.list()) {
 *   console.log(product.name);
 * }
 */
export class AsyncIterableList<T> implements PromiseLike<PaginatedResponse<T>>, AsyncIterable<T> {
  private _fetchPage: (page: number) => Promise<PaginatedResponse<T>>;
  private _firstPage: number;

  constructor(fetchPage: (page: number) => Promise<PaginatedResponse<T>>, firstPage = 1) {
    this._fetchPage = fetchPage;
    this._firstPage = firstPage;
  }

  /** Await resolves to the first page (backward-compatible). */
  then<R1 = PaginatedResponse<T>, R2 = never>(
    onFulfilled?: ((value: PaginatedResponse<T>) => R1 | PromiseLike<R1>) | null,
    onRejected?: ((reason: unknown) => R2 | PromiseLike<R2>) | null
  ): Promise<R1 | R2> {
    return this._fetchPage(this._firstPage).then(onFulfilled, onRejected);
  }

  /** `for await` iterates through all items across all pages. */
  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    let page = this._firstPage;
    while (true) {
      const response = await this._fetchPage(page);
      for (const item of response.data) {
        yield item;
      }
      if (!response.meta.next) break;
      page = response.meta.next;
    }
  }
}
