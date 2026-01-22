module Spree
  module Api
    module V3
      module Store
        class ShippingMethodSerializer < BaseSerializer
          attributes :id, :name, :code
        end
      end
    end
  end
end
