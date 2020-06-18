module Spree
  class Price < Spree::Base
    include VatPriceCalculation

    acts_as_paranoid

    MAXIMUM_AMOUNT = BigDecimal('99_999_999.99')

    belongs_to :variant, class_name: 'Spree::Variant', inverse_of: :prices, touch: true

    before_validation :ensure_currency

    validates :amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }

    validates :compare_at_amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }

    extend DisplayMoney
    money_methods :amount, :price, :compare_at_amount
    alias display_compare_at_price display_compare_at_amount

    self.whitelisted_ransackable_attributes = ['amount', 'compare_at_amount']

    def money
      Spree::Money.new(amount || 0, currency: currency)
    end

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    def compare_at_money
      Spree::Money.new(compare_at_amount || 0, currency: currency)
    end

    def compare_at_amount=(compare_at_amount)
      self[:compare_at_amount] = Spree::LocalizedNumber.parse(compare_at_amount)
    end

    alias_attribute :price, :amount
    alias_attribute :compare_at_price, :compare_at_amount

    def price_including_vat_for(price_options)
      options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(price, options)
    end

    def compare_at_price_including_vat_for(price_options)
      options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(compare_at_price, options)
    end

    def display_price_including_vat_for(price_options)
      Spree::Money.new(price_including_vat_for(price_options), currency: currency)
    end

    def display_compare_at_price_including_vat_for(price_options)
      Spree::Money.new(compare_at_price_including_vat_for(price_options), currency: currency)
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    private

    def ensure_currency
      self.currency ||= Spree::Config[:currency]
    end
  end
end
