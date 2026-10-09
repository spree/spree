module Spree
  # One rung of a catalog's quantity ladder, as the agreement page reads it:
  # from this quantity up, a buyer on this catalog pays this amount.
  #
  # Resolved rather than stored, like the {Spree::CatalogPrice} it hangs from
  # — a fixed break reads its own row's amount, and a percentage band reads
  # the base price adjusted by that band (docs/plans/6.0-volume-pricing.md).
  class CatalogPriceTier
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :min_quantity, :integer
    attribute :amount, :decimal
    attribute :currency, :string

    validates :min_quantity, numericality: { greater_than: 1 }

    # @return [Spree::Money]
    def money
      Spree::Money.new(amount, currency: currency)
    end

    # @return [String]
    def display_amount
      money.to_s
    end
  end
end
