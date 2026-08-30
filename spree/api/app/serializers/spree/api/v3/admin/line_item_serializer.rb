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
                   tax_category_id: [:string, nullable: true],
                   price_source: [:string, nullable: true],
                   catalog_price: [:string, nullable: true]

          # price_source is operational provenance (which pricing engine — or
          # a staff member, 'manual' — set the price), so it is admin-only and
          # never reaches the store serializer.
          attributes :metadata, :price_source,
                     created_at: :iso8601, updated_at: :iso8601

          # What the catalog charges for this variant, so the order editor can
          # show a negotiated line against the price it replaced and preview
          # what a revert restores.
          #
          # The BASE catalog price deliberately — not a resolved one. Resolving
          # would consult the store's pricing provider once per line on a read
          # path the plan keeps provider-free
          # (docs/plans/6.0-third-party-pricing-inventory.md), and this is a
          # comparison figure, not what the revert is contractually promised to
          # produce: the revert re-prices through the resolver, which may land
          # on a price-list or contract amount instead.
          attribute :catalog_price do |line_item|
            line_item.variant&.amount_in(line_item.currency)&.to_s
          end

          attribute :cost_price do |line_item|
            line_item.cost_price&.to_s
          end

          attribute :tax_category_id do |line_item|
            line_item.tax_category&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          many :option_values, resource: proc { Spree.api.admin_option_value_serializer }
          many :digital_links, resource: proc { Spree.api.admin_digital_link_serializer }
          many :tax_lines, resource: proc { Spree.api.admin_tax_line_serializer }, if: proc { expand?('tax_lines') }

          # `seller_id` comes from the store serializer; the expand resolves
          # to the operator's view of the seller rather than the public one.
          one :seller,
              resource: proc { Spree.api.admin_seller_serializer },
              if: proc { expand?('seller') }

          one :variant,
              resource: proc { Spree.api.admin_variant_serializer },
              if: proc { expand?('variant') }

          one :tax_category,
              resource: proc { Spree.api.admin_tax_category_serializer },
              if: proc { expand?('tax_category') }

        end
      end
    end
  end
end
