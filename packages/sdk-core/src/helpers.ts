/** Serialize expand/fields arrays into comma-separated query params */
export function getParams(params?: { expand?: string[]; fields?: string[] }): Record<string, string> | undefined {
  if (!params) return undefined;
  const result: Record<string, string> = {};
  if (params.expand?.length) result.expand = params.expand.join(',');
  if (params.fields?.length) result.fields = params.fields.join(',');
  return Object.keys(result).length > 0 ? result : undefined;
}

/** Resolve retry config with defaults */
export interface ResolvedRetryConfig {
  maxRetries: number;
  retryOnStatus: number[];
  baseDelay: number;
  maxDelay: number;
  retryOnNetworkError: boolean;
}

export function resolveRetryConfig(retry?: import('./request').RetryConfig | false): ResolvedRetryConfig | false {
  if (retry === false) return false;
  return {
    maxRetries: retry?.maxRetries ?? 2,
    retryOnStatus: retry?.retryOnStatus ?? [429, 500, 502, 503, 504],
    baseDelay: retry?.baseDelay ?? 300,
    maxDelay: retry?.maxDelay ?? 10000,
    retryOnNetworkError: retry?.retryOnNetworkError ?? true,
  };
}
