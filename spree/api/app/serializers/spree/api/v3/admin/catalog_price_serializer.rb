module Spree
  module Api
    module V3
      module Admin
        # What a buyer on one catalog pays for one product, and where that
        # number came from — an explicit amount on the catalog's own list,
        # that list's percentage applied to the base price, or the base price
        # itself, meaning this agreement does not price the product at all
        # (docs/plans/6.0-catalog-agreement-rework.md).
        #
        # Serializes a {Spree::CatalogPrice}, which is resolved rather than
        # stored, so it carries no id.
        class CatalogPriceSerializer < V3::BaseSerializer
          # Resolved rather than stored, so the id is the priced variant's —
          # the thing a client would actually act on. Null on a reading that
          # names no variant.
          _attributes.delete(:id)

          typelize id: 'string | null', label: 'string | null', sku: 'string | null',
                   amount: :string, display_amount: :string,
                   currency: :string, source: :string, break_count: :number

          # The variant this prices, so a row can name what it is showing —
          # a product's variants can be priced differently, and one figure
          # without a variant beside it names nothing
          # (docs/plans/6.0-volume-pricing.md).
          attribute :id, &:prefixed_id

          attributes :label, :sku

          # How many quantity tiers sit above this amount, so the view can say
          # "and three more from a case up" rather than showing one figure as
          # though it were the only one.
          attributes :currency, :source, :break_count

          attribute :amount, &:display_value

          attributes :display_amount

          # The ladder itself, so the agreement page can show what a buyer
          # pays at each threshold without opening the price sheet
          # (docs/plans/6.0-volume-pricing.md).
          many :tiers, resource: proc { Spree.api.admin_catalog_price_tier_serializer }
        end
      end
    end
  end
end
