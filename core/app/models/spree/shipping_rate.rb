module Spree
  class ShippingRate < Spree.base_class
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :tax_rate, -> { with_deleted }, class_name: 'Spree::TaxRate'
    belongs_to :shipping_method, -> { with_deleted }, class_name: 'Spree::ShippingMethod', inverse_of: :shipping_rates
    extend Spree::DisplayMoney

    money_methods :base_price, :final_price, :tax_amount

    delegate :order, :currency, :with_free_shipping_promotion?, to: :shipment
    delegate :name, to: :shipping_method
    delegate :code, to: :shipping_method, prefix: true

    def display_price
      price = display_base_price.to_s

      return price if tax_rate.nil? || tax_amount.zero? || !tax_rate.show_rate_in_label

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

    def free?
      final_price.zero?
    end

    def tax_amount
      @tax_amount ||= tax_rate&.calculator&.compute_shipping_rate(self) || BigDecimal(0)
    end

    # returns base price - any available discounts for this Shipment
    # useful when you want to present a list of available shipping rates
    def final_price
      if with_free_shipping_promotion? || cost < -discount_amount
        BigDecimal(0)
      else
        cost + discount_amount
      end
    end

    # Returns the delivery range for the shipping method
    #
    # @return [String]
    def delivery_range
      return unless shipping_method.delivery_range

      shipping_method.delivery_range
    end

    # Returns the display delivery range for the shipping method
    #
    # @return [String]
    def display_delivery_range
      return unless delivery_range

      Spree.t(:display_delivery_range, delivery_range: delivery_range)
    end

    private

    def discount_amount
      shipment.adjustments.promotion.sum(:amount)
    end
  end
end
