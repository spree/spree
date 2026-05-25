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
                   currently_active: :boolean,
                   products_count: :number,
                   prices_count: :number,
                   product_ids: [:string, multi: true]

          attributes :name, :description, :status, :position, :match_policy,
                     starts_at: :iso8601, ends_at: :iso8601, deleted_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :currently_active, &:currently_active?

          # Cheap counts so the index can render "12 products / 36 prices"
          # without forcing each row to expand the children.
          attribute :products_count do |pl|
            pl.products.count
          end

          attribute :prices_count do |pl|
            pl.prices.count
          end

          # Prefixed product ids in the list — drives the SPA's
          # Products picker pre-fill, and is the same payload the
          # client ships back on PATCH to reconcile membership.
          attribute :product_ids, &:product_prefixed_ids

          many :price_rules,
               resource: Spree.api.admin_price_rule_serializer,
               if: proc { expand?('price_rules') }
        end
      end
    end
  end
end
