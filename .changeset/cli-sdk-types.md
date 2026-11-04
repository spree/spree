---
"@spree/cli": patch
---

Added `spree sdk generate`, which writes the whole client of a package that extends Spree's SDKs from the extension it is for: it runs the extension's `rake spree:openapi:generate` and `rake spree:sdk:serializer_types`, then writes one SDK extension per resource, with a method per documented operation, and the request, filter and response types. The extension is named in the package's `package.json` (`"spree": { "extension": "../my_extension" }`); `--check` fails when the generated files are out of date, and `--no-backend` uses the committed documents.
