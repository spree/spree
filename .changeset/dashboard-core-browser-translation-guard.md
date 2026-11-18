---
"@spree/dashboard-core": patch
---

Fix: The dashboard and the seller panel no longer crash while the browser translates the page. Google Translate (Chrome, the Google app on iOS, Edge) replaces the text React rendered, and the next change on the page — ticking a checkbox, opening a menu — threw `NotFoundError: The object can not be found here` and showed the error screen. React's changes now follow the translator's replacement: text that goes away takes its translation with it, new content lands where it belongs, and changed text such as a selection count shows its new value instead of a stale translation. Pages that are not being translated are unaffected.
