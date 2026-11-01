#!/usr/bin/env node
// A stable bin target that exists before the first build, so `pnpm install`
// on a fresh clone can link `spree` before its postinstall builds dist/.
import '../dist/index.js'
