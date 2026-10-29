---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/seller-dashboard": patch
"@spree/seller-sdk": patch
---

Fixed the invitation link redirecting anyone already signed in to the dashboard instead of letting them accept. Someone signed in as the invited account now accepts with one click, and someone signed in as another account is asked to sign out first. The seller panel's acceptance page shares these screens: an existing account confirms its password instead of being asked to set a new one, and the seller invitation lookup now says whether the invitee has an account.
