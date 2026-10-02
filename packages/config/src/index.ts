/**
 * `@spree/config` — the configurator engine. Reads a `spree.config.yml`,
 * plans the changes a live store needs to match it, applies them through the
 * Admin API, and reads a store back into the file format.
 */
export { applyPlan, deployConfig, reportHasFailures } from './apply.js'
export { RunContext } from './context.js'
export { diffAttributes, PendingRef, valuesEqual } from './diff.js'
export { ConfigError, DanglingReferenceError } from './errors.js'
export type { IntrospectOptions } from './introspect.js'
export { introspect, renderConfigYaml } from './introspect.js'
export type { ConfigIssue, LoadedConfig, Variables } from './load.js'
export {
  ConfigValidationError,
  formatPath,
  parseConfig,
  substituteEnv,
} from './load.js'
export type { PlannedOperation, PlannedRun, PlannedSection } from './plan.js'
export {
  assertPrunable,
  planConfig,
  planHasChanges,
  planHasDeletes,
  planHasErrors,
  planOperations,
  presentSections,
} from './plan.js'
export type { DefaultsOptions } from './provision.js'
export { provisionStore, storeDefaults } from './provision.js'
export type { RenderOptions } from './render.js'
export { countByKind, planToJson, renderPlan, renderReport, summaryLine } from './render.js'
export type {
  CategoryEntry,
  ChannelEntry,
  CustomerEntry,
  CustomerGroupEntry,
  DeliveryMethodEntry,
  DeliveryZoneEntry,
  MarketEntry,
  ProductEntry,
  SellerEntry,
  SpreeConfig,
  StockLocationEntry,
  StoreEntry,
  SupplierEntry,
  TaxCategoryEntry,
  VariantEntry,
} from './schema.js'
export { configSchema, SCHEMA_URL, toJsonSchema } from './schema.js'
export { missingScopes, requiredScopes } from './scopes.js'
export { ORDERED_SECTIONS, SECTIONS } from './sections/index.js'
export type {
  ApplyReport,
  ApplyResult,
  ApplyStatus,
  AttributeChange,
  ConfigClient,
  LiveRecord,
  OperationKind,
  Plan,
  PlanOperation,
  PlanOptions,
  SectionName,
  SectionPlan,
} from './types.js'
export { SECTION_NAMES } from './types.js'
