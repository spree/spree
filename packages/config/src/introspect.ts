import { stringify } from 'yaml'
import { RunContext } from './context.js'
import { SCHEMA_URL, type SpreeConfig } from './schema.js'
import { ORDERED_SECTIONS, SOURCES } from './sections/index.js'
import type { ConfigClient, LiveRecord, SectionName } from './types.js'

export interface IntrospectOptions {
  /** Sections to read; defaults to every section but products and customers. */
  include?: SectionName[]
}

/**
 * Reads the live store back into the file format: ids, timestamps and
 * computed attributes dropped, references written as natural keys.
 */
export async function introspect(
  client: ConfigClient,
  options: IntrospectOptions = {},
): Promise<SpreeConfig> {
  const wanted = new Set(
    options.include ??
      ORDERED_SECTIONS.filter((section) => section.introspectByDefault).map(
        (section) => section.name,
      ),
  )
  const config: Record<string, unknown> = { version: 1 }
  const ctx = new RunContext(client, { version: 1 }, SOURCES)

  for (const section of ORDERED_SECTIONS) {
    if (!wanted.has(section.name)) continue
    if (section.singleton) {
      const live = await client.request<LiveRecord>('GET', section.path)
      config[section.name] = await section.toFile(live, ctx)
      continue
    }
    const loaded = await ctx.load(section.name)
    const entries: unknown[] = []
    for (const records of loaded.byKey.values()) {
      for (const record of records) entries.push(await section.toFile(record, ctx))
    }
    config[section.name] = entries
  }

  return config as SpreeConfig
}

/** The config as a YAML document with the schema header editors read. */
export function renderConfigYaml(config: SpreeConfig): string {
  return `# yaml-language-server: $schema=${SCHEMA_URL}\n${stringify(config, { lineWidth: 0 })}`
}
