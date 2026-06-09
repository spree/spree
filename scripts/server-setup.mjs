#!/usr/bin/env node
/**
 * Cross-platform clone + post-steps for `pnpm server:setup`.
 * Replaces Unix-only `rm -rf` / `echo` so Windows works the same as macOS/Linux.
 */
import { execSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const serverDir = path.join(root, 'server')
const repoUrl = 'https://github.com/spree/spree-starter.git'

if (!fs.existsSync(serverDir)) {
  execSync(`git clone --depth 1 ${repoUrl} server`, { cwd: root, stdio: 'inherit' })
} else {
  const gitDir = path.join(serverDir, '.git')
  if (fs.existsSync(gitDir)) {
    console.log('server/ already exists with a git checkout; finishing cleanup and .env…')
  } else {
    console.error(
      'server/ already exists and is not a fresh clone (no .git). Remove server/ manually if you want to re-run setup.',
    )
    process.exit(1)
  }
}

const gitPath = path.join(serverDir, '.git')
if (fs.existsSync(gitPath)) {
  fs.rmSync(gitPath, { recursive: true, force: true })
}

const gitignorePath = path.join(serverDir, '.gitignore')
if (fs.existsSync(gitignorePath)) {
  fs.unlinkSync(gitignorePath)
}

fs.writeFileSync(path.join(serverDir, '.env'), 'SPREE_PATH=..\n', 'utf8')

console.log(`
Server cloned to server/. Next steps:
  cd server
  # edit .env if needed (DATABASE_USERNAME, etc.)
  bin/setup
  bin/dev
`)
