---
"@spree/admin-sdk": patch
---

The types of `client.reporting.query()` results (`ReportingResult`, `ReportingRow`, `ReportingMetricValue`, `ReportingDimensionValue`) are now generated from the API's serializers, so they match what the API returns. In `ReportingMetricValue`, `value` and `previous` are a decimal string for money, decimal and percent metrics (`"110.00"`) and a number for integer metrics, and `growth` is a decimal string such as `"12.5"` or `null`; all three were typed as `number`. `value` can also be `null` in `totals`, and a dimension value in a `ReportingRow` can be `null` for a group that has none. Convert a value before calculating with it, and never parse a money string into a float. `ReportingResultMeta` is exported as its own type, and the matching Zod schemas are in `@spree/admin-sdk/zod`.
