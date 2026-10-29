---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
---

Store setup moved from a Getting Started nav entry to a checklist card above the account menu in the admin dashboard. It shows overall progress and every step, marks the next one to take, and each step goes straight to where it is done: a settings page, or the address and storefront dialogs opened in place. The card can be minimized to its header, and stays that way until expanded again. Like the old entry, it disappears once setup is done or for staff who cannot change the store. The Getting Started page and the seller panel's onboarding page use the same step icons, now exported from `@spree/dashboard-ui` as `StepIcon` and `StepProgressRing`. `AppShell` gains a `sidebarWidget` prop for cards pinned above the account menu.
