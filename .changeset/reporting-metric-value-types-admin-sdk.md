---
"@spree/admin-sdk": patch
---

`ReportingMetricValue`, the type of every metric in `client.reporting.query()` results, now matches what the API returns. `value` and `previous` are `string | number`: a decimal string for money, decimal and percent metrics (`"110.00"`) and a number for integer metrics. `growth` is `string | null`, a decimal string such as `"12.5"`. They were typed as `number`, so code that did arithmetic on them compiled but received strings; convert a value before calculating with it, and never parse a money string into a float.
