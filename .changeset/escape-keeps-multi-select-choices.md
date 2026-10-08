---
"@spree/dashboard-ui": patch
---

Fixed pressing Escape in a multi-select picker removing every chosen item. After searching and picking a category, the Escape meant to close the search emptied the whole field, and saving the product then stored no categories. Escape no longer removes chosen items, which are removed with their own remove button or Backspace; with the list already closed, it closes the surrounding sheet or dialog instead.
