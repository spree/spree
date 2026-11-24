---
"@spree/admin-sdk": patch
---

`ResourceTypeDefinition`, `PaymentMethodType`, `IntegrationTypeDefinition` and `SetupStatus` are now generated from the API's serializers. Their shape is unchanged.

Responses that were typed inline now have a generated type of their own, with the same fields: `CalculatorType`, `Tag`, `IntegrationConnectionResult`, `BulkStockLevelResult`, `AddedCount`, `RemovedCount`, `PasswordResetAcknowledgement`, and `BulkProductResult` with its variants `BulkProductStatusResult`, `BulkProductCategoriesResult`, `BulkProductCollectionsResult`, `BulkProductChannelsResult` and `BulkProductTagsResult`.

`permissions.list()` and `emailTemplates.list()` return the standard pagination `meta` (`page`, `limit`, `count`, `pages` and the rest). Both still return every row in one page.
