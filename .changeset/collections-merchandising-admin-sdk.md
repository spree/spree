---
"@spree/admin-sdk": minor
---

Added `categories.publications`, `collections.publications` and `collections.exclusions`, and `collections.products.list` rows say whether the rules matched them or they were hand-picked (`membership_source`). Categories and collections are published per channel with an optional schedule; hiding a category hides its subcategories. Collections mix rule-matched and hand-picked products, can exclude products, and take seven new rule types: category, product type, price, in stock, title, seller and custom field.
