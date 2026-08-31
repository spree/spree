---
"@spree/dashboard": patch
---

Show why an order tax line is zero.

The Taxes card now names the treatment (buyer exempt, zero-rated, and the
other recorded reasons) and, when the buyer is exempt, the certificate that
made it so. A completed order with no matching rate says so instead of
looking like a draft that has not been taxed yet, and the Summary card keeps
its tax row at zero so an exempt sale is still visible there.
