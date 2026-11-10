---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
---

The media library opens as a large dialog with search, type and usage filters, upload, grid or list view and sorting, and the Media page gains the same views. Product media opens in a full-screen editor and can be removed in bulk, with files only deleted once the product saves, and each variant picks its images from the product's own.

`MediaPickerSheet` is deprecated in favour of `MediaPickerDialog`, and `useFormDeleteProductMedia` in favour of marking files in `removed_media_ids` and saving with `useCommitRemovedProductMedia`. Both old names keep working until the next minor release.
