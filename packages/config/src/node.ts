import fs from 'node:fs'
import { type LoadedConfig, parseConfig } from './load.js'

export * from './index.js'

/** Reads and validates a configuration file from disk. */
export function loadConfig(file: string, env: NodeJS.ProcessEnv = process.env): LoadedConfig {
  return parseConfig(fs.readFileSync(file, 'utf-8'), env)
}
