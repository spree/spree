// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { TranslationBatchEntryParams } from './TranslationBatchEntryParams'

export type TranslationBatchParams = {
  /** At least one entry. All entries are saved, or none are. */
  translations: TranslationBatchEntryParams[]
}
