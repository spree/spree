module Spree
  class ShippingRate < ActiveRecord::Base
    belongs_to :shipment, class_name: 'Spree::Shipment'
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod'

    attr_accessible :id, :shipping_method, :shipment,
                    :name, :cost, :selected, :shipping_method_id

    scope :frontend, -> { includes(:shipping_method).where(ShippingMethod.on_frontend_query) }
    scope :backend, -> { includes(:shipping_method).where(ShippingMethod.on_backend_query) }

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

    def shipping_method
      Spree::ShippingMethod.unscoped { super }
    end
  end
end
