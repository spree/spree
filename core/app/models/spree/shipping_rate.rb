module Spree
  class ShippingRate < ActiveRecord::Base
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod'

    scope :with_shipping_method,
      -> { includes(:shipping_method).
           references(:shipping_method).
           order("cost ASC") }
    
    delegate :order, :currency, to: :shipment
    delegate :name, to: :shipping_method

    def display_price
      if Spree::Config[:shipment_inc_vat]
        price = (1 + Spree::TaxRate.default) * cost
      else
        price = cost
      end

      Spree::Money.new(price, { currency: currency })
    end

    alias_method :display_cost, :display_price
  end
end
