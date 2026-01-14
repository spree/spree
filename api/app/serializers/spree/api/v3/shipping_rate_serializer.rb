module Spree
  module Api
    module V3
      class ShippingRateSerializer < BaseSerializer
        attributes :id, :name, :selected, :shipping_method_id,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :cost do |shipping_rate|
          shipping_rate.cost.to_f
        end

        attribute :display_cost do |shipping_rate|
          shipping_rate.display_cost.to_s
        end

        attribute :shipping_method_code do |shipping_rate|
          shipping_rate.shipping_method&.code
        end
      end
    end
  end
end
