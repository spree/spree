/**
 * Type-level tests for the webhook event union. These are checked by
 * `pnpm typecheck:types` (NOT by Vitest, which transpiles without type-checking
 * and so can't catch a regression in the narrowing behaviour). They exist
 * because the whole value of `SpreeWebhookEvent` is that `switch (event.name)`
 * narrows `event.data` — a regression there compiles fine but silently makes
 * `data` `unknown` everywhere, defeating the feature.
 */
import type { Order, Product } from '../src/types/generated'
import type { SpreeWebhookEvent } from '../src/webhooks'

/** Asserts `T` is exactly `Expected` (both directions). */
type Expect<T, Expected> = [T] extends [Expected] ? ([Expected] extends [T] ? true : never) : never

// ── Built-in events narrow `data` to the matching resource ───────────────────
function builtin(event: SpreeWebhookEvent) {
  if (event.name === 'order.completed') {
    const _check: Expect<typeof event.data, Order> = true
    return _check
  }
  if (event.name === 'product.updated') {
    const _check: Expect<typeof event.data, Product> = true
    return _check
  }
  return true
}

// ── Custom events (TExtra) narrow alongside built-ins ────────────────────────
interface Subscription {
  id: string
  plan: string
}
type MyEvents =
  | { name: 'subscription.created'; data: Subscription }
  | { name: 'subscription.renewed'; data: Subscription }

function custom(event: SpreeWebhookEvent<MyEvents>) {
  if (event.name === 'order.completed') {
    const _check: Expect<typeof event.data, Order> = true
    return _check
  }
  if (event.name === 'subscription.renewed') {
    const _check: Expect<typeof event.data, Subscription> = true
    return _check
  }
  return true
}

// ── Envelope fields are present regardless of the event ──────────────────────
function envelope(event: SpreeWebhookEvent) {
  const _id: string = event.id
  const _at: string = event.created_at
  const _v: string = event.metadata.spree_version
  return [_id, _at, _v]
}

// Silence unused-export lint without running anything.
export const _typeTests = [builtin, custom, envelope]
