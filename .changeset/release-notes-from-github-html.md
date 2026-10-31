---
"@spree/dashboard": patch
---

Release notes in the dashboard's notifications now use the HTML GitHub renders for each release, cleaned with DOMPurify, instead of parsing the markdown in the browser. They look the same as on GitHub, tables and code blocks included, and the dashboard installs about 100 fewer packages.
