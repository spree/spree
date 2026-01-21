module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        attributes :id, :name, :description, :type
      end
    end
  end
end
