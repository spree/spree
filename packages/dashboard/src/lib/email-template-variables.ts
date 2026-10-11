import type {
  Company,
  Customer,
  EmailFulfillment,
  EmailOrder,
  EmailOrderGroup,
  EmailReturn,
  EmailStore,
} from '@spree/admin-sdk'
import {
  EmailFulfillmentSchema,
  EmailOrderGroupSchema,
  EmailOrderSchema,
  EmailReturnSchema,
  EmailStoreSchema,
} from '@spree/admin-sdk/zod'

type FieldsOf<T> = ReadonlyArray<Extract<keyof T, string>>

/** A variable a template receives, with the fields worth pointing out. */
export interface EmailTemplateVariable {
  name: string
  /** The generated schema of the data it holds, for suggesting all of its fields. */
  schema?: unknown
  /** Translation key for one line saying what it is. */
  descriptionKey: string
  fields?: readonly string[]
  /** The fields holding an amount, inserted through the `money` filter. */
  moneyFields?: readonly string[]
}

const variable = (
  name: string,
  fields?: readonly string[],
  schema?: unknown,
  moneyFields?: readonly string[],
): EmailTemplateVariable => ({
  name,
  descriptionKey: `admin.email_templates.variables.${name}`,
  fields,
  schema,
  moneyFields,
})

/**
 * The Liquid a field's chip inserts: an amount goes through the `money`
 * filter, which formats it in the email's currency and language.
 */
export function insertionFor(variable: EmailTemplateVariable, field: string): string {
  const path = `${variable.name}.${field}`
  return variable.moneyFields?.includes(field) ? `{{ ${path} | money }}` : `{{ ${path} }}`
}

const ORDER_FIELDS = [
  'number',
  'customer_name',
  'email',
  'completed_at',
  'items',
  'item_total',
  'delivery_total',
  'tax_total',
  'total',
  'shipping_address',
  'billing_address',
  'payments',
] as const satisfies FieldsOf<EmailOrder>

const order = variable('order', ORDER_FIELDS, EmailOrderSchema, [
  'item_total',
  'delivery_total',
  'tax_total',
  'total',
] satisfies FieldsOf<EmailOrder>)
const resend = variable('resend')

const STORE_FIELDS = [
  'name',
  'url',
  'support_email',
  'logo_url',
  'address',
  'branding',
] as const satisfies FieldsOf<EmailStore>

/** Every email receives these. */
export const SHARED_EMAIL_VARIABLES: EmailTemplateVariable[] = [
  variable('store', STORE_FIELDS, EmailStoreSchema),
  variable('locale'),
]

/** The variables each editable email receives, by its key with dots. */
export const EMAIL_TEMPLATE_VARIABLES: Record<string, EmailTemplateVariable[]> = {
  'spree.order_mailer.confirm_email': [order, resend],
  'spree.order_mailer.cancel_email': [order, resend],
  'spree.order_mailer.payment_link_email': [order, variable('payment_url')],
  'spree.order_group_mailer.confirm_email': [
    variable(
      'order_group',
      [
        'number',
        'customer_name',
        'order_count',
        'items',
        'fulfillment_groups',
        'total',
      ] as const satisfies FieldsOf<EmailOrderGroup>,
      EmailOrderGroupSchema,
      ['total'] satisfies FieldsOf<EmailOrderGroup>,
    ),
    resend,
  ],
  'spree.fulfillment_mailer.fulfilled_email': [
    order,
    variable(
      'fulfillment',
      [
        'number',
        'tracking',
        'tracking_url',
        'delivery_method_name',
        'items',
      ] as const satisfies FieldsOf<EmailFulfillment>,
      EmailFulfillmentSchema,
    ),
    resend,
  ],
  'spree.return_mailer.refunded_email': [
    order,
    variable(
      'return',
      ['number', 'returned_items', 'refunded_total'] as const satisfies FieldsOf<EmailReturn>,
      EmailReturnSchema,
      ['refunded_total'] satisfies FieldsOf<EmailReturn>,
    ),
    resend,
  ],
  'spree.digital_asset_mailer.files_ready_email': [order, variable('downloads'), resend],
  'spree.customer_mailer.password_reset_email': [
    variable('customer', [
      'first_name',
      'last_name',
      'email',
    ] as const satisfies FieldsOf<Customer>),
    variable('reset_url'),
  ],
  'spree.customer_mailer.data_export_email': [variable('download_url'), variable('expires_at')],
  'spree.newsletter_mailer.email_confirmation': [variable('confirmation_url')],
  'spree.company_mailer.invitation_email': [
    variable('company', ['name'] as const satisfies FieldsOf<Company>),
    variable('accept_url'),
  ],
}

/** The variables a template receives: its own, then the shared ones. */
export function templateVariables(templateId: string): EmailTemplateVariable[] {
  return [...(EMAIL_TEMPLATE_VARIABLES[templateId] ?? []), ...SHARED_EMAIL_VARIABLES]
}

const SCHEMA_DEPTH = 3

interface SchemaNode {
  def?: { type?: string }
  shape?: Record<string, unknown>
  element?: unknown
  unwrap?: () => unknown
}

/**
 * Every dotted path in a generated email schema. A list contributes the
 * fields of its items, as a loop over it (`{% for item in order.items %}`)
 * reads them.
 */
function schemaPaths(schema: unknown, prefix: string, depth: number): string[] {
  let node = schema as SchemaNode
  while (node.def?.type === 'nullable' || node.def?.type === 'optional')
    node = node.unwrap?.() as SchemaNode
  if (node.def?.type === 'array') return schemaPaths(node.element, prefix, depth)
  if (node.def?.type !== 'object' || !node.shape || depth > SCHEMA_DEPTH) return []

  return Object.keys(node.shape).flatMap((field) => {
    const path = `${prefix}.${field}`
    return [path, ...schemaPaths(node.shape?.[field], path, depth + 1)]
  })
}

/**
 * Every dotted path a template can read: each variable, and for those
 * holding generated email data, all of its fields, whether or not the
 * sample record has them.
 */
export function documentedPaths(templateId: string): string[] {
  return templateVariables(templateId).flatMap(({ name, fields = [], schema }) => [
    name,
    ...(schema ? schemaPaths(schema, name, 1) : fields.map((field) => `${name}.${field}`)),
  ])
}

/** Spree's own Liquid filters, on top of Liquid's standard ones. */
export const EMAIL_TEMPLATE_FILTERS = ['money', 'money_with_currency', 'date', 't'] as const

const MAX_DEPTH = 4

/**
 * Dotted paths to every value in a rendered email's variables, with a sample
 * of each. A list contributes the fields of its first item, as a loop over it
 * (`{% for item in order.items %}`) reads them.
 */
export function flattenVariables(
  variables: Record<string, unknown>,
): Array<{ path: string; sample: string }> {
  const paths: Array<{ path: string; sample: string }> = []

  const visit = (value: unknown, path: string, depth: number) => {
    if (Array.isArray(value)) {
      paths.push({ path, sample: `[${value.length}]` })
      if (depth < MAX_DEPTH && value.length > 0) visitObject(value[0], path, depth + 1)
    } else if (value !== null && typeof value === 'object') {
      paths.push({ path, sample: '{…}' })
      if (depth < MAX_DEPTH) visitObject(value, path, depth + 1)
    } else {
      paths.push({ path, sample: value === null || value === undefined ? 'null' : String(value) })
    }
  }

  const visitObject = (value: unknown, prefix: string, depth: number) => {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) return
    for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
      visit(child, prefix ? `${prefix}.${key}` : key, depth)
    }
  }

  visitObject(variables, '', 0)
  return paths
}
