---
"@spree/sdk": minor
---

Add newsletter unsubscribe endpoints. `newsletterSubscribers.requestUnsubscribe({ email })` asks the store to fire a `newsletter_subscriber.unsubscribe_requested` webhook event carrying an unsubscribe token (always 202, so email existence is never revealed). `newsletterSubscribers.delete(id, { token })` removes a subscription using that token from an email link, or — with a customer JWT instead of the token — removes the signed-in customer's own subscription. `Customer` now exposes the store-scoped `newsletter_subscriber` on `GET /customers/me`, which is where a signed-in customer reads the subscription id.
