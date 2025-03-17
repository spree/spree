module Spree
  module V2
    module Storefront
      class EstimatedShippingRateSerializer < BaseSerializer
        set_type :shipping_rate

        cache_options store: nil

        attributes :name, :selected, :cost, :tax_amount

        attribute :shipping_method_id do |shipping_rate|
          shipping_rate.shipping_method_id.to_s
        end

        belongs_to :shipping_method

        attribute :final_price do |shipping_rate|
          shipping_rate.cost
        end

        attributes :display_cost, :display_final_price do |object, params|
          Spree::Money.new(object.cost, currency: params[:currency]).to_s
        end

        attribute :display_tax_amount do |object, params|
          Spree::Money.new(object.tax_amount, currency: params[:currency]).to_s
        end

        attribute :free do |object|
          object.cost.zero?
        end
      end
    end
  end
end
