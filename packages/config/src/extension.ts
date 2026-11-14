import type { SpreeConfig } from './schema.js'
import type { EntrySchema, SectionDefinition } from './sections/index.js'
import { type PlainOptions, plainSection } from './sections/section.js'
import type { LiveRecord, SectionName } from './types.js'

export type SectionOptions<Entry, Live extends LiveRecord> = Omit<
  PlainOptions<Entry, Live>,
  'name' | 'introspectByDefault' | 'references'
> & {
  /** The file's top-level key, and the Admin API path unless `path` says otherwise. */
  name: string
  /** Checks one entry of the section before anything is sent. */
  schema: EntrySchema
  /** Natural keys of other sections the entries refer to, so they load in one request per section. */
  references?: (entries: Entry[]) => Partial<Record<string, string[]>>
  /** Whether `introspect` reads the section when no `--include` is given; it does unless told not to. */
  introspectByDefault?: boolean
}

/**
 * Describes a section an extension adds to the file: one Admin API resource
 * the extension serves, matched on a natural key. Hand the result to
 * `registerSection`, or export it as the default of a module the file lists
 * under `extensions`.
 */
export function defineSection<Entry extends object, Live extends LiveRecord = LiveRecord>(
  options: SectionOptions<Entry, Live>,
): SectionDefinition {
  const { schema, name, references, ...rest } = options
  const section = plainSection<Entry, Live>({
    introspectByDefault: true,
    ...rest,
    name: name as SectionName,
  })
  return {
    ...section,
    ...(references
      ? { references: (config: SpreeConfig) => references(section.entries(config)) }
      : {}),
    schema,
  } as unknown as SectionDefinition
}
