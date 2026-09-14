/**
 * The project's `spree.config.yml`: the store's declared shape, deployed by
 * `spree init` after seeding and by `spree config deploy` from then on. It
 * ships as a skeleton because first-run setup owns the store name, country,
 * currency and default market — a file that pre-filled those would fight the
 * setup screen. `spree config introspect` captures the store into the file
 * once setup has run.
 */
export function spreeConfigContent(): string {
  return `# yaml-language-server: $schema=https://spreecommerce.org/docs/schemas/spree-config/1.json
#
# Declarative configuration of this store. \`spree config diff\` shows what a
# deploy would change and \`spree config deploy\` applies it — locally, in CI
# against staging, or against production with a profile (\`spree auth login\`).
# Records match on natural keys (code, slug, name, SKU), never on ids, so the
# same file provisions every environment. Only sections present here are
# managed; the rest of the store is left alone.
#
# The store name, country, currency and default market come from first-run
# setup. Capture them here afterwards with:
#   spree config introspect --out spree.config.yml
#
# Docs: https://spreecommerce.org/docs/developer/cli/configurator
version: 1

# channels:
#   - code: wholesale
#     name: Wholesale
#     preferences: { storefront_access: login_required, guest_checkout: false }

# customer_groups:
#   - name: Wholesale

# tax_categories:
#   - name: Default
#     default: true

# delivery_zones:
#   - name: Europe
#     countries: [DE, FR, NL, PL]

# delivery_methods:
#   - name: Standard EU
#     delivery_zone: Europe
#     calculator: { type: flat_rate, preferences: { amount: 9.9, currency: EUR } }

# stock_locations:
#   - name: Warehouse
#     country_code: US

# categories:
#   - permalink: clothing
#     name: Clothing
#   - permalink: clothing/t-shirts
#     name: T-Shirts

# products:
#   - slug: classic-tee
#     name: Classic Tee
#     status: active
#     categories: [clothing/t-shirts]
#     channels: [online]
#     variants:
#       - sku: TEE-S
#         options: { size: S }
#         prices: { USD: 29.99 }
#         stock: { Warehouse: 100 }

# customers:
#   - email: buyer@example.com
#     first_name: Ada
#     customer_groups: [Wholesale]
`
}
