---
'@spree/dashboard': patch
'@spree/dashboard-ui': patch
---

Fix the dashboard date range picker remembering "Last 30 days" after another preset is chosen.

The trigger label lived in local state that reset whenever analytics refetch replaced the page. It now follows the selected dates, so Last 90 days stays selected after the figures update.
