---
"@spree/dashboard-core": patch
---

`@types/spark-md5` is now a regular dependency. The package ships TypeScript source, so its consumers type-check `use-direct-upload`, and `tsc` failed with "Could not find a declaration file for module 'spark-md5'" unless each app installed the types itself.
