module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        typelize_from Spree::PaymentMethod

        attributes :id, :name, :description, :type
      end
    end
  end
end
