module Spree
  class ShippingRate < ActiveRecord::Base
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod', inverse_of: :shipping_rates
    belongs_to :tax_rate, class_name: 'Spree::TaxRate'

    scope :with_shipping_method,
      -> { includes(:shipping_method).
           references(:shipping_method).
           order("cost ASC") }

    delegate :order, :currency, to: :shipment
    delegate :name, to: :shipping_method

    def display_price
      
    end
    alias_method :display_cost, :display_price

    def shipping_method
      Spree::ShippingMethod.unscoped { super }
    end

    def tax_rate
      Spree::TaxRate.unscoped { super }
    end
  end
end
