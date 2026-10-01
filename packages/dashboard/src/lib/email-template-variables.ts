import type {
  Address,
  Company,
  Customer,
  EmailFulfillment,
  EmailOrder,
  EmailOrderGroup,
  EmailReturn,
  EmailStore,
} from '@spree/admin-sdk'

type FieldsOf<T> = ReadonlyArray<Extract<keyof T, string>>

/** A variable a template receives, with the fields worth pointing out. */
export interface EmailTemplateVariable {
  name: string
  /** Translation key for one line saying what it is. */
  descriptionKey: string
  fields?: readonly string[]
}

const variable = (name: string, fields?: readonly string[]): EmailTemplateVariable => ({
  name,
  descriptionKey: `admin.email_templates.variables.${name}`,
  fields,
})

const ORDER_FIELDS = [
  'number',
  'customer_name',
  'email',
  'completed_at',
  'items',
  'display_item_total',
  'display_delivery_total',
  'display_tax_total',
  'display_total',
  'shipping_address',
  'billing_address',
  'payments',
] as const satisfies FieldsOf<EmailOrder>

/**
 * Fields of objects a sample record often lacks (a pickup order has no
 * shipping address), so they are suggested even when the preview has none.
 */
const ADDRESS_FIELDS = [
  'first_name',
  'last_name',
  'full_name',
  'company',
  'address1',
  'address2',
  'city',
  'postal_code',
  'state_name',
  'state_code',
  'country_name',
  'country_code',
  'phone',
] as const satisfies FieldsOf<Address>

const NESTED_FIELDS: Record<string, readonly string[]> = {
  billing_address: ADDRESS_FIELDS,
  shipping_address: ADDRESS_FIELDS,
}

const order = variable('order', ORDER_FIELDS)
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
  variable('store', STORE_FIELDS),
  variable('locale'),
]

/** The variables each editable email receives, by its key with dots. */
export const EMAIL_TEMPLATE_VARIABLES: Record<string, EmailTemplateVariable[]> = {
  'spree.order_mailer.confirm_email': [order, resend],
  'spree.order_mailer.cancel_email': [order, resend],
  'spree.order_mailer.payment_link_email': [order, variable('payment_url')],
  'spree.order_group_mailer.confirm_email': [
    variable('order_group', [
      'number',
      'customer_name',
      'order_count',
      'items',
      'fulfillment_groups',
      'display_total',
    ] as const satisfies FieldsOf<EmailOrderGroup>),
    resend,
  ],
  'spree.fulfillment_mailer.fulfilled_email': [
    order,
    variable('fulfillment', [
      'number',
      'tracking',
      'tracking_url',
      'delivery_method_name',
      'items',
    ] as const satisfies FieldsOf<EmailFulfillment>),
    resend,
  ],
  'spree.return_mailer.refunded_email': [
    order,
    variable('return', [
      'number',
      'returned_items',
      'display_refunded_total',
    ] as const satisfies FieldsOf<EmailReturn>),
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

/**
 * Every dotted path the manifest documents for a template: each variable,
 * its highlighted fields, and the fields of those that are objects.
 */
export function documentedPaths(templateId: string): string[] {
  return templateVariables(templateId).flatMap(({ name, fields = [] }) => [
    name,
    ...fields.flatMap((field) => [
      `${name}.${field}`,
      ...(NESTED_FIELDS[field] ?? []).map((nested) => `${name}.${field}.${nested}`),
    ]),
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
