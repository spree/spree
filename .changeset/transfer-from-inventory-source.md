---
"@spree/dashboard": patch
---

Create transfer from an Inventory row lets you choose where the stock leaves from. The line it adds no longer locks an empty From, which left Create draft disabled until the line was removed.
From no longer offers the warehouse the transfer is going to, so choosing it cannot leave To showing an id instead of a name.
