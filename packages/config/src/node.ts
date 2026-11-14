import fs from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'
import { pathToFileURL } from 'node:url'
import { parseDocument } from 'yaml'
import { ConfigValidationError, type LoadedConfig, parseConfig } from './load.js'
import { registerSection, type SectionDefinition } from './sections/index.js'

export * from './index.js'

/** Reads and validates a configuration file from disk. */
export function loadConfig(file: string, env: NodeJS.ProcessEnv = process.env): LoadedConfig {
  return parseConfig(fs.readFileSync(file, 'utf-8'), env)
}

/**
 * Imports the modules a file lists under `extensions` and registers the
 * sections they export, so the file can then be read with `loadConfig`. A
 * path is taken from the file's directory; anything else is a package the
 * project has installed. Returns the names of the sections added. A file
 * that is missing or is not YAML adds nothing: `loadConfig` reports it.
 */
export async function loadExtensions(file: string): Promise<string[]> {
  let listed: unknown
  try {
    listed = parseDocument(fs.readFileSync(file, 'utf-8')).toJS()?.extensions
  } catch {
    return []
  }
  if (!Array.isArray(listed)) return []

  const require = createRequire(pathToFileURL(file))
  const names: string[] = []
  for (const [index, specifier] of listed.entries()) {
    if (typeof specifier !== 'string') continue
    const at = `extensions[${index}]`
    try {
      const resolved = /^\.{1,2}\//.test(specifier)
        ? path.resolve(path.dirname(file), specifier)
        : require.resolve(specifier)
      const module = (await import(pathToFileURL(resolved).href)) as { default?: unknown }
      // A CommonJS module's `module.exports.default` arrives one level down.
      const exported =
        (module.default as { default?: unknown } | undefined)?.default ?? module.default
      const definitions = (Array.isArray(exported) ? exported : [exported]) as SectionDefinition[]
      if (exported === undefined) throw new Error('the module has no default export')
      for (const definition of definitions) {
        registerSection(definition)
        names.push(definition.name)
      }
    } catch (error) {
      throw new ConfigValidationError([
        { path: at, message: `could not load "${specifier}": ${(error as Error).message}` },
      ])
    }
  }
  return names
}
