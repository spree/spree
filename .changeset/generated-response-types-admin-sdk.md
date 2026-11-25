---
"@spree/admin-sdk": patch
---

`ResourceTypeDefinition`, `PaymentMethodType`, `IntegrationTypeDefinition` and `SetupStatus` are now generated from the API's serializers. Their shape is unchanged.

Responses that were typed inline now have a generated type: `BulkProductResult`, `ProductMembershipResult`, `BulkStockLevelResult`, `CalculatorType`, `Tag`, `IntegrationConnectionResult` and `PasswordResetAcknowledgement`. Every bulk product action returns `BulkProductResult`: `product_count` is always there, and the figures only some actions send (`category_count`, `collection_count`, `channel_count`, `tag_count`, `status`, `removed`, `skipped_in_review_count`) are optional. Adding and removing products on a category, collection, price list or catalog returns `ProductMembershipResult`, with `added_count` and `removed_count` optional.

`permissions.list()` and `emailTemplates.list()` return the standard pagination `meta` (`page`, `limit`, `count`, `pages` and the rest). Both still return every row in one page.

`CompanyMembership` and `CompanyInvitation` accept `expand: ['company']`.
