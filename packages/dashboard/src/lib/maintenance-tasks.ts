import type { MaintenanceTaskParameter } from '@spree/admin-sdk'

/**
 * The last segment of a task's class name, for places where the full
 * namespace is noise — `Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets`
 * reads as "Backfill order markets" in a table cell.
 */
export function taskShortName(taskName: string): string {
  const leaf = taskName.split('::').pop() ?? taskName
  return leaf
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/^./, (character) => character.toUpperCase())
}

/**
 * Seeds a run form from the parameter schema the server published.
 *
 * Values are kept as the strings the inputs produce; the server casts them
 * through the task's own attribute types, which is what makes a parameter's
 * declared type the single source of truth for how it is parsed.
 */
export function defaultTaskArguments(
  parameters: MaintenanceTaskParameter[],
): Record<string, unknown> {
  const values: Record<string, unknown> = {}

  for (const parameter of parameters) {
    if (parameter.default !== null && parameter.default !== undefined) {
      values[parameter.name] = parameter.default
    } else if (parameter.type === 'boolean') {
      values[parameter.name] = false
    } else {
      values[parameter.name] = ''
    }
  }

  return values
}

/**
 * Drops empty optional parameters so the server applies its own defaults
 * rather than casting an empty string to zero.
 */
export function pruneTaskArguments(
  parameters: MaintenanceTaskParameter[],
  values: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {}

  for (const parameter of parameters) {
    const value = values[parameter.name]
    if (value === '' || value === undefined || value === null) continue
    result[parameter.name] = value
  }

  return result
}

/** Client-side check for the required parameters, so an empty form never round-trips. */
export function missingRequiredArguments(
  parameters: MaintenanceTaskParameter[],
  values: Record<string, unknown>,
): string[] {
  return parameters
    .filter((parameter) => parameter.required)
    .filter((parameter) => {
      const value = values[parameter.name]
      return value === '' || value === undefined || value === null
    })
    .map((parameter) => parameter.name)
}
