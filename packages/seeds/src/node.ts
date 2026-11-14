import fs from 'node:fs'
import { type LoadedSeeds, parseSeeds } from './load.js'

export * from './index.js'

/** Reads and validates a configuration file from disk. */
export function loadSeeds(file: string, env: NodeJS.ProcessEnv = process.env): LoadedSeeds {
  return parseSeeds(fs.readFileSync(file, 'utf-8'), env)
}
