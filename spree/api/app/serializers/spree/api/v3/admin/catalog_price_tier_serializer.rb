module Spree
  module Api
    module V3
      module Admin
        # One rung of a catalog's quantity ladder: from this quantity up, a
        # buyer on this agreement pays this amount
        # (docs/plans/6.0-volume-pricing.md).
        #
        # Serializes a {Spree::CatalogPriceTier}, which is resolved rather
        # than stored, so it carries no id.
        class CatalogPriceTierSerializer < V3::BaseSerializer
          _attributes.delete(:id)

          typelize min_quantity: :number, amount: :string, display_amount: :string

          attributes :min_quantity, :display_amount

          attribute :amount, &:display_value
        end
      end
    end
  end
end
