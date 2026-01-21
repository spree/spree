module Spree
  module Api
    module V3
      class ShippingMethodSerializer < BaseSerializer
        attributes :id, :name, :code
      end
    end
  end
end
