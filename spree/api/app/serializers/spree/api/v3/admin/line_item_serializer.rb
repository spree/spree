module Spree
  module Api
    module V3
      module Admin
        # Admin API Line Item Serializer
        # Extends the store serializer with metadata visibility
        class LineItemSerializer < V3::LineItemSerializer
          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize price: [:string, nullable: false], display_price: [:string, nullable: false],
                   total: [:string, nullable: false], display_total: [:string, nullable: false],
                   adjustment_total: [:string, nullable: false], display_adjustment_total: [:string, nullable: false],
                   additional_tax_total: [:string, nullable: false], display_additional_tax_total: [:string, nullable: false],
                   included_tax_total: [:string, nullable: false], display_included_tax_total: [:string, nullable: false],
                   discount_total: [:string, nullable: false], display_discount_total: [:string, nullable: false],
                   pre_tax_amount: [:string, nullable: false], display_pre_tax_amount: [:string, nullable: false],
                   discounted_amount: [:string, nullable: false], display_discounted_amount: [:string, nullable: false]

          typelize metadata: 'Record<string, unknown>',
                   cost_price: [:string, nullable: true],
                   tax_category_id: [:string, nullable: true]

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :cost_price do |line_item|
            line_item.cost_price&.to_s
          end

          attribute :tax_category_id do |line_item|
            line_item.tax_category&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          many :option_values, resource: proc { Spree.api.admin_option_value_serializer }
          many :digital_links, resource: proc { Spree.api.admin_digital_link_serializer }

          one :variant,
              resource: proc { Spree.api.admin_variant_serializer },
              if: proc { expand?('variant') }

          one :tax_category,
              resource: proc { Spree.api.admin_tax_category_serializer },
              if: proc { expand?('tax_category') }

          many :adjustments,
               resource: proc { Spree.api.admin_adjustment_serializer },
               if: proc { expand?('adjustments') }
        end
      end
    end
  end
end
