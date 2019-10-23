module Spree
  class ShippingRate < Spree::Base
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :tax_rate, class_name: 'Spree::TaxRate'
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod', inverse_of: :shipping_rates

    extend Spree::DisplayMoney

    money_methods :base_price, :final_price, :tax_amount

    delegate :order, :currency, :free?, to: :shipment
    delegate :name,             to: :shipping_method
    delegate :code,             to: :shipping_method, prefix: true

    def display_price
      price = display_base_price.to_s

      return price if tax_rate.nil? || tax_amount.zero?

      Spree.t(
        tax_rate.included_in_price? ? :including_tax : :excluding_tax,
        scope: 'shipping_rates.display_price',
        price: price,
        tax_amount: display_tax_amount,
        tax_rate_name: tax_rate.name
      )
    end
    alias display_cost display_price
    alias_attribute :base_price, :cost

    def tax_amount
      @tax_amount ||= tax_rate&.calculator&.compute_shipping_rate(self) || BigDecimal(0)
    end

    def shipping_method
      Spree::ShippingMethod.unscoped { super }
    end

    def tax_rate
      Spree::TaxRate.unscoped { super }
    end

    # returns base price - any available discounts for this Shipment
    # useful when you want to present a list of available shipping rates
    def final_price
      if free? || cost < -discount_amount
        BigDecimal(0)
      else
        cost + discount_amount
      end
    end

    private

    def discount_amount
      shipment.adjustments.promotion.sum(:amount)
    end
  end
end
