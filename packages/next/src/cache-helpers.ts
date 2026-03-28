import { revalidateTag as nextRevalidateTag } from 'next/cache';

/**
 * Compatibility wrapper for revalidateTag across Next.js 15 and 16.
 *
 * Next.js 16 changed revalidateTag to require a second `profile` argument.
 * This wrapper passes `{ expire: 0 }` (immediate invalidation) to maintain
 * the same behavior as Next.js 15's single-arg revalidateTag.
 */
export function revalidateTag(tag: string): void {
  (nextRevalidateTag as (tag: string, profile: { expire: number }) => void)(tag, { expire: 0 });
}
