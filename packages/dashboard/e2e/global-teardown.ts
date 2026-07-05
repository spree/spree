import { readFileSync, unlinkSync } from 'node:fs'
import { RAILS_PID_FILE } from './paths'

export default async function globalTeardown() {
  let pid: number
  try {
    pid = Number.parseInt(readFileSync(RAILS_PID_FILE, 'utf-8'), 10)
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === 'ENOENT') return
    throw e
  }

  try {
    process.kill(pid, 'SIGTERM')
  } catch {
    // Process already dead.
  }

  try {
    unlinkSync(RAILS_PID_FILE)
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') throw e
  }
}
