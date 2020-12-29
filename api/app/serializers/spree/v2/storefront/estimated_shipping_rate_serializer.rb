module Spree
  module V2
    module Storefront
      class EstimatedShippingRateSerializer < BaseSerializer
        set_type :shipping_rate

        attributes :name, :selected, :cost, :tax_amount, :shipping_method_id

        attribute :final_price, &:cost

        attributes :display_cost, :display_final_price do |object, params|
          Spree::Money.new(object.cost, currency: params[:currency])
        end

        attribute :display_tax_amount do |object, params|
          Spree::Money.new(object.tax_amount, currency: params[:currency])
        end

        attribute :free do |object|
          object.cost.zero?
        end
      end
    end
  end
end
