module Spree
  # The least a whole order must come to under a catalog's agreement, in one
  # currency. Born per currency — one row each — because Spree holds no
  # exchange rates and a threshold converted at read time is a different
  # promise every day.
  class CatalogOrderMinimum < Spree.base_class
    has_prefix_id :com

    belongs_to :catalog, class_name: 'Spree::Catalog', touch: true, inverse_of: :order_minimums

    validates :currency, presence: true,
                         uniqueness: { scope: [:catalog_id, *spree_base_uniqueness_scope] }
    validates :amount, numericality: { greater_than: 0 }

    normalizes :currency, with: ->(value) { value&.to_s&.strip&.upcase }

    delegate :store, :store_id, to: :catalog

    after_commit -> { Spree::Current.reset_catalog_memos }

    # @return [Spree::Money]
    def display_amount
      Spree::Money.new(amount, currency: currency)
    end
  end
end
