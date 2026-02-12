module Spree
  class WishedItem < Spree.base_class
    has_prefix_id :wi  # Spree-specific: wished item

    extend DisplayMoney
    money_methods :total, :price

    publishes_lifecycle_events

    belongs_to :variant, class_name: 'Spree::Variant'
    belongs_to :wishlist, class_name: 'Spree::Wishlist'

    has_one :product, class_name: 'Spree::Product', through: :variant

    validates :variant, :wishlist, presence: true
    validates :variant, uniqueness: { scope: [:wishlist] }
    validates :quantity, numericality: { only_integer: true, greater_than: 0 }

    # This is a workaround to allow the variant_id to be set with a prefixed ID
    # in the API.
    #
    # @param id [String] the prefixed ID of the variant
    def variant_id=(id)
      if id.to_s.include?('_')
        decoded = Spree::Variant.decode_prefixed_id(id)
        super(decoded)
      else
        super(id)
      end
    end

    def price(currency)
      variant.amount_in(currency[:currency])
    end

    def total(currency)
      variant_price = variant.amount_in(currency[:currency])

      if variant_price.nil?
        variant_price
      else
        quantity * variant_price
      end
    end
  end
end
