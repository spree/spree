module Spree
  class ShippingRate < ActiveRecord::Base
    belongs_to :shipment
    belongs_to :shipping_method

    attr_accessible :id, :shipping_method, :shipment,
                    :name, :cost, :selected

    delegate :order, :currency, to: :shipment

    def display_price
      if Spree::Config[:shipment_inc_vat]
        price = (1 + Spree::TaxRate.default) * cost
      else
        price = cost
      end

      Spree::Money.new(price, { :currency => currency })
    end
  end
end
