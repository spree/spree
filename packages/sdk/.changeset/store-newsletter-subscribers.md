---
'@spree/sdk': minor
---

Add `client.newsletterSubscribers.create()` and `client.newsletterSubscribers.verify()` for the new Store API newsletter subscription endpoints.

Lets headless storefronts subscribe guests to the newsletter before account creation and confirm the double opt-in via the verification token from the confirmation email. Pass `redirect_url` on `create()` and the storefront receives a `newsletter_subscriber.subscription_requested` webhook with the token + validated redirect URL so it can send the confirmation email itself — same pattern as `customer.password_reset_requested`. When called with a JWT and the customer's own email, the subscription is auto-verified.
