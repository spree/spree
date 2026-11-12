---
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
"@spree/seller-sdk": patch
---

The seller panel's settings gain a Store group with three single-column form pages. Profile holds the name, description, logo and cover photo shoppers see, and replaces the old Profile page, whose address now redirects there. General holds the contact and business details, addresses and holiday mode. Taxes holds tax registrations. List pages show their title and actions on one row, and the Seller API accepts `holiday_mode_until` on the profile. `ReadRow`, `ResourceImageField` and the seller form schema move to `@spree/dashboard-core`. File and image upload fields hide their drop zone once a file is attached and offer Replace beside Remove. A rich text field no longer marks its form as changed when it opens on a description that is inline markup without paragraphs. A date picker's label is left-aligned.
