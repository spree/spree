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

    # This method shows the price with VAT if the variant has a VAT tax in the default zone.
    def form_field_price
      amount * (1 + included_tax_amount)
    end

    def display_price_adding_vat_for(order)
      zone = order ? order.tax_zone : default_zone
      Spree::Money.new(amount * (1 + included_tax_amount(zone)), currency: currency)
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    def included_tax_amount(zone = default_zone)
      Spree::TaxRate.included_tax_amount_for(zone, variant.tax_category)
    end

    private

    def default_zone
      Spree::Zone.default_tax
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
