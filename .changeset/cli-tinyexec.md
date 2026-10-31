---
"@spree/cli": patch
"create-spree-app": patch
---

`spree` and `create-spree-app` install fewer packages. They run commands through `tinyexec`, which has no dependencies of its own, instead of `execa`, and `create-spree-app` finds free ports itself instead of using `get-port`. The CLI installs 11 packages instead of 28, and `create-spree-app` 9 instead of 27. Commands behave the same, including on Windows.
