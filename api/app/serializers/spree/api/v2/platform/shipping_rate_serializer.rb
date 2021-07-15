module Spree
  module Api
    module V2
      module Platform
        class ShippingRateSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          set_type :shipping_rate

          attributes :name, :selected, :final_price, :display_final_price, :cost,
                     :display_cost, :tax_amount, :display_tax_amount, :shipping_method_id

          attribute :free do |shipping_rate|
            shipping_rate.free?
          end
        end
      end
    end
  end
end
