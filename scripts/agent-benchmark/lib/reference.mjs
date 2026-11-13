#!/usr/bin/env node
// The reference agent: applies the hand-written solution in
// tasks/<task>/reference/ to the current directory, the way a coding agent
// would. Files under files/ are copied over the project, then apply.sh (if
// any) runs from the project root. Calibrates the checks: every task should
// pass with its reference solution.
//
//   node lib/reference.mjs <task-id>
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const taskId = process.argv[2]
const referenceDir = fileURLToPath(new URL(`../tasks/${taskId}/reference/`, import.meta.url))
if (!fs.existsSync(referenceDir)) {
  console.error(`No reference solution for ${taskId} in ${referenceDir}`)
  process.exit(1)
}

const filesDir = path.join(referenceDir, 'files')
if (fs.existsSync(filesDir)) fs.cpSync(filesDir, process.cwd(), { recursive: true })

const script = path.join(referenceDir, 'apply.sh')
if (fs.existsSync(script)) {
  // The script's output goes to stderr: stdout is the agent transcript.
  const result = spawnSync('bash', [script], { stdio: ['ignore', 2, 2] })
  process.exit(result.status ?? 1)
}
