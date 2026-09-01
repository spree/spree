module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PriceList for the admin pricing surface.
        # Price lists are admin-only — there's no Store API counterpart;
        # storefront callers only ever see the *resolved* price (see
        # PriceSerializer#price_list_id), never the list itself.
        class PriceListSerializer < V3::BaseSerializer
          typelize name: :string,
                   description: 'string | null',
                   status: :string,
                   position: :number,
                   starts_at: 'string | null',
                   ends_at: 'string | null',
                   deleted_at: 'string | null',
                   match_policy: :string,
                   price_adjustment_percentage: 'string | null',
                   adjust_compare_at: :boolean,
                   automatic_pricing: :boolean,
                   currently_active: :boolean,
                   products_count: :number,
                   prices_count: :number

          attributes :name, :description, :status, :position, :match_policy,
                     :adjust_compare_at,
                     starts_at: :iso8601, ends_at: :iso8601, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          # A decimal as a string, like every other money-shaped value on the
          # wire — a float would round the merchant's own figure.
          attribute :price_adjustment_percentage do |price_list|
            price_list.price_adjustment_percentage&.to_s
          end

          attribute :automatic_pricing, &:automatic_pricing?

          attribute :currently_active, &:currently_active?

          # Cheap counts so the index can render "12 products / 36 prices"
          # without forcing each row to expand the children.
          attribute :products_count do |pl|
            pl.products.count
          end

          attribute :prices_count do |pl|
            pl.prices.count
          end

          many :price_rules,
               resource: proc { Spree.api.admin_price_rule_serializer },
               if: proc { expand?('price_rules') }
        end
      end
    end
  end
end
