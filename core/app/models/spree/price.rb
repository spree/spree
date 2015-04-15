module Spree
  class Price < Spree::Base
    acts_as_paranoid
    belongs_to :variant, class_name: 'Spree::Variant', inverse_of: :prices, touch: true

    validate :check_price
    validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :validate_amount_maximum

    extend DisplayMoney
    money_methods :amount, :price

    def money
      Spree::Money.new(amount || 0, { currency: currency })
    end

    def price
      amount
    end

    def price=(price)
      self[:amount] = Spree::LocalizedNumber.parse(price)
    end

    def price_including_vat_for(zone)
      if !default_zone || !zone || zone == default_zone
        price
      else
        gross_price_for(zone)
      end
    end

    def display_price_including_vat_for(zone)
      Spree::Money.new(price_including_vat_for(zone), currency: currency)
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    private

    def default_zone
      @_default_zone ||= Spree::Zone.default_tax
    end

    def net_price
      @_net_price ||= price / (1 + included_tax_amount(default_zone))
    end

    def gross_price_for(zone)
      round_to_two_places(net_price * (1 + included_tax_amount(zone)))
    end

    def round_to_two_places(amount)
      BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end

    def included_tax_amount(zone = default_zone)
      Spree::TaxRate.included_tax_amount_for(zone, variant.tax_category)
    end

    def check_price
      self.currency ||= Spree::Config[:currency]
    end

    def maximum_amount
      BigDecimal '999999.99'
    end

    def validate_amount_maximum
      if amount && amount > maximum_amount
        errors.add :amount, I18n.t('errors.messages.less_than_or_equal_to', count: maximum_amount)
      end
    end
  end
end
