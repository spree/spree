import type { Promotion as SdkPromotion } from '@spree/admin-sdk'
import type { RunContext } from '../context.js'
import { PROMOTION_ATTRIBUTES, type PromotionEntry } from '../schema.js'
import type { LiveRecord } from '../types.js'
import {
  comparableRules,
  desiredRules,
  rulesToFile,
  sortedRules,
  wirePreferences,
  wireRules,
  withLiveIds,
} from './rules.js'
import { filePreferences, type Payload, pick, present, type Section } from './section.js'

type Promotion = SdkPromotion & LiveRecord

const RULE_TYPES = '/promotion_rules/types'
const ACTION_TYPES = '/promotion_actions/types'
/** The calculators an action kind can use. */
const calculatorsOf = (action: string) =>
  `/promotion_actions/calculators?type=${encodeURIComponent(action)}`

interface Calculator {
  type: string
  preferences?: Record<string, unknown>
}

interface LiveAction {
  type: string
  preferences?: Record<string, unknown>
  calculator?: Calculator | null
}

async function wireActions(actions: unknown, ctx: RunContext) {
  const wired = (await wireRules(actions, ACTION_TYPES, ctx)) as (Payload & {
    calculator?: Calculator
  })[]
  return Promise.all(
    wired.map(async (action) =>
      action.calculator
        ? {
            ...action,
            calculator: await wirePreferences(
              action.calculator,
              calculatorsOf(String(action.type)),
              ctx,
            ),
          }
        : action,
    ),
  )
}

/**
 * Promotions match on name. Rules and actions are the whole set, written by
 * kind with that kind's settings; the products, categories or customers some
 * rule kinds select are managed in the dashboard.
 */
export const promotions: Section<PromotionEntry, Promotion> = {
  name: 'promotions',
  scope: 'write_promotions',
  introspectByDefault: true,
  path: '/promotions',
  keyAttribute: 'name',
  filterable: true,
  expand: ['rules', 'actions'],
  entries: (config) => config.promotions ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry, ctx, path) {
    return {
      ...pick(entry, PROMOTION_ATTRIBUTES),
      ...(entry.rules ? { rules: await desiredRules(entry.rules, RULE_TYPES, ctx, path) } : {}),
      ...(entry.actions
        ? { actions: await desiredRules(entry.actions, ACTION_TYPES, ctx, path) }
        : {}),
    }
  },
  async current(live, _ctx, desired) {
    return {
      ...live,
      ...(desired.rules ? { rules: comparableRules(live.rules) } : {}),
      ...(desired.actions ? { actions: comparableRules(live.actions) } : {}),
    }
  },
  async wire(payload, ctx) {
    return {
      ...payload,
      ...(payload.rules ? { rules: await wireRules(payload.rules, RULE_TYPES, ctx) } : {}),
      ...(payload.actions ? { actions: await wireActions(payload.actions, ctx) } : {}),
    }
  },
  // A promotion holds one rule and one action of each kind, so a declared one
  // replaces the live one of its kind.
  async update(live, payload, _entry, ctx) {
    return ctx.client.request<Promotion>('PATCH', `/promotions/${live.id}`, {
      params: { expand: 'rules,actions' },
      body: {
        ...payload,
        ...(payload.rules ? { rules: withLiveIds(payload.rules, live.rules) } : {}),
        ...(payload.actions ? { actions: withLiveIds(payload.actions, live.actions) } : {}),
      },
    })
  },
  async toFile(live, ctx) {
    const rules = await rulesToFile(live.rules as LiveAction[] | undefined, RULE_TYPES, ctx)
    const liveActions = sortedRules(live.actions as LiveAction[] | undefined)
    const actions = (await rulesToFile(liveActions, ACTION_TYPES, ctx)).map((action, index) => {
      const calculator = liveActions[index].calculator
      if (!calculator) return action
      const preferences = filePreferences(calculator.preferences)
      return {
        ...action,
        calculator: {
          type: calculator.type,
          ...(Object.keys(preferences).length ? { preferences } : {}),
        },
      }
    })
    const entry = present(live as unknown as PromotionEntry, PROMOTION_ATTRIBUTES) as PromotionEntry
    if (entry.match_policy === 'all') delete entry.match_policy
    if (entry.kind === 'coupon_code') delete entry.kind
    return {
      ...entry,
      ...(rules.length ? { rules } : {}),
      ...(actions.length ? { actions } : {}),
    } as PromotionEntry
  },
}
