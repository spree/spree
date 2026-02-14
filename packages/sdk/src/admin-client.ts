import type { RequestFn } from './request';

export class AdminClient {
  /** @internal */
  private readonly request: RequestFn;

  constructor(request: RequestFn) {
    this.request = request;

    // Prevent "unused" TS error — will be used as admin endpoints are added
    void this.request;
  }
}
