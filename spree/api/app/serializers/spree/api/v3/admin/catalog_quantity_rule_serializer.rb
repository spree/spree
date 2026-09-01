module Spree
  module Api
    module V3
      module Admin
        # One catalog's quantity terms for one variant. Carries enough of the
        # variant to render the row without a second request — a merchant
        # reading a terms table needs to know which SKU each line is about.
        class CatalogQuantityRuleSerializer < V3::BaseSerializer
          typelize variant_id: 'string | null', variant_sku: 'string | null',
                   product_name: 'string | null',
                   options_text: 'string | null',
                   minimum_order_quantity: ['number | null'],
                   order_multiple: ['number | null']

          attributes :minimum_order_quantity, :order_multiple,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :variant_id do |rule|
            rule.variant&.prefixed_id
          end

          attribute :variant_sku do |rule|
            rule.variant&.sku
          end

          attribute :product_name do |rule|
            rule.variant&.name
          end

          attribute :options_text do |rule|
            rule.variant&.options_text.presence
          end
        end
      end
    end
  end
end
