import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const E2E_DIR = dirname(fileURLToPath(import.meta.url))
export const CREDENTIALS_FILE = resolve(E2E_DIR, '.credentials.json')
export const RAILS_PID_FILE = resolve(E2E_DIR, '.rails.pid')
