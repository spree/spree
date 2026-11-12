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
                   status: [:string, enum: Spree::PriceList.statuses, enum_type_name: 'PriceListStatus'],
                   position: :number,
                   starts_at: 'string | null',
                   ends_at: 'string | null',
                   deleted_at: 'string | null',
                   match_policy: [:string, enum: Spree::PriceList::MATCH_POLICIES, enum_type_name: 'MatchPolicy'],
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

          rate_attributes :price_adjustment_percentage

          attribute :automatic_pricing, &:automatic_pricing?

          attribute :currently_active, &:currently_active?

          # Cheap counts so the index can render "12 products / 36 prices"
          # without forcing each row to expand the children. The index counts
          # the whole page at once; a single list asks for its own.
          attribute :products_count do |pl|
            counts = params[:products_counts]

            (counts || Spree::PriceList.products_count_by_list(pl.id)).fetch(pl.id, 0)
          end

          attribute :prices_count do |pl|
            counts = params[:prices_counts]

            counts ? counts.fetch(pl.id, 0) : pl.prices.count
          end

          # Always expanded: a list's bands are the rest of the sentence its
          # percentage starts, and the pricing card cannot render one without
          # the other.
          many :price_adjustment_tiers,
               resource: proc { Spree.api.admin_price_adjustment_tier_serializer }

          many :price_rules,
               resource: proc { Spree.api.admin_price_rule_serializer },
               if: proc { expand?('price_rules') }
        end
      end
    end
  end
end
