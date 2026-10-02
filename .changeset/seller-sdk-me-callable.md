---
"@spree/seller-sdk": minor
---

`client.me` is now an object: read the signed-in person with `client.me.get()` and edit their own account — first and last name, photo (`avatar`: a direct-upload signed id, or `null` to remove it) and the panel's `selected_locale` — with `client.me.update(params)`. `me.get()` and `me.update()` return `user` as an `Account`, which adds `selected_locale` to the fields `TeamMember` had.

1.0.0-beta.3 made this change without keeping the old form, so code written against beta.1 or beta.2 failed with `client.me is not a function`. Calling `client.me()` works again and returns the same response as `client.me.get()`, but it is deprecated and logs a one-time `console.warn`. To migrate, replace `client.me()` with `client.me.get()`.
